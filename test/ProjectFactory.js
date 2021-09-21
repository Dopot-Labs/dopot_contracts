// Load dependencies
const { expect } = require('chai');
const keccak256 = require('keccak256')
var CREATOR_ROLE = keccak256("CREATOR_ROLE");
var REVIEWER_ROLE = keccak256("REVIEWER_ROLE");


const tokenContractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
(async () => {
  let owner;
  let addr1, addr2, addrs;
  [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
  // Start test block
  describe('ProjectFactory', function () {
    let ProjectFactory;
    let projectfactory;
  
    beforeEach(async function () {
      ProjectFactory = await ethers.getContractFactory("ProjectFactory");
      projectfactory = await ProjectFactory.deploy(/*tokenContractAddress*/);
      await projectfactory.deployed();
    });

    describe("Deployment", async () => {
      it("Should set the right ADMIN", async () => {
        expect(await projectfactory.owner()).to.equal(owner.address);
      });
    });
  });

  describe("Project Creation", async () => {
    var ProjectFactory;
    var projectfactory;
    var project;
    const fundingGoal = 10;
    const minimumInvestment = 2;

    beforeEach(async () => {
      ProjectFactory = await ethers.getContractFactory("ProjectFactory");
      projectfactory = await ProjectFactory.deploy(/*tokenContractAddress*/);
      await projectfactory.deployed();
      project = await projectfactory.connect(addr1).createProject(new Date(new Date().setFullYear(new Date().getFullYear() + 1)).getTime(), fundingGoal, minimumInvestment);
      await project.deployed();
    });

    it("Should fail investing less than minumum", async () => {
      let successInvest = await project.connect(addr2).invest.value(minimumInvestment-1);
      
    });

    it("Should set the right ROLES", async () => { return;
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
    });
  });
})();