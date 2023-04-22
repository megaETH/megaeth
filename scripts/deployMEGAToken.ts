import { ethers, upgrades } from "hardhat";

async function main() {
    // goerli Deployed MEGACoin to 0xa49573920bd91e61bd46669059E80288FB44FAa0
    // goerli Deployed ESMEGAToken to 0x6bCdeB6457982b26A244521CC3A129571BAB8D22 
    const MEGACoin = await ethers.getContractFactory('MEGACoin');
    const contract = await MEGACoin.deploy();
    console.log(`Deployed MEGACoin to ${contract.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});