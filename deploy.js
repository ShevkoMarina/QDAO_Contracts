const { ethers } = require('hardhat');


async function main() {
  try {
    const deployedAddresses = await deploy();
  } 
  catch (error) {
    console.error('Error deploying constracts: ', error);
  }
}

async function deploy() {

  // засетить таймлок
    const QDAOToken = await ethers.getContractFactory("QDAOToken");
    const token = await QDAOToken.deploy(process.env.TOTAL, process.env.NAME,  process.env.SYMBOL, process.env.ADMIN_ADDRESS);
    console.log("QDAOToken deployed to address:", token.address);

    const QDAOTimelock = await ethers.getContractFactory("QDAOTimelock");
    const timelock = await QDAOTimelock.deploy(process.env.DELAY, process.env.ADMIN_ADDRESS); 
    console.log("QDAOTimelock deployed to address:", timelock.address);

    const QDAOGovernor = await ethers.getContractFactory("QDAOGovernor");
    const governor = await QDAOGovernor.deploy();
    console.log("QDAOGovernor deployed to address:", governor.address);

    const QDAOMultisig = await ethers.getContractFactory("QDAOMultisig");
    const multisig = await QDAOMultisig.deploy(process.env.ADMIN_ADDRESS);
    console.log("QDAOMultisig deployed to address:", multisig.address);

    const QDAOGovernorDelegator = await ethers.getContractFactory("QDAOGovernorDelegator");
    const delegator = await QDAOGovernorDelegator.deploy(
      timelock.address, token.address, multisig.address, governor.address, process.env.VOTING_PERIOD, process.env.QUORUM, process.env.VOTING_DELAY, process.env.ADMIN_ADDRESS);
    console.log("QDAODelegator deployed to address: ", delegator.address)
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
