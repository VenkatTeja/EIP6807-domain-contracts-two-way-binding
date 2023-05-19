require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy")

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  defaultNetwork: "hardhat",
  networks: {
    "hardhat" : {
      chainId: 31337,
    },
  },
  getNamedAccounts: {
    deployer: {
      default: 0,
  }
}
};
