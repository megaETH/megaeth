import { ethers } from "hardhat";

// // Goerli
    // goerli Deployed MEGACoin to 0xa49573920bd91e61bd46669059E80288FB44FAa0
    // goerli Deployed ESMEGAToken to 0x6bCdeB6457982b26A244521CC3A129571BAB8D22 
    // goerli Deployed StakingPoolFactory to 0xa378671de217b5B69154CA14297e00086619b512
    // wethAddress 0xb4fbf271143f4fbf7b91a5ded31805e42b2208d6


// Goerli
const MEGACoinAddress = '0xa49573920bd91e61bd46669059E80288FB44FAa0';
const esMEGATokenAddress = '0x6bCdeB6457982b26A244521CC3A129571BAB8D22';
const wethAddress = '0xb4fbf271143f4fbf7b91a5ded31805e42b2208d6';

async function main() {
  const StakingPoolFactory = await ethers.getContractFactory("StakingPoolFactory");
  const contract = await StakingPoolFactory.deploy(esMEGATokenAddress, wethAddress);
  console.log(`Deployed StakingPoolFactory to ${contract.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});