const { ethers, upgrades } = require("hardhat");

async function main() {
  const Project = await ethers.getContractFactory("Project");
  const instance = await upgrades.deployProxy(Project, ["0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", 12, 123, 1]);
  await instance.deployed();
  console.log("Project deployed to:", instance.address);
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});