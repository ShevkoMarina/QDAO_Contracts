// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  var adminAddress = "0x75c09fb19051f8F13B0C8BdD7e7c3BE123821C77";

  const QDAOGovernor = await ethers.getContractFactory("QDAOGovernor");
  const governor = await QDAOGovernor.deploy();
  console.log("QDAOGovernor deployed to address:", governor.address);

  var timelock = "0x9B3aeDe960AAdcb366841fB4bc99eC0E2E692c52";
  var token = "0xF9c7C95a4BBE357120726ECE972Ffed59B6087A3";
  const QDAOGovernorDelegator = await ethers.getContractFactory("QDAOGovernorDelegator");
  const delegator = await QDAOGovernorDelegator.deploy(timelock, token, adminAddress, governor.address, 5, 5);
  console.log("QDAODelegator deployed to address:", delegator.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
