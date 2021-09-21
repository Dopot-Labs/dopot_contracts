# deploy to localchain

npx hardhat node
npx hardhat run scripts/deploy-dopot.js --network localhost
npx hardhat run scripts/deploy-factory.js --network localhost
npx hardhat run scripts/initialize-project.js --network localhost

moralis-admin-cli connect-local-devchain
npx hardhat test

# deploy to testnet

npx hardhat run scripts/deploy-dopot.js --network mumbai
npx hardhat run scripts/deploy-factory.js --network mumbai
npx hardhat run scripts/initialize-project.js --network mumbai