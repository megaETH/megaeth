import * as _ from 'lodash';
import dotenv from "dotenv";
import { ethers } from "hardhat";
import { StakingPoolFactory__factory } from '../typechain/factories/contracts/StakingPoolFactory__factory';

const dayjs = require('dayjs');

dotenv.config();

const privateKey: string = process.env.PRIVATE_KEY || "";
const infuraKey: string = process.env.INFURA_KEY || "";

// Goerli
const provider = new ethers.providers.JsonRpcProvider(`https://goerli.infura.io/v3/${infuraKey}`);
const stakingPoolFactoryContractAddress = '0xa378671de217b5B69154CA14297e00086619b512';


const pools = [
  {
    stakingTokenName: 'ETH',
    stakingTokenAddress: '0x0000000000000000000000000000000000000000',
    startTime: "1680340100",
    roundDurationInDays: 7
  },
  {
    stakingTokenName: 'stETH',
    stakingTokenAddress: '0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F', // Goerli
    // stakingTokenAddress: '0xae7ab96520de3a18e5e111b5eaab095312d7fe84', // mainnet
    startTime: "1680340200", // UTC time
    roundDurationInDays: 7
  },
];

async function main() {
  const stakingPoolFactory = StakingPoolFactory__factory.connect(stakingPoolFactoryContractAddress, provider);

  const deployer = new ethers.Wallet(privateKey, provider);

  for (let i = 0; i < _.size(pools); i++) {
    const pool = pools[i];
    const trans = await stakingPoolFactory.connect(deployer).deployPool(pool.stakingTokenAddress, pool.startTime, pool.roundDurationInDays);
    await trans.wait();
    console.log(`Deployed staking pool for ${pool.stakingTokenName}`);
    console.log(`\t\tPool Address: ${await stakingPoolFactory.getStakingPoolAddress(pool.stakingTokenAddress)}`);
    console.log(`\t\tStart timestamp: ${pool.startTime}`);
    console.log(`\t\tRound duration (days): ${pool.roundDurationInDays}`);
  }
}
//  goerli eth pool: 0xdee9477b0a5D62f987aA9cfE18Ee651a68F13556
// goerli steth pool: 0x8E7A8962a16f21005E93B3C8FCD39a81608ee520
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
