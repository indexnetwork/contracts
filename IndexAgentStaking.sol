// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title IndexAgentStaking
 * @dev Staking contract for Index Network agents to stake on intent connections
 * Agents stake MON tokens on their connection predictions and earn rewards for successful matches
 */
contract IndexAgentStaking is ReentrancyGuard, Ownable, Pausable {
    struct Stake {
        uint256 id;
        address agent;
        string[] intentIds;
        uint256 amount;
        string reasoning;
        uint256 timestamp;
        StakeStatus status;
        uint256 rewardAmount;
        uint256 slashAmount;
    }

    enum StakeStatus {
        ACTIVE,
        SUCCESSFUL,
        FAILED,
        SLASHED,
        WITHDRAWN
    }

    // State variables
    mapping(uint256 => Stake) public stakes;
    mapping(address => uint256[]) public agentStakes;
    mapping(string => uint256[]) public intentStakes;
    mapping(address => uint256) public agentTotalStaked;
    mapping(address => uint256) public agentRewardsEarned;
    mapping(address => bool) public authorizedSlashers;

    uint256 public nextStakeId;
    uint256 public totalStaked;
    uint256 public totalRewardsDistributed;
    uint256 public minStakeAmount;
    uint256 public maxStakeAmount;
    uint256 public rewardMultiplier; // Basis points (10000 = 100%)
    uint256 public slashingPenalty; // Basis points (10000 = 100%)

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant STAKE_DURATION = 7 days;

    // Events
    event StakeCreated(
        uint256 indexed stakeId,
        address indexed agent,
        string[] intentIds,
        uint256 amount,
        string reasoning
    );

    event StakeResolved(
        uint256 indexed stakeId,
        address indexed agent,
        bool successful,
        uint256 rewardAmount
    );

    event StakeSlashed(
        uint256 indexed stakeId,
        address indexed agent,
        uint256 slashAmount,
        address indexed slasher
    );

    event RewardsClaimed(
        address indexed agent,
        uint256 amount
    );

    event StakeWithdrawn(
        uint256 indexed stakeId,
        address indexed agent,
        uint256 amount
    );

    constructor(
        uint256 _minStakeAmount,
        uint256 _maxStakeAmount,
        uint256 _rewardMultiplier,
        uint256 _slashingPenalty
    ) {
        minStakeAmount = _minStakeAmount;
        maxStakeAmount = _maxStakeAmount;
        rewardMultiplier = _rewardMultiplier;
        slashingPenalty = _slashingPenalty;
        nextStakeId = 1;
    }

    /**
     * @dev Stake MON tokens on intent connections
     * @param intentIds Array of intent IDs being connected
     * @param reasoning Agent's explanation for the connection
     */
    function stakeOnConnection(
        string[] calldata intentIds,
        string calldata reasoning
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        require(msg.value >= minStakeAmount, "Stake amount too low");
        require(msg.value <= maxStakeAmount, "Stake amount too high");
        require(intentIds.length >= 2, "Must connect at least 2 intents");
        require(bytes(reasoning).length > 0, "Reasoning required");

        uint256 stakeId = nextStakeId++;

        stakes[stakeId] = Stake({
            id: stakeId,
            agent: msg.sender,
            intentIds: intentIds,
            amount: msg.value,
            reasoning: reasoning,
            timestamp: block.timestamp,
            status: StakeStatus.ACTIVE,
            rewardAmount: 0,
            slashAmount: 0
        });

        agentStakes[msg.sender].push(stakeId);
        agentTotalStaked[msg.sender] += msg.value;
        totalStaked += msg.value;

        // Add stake to intent mappings
        for (uint i = 0; i < intentIds.length; i++) {
            intentStakes[intentIds[i]].push(stakeId);
        }

        emit StakeCreated(stakeId, msg.sender, intentIds, msg.value, reasoning);

        return stakeId;
    }

    /**
     * @dev Resolve stake as successful and distribute rewards
     * @param stakeId The stake ID to resolve
     */
    function resolveStakeSuccessful(uint256 stakeId) external onlyOwner {
        Stake storage stake = stakes[stakeId];
        require(stake.status == StakeStatus.ACTIVE, "Stake not active");
        require(stake.agent != address(0), "Stake does not exist");

        uint256 rewardAmount = (stake.amount * rewardMultiplier) / BASIS_POINTS;
        
        stake.status = StakeStatus.SUCCESSFUL;
        stake.rewardAmount = rewardAmount;
        
        agentRewardsEarned[stake.agent] += rewardAmount;
        totalRewardsDistributed += rewardAmount;

        emit StakeResolved(stakeId, stake.agent, true, rewardAmount);
    }

    /**
     * @dev Resolve stake as failed (no reward, but no slashing)
     * @param stakeId The stake ID to resolve
     */
    function resolveStakeFailed(uint256 stakeId) external onlyOwner {
        Stake storage stake = stakes[stakeId];
        require(stake.status == StakeStatus.ACTIVE, "Stake not active");
        require(stake.agent != address(0), "Stake does not exist");

        stake.status = StakeStatus.FAILED;

        emit StakeResolved(stakeId, stake.agent, false, 0);
    }

    /**
     * @dev Slash stake for malicious behavior
     * @param stakeId The stake ID to slash
     * @param reason Reason for slashing
     */
    function slashStake(uint256 stakeId, string calldata reason) external {
        require(authorizedSlashers[msg.sender] || msg.sender == owner(), "Not authorized to slash");
        
        Stake storage stake = stakes[stakeId];
        require(stake.status == StakeStatus.ACTIVE, "Stake not active");
        require(stake.agent != address(0), "Stake does not exist");

        uint256 slashAmount = (stake.amount * slashingPenalty) / BASIS_POINTS;
        
        stake.status = StakeStatus.SLASHED;
        stake.slashAmount = slashAmount;
        
        agentTotalStaked[stake.agent] -= stake.amount;
        totalStaked -= stake.amount;

        emit StakeSlashed(stakeId, stake.agent, slashAmount, msg.sender);
    }

    /**
     * @dev Claim accumulated rewards
     */
    function claimRewards() external nonReentrant {
        uint256 rewardAmount = agentRewardsEarned[msg.sender];
        require(rewardAmount > 0, "No rewards to claim");
        require(address(this).balance >= rewardAmount, "Insufficient contract balance");

        agentRewardsEarned[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: rewardAmount}("");
        require(success, "Reward transfer failed");

        emit RewardsClaimed(msg.sender, rewardAmount);
    }

    /**
     * @dev Withdraw stake after resolution
     * @param stakeId The stake ID to withdraw
     */
    function withdrawStake(uint256 stakeId) external nonReentrant {
        Stake storage stake = stakes[stakeId];
        require(stake.agent == msg.sender, "Not stake owner");
        require(
            stake.status == StakeStatus.SUCCESSFUL || 
            stake.status == StakeStatus.FAILED, 
            "Stake not resolved"
        );
        require(
            block.timestamp >= stake.timestamp + STAKE_DURATION,
            "Stake duration not met"
        );

        uint256 withdrawAmount = stake.amount;
        stake.status = StakeStatus.WITHDRAWN;
        
        agentTotalStaked[msg.sender] -= withdrawAmount;
        totalStaked -= withdrawAmount;

        (bool success, ) = payable(msg.sender).call{value: withdrawAmount}("");
        require(success, "Withdrawal failed");

        emit StakeWithdrawn(stakeId, msg.sender, withdrawAmount);
    }

    /**
     * @dev Get stakes for a specific intent
     * @param intentId The intent ID
     * @return Array of stake IDs
     */
    function getStakesForIntent(string calldata intentId) external view returns (uint256[] memory) {
        return intentStakes[intentId];
    }

    /**
     * @dev Get stakes for a specific agent
     * @param agent The agent address
     * @return Array of stake IDs
     */
    function getAgentStakes(address agent) external view returns (uint256[] memory) {
        return agentStakes[agent];
    }

    /**
     * @dev Get stake details
     * @param stakeId The stake ID
     * @return Stake struct
     */
    function getStake(uint256 stakeId) external view returns (Stake memory) {
        return stakes[stakeId];
    }

    /**
     * @dev Get agent statistics
     * @param agent The agent address
     * @return totalStaked Total amount staked by agent
     * @return rewardsEarned Total rewards earned by agent
     * @return activeStakes Number of active stakes
     */
    function getAgentStats(address agent) external view returns (
        uint256 totalStaked_,
        uint256 rewardsEarned,
        uint256 activeStakes
    ) {
        totalStaked_ = agentTotalStaked[agent];
        rewardsEarned = agentRewardsEarned[agent];
        
        uint256[] memory stakes_ = agentStakes[agent];
        for (uint i = 0; i < stakes_.length; i++) {
            if (stakes[stakes_[i]].status == StakeStatus.ACTIVE) {
                activeStakes++;
            }
        }
    }

    // Admin functions

    /**
     * @dev Add authorized slasher
     * @param slasher Address to authorize for slashing
     */
    function addAuthorizedSlasher(address slasher) external onlyOwner {
        authorizedSlashers[slasher] = true;
    }

    /**
     * @dev Remove authorized slasher
     * @param slasher Address to remove from slashing authorization
     */
    function removeAuthorizedSlasher(address slasher) external onlyOwner {
        authorizedSlashers[slasher] = false;
    }

    /**
     * @dev Update staking parameters
     */
    function updateStakingParameters(
        uint256 _minStakeAmount,
        uint256 _maxStakeAmount,
        uint256 _rewardMultiplier,
        uint256 _slashingPenalty
    ) external onlyOwner {
        minStakeAmount = _minStakeAmount;
        maxStakeAmount = _maxStakeAmount;
        rewardMultiplier = _rewardMultiplier;
        slashingPenalty = _slashingPenalty;
    }

    /**
     * @dev Fund contract with rewards
     */
    function fundRewards() external payable onlyOwner {
        // Allow owner to fund the contract with MON for rewards
    }

    /**
     * @dev Emergency withdraw (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Emergency withdrawal failed");
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Receive function to accept MON
     */
    receive() external payable {}
}
