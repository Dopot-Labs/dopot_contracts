const { ethers, upgrades } = require("hardhat");
const web3 = require("web3");
 
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Token = await ethers.getContractFactory("Dopot");
  const token = await Token.deploy();
  await token.deployed();
  const deployerBalance = await token.callStatic.balanceOf(deployer.address);
  console.log("Deployer DPT balance: ", web3.utils.fromWei(deployerBalance._hex));
  console.log("Dopot deployed to:", token.address);
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});