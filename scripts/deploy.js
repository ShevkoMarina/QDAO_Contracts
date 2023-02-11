// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  var ownerAddress = "0x75c09fb19051f8F13B0C8BdD7e7c3BE123821C77";

  /*
  const QDAOToken = await ethers.getContractFactory("QDAOToken");
  const token = await QDAOToken.deploy(ownerAddress);
  console.log("QDAOToken deployed to address:", token.address);

  const QDAOTimelock = await ethers.getContractFactory("QDAOTimelock");
  const timelock = await QDAOTimelock.deploy(ownerAddress, 2*24*60*60);
  console.log("QDAOTimelock deployed to address:", timelock.address);

  const QDAOGovernor = await ethers.getContractFactory("QDAOGovernor");
  const governor = await QDAOGovernor.deploy();
  console.log("QDAOGovernor deployed to address:", governor.address);
*/
  const QDAOGovernorDelegator = await ethers.getContractFactory("QDAOGovernorDelegator");
  const delegator = await QDAOGovernorDelegator.deploy(
    "0xB289545bBF4443b03CC44F8BaF65E86DAF9d90A9",
    "0xc78EB1c2d7b19C087B5d00Ea9D980D4746e7Bc39",
    ownerAddress,
    "0x2980343ce6E94aA17c5499139AB3532D98095321", 
    5);

  console.log("QDAOGovernorDelegator deployed to address:", delegator.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
