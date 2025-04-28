const { network } = require("hardhat");
const { verify } = require("../utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  //0xE6dAEE6c1716091F41158b58F1e68401eb43A69c
const args = ["0x0F668C1f4f53556FC8c90030e14d33e875b10d2e","0x1B45059a73e96E380F75c8aC4e980d32f7560d21", "10000000000000000000"]
  const token = await deploy("SolarChainICO", {
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
module.exports.tags = ["ico"]