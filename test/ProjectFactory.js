// Load dependencies
var chai = require("chai");
var { expect } = chai;
var BN = require('bn.js');
const keccak256 = require('keccak256')
var CREATOR_ROLE = keccak256("CREATOR_ROLE");
var REVIEWER_ROLE = keccak256("REVIEWER_ROLE");
const fundingTokenAbi = require("./abi/fundingToken.json");

(async () => {
  let owner;
  let addr1, addr2, addrs;
  [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
  // Start test block
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
    const investment = 2;
    const amountTokens = 100;
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
      const raiseBy = new Date(new Date().setFullYear(new Date().getFullYear() + 1)).getTime();
      const projectMedia = ["0xfad3b4b8270ea30f09c1364b990db3351b2f720115b774071f4cc4e2ba25dfc2"]; // a
      const rewardTiers = [{ipfshash: "0x1db59a982e018221f8f97b9044f13d58b8ed5c4b7943fe48cad9ca8f68f9c23c", tokenId: 0, investment, supply: amountTokens}]; // b
      const survey = "0xedeb62f6233e9de80fb9d67cf307844046c5e62631045868adaf5e221ad9cf62"; // s

      const RewardFactory = await ethers.getContractFactory("DopotReward");
      reward = await RewardFactory.deploy(projectfactory.address);
      await reward.deployed();
      await projectfactory.connect(owner).setRewardContract(reward.address);

      let projecttx = await projectfactory.connect(owner).createProject(raiseBy, projectMedia, rewardTiers, survey); // <---------------------
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
      await project.changeState(2);
      await fundingToken.mint(addr2.address, amountTokens * investment);
      const approvaltx = await fundingToken.connect(addr2).increaseAllowance(project.address, amountTokens * investment );
      await approvaltx.wait(1);
      //console.dir(ethers.utils.formatEther(approvalEvent.args.amount));
      let investtx = await project.connect(addr2).invest(0, amountTokens);
      let receipt = await investtx.wait(1);
      let investedEvent = receipt.events.pop();
      expect(investedEvent.args).to.exist;
      expect(parseInt((await reward.balanceOf(addr2.address, 0))._hex, 16)).to.be.equal(amountTokens);
      expect(await project.fundingGoalReached(0)).to.be.equal(true);

      let withdrawttx = await project.connect(owner).withdraw(0);
      await withdrawttx.wait(1);
      console.dir(await fundingToken.balanceOf(owner.address));
      expect(parseInt((await fundingToken.balanceOf(owner.address))._hex, 16)).to.be.greaterThanOrEqual(1);
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
      expect(await project.hasRole(CREATOR_ROLE, owner.address)).to.equal(true);
      expect(await project.hasRole(REVIEWER_ROLE, owner.address)).to.equal(true);
      expect(owner.address).to.equal(await project.reviewer());
    });
  });
})();