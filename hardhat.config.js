require("@nomicfoundation/hardhat-toolbox");

//0x75c09fb19051f8F13B0C8BdD7e7c3BE123821C77

const ALCHEMY_API_KEY = "PU1jr72jAHmucb_oUHObuiwoCCsdtODL";
const GOERLI_PRIVATE_KEY = "01d25758cdfb1eeae4c79abda2491a3d9e5f003c5527815d0052a1910450386b";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false
    },
   // goerli: {
   //   url: `https://eth-goerli.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
   //   accounts: [GOERLI_PRIVATE_KEY]
  //  },
  }
 };