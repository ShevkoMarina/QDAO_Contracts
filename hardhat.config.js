require("@nomicfoundation/hardhat-toolbox");

//0x75c09fb19051f8F13B0C8BdD7e7c3BE123821C77

const ALCHEMY_API_KEY = "";
const GOERLI_PRIVATE_KEY = "";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false
    },
  }
 };