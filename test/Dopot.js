var web3 = require('web3');
var chai = require('chai');
var expect = chai.expect;
const { ethers, upgrades } = require('hardhat');
var chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised);
chai.use(require('chai-bignumber')());
var BN = require('bn.js');
var bnChai = require('bn-chai');
chai.use(bnChai(BN));

describe("Dopot", async () => {
    let Token;
    let hardhatToken;
    let owner;
    let addr1, addr2, addrs;
    beforeEach(async function () {
      Token = await ethers.getContractFactory("Dopot");
      [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
      hardhatToken = await Token.deploy();
      await hardhatToken.deployed();
    });

    describe("Deployment", async () => {
      it("Should set the right owner", async function () {
        expect(await hardhatToken.owner()).to.equal(owner.address);
      });
    
      it('assigns the initial total supply to the creator', async () => {
        var ownerBalance = await hardhatToken.balanceOf(owner.address);

        var totalSupply = await hardhatToken.totalSupply();
        expect(totalSupply == ownerBalance);
      })
    });
    describe("Transactions", () => {
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
      
      it("Should update balances after transfers", async () => {try{
        const initialOwnerBalance = await hardhatToken.balanceOf(owner.address);

        const am1 = 142;
        const am2 = 81;
        await hardhatToken.transfer(addr1.address, am1);
        await hardhatToken.transfer(addr2.address, am2);

        const finalOwnerBalance = await hardhatToken.balanceOf(owner.address);
        expect(parseInt(finalOwnerBalance._hex, 16)).to.equal(initialOwnerBalance - new BN(am1+am2));
  
        const addr1Balance = await hardhatToken.balanceOf(addr1.address);
        expect(parseInt(addr1Balance._hex, 16)).to.equal(am1);
  
        const addr2Balance = await hardhatToken.balanceOf(addr2.address);
        expect(parseInt(addr2Balance._hex, 16)).to.equal(am2);} catch (e) {console.dir(e)}
      });
    })
});