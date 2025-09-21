const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying IndexAgentStaking to Monad Testnet...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Check balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "MON");

  // Deployment parameters
  const minStakeAmount = ethers.parseEther("0.01"); // 0.01 MON minimum
  const maxStakeAmount = ethers.parseEther("0.5"); // 0.5 MON maximum
  const rewardMultiplier = 1500; // 15% reward (1500 basis points)
  const slashingPenalty = 2000; // 20% slashing penalty (2000 basis points)

  console.log("Deployment parameters:");
  console.log("- Min stake amount:", ethers.formatEther(minStakeAmount), "MON");
  console.log("- Max stake amount:", ethers.formatEther(maxStakeAmount), "MON");
  console.log("- Reward multiplier:", rewardMultiplier / 100, "%");
  console.log("- Slashing penalty:", slashingPenalty / 100, "%");

  // Deploy the contract
  const IndexAgentStaking = await ethers.getContractFactory("IndexAgentStaking");
  const indexAgentStaking = await IndexAgentStaking.deploy(
    minStakeAmount,
    maxStakeAmount,
    rewardMultiplier,
    slashingPenalty
  );

  await indexAgentStaking.waitForDeployment();

  const contractAddress = await indexAgentStaking.getAddress();
  console.log("IndexAgentStaking deployed to:", contractAddress);

  // Fund the contract with some initial rewards
  const fundAmount = ethers.parseEther("0.1"); // 0.1 MON for rewards
  console.log("Funding contract with", ethers.formatEther(fundAmount), "MON for rewards...");
  
  const fundTx = await indexAgentStaking.fundRewards({ value: fundAmount });
  await fundTx.wait();
  console.log("Contract funded successfully");

  // Verify deployment
  const contractBalance = await ethers.provider.getBalance(contractAddress);
  console.log("Contract balance:", ethers.formatEther(contractBalance), "MON");

  console.log("\n=== Deployment Summary ===");
  console.log("Network: Monad Testnet");
  console.log("Contract Address:", contractAddress);
  console.log("Deployer:", deployer.address);
  console.log("Transaction Hash:", indexAgentStaking.deploymentTransaction().hash);
  console.log("Block Number:", indexAgentStaking.deploymentTransaction().blockNumber);

  console.log("\n=== Contract Interaction Examples ===");
  console.log("To stake on a connection:");
  console.log(`await contract.stakeOnConnection(["intent1", "intent2"], "Reasoning for connection", { value: ethers.parseEther("1") });`);
  
  console.log("\nTo check agent stats:");
  console.log(`await contract.getAgentStats("${deployer.address}");`);

  console.log("\n=== Explorer Link ===");
  console.log(`https://testnet.monadexplorer.com/address/${contractAddress}`);

  // Save deployment info
  const deploymentInfo = {
    network: "monad-testnet",
    contractAddress: contractAddress,
    deployerAddress: deployer.address,
    transactionHash: indexAgentStaking.deploymentTransaction().hash,
    blockNumber: indexAgentStaking.deploymentTransaction().blockNumber,
    timestamp: new Date().toISOString(),
    parameters: {
      minStakeAmount: minStakeAmount.toString(),
      maxStakeAmount: maxStakeAmount.toString(),
      rewardMultiplier,
      slashingPenalty
    }
  };

  const fs = require('fs');
  fs.writeFileSync(
    'deployment-info.json',
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("\nDeployment info saved to deployment-info.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
