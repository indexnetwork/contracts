const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("IndexAgentStaking", function () {
  let indexAgentStaking;
  let owner;
  let agent1;
  let agent2;
  let slasher;

  const minStakeAmount = ethers.parseEther("0.01");
  const maxStakeAmount = ethers.parseEther("0.5");
  const rewardMultiplier = 1500; // 15%
  const slashingPenalty = 2000; // 20%

  beforeEach(async function () {
    [owner, agent1, agent2, slasher] = await ethers.getSigners();

    const IndexAgentStaking = await ethers.getContractFactory("IndexAgentStaking");
    indexAgentStaking = await IndexAgentStaking.deploy(
      minStakeAmount,
      maxStakeAmount,
      rewardMultiplier,
      slashingPenalty
    );
    await indexAgentStaking.waitForDeployment();

    // Fund contract with rewards
    await indexAgentStaking.fundRewards({ value: ethers.parseEther("0.1") });

    // Add authorized slasher
    await indexAgentStaking.addAuthorizedSlasher(slasher.address);
  });

  describe("Deployment", function () {
    it("Should set the correct parameters", async function () {
      expect(await indexAgentStaking.minStakeAmount()).to.equal(minStakeAmount);
      expect(await indexAgentStaking.maxStakeAmount()).to.equal(maxStakeAmount);
      expect(await indexAgentStaking.rewardMultiplier()).to.equal(rewardMultiplier);
      expect(await indexAgentStaking.slashingPenalty()).to.equal(slashingPenalty);
    });

    it("Should set the correct owner", async function () {
      expect(await indexAgentStaking.owner()).to.equal(owner.address);
    });
  });

  describe("Staking", function () {
    it("Should allow agents to stake on connections", async function () {
      const stakeAmount = ethers.parseEther("0.05");
      const intentIds = ["intent1", "intent2"];
      const reasoning = "These users should connect";

      const tx = await indexAgentStaking.connect(agent1).stakeOnConnection(
        intentIds,
        reasoning,
        { value: stakeAmount }
      );

      await expect(tx)
        .to.emit(indexAgentStaking, "StakeCreated")
        .withArgs(1, agent1.address, intentIds, stakeAmount, reasoning);

      const stake = await indexAgentStaking.getStake(1);
      expect(stake.agent).to.equal(agent1.address);
      expect(stake.amount).to.equal(stakeAmount);
      expect(stake.reasoning).to.equal(reasoning);
      expect(stake.status).to.equal(0); // ACTIVE
    });

    it("Should reject stakes below minimum amount", async function () {
      const stakeAmount = ethers.parseEther("0.005");
      const intentIds = ["intent1", "intent2"];
      const reasoning = "Test reasoning";

      await expect(
        indexAgentStaking.connect(agent1).stakeOnConnection(
          intentIds,
          reasoning,
          { value: stakeAmount }
        )
      ).to.be.revertedWith("Stake amount too low");
    });

    it("Should reject stakes above maximum amount", async function () {
      const stakeAmount = ethers.parseEther("0.6");
      const intentIds = ["intent1", "intent2"];
      const reasoning = "Test reasoning";

      await expect(
        indexAgentStaking.connect(agent1).stakeOnConnection(
          intentIds,
          reasoning,
          { value: stakeAmount }
        )
      ).to.be.revertedWith("Stake amount too high");
    });
  });

  describe("Stake Resolution", function () {
    beforeEach(async function () {
      // Create a stake
      await indexAgentStaking.connect(agent1).stakeOnConnection(
        ["intent1", "intent2"],
        "Test connection",
        { value: ethers.parseEther("0.05") }
      );
    });

    it("Should resolve stake as successful and distribute rewards", async function () {
      await indexAgentStaking.resolveStakeSuccessful(1);

      const stake = await indexAgentStaking.getStake(1);
      expect(stake.status).to.equal(1); // SUCCESSFUL

      const expectedReward = ethers.parseEther("0.05") * BigInt(rewardMultiplier) / BigInt(10000);
      expect(stake.rewardAmount).to.equal(expectedReward);

      const agentRewards = await indexAgentStaking.agentRewardsEarned(agent1.address);
      expect(agentRewards).to.equal(expectedReward);
    });

    it("Should resolve stake as failed", async function () {
      await indexAgentStaking.resolveStakeFailed(1);

      const stake = await indexAgentStaking.getStake(1);
      expect(stake.status).to.equal(2); // FAILED
      expect(stake.rewardAmount).to.equal(0);
    });

    it("Should allow slashing of stakes", async function () {
      const tx = await indexAgentStaking.connect(slasher).slashStake(1, "Malicious behavior");

      await expect(tx)
        .to.emit(indexAgentStaking, "StakeSlashed")
        .withArgs(1, agent1.address, ethers.parseEther("0.01"), slasher.address);

      const stake = await indexAgentStaking.getStake(1);
      expect(stake.status).to.equal(3); // SLASHED
    });
  });

  describe("Rewards", function () {
    it("Should allow agents to claim rewards", async function () {
      // Create and resolve successful stake
      await indexAgentStaking.connect(agent1).stakeOnConnection(
        ["intent1", "intent2"],
        "Test connection",
        { value: ethers.parseEther("0.05") }
      );
      await indexAgentStaking.resolveStakeSuccessful(1);

      const initialBalance = await ethers.provider.getBalance(agent1.address);
      
      const tx = await indexAgentStaking.connect(agent1).claimRewards();
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;

      const finalBalance = await ethers.provider.getBalance(agent1.address);
      const expectedReward = ethers.parseEther("0.0075"); // 15% of 0.05 MON

      expect(finalBalance - initialBalance + gasUsed).to.equal(expectedReward);
    });
  });

  describe("Agent Statistics", function () {
    it("Should track agent statistics correctly", async function () {
      await indexAgentStaking.connect(agent1).stakeOnConnection(
        ["intent1", "intent2"],
        "Test connection 1",
        { value: ethers.parseEther("0.05") }
      );

      await indexAgentStaking.connect(agent1).stakeOnConnection(
        ["intent3", "intent4"],
        "Test connection 2",
        { value: ethers.parseEther("0.1") }
      );

      const [totalStaked, rewardsEarned, activeStakes] = await indexAgentStaking.getAgentStats(agent1.address);
      
      expect(totalStaked).to.equal(ethers.parseEther("0.15"));
      expect(rewardsEarned).to.equal(0);
      expect(activeStakes).to.equal(2);
    });
  });
});
