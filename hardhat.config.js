require("@nomicfoundation/hardhat-toolbox");


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false
    },
    ganache: {
      url: 'http://192.168.1.45:8545', // Ganache URL
      accounts: {
        mnemonic: 'myself march cram diary tunnel alarm reason kit shadow match cheap shed'
      },
    },
  }
 };