# Index Agent Staking Smart Contract

A smart contract for Index Network agents to stake MON tokens on intent connections and earn rewards for successful matches.

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
- **RPC URL**: https://testnet1.monad.xyz
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

## Integration with Index Network

This contract is designed to integrate with Index Network's agent architecture:

1. **Context Brokers** stake on intent connections they identify
2. **Successful connections** result in rewards for the broker
3. **Failed connections** return stake without penalty
4. **Malicious behavior** results in slashing

The contract supports Index's multi-agent architecture where different agents can stake on the same connections with different reasoning, creating a competitive market for connection quality.

## License

MIT License
