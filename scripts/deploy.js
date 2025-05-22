const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🚀 Starting deployment of Decentralized Amazon Platform...\n");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  
  console.log("📝 Deployment Details:");
  console.log("Deploying contracts with account:", deployerAddress);
  
  // Get balance
  const balance = await ethers.provider.getBalance(deployerAddress);
  console.log("Account balance:", ethers.utils.formatEther(balance), "CORE");
  
  // Get network information
  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name || "Unknown");
  console.log("Chain ID:", network.chainId);
  console.log("Block number:", await ethers.provider.getBlockNumber());
  console.log("─".repeat(50));

  // Deploy the contract
  console.log("\n📦 Deploying DecentralizedAmazonPlatform contract...");
  
  const DecentralizedAmazonPlatform = await ethers.getContractFactory("DecentralizedAmazonPlatform");
  
  // Estimate gas for deployment
  const deploymentData = DecentralizedAmazonPlatform.getDeployTransaction();
  const gasEstimate = await ethers.provider.estimateGas(deploymentData);
  console.log("Estimated gas for deployment:", gasEstimate.toString());
  
  // Deploy with estimated gas and some buffer
  const gasLimit = gasEstimate.mul(120).div(100); // Add 20% buffer
  
  const decentralizedAmazon = await DecentralizedAmazonPlatform.deploy({
    gasLimit: gasLimit
  });

  console.log("⏳ Waiting for deployment transaction to be mined...");
  await decentralizedAmazon.deployed();

  console.log("\n✅ Deployment Successful!");
  console.log("Contract Address:", decentralizedAmazon.address);
  console.log("Transaction Hash:", decentralizedAmazon.deployTransaction.hash);
  console.log("Gas Used:", decentralizedAmazon.deployTransaction.gasLimit?.toString());
  console.log("Deployer Address:", deployerAddress);

  // Verify contract deployment
  console.log("\n🔍 Verifying deployment...");
  const owner = await decentralizedAmazon.owner();
  const productCounter = await decentralizedAmazon.productCounter();
  const orderCounter = await decentralizedAmazon.orderCounter();
  
  console.log("Contract Owner:", owner);
  console.log("Initial Product Counter:", productCounter.toString());
  console.log("Initial Order Counter:", orderCounter.toString());

  // Save deployment information
  const deploymentInfo = {
    network: network.name || "core_testnet2",
    chainId: network.chainId,
    contractAddress: decentralizedAmazon.address,
    deployerAddress: deployerAddress,
    transactionHash: decentralizedAmazon.deployTransaction.hash,
    blockNumber: decentralizedAmazon.deployTransaction.blockNumber,
    gasUsed: decentralizedAmazon.deployTransaction.gasLimit?.toString(),
    timestamp: new Date().toISOString(),
  };

  // Create deployments directory if it doesn't exist
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  // Save deployment info to file
  const deploymentFile = path.join(deploymentsDir, `${network.name || "core_testnet2"}_deployment.json`);
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  
  console.log("\n💾 Deployment information saved to:", deploymentFile);

  // Generate ABI file
  const contractArtifact = await hre.artifacts.readArtifact("DecentralizedAmazonPlatform");
  const abiFile = path.join(deploymentsDir, "DecentralizedAmazonPlatform_ABI.json");
  fs.writeFileSync(abiFile, JSON.stringify(contractArtifact.abi, null, 2));
  
  console.log("📄 Contract ABI saved to:", abiFile);

  // Display useful information for frontend integration
  console.log("\n🎯 Frontend Integration Information:");
  console.log("─".repeat(50));
  console.log("Contract Address:", decentralizedAmazon.address);
  console.log("Network:", network.name || "Core Testnet 2");
  console.log("Chain ID:", network.chainId);
  console.log("Explorer URL:", network.chainId === 1116 ? 
    `https://scan.test2.btcs.network/address/${decentralizedAmazon.address}` : 
    "Check network explorer");

  console.log("\n📋 Next Steps:");
  console.log("1. Update your .env file with the contract address");
  console.log("2. Update frontend configuration with the new contract address");
  console.log("3. Test the contract functions using the provided scripts");
  console.log("4. Consider verifying the contract on the block explorer");

  // Sample interaction (optional)
  if (process.env.TEST_DEPLOYMENT === "true") {
    console.log("\n🧪 Running deployment test...");
    
    try {
      // Test listing a product
      const tx = await decentralizedAmazon.listProduct(
        "Test Product",
        "This is a test product for deployment verification",
        ethers.utils.parseEther("0.1"),
        10,
        "QmTestHash"
      );
      
      await tx.wait();
      console.log("✅ Test product listed successfully");
      
      const newProductCounter = await decentralizedAmazon.productCounter();
      console.log("Updated Product Counter:", newProductCounter.toString());
      
    } catch (error) {
      console.log("❌ Test failed:", error.message);
    }
  }

  console.log("\n🎉 Deployment Complete!");
  console.log("Contract is ready for use on Core Testnet 2");
}

// Error handling
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });
