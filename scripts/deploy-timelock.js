// deployer for timelock

const argumentsArray = require('../arguments.js');

async function main() { 

    var delayTime = argumentsArray[0];
    var proposersArray = argumentsArray[1];
    var executorsArray = argumentsArray[2];

    const [deployer] = await ethers.getSigners();
  
    console.log(
      "Deploying contracts with the account:",
      deployer.address
    );
    
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const Token = await ethers.getContractFactory("TimelockController");

    const token = await Token.deploy(delayTime, proposersArray, executorsArray);

    console.log("Timelock address:", token.address);

  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });