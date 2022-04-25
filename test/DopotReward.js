// Load dependencies
const { expect } = require('chai');
const keccak256 = require('keccak256')
var CREATOR_ROLE = keccak256("CREATOR_ROLE");
var REVIEWER_ROLE = keccak256("REVIEWER_ROLE");

const fundingTokenAbi = require("./abi/fundingToken.json");


(async () => {
  let owner;
  let addr1, addr2, addrs;
  var media;
  [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

  describe("DopotReward deploy", async () => {

    beforeEach(async () => {
      const RewardFactory = await ethers.getContractFactory("DopotReward");
      const reward = await RewardFactory.deploy("0x3355FA97cEa19F6c11Eee2559AA01E188472f737");
      await reward.deployed();

      media = "0x01559ae4021a99b0d373d7bc8a80504bad782367abe12c21373c83adc6bf6a7e";
    });

    it("Should fail investing less than allowance", async () => {
      //reward.mint
      //expect(project.connect(addr2).invest(0)).to.be.rejectedWith('Insufficient token allowance');
    });

    it("Should succed investing allowance", async () => {
      //await project.changeState(2);
      // mint dai
      //await fundingToken.increaseAllowance(addr2, 1000000);
      //await project.connect(addr2).invest(0);
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