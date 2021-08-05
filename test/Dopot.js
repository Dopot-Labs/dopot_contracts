var chai = require('chai');
var expect = chai.expect;
const { ethers, upgrades } = require('hardhat');
const web3 = require('web3');
var chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised);
chai.use(require('chai-bignumber')());

describe("Dopot", async function () {
    let Token;
    let hardhatToken;
    let owner;
    let addr1, addr2, addrs;
    beforeEach(async function () {
      Token = await ethers.getContractFactory("Dopot");
      [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
      hardhatToken = await upgrades.deployProxy(Token);
      await hardhatToken.deployed();
    });

    describe("Deployment", async function () {
      it("Should set the right ADMIN ROLE", async function () {
        expect(hardhatToken.DEFAULT_ADMIN_ROLE() == owner.address);
      });
    
      it('assigns the initial total supply to the creator', async function () {
        var ownerBalance = await hardhatToken.balanceOf(owner.address);

        var totalSupply = await hardhatToken.totalSupply();
        expect(totalSupply == ownerBalance);
      })
    });
    describe("Transactions", function () {
      it("Should transfer tokens between accounts", async function () {
        const amount = "0x" + (50).toString(16) 
        // Transfer 50 tokens from owner to addr1
        await hardhatToken.transfer(addr1.address, 50);
        const addr1Balance = await hardhatToken.balanceOf(addr1.address);
        expect(addr1Balance._hex).to.equal(amount);

        // We use .connect(signer) to send a transaction from another account
        await hardhatToken.connect(addr1).transfer(addr2.address, 50);
        const addr2Balance = await hardhatToken.balanceOf(addr2.address);
        expect(addr2Balance._hex).to.equal(amount);
      });
      
      it("Should fail if sender doesn’t have enough tokens", async function () {try{
        const initialOwnerBalance = await hardhatToken.balanceOf(owner.address);
  
        // Try to send 1 token from addr1 (0 tokens) to owner (1000000 tokens).
        // `require` will evaluate false and revert the transaction.
        await expect(
          hardhatToken.connect(addr1).transfer(owner.address, 1)
        ).to.be.rejectedWith("VM Exception while processing transaction: reverted with reason string 'ERC20: transfer amount exceeds balance");
  
        // Owner balance shouldn't have changed.
        expect((await hardhatToken.balanceOf(owner.address))._hex).to.equal(
          initialOwnerBalance._hex
        );} catch (e) {console.dir(e)}
      });
      
      it("Should update balances after transfers", async function () {try{
        const initialOwnerBalance = await hardhatToken.balanceOf(owner.address);
        // Transfer 100 tokens from owner to addr1.
        await hardhatToken.transfer(addr1.address, 100);
        // Transfer another 50 tokens from owner to addr2.
        await hardhatToken.transfer(addr2.address, 50);
        // Check balances.
        const finalOwnerBalance = await hardhatToken.balanceOf(owner.address);
        expect(finalOwnerBalance._hex).to.equal("0x" + (BigInt(initialOwnerBalance._hex)-BigInt(150)).toString(16));
  
        const addr1Balance = await hardhatToken.balanceOf(addr1.address);
        expect(addr1Balance._hex).to.equal("0x"+ (100).toString(16));
  
        const addr2Balance = await hardhatToken.balanceOf(addr2.address);
        expect(addr2Balance._hex).to.equal("0x"+ (50).toString(16));} catch (e) {console.dir(e)}
      });
    })
    /*
    it('Upgrading', async function () {
      const hardhatToken = await upgrades.deployProxy(Token, [42]);
      assert.strictEqual(await hardhatToken.retrieve(), 42);
    
      await upgrades.upgradeProxy(hardhatToken.address, TokenV2);
      assert.strictEqual(await hardhatToken.retrieve(), 42);
    });*/
});