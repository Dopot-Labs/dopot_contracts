// Load dependencies
var chai = require("chai");
var { expect } = chai;
var BN = require('bn.js');
const keccak256 = require('keccak256')
var CREATOR_ROLE = keccak256("CREATOR_ROLE");
var REVIEWER_ROLE = keccak256("REVIEWER_ROLE");
const fundingTokenAbi = require("./abi/fundingToken.json");
const investment = 2;
const amountTokens = 100;
const raiseBy = new Date(new Date().setFullYear(new Date().getFullYear() + 1)).getTime();
const projectMedia = "0xfad3b4b8270ea30f09c1364b990db3351b2f720115b774071f4cc4e2ba25dfc2"; // a
const rewardTiers = [{ipfshash: "0x1db59a982e018221f8f97b9044f13d58b8ed5c4b7943fe48cad9ca8f68f9c23c", tokenId: 0, investment, supply: amountTokens, projectaddress: ethers.constants.AddressZero}]; // b
const survey = "0xedeb62f6233e9de80fb9d67cf307844046c5e62631045868adaf5e221ad9cf62"; // s


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
      const Token = await ethers.getContractFactory("Dopot");
      const token = await Token.deploy();
      await token.deployed();
      let ProjectFactory = await ethers.getContractFactory("ProjectFactory");
      const FundingToken = await ethers.getContractFactory("GodModeErc20");
      let fundingToken = await FundingToken.deploy("DAI", "DAI", 18);
      await fundingToken.deployed();
      let projectfactory = await ProjectFactory.connect(owner).deploy(fundingToken.address/*,tokenContractAddress*/);
      await projectfactory.deployed();
  
      const RewardFactory = await ethers.getContractFactory("DopotReward");
      let reward = await RewardFactory.deploy(projectfactory.address);
      await reward.deployed();
      await projectfactory.connect(owner).setRewardContract(reward.address);
      const projectLimit = parseInt((await projectfactory.projectLimit())._hex, 16);
      for(let i = 1; i < projectLimit + 5; i++){
        if(i > projectLimit)
          await expect(projectfactory.createProject(raiseBy, projectMedia, rewardTiers, survey)).to.be.rejected;
        else 
          await projectfactory.createProject(raiseBy, projectMedia, rewardTiers, survey);
      }
    });
  });

  describe('ProjectFactory', function () {
    let ProjectFactory;
    let projectfactory;
  
    beforeEach(async function () {
      const Token = await ethers.getContractFactory("Dopot");
      const token = await Token.deploy();
      await token.deployed();

      ProjectFactory = await ethers.getContractFactory("ProjectFactory");
      projectfactory = await ProjectFactory.deploy(token.address/*,tokenContractAddress*/);
      await projectfactory.deployed();

      const RewardFactory = await ethers.getContractFactory("DopotReward");
      const reward = await RewardFactory.deploy(projectfactory.address);
      await reward.deployed();
      await projectfactory.setRewardContract(reward.address);
    });

    describe("Deployment", async () => {
      it("Should set the right owner", async () => {
        expect(await projectfactory.owner()).to.equal(owner.address);
      });
    });
  });

  describe("Project Creation", async () => {
    var projectfactory;
    var project;
    var fundingToken;
    var reward;
    const rndTierAmount = Math.floor(Math.random() * (amountTokens - 1) + 1);
    


    beforeEach(async () => {
      const Token = await ethers.getContractFactory("Dopot");
      const token = await Token.deploy();
      await token.deployed();

      let Project = await ethers.getContractFactory("Project");
      let ProjectFactory = await ethers.getContractFactory("ProjectFactory");
      const FundingToken = await ethers.getContractFactory("GodModeErc20");
      fundingToken = await FundingToken.deploy("DAI", "DAI", 18);
      await fundingToken.deployed();
      projectfactory = await ProjectFactory.connect(owner).deploy(fundingToken.address/*,tokenContractAddress*/);
      await projectfactory.deployed();

      const RewardFactory = await ethers.getContractFactory("DopotReward");
      reward = await RewardFactory.deploy(projectfactory.address);
      await reward.deployed();
      await projectfactory.connect(owner).setRewardContract(reward.address);

      let projecttx = await projectfactory.connect(projectOwner).createProject(raiseBy, projectMedia, rewardTiers, survey); // <---------------------      
      let receipt = await projecttx.wait(1);
      let projectCreatedEvent = receipt.events.pop();
      let projectaddr = projectCreatedEvent.args["project"];
      project = await Project.attach(projectaddr);
    });

    it("Should fail investing less than allowance", async () => {
      await project.changeState(2);
      await expect(project.connect(addr2).invest(0, 1)).to.be.rejectedWith('Insufficient token allowance');
    });

    it("Should fail investing on pending project", async () => {
      await fundingToken.mint(addr2.address, rndTierAmount * investment );
      const approvaltx = await fundingToken.connect(addr2).increaseAllowance(project.address, rndTierAmount * investment );
      await approvaltx.wait(1);
      await expect(project.connect(addr2).invest(0, rndTierAmount)).to.be.rejectedWith('Project state error');
    });

    it("Should succeed project tier and withdraw", async () => {
      const tier = 0;
      await project.changeState(2);
      await fundingToken.mint(addr2.address, amountTokens * investment);
      const approvaltx = await fundingToken.connect(addr2).increaseAllowance(project.address, amountTokens * investment );
      await approvaltx.wait(1);
      //console.dir(ethers.utils.formatEther(approvalEvent.args.amount));
      let investtx = await project.connect(addr2).invest(tier, amountTokens);
      let receipt = await investtx.wait(1);
      let investedEvent = receipt.events.pop();
      expect(investedEvent.args).to.exist;
      expect(parseInt((await reward.balanceOf(addr2.address, 0))._hex, 16)).to.be.equal(amountTokens);
      expect(await project.tierFundingGoalReached(tier)).to.be.equal(true);
      let withdrawttx = await project.connect(projectOwner).withdraw(0);
      await withdrawttx.wait(1);
      const reviewerFee = amountTokens*investment * await project.projectWithdrawalFee() / 1e18;
      const balanceProjectOwner = (amountTokens*investment) - reviewerFee;
      expect(parseInt((await fundingToken.balanceOf(owner.address))._hex, 16)).to.be.equal(reviewerFee);
      expect(parseInt((await fundingToken.balanceOf(projectOwner.address))._hex, 16)).to.be.equal(balanceProjectOwner);
    });

    it("Should succed investing allowance 1x", async () => {
      await project.changeState(2);
      await fundingToken.mint(addr2.address, rndTierAmount * investment);
      const approvaltx = await fundingToken.connect(addr2).increaseAllowance(project.address, rndTierAmount * investment );
      await approvaltx.wait(1);
      //console.dir(ethers.utils.formatEther(approvalEvent.args.amount));
      let investtx = await project.connect(addr2).invest(0, rndTierAmount);
      let receipt = await investtx.wait(1);
      let investedEvent = receipt.events.pop();
      expect(investedEvent.args).to.exist;
      expect(parseInt((await reward.balanceOf(addr2.address, 0))._hex, 16)).to.be.equal(rndTierAmount);
    });
    
    it("Should set the right ROLES", async () => {
      expect(await project.hasRole(CREATOR_ROLE, projectOwner.address)).to.equal(true);
      expect(await project.hasRole(REVIEWER_ROLE, owner.address)).to.equal(true);
      expect(owner.address).to.equal(await project.reviewer());
    });
  });
})();
