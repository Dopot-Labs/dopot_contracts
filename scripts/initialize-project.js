/* 
npx hardhat run --network mumbai scripts/initialize-project.js
*/
const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  //console.log("Initializing project with the account:", deployer.address);
  //console.log("Account balance:", (await deployer.getBalance()).toString());
/*
  const ProjectFactory = await ethers.getContractFactory("ProjectFactory", { libraries: {  Utils: "0x80B2caa4ce38065dEcc0D74dd188d63A3c7D2139" }  });
  const projectfactory = await ProjectFactory.attach( "0x12aa172b8Df0b3f9136786c8D5a776D86cc3f6Af" );
 
  const fundRaisingDeadline = 45 * 60 * 60 * 24;
  const investment = 2;
  const amountTokens = 100;
  const projectMedia = "bafybeiblt47ot4baj4vl5faecqyzzmnqg3evdb7jrhiyp5adgei2ft4onm/proj.json";
  //console.dir(await projectfactory.projectsVersions(2));
 
  let projecttx = await projectfactory.connect(deployer).createProject(fundRaisingDeadline, projectMedia);
  let receipt = await projecttx.wait(1);
  let projectCreatedEvent = receipt.events.pop();
  let projectaddr = projectCreatedEvent.args["project"];
  console.log("Project Address: " + projectaddr);       */  
  try{                        
  const projectaddr = "0x8E47c71AEFcF0CE7cD2bb0E07883B693C2Befc97";
  const Project = await ethers.getContractFactory("Project", { libraries: {  Utils: "0x9889C280a5Fc696b7b80399FEd3fEC4E26E7E121" } });
  const project = await Project.attach(projectaddr); //projectaddr
  //const res = await project.connect(deployer).addRewardTier("bafkreihkplf2i3crflruenv4e5rnoqy6s7mrmddf7xcvzfsb7iihsgnjre", investment, amountTokens);
  //const res = await project.connect(deployer).stakes("0xd52b78D9ba494e5bdCc874dc3C369F2735e24FB3");console.log(res.toString())
  const res = await project.connect(deployer).changeState(2);
  //console.log(await project.connect(deployer).addrParams());
  //const res = await project.connect(deployer).setAddrParam("0xdf5e77cB650DA50c0fe5C8A162DfD4F36C1B5Ec2", "0x2f200714093CC4eBC7Bfc15EB1CE4dAf9F925219", "0xDC9CB9cad99B058307D0e7098467820CCcEdDf8A", "0x2A33D7FcdCde0D7A82b2D470d0D9eDb21400Aa11", "0x340cb0AA007F2ECbF6fCe3cd8929a22429893213");
  } catch (e) {
    console.log(e);
  }
  //console.log(parseInt((await project.totalGoal())._hex, 16));
  /*try{
  const Utils = await ethers.getContractFactory("Mock");
  // Create a contract instance representing your library
  const utils = Utils.attach("0xfFB40bD34e714ca6D5085d108A173DCdcCC08414");
    console.log("aaa");
  // Now you can call your library's function
  var _fundToken = "0xdf5e77cB650DA50c0fe5C8A162DfD4F36C1B5Ec2";
  var dptTokenAddress = "0x1f0901F4a2d4ddAD4b9cBBC25d70E22fa0976fB8";
  var dptUniPoolAddress = "0x4b3B39d57bCf8bA665789E09837B1B1229758F4c";
  var balance = ethers.utils.parseEther("100");
  const result = await utils.dptOracleQuote(balance, projectWithdrawalFee, dptTokenAddress, dptUniPoolAddress, _fundToken);
  console.log("fee to pay in dpt: " +(result));

  const Dopot = await ethers.getContractFactory("Dopot");
  const dopot = Dopot.attach("0x1f0901F4a2d4ddAD4b9cBBC25d70E22fa0976fB8");
  console.log(await dopot.connect(deployer).balanceOf(deployer.address));

  const tx = await dopot.approve(deployer.getAddress(), "115792089237316195423570985008687907853269984665640564039457584007913129639935");
  await tx.wait(1);
  console.log(await dopot.transferFrom(deployer.getAddress(), "0xd52b78D9ba494e5bdCc874dc3C369F2735e24FB3", result));
  //_fundingTokenContract.safeTransfer(msg.sender, discountDPT? balance - insuranceAmount : balance - insuranceAmount - feeAmount);
  //_fundingTokenContract.safeTransfer(addrProjectFactory, insuranceAmount);
  } catch (e) {
    console.log(e);
  } */
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});