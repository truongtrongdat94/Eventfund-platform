// Deploy script for EventFund contracts
// This script deploys Fund, Ticket, and Marketplace contracts to the specified network

const hre = require("hardhat");

async function main() {
  console.log(" Starting contract deployment...\n");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log(" Deploying contracts with account:", deployer.address);
  console.log(" Account balance:", hre.ethers.formatEther(await hre.ethers.provider.getBalance(deployer.address)), "ETH\n");

  // ===== Deploy Fund Contract =====
  console.log(" Deploying Fund contract...");
  const Fund = await hre.ethers.getContractFactory("Fund");
  const fund = await Fund.deploy();
  await fund.waitForDeployment();
  const fundAddress = await fund.getAddress();
  console.log(" Fund deployed to:", fundAddress);

  // ===== Deploy Ticket Contract =====
  console.log("\n Deploying Ticket contract...");
  const Ticket = await hre.ethers.getContractFactory("Ticket");
  const ticket = await Ticket.deploy();
  await ticket.waitForDeployment();
  const ticketAddress = await ticket.getAddress();
  console.log(" Ticket deployed to:", ticketAddress);

  // ===== Deploy Marketplace Contract =====
  console.log("\n Deploying Marketplace contract...");
  const Marketplace = await hre.ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy(
    ticketAddress,  // ticket NFT address
    fundAddress,    // fund contract address
    500             // 5% royalty (500 basis points)
  );
  await marketplace.waitForDeployment();
  const marketplaceAddress = await marketplace.getAddress();
  console.log(" Marketplace deployed to:", marketplaceAddress);

  // ===== Setup Contract Connections =====
  console.log("\n Setting up contract connections...");

  // Fund: Set Ticket contract
  console.log("Setting Ticket contract in Fund...");
  const setTicketTx = await fund.setTicketContract(ticketAddress);
  await setTicketTx.wait();
  console.log(" Ticket contract set in Fund");

  // Fund: Set Marketplace contract
  console.log("Setting Marketplace contract in Fund...");
  const setMarketplaceTx = await fund.setMarketplaceContract(marketplaceAddress);
  await setMarketplaceTx.wait();
  console.log(" Marketplace contract set in Fund");

  // Ticket: Set Fund contract
  console.log("Setting Fund contract in Ticket...");
  const setFundTx = await ticket.setFundContract(fundAddress);
  await setFundTx.wait();
  console.log(" Fund contract set in Ticket");

  // ===== Deployment Summary =====
  console.log("\n" + "=".repeat(60));
  console.log(" Deployment completed successfully!");
  console.log("=".repeat(60));
  console.log("\n Contract Addresses:");
  console.log("   Fund:        ", fundAddress);
  console.log("   Ticket:      ", ticketAddress);
  console.log("   Marketplace: ", marketplaceAddress);
  console.log("\n Etherscan Links:");
  console.log("   Fund:        ", `https://sepolia.etherscan.io/address/${fundAddress}`);
  console.log("   Ticket:      ", `https://sepolia.etherscan.io/address/${ticketAddress}`);
  console.log("   Marketplace: ", `https://sepolia.etherscan.io/address/${marketplaceAddress}`);
  console.log("\n Save these addresses to your .env file:");
  console.log(`FUND_ADDRESS=${fundAddress}`);
  console.log(`TICKET_ADDRESS=${ticketAddress}`);
  console.log(`MARKETPLACE_ADDRESS=${marketplaceAddress}`);
  console.log("\n" + "=".repeat(60) + "\n");
}

// Execute deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n Deployment failed:");
    console.error(error);
    process.exit(1);
  });
