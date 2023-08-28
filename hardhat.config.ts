require("dotenv").config();
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

const GOERLI_API_KEY = "rMix0FTCk8RsXWevgnfwBeHnLuJbxOwh";
const MAINNET_API_KEY = "n56SZyCQ9h8hcCO4SVSpMfmohLJb9WJt";

module.exports = {
  solidity: "0.8.4",

  networks: {
    goerli: {
      url: `https://eth-goerli.g.alchemy.com/v2/${GOERLI_API_KEY}`,
      accounts: [`0x` + process.env.PRIVATE_KEY],
      chainId: 5,
    },
    mainnet: {
      url: `https://eth-mainnet.g.alchemy.com/v2/${MAINNET_API_KEY}`,
      accounts: [`0x` + process.env.PRIVATE_KEY],
      chainId: 1,
    },
  },
  etherscan: {
    apiKey: "GRWRQK98M1XTBH4XP21YAY32CJ56P9QQUK"
  },
};
