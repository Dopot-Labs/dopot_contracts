// Load dependencies
const { expect } = require('chai');
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

      const RewardFactory = await ethers.getContractFactory("DopotReward");
      const reward = await RewardFactory.deploy();
      await reward.deployed();

      ProjectFactory = await ethers.getContractFactory("ProjectFactory");
      projectfactory = await ProjectFactory.deploy(token.address, reward.address /*,tokenContractAddress*/);
      await projectfactory.deployed();
    });

    describe("Deployment", async () => {
      it("Should set the right ADMIN", async () => {
        expect(await projectfactory.owner()).to.equal(owner.address);
      });
    });
  });

  describe("Project Creation", async () => {
    var projectfactory;
    var project;
    var fundingToken;
    const amountTokens = 100;

    beforeEach(async () => {
      const Token = await ethers.getContractFactory("Dopot");
      const token = await Token.deploy();
      await token.deployed();

      const RewardFactory = await ethers.getContractFactory("DopotReward");
      const reward = await RewardFactory.deploy();
      await reward.deployed();

      let Project = await ethers.getContractFactory("Project");
      let ProjectFactory = await ethers.getContractFactory("ProjectFactory");
      const FundingToken = await ethers.getContractFactory("GodModeErc20");
      fundingToken = await FundingToken.deploy("DAI", "DAI", 18);
      await fundingToken.deployed();
      projectfactory = await ProjectFactory.deploy(fundingToken.address, reward.address /*,tokenContractAddress*/);
      await projectfactory.deployed();
      const raiseBy = new Date(new Date().setFullYear(new Date().getFullYear() + 1)).getTime();
      const projectMedia = [{digest: "0xfad3b4b8270ea30f09c1364b990db3351b2f720115b774071f4cc4e2ba25dfc2", hashFunction: 18, size: 32}]; // a
      const rewardTiers = [{digest: "0x1db59a982e018221f8f97b9044f13d58b8ed5c4b7943fe48cad9ca8f68f9c23c", hashFunction: 18, size: 32, investment:  amountTokens , supply: 100}]; // b
      const survey = {digest: "0xedeb62f6233e9de80fb9d67cf307844046c5e62631045868adaf5e221ad9cf62", hashFunction: 18, size: 32}; // s

      let projecttx = await projectfactory.createProject(raiseBy, projectMedia, rewardTiers, survey); // <---------------------
      let receipt = await projecttx.wait(1);
      let projectCreatedEvent = receipt.events.pop();
      let projectaddr = projectCreatedEvent.args["project"];
      project = await Project.attach(projectaddr);
    });

    it("Should fail investing less than allowance", async () => {
      await project.changeState(2);
      expect(project.connect(addr2).invest(0)).to.be.rejectedWith('ERR_ERC20_TRANSFER_INSUFFICIENT_BALANCE');
    });

    it("Should succed investing allowance", async () => {
      await project.changeState(2);
      await fundingToken.mint(addr2.address, amountTokens );
      const approvaltx = await fundingToken.connect(addr2).increaseAllowance(project.address, amountTokens );
      const approvalreceipt = await approvaltx.wait(1);
      const approvalEvent = approvalreceipt.events.pop();
      //console.dir(ethers.utils.formatEther(approvalEvent.args.amount));
      
      let investtx = await project.connect(addr2).invest(0);
      let receipt = await investtx.wait(1);
      let investedEvent = receipt.events.pop();
      expect(investedEvent.args).to.exist;
    });
    /*
    it("Should set the right ROLES", async () => {
      var roleCount = await project.getRoleMemberCount(CREATOR_ROLE);
      var members = [];
      for (let i = 0; i < roleCount; ++i) {
          members.push(await project.getRoleMember(CREATOR_ROLE, i));
      }

      expect(project.CREATOR_ROLE).to.equal(mermbers[0]);
      roleCount = await project.getRoleMemberCount(REVIEWER_ROLE);
      members = [];
      for (let i = 0; i < roleCount; ++i) {
          members.push(await project.getRoleMember(REVIEWER_ROLE, i));
      }

      expect(project.REVIEWER_ROLE).to.equal(owner.address).to.equal(mermbers[0]).to.equal(project.reviewer);
    });*/
  });
})();