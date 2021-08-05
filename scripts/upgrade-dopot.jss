const { ethers, upgrades } = require("hardhat");

async function main() {
  const DopotV2 = await ethers.getContractFactory("DopotV2");
  const dopot = await upgrades.upgradeProxy(BOX_ADDRESS, DopotV2);
  console.log("Dopot upgraded");
}

main();
