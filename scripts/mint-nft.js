// npx hardhat run --network goerli scripts/mint-nft.js

const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Initializing reward with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  
  const media = "bafkreifq6gowfov72wbfpqgpauye3eqpudv3roowgqpck26lxdqjugh63m";
  const RewardFactory = await ethers.getContractFactory("DopotReward");
  const reward = await RewardFactory.attach( "0x72D0D2f44BB102c00f934D6F6AdCeA4Ac952BDd5" ); //await RewardFactory.deploy();
  //await reward.deployed();
  console.log("Reward contract:" + reward.address);
  let minttx = await reward.connect(deployer).mintToken(deployer.getAddress(), media, 1, await reward.rewardTierToBytes({ipfshash: "bafkreihkplf2i3crflruenv4e5rnoqy6s7mrmddf7xcvzfsb7iihsgnjre", tokenId: 0, investment: 100, supply: 100}));
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