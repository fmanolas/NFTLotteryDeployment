require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config(); // Add this line

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {},
    baseSepolia: {
      url: process.env.ALCHEMY_API_KEY,
      accounts: [process.env.PRIVATE_KEY],
      chainid:84532
    },
  },
  etherscan: {
    url:process.env.ALCHEMY_API_KEY,
    apiKey: process.env.BASE_ETHERSCAN_API_KEY, // Use the correct Etherscan-like service API key for Base Sepolia
  },
};
