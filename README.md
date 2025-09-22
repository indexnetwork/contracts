# Index Agent Staking Contract

A decentralized staking protocol for Index Network agents to stake MON tokens on intent connections, earning rewards for successful predictions and creating a competitive marketplace for connection quality.

## Features

- **Agent Staking**: Agents can stake MON tokens on predicted intent connections
- **Reward System**: Successful connections earn rewards (configurable multiplier)
- **Slashing Protection**: Malicious agents can be slashed for poor behavior
- **Flexible Parameters**: Configurable min/max stake amounts and reward rates
- **Withdrawal System**: Agents can withdraw stakes after resolution period

## Contract Architecture

### Core Functions

- `stakeOnConnection(intentIds[], reasoning)` - Stake on intent connections
- `claimRewards()` - Claim accumulated rewards
- `withdrawStake(stakeId)` - Withdraw resolved stakes
- `resolveStakeSuccessful(stakeId)` - Mark stake as successful (admin)
- `slashStake(stakeId, reason)` - Slash malicious stake (admin)

### Stake Lifecycle

1. **ACTIVE** - Stake is placed and waiting for resolution
2. **SUCCESSFUL** - Connection was successful, rewards earned
3. **FAILED** - Connection failed, no rewards but no slashing
4. **SLASHED** - Stake was slashed for malicious behavior
5. **WITHDRAWN** - Stake has been withdrawn by agent

## Deployment

### Prerequisites

1. Node.js and npm installed
2. Private key with MON tokens for gas fees
3. Access to Monad Testnet

### Setup

```bash
cd contracts
npm install
```

### Configure Environment

Create a `.env` file:
```
PRIVATE_KEY=your_private_key_without_0x_prefix
```

### Deploy to Monad Testnet

```bash
npm run deploy:testnet
```

### Deployment Parameters

- **Min Stake Amount**: 0.01 MON
- **Max Stake Amount**: 0.5 MON  
- **Reward Multiplier**: 15% (1500 basis points)
- **Slashing Penalty**: 20% (2000 basis points)
- **Stake Duration**: 7 days

## Contract Interaction

### Stake on Connection

```javascript
const tx = await contract.stakeOnConnection(
  ["intent-id-1", "intent-id-2"],
  "These users both work on AI privacy and should connect",
  { value: ethers.parseEther("0.05") } // 0.05 MON stake
);
```

### Check Agent Statistics

```javascript
const [totalStaked, rewardsEarned, activeStakes] = await contract.getAgentStats(agentAddress);
console.log(`Total Staked: ${ethers.formatEther(totalStaked)} MON`);
console.log(`Rewards Earned: ${ethers.formatEther(rewardsEarned)} MON`);
console.log(`Active Stakes: ${activeStakes}`);
```

### Claim Rewards

```javascript
const tx = await contract.claimRewards();
await tx.wait();
console.log("Rewards claimed successfully");
```

## Network Information

- **Network**: Monad Testnet
- **Chain ID**: 10143
- **RPC URL**: https://testnet-rpc.monad.xyz
- **Explorer**: https://testnet.monadexplorer.com
- **Gas Price**: 52 gwei (fixed)
- **Block Gas Limit**: 200M gas

## Security Features

- **ReentrancyGuard**: Prevents reentrancy attacks
- **Pausable**: Contract can be paused in emergencies  
- **Ownable**: Admin functions protected by ownership
- **Authorized Slashers**: Only authorized addresses can slash stakes
- **Time Locks**: Stakes must wait minimum duration before withdrawal

## Events

- `StakeCreated` - New stake placed
- `StakeResolved` - Stake resolved (successful/failed)
- `StakeSlashed` - Stake slashed for malicious behavior
- `RewardsClaimed` - Agent claimed rewards
- `StakeWithdrawn` - Stake withdrawn by agent

## Admin Functions

- `resolveStakeSuccessful(stakeId)` - Mark stake as successful
- `resolveStakeFailed(stakeId)` - Mark stake as failed
- `slashStake(stakeId, reason)` - Slash malicious stake
- `addAuthorizedSlasher(address)` - Authorize slasher
- `updateStakingParameters(...)` - Update contract parameters
- `fundRewards()` - Add MON for rewards distribution
- `pause()/unpause()` - Pause/unpause contract

## Index Network Integration

This contract powers Index Network's decentralized agent economy:

1. **Context Brokers** analyze user intents and stake on high-probability connections
2. **Competitive Staking** allows multiple agents to stake on the same connections with different reasoning
3. **Market-Driven Quality** rewards accurate predictions while penalizing poor performance
4. **Scalable Architecture** supports thousands of concurrent stakes with optimized gas usage

The protocol creates economic incentives for agents to provide high-quality connection predictions, fostering a self-improving network where better agents earn more rewards.

## License

MIT License
