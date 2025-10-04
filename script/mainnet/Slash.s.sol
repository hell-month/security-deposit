// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {SecurityDepositPool} from "../../src/SecurityDepositPool.sol";

contract SlashScript is Script {
    SecurityDepositPool public pool = SecurityDepositPool(0x94ae95E096fE4C5954840760E0190c27a2ebBDDE);
    // USDT contract address on Ethereum mainnet
    // https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7
    address public usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    function run() public {
        vm.startBroadcast();

        require(msg.sender == pool.owner(), "pool owner");

        address[] memory students = new address[](21);
        uint256[] memory amounts = new uint256[](21);
        // https://docs.google.com/spreadsheets/d/1LtR6zEHqmUgXdRn0NSkm2pmDreL8w3GBOMDGs7vVUGE/edit?gid=1384484463#gid=1384484463
        students[0] = 0x8eE84937C2BF37424F0Ba885653d2Bf3cdc77080;
        amounts[0] = 54750000;
        students[1] = 0xDc581a5f5328ED03d8737bf09B8Cab4BB85Af707;
        amounts[1] = 73000000;
        students[2] = 0x0B2a6F97aa427d6CC82F8b30D950FddB6614Ce85;
        amounts[2] = 54750000;
        students[3] = 0xD76ce7F02351Ab3E3103ee3b6A64601BEc580c6E;
        amounts[3] = 2000000;
        students[4] = 0x3458B20044F5f20a80ab25af160498A853fDE013;
        amounts[4] = 2000000;
        students[5] = 0x7181C06492B9e9a36fAC1A6204dF8be0BD4E8641;
        amounts[5] = 18250000;
        students[6] = 0x8b57AeFCa35eef5ccA30cE72e262177cf2b95917;
        amounts[6] = 54750000;
        students[7] = 0x3435Bad6F68a6a14a177485b68d233a4074943dB;
        amounts[7] = 54750000;
        students[8] = 0xEA56b22c446A5fbEd33c231feCD42A1d78641119;
        amounts[8] = 40150000;
        students[9] = 0xeFcb13871eCBcF20c528D3209bc236336A35B0F4;
        amounts[9] = 18250000;
        students[10] = 0x302B18b95A2b6345c8ec5D8B67AB84076F507D01;
        amounts[10] = 32850000;
        students[11] = 0x118a6899c241816880458b9953C4D6a8F9445FcB;
        amounts[11] = 73000000;
        students[12] = 0xAcD1D964551a1dEd46EA7CC7A71F0c6Ee4b1C554;
        amounts[12] = 54750000;
        students[13] = 0xC8F77E8Fb65aD25425eCaCB2AD359A186a5125c9;
        amounts[13] = 54750000;
        students[14] = 0xC08a86384BBAaC0C2D0E14961d563088cea31b35;
        amounts[14] = 73000000;
        students[15] = 0xe5d152912c042e9F8Cb4B6658a0b2A8562a7D9FE;
        amounts[15] = 73000000;
        students[16] = 0x25DfF2cC7d63Fcff96aded40bdFf0A7F7f9A562F;
        amounts[16] = 29200000;
        students[17] = 0x1d2073424841569e531Ef1a7C2E7749185412f8D;
        amounts[17] = 54750000;
        students[18] = 0x0833E6e33A5397ED4147bb8cf31aFB0a6055Dd62;
        amounts[18] = 54750000;
        students[19] = 0x99bB0c670B496c107782dad2833c01d1f45429a5;
        amounts[19] = 54750000;
        students[20] = 0x51ff66B7A4b1950ff6C1CA252172eD8040f2A20c;
        amounts[20] = 18250000;
        // students[] = 0xB407b1d64A01c880e4E0890f9ceAc56e6F48D807; amounts[] =	0;
        // students[] = 0x13c1591e25f290861171ce2C7700E39e36AA5514; amounts[] =	0;
        // students[] = 0xddBB537c00D8c15623F88a37c336d56B69CbA486; amounts[] =	0;
        // students[] = 0x563d8cC5b5DC56E4096B9B2ca170DC818B848e12; amounts[] =	0;
        // students[] = 0xB6b2FeA308dB76BE0a28938AEfc76f5BAf716730; amounts[] =	0;
        // students[] = 0x39BC1b6038757c76aE9E73C9A0207c2feB36a169; amounts[] =	0;
        // students[] = 0x6758EDfd13040f577A00b13eB0b1c49400AACa29; amounts[] =	0;
        // students[] = 0x8ae9B203a0fE7F8167B54856E59cc52135E14FbC; amounts[] =	0;
        // students[] = 0x8C67Bb0AfCEb6750ed89D592A1C0B65EB9D26aBf; amounts[] =	0;
        // students[] = 0xe2CC30cCB1d92d7C7Efb0fd61D5a937586bA0D11; amounts[] =	0;
        // students[] = 0xfC5726B3ad9f313d8e7cF0cBf8fd4df9A7c2261A; amounts[] =	0;

        pool.slashMany(students, amounts);
        vm.stopBroadcast();
    }

    // Adding this to be excluded from forge coverage report
    function testA() public {}
}
