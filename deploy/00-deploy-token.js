const { network } = require("hardhat");
const { verify } = require("../utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
const args = []
  const token = await deploy("SolarChainCoin", {
    from: deployer,
    log: true,
    args: args,
    waitConfirmations: network.config.blockConfirmations || 1,
  });
  if (network.config.chainId == 11155111 && process.env.ETHERSCAN_API_KEY) {
    await verify(token.address, args);
  }
  console.log(`Contract deployed at : ${token.address}`);
};
module.exports.tags = ["token"]