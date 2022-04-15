// npx hardhat run --network goerli scripts/mint-nft.js

const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Initializing reward with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  
  const media = "bafkreifq6gowfov72wbfpqgpauye3eqpudv3roowgqpck26lxdqjugh63m";
  const RewardFactory = await ethers.getContractFactory("DopotReward");
  const reward = await RewardFactory.attach( "0xAfAcde5DA0229A44357a20FaF564C22E63549A4c" ); //await RewardFactory.deploy();
  //await reward.deployed();
  console.log("Reward contract:" + reward.address);

  let minttx = await reward.connect(deployer).mintToken(deployer.getAddress(), media, 1);
  let receipt = await minttx.wait(1);
  let rewardMintedEvent = receipt.events.pop();
  let rewardData = rewardMintedEvent.args;
  console.log(rewardData);
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});