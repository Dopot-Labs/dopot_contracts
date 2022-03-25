// npx hardhat run --network goerli scripts/mint-nft.js

const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Initializing reward with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  
  const media = "0x01559ae4021a3b33529b22967b2865dcde755e06ee66f514e2967da6c5f324e6";
  const RewardFactory = await ethers.getContractFactory("DopotReward");
  const reward = await RewardFactory.attach( "0x1F51353D5F1D0a12913602a4061b813992D38e6F" ); //await RewardFactory.deploy();
  //await reward.deployed();
  console.log("Reward deployed to:" + reward.address);

  let minttx = await reward.connect(deployer).mint(deployer.getAddress(), media, 1, 0);
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