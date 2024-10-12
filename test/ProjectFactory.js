// Load dependencies
const { ethers, upgrades } = require("hardhat");
var chai = require("chai");
var { expect } = chai;
var BN = require('bn.js');
const keccak256 = require('keccak256')
var CREATOR_ROLE = keccak256("CREATOR_ROLE");
var REVIEWER_ROLE = keccak256("REVIEWER_ROLE");
const fundingTokenAbi = require("./abi/fundingToken.json");
const investment = 2;
const amountTokens = 100;
const goal = ethers.utils.parseEther("100");
const fundRaisingDeadline = 3888000; // 45 days
const projectMedia = "0xfad3b4b8270ea30f09c1364b990db3351b2f720115b774071f4cc4e2ba25dfc2"; // a
const rewardTiers = [{ipfshash: "0x1db59a982e018221f8f97b9044f13d58b8ed5c4b7943fe48cad9ca8f68f9c23c", tokenId: 0, investment, supply: amountTokens, projectaddress: ethers.constants.AddressZero}]; // b
const dptUniPoolAddress = "0x9Ee2D1A3E913ded868B2c381b07520519D9425EA";
const dptTokenAddress = "0x19d29A99880560832d9fa9B7d30211E5936B3Db7";

async function pubKeyFromTx(tx){
  const expandedSig = {
    r: tx.r,
    s: tx.s,
    v: tx.v
   }
   const signature = ethers.utils.joinSignature(expandedSig)
   const txData = {
    gasPrice: tx.gasPrice,
    gasLimit: tx.gasLimit,
    value: tx.value,
    nonce: tx.nonce,
    data: tx.data,
    chainId: tx.chainId,
    to: tx.to
   }
   const rsTx = await ethers.utils.resolveProperties(txData)
   const raw = ethers.utils.serializeTransaction(rsTx)
   const msgHash = ethers.utils.keccak256(raw)
   const msgBytes = ethers.utils.arrayify(msgHash)
   return ethers.utils.recoverPublicKey(msgBytes, signature)
}

(async () => {
  let owner;
  let projectOwner, addr2, addrs;
  [owner, projectOwner, addr2, ...addrs] = await ethers.getSigners();

  describe("Project Creation limits", async () => {
    it("Should fail exceeding project creation limit", async () => {
      //const Token = await ethers.getContractFactory("Dopot");
      //const token = await Token.deploy();
      //await token.deployed();

      const Utils = await ethers.getContractFactory("Utils");
      const utils = await Utils.deploy();
      await utils.deployed();

      let ProjectFactory = await ethers.getContractFactory("ProjectFactory", { libraries: {  Utils: utils.address }  });
      //const FundingToken = await ethers.getContractFactory("GodModeErc20");
      //let fundingToken = await FundingToken.deploy("DAI", "DAI", 18);
      //await fundingToken.deployed();
      let projectfactory = await ProjectFactory.connect(owner).deploy("0x0000000000000000000000000000000000000000" , "0x0000000000000000000000000000000000000000" , "0x0000000000000000000000000000000000000000");
      await projectfactory.deployed();
  
      const RewardFactory = await ethers.getContractFactory("DopotReward", { libraries: {  Utils: utils.address }  });
      let reward = await RewardFactory.deploy(projectfactory.address);
      await reward.deployed();
      await projectfactory.connect(owner).setRewardContract(reward.address);
      const projectLimit = 20;
      for(let i = 1; i < projectLimit + 1; i++){
        if(i > projectLimit)
          await expect(projectfactory.createProject(goal, fundRaisingDeadline)).to.be.rejected;
        else 
          await projectfactory.createProject(goal, fundRaisingDeadline);
      }
    });
  });

})();
