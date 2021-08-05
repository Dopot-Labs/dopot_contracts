const { ethers, upgrades } = require("hardhat");

async function main() {
  const ProjectV2 = await ethers.getContractFactory("ProjectV2");
  const project = await upgrades.upgradeProxy(BOX_ADDRESS, ProjectV2);
  console.log("Project upgraded");
}

main();