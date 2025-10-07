// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {SecurityDepositPool} from "../../src/SecurityDepositPool.sol";

contract WithdrawScript is Script {
    SecurityDepositPool public pool = SecurityDepositPool(0x94ae95E096fE4C5954840760E0190c27a2ebBDDE);
    // USDT contract address on Ethereum mainnet
    // https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7
    address public usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    function run() public {
        vm.startBroadcast();

        require(msg.sender == pool.owner(), "pool owner");

        // ========================================
        // ========================================
        // Withdraw students
        // ========================================
        // ========================================

        address[] memory students = new address[](21);
        // https://docs.google.com/spreadsheets/d/1LtR6zEHqmUgXdRn0NSkm2pmDreL8w3GBOMDGs7vVUGE/edit?gid=1384484463#gid=1384484463
        students[0] = 0x0B2a6F97aa427d6CC82F8b30D950FddB6614Ce85;
        students[1] = 0xD76ce7F02351Ab3E3103ee3b6A64601BEc580c6E;
        students[2] = 0x3458B20044F5f20a80ab25af160498A853fDE013;
        students[3] = 0x7181C06492B9e9a36fAC1A6204dF8be0BD4E8641;
        students[4] = 0x8b57AeFCa35eef5ccA30cE72e262177cf2b95917;
        students[5] = 0x3435Bad6F68a6a14a177485b68d233a4074943dB;
        students[6] = 0xEA56b22c446A5fbEd33c231feCD42A1d78641119;
        students[7] = 0xeFcb13871eCBcF20c528D3209bc236336A35B0F4;
        students[8] = 0x302B18b95A2b6345c8ec5D8B67AB84076F507D01;
        students[9] = 0xAcD1D964551a1dEd46EA7CC7A71F0c6Ee4b1C554;
        students[10] = 0xC8F77E8Fb65aD25425eCaCB2AD359A186a5125c9;
        students[11] = 0x25DfF2cC7d63Fcff96aded40bdFf0A7F7f9A562F;
        students[12] = 0x1d2073424841569e531Ef1a7C2E7749185412f8D;
        students[13] = 0x0833E6e33A5397ED4147bb8cf31aFB0a6055Dd62;
        students[14] = 0x99bB0c670B496c107782dad2833c01d1f45429a5;
        students[15] = 0x51ff66B7A4b1950ff6C1CA252172eD8040f2A20c;
        // students[] = 0xB407b1d64A01c880e4E0890f9ceAc56e6F48D807;
        // students[] = 0x13c1591e25f290861171ce2C7700E39e36AA5514;
        students[16] = 0xddBB537c00D8c15623F88a37c336d56B69CbA486;
        // students[] = 0x563d8cC5b5DC56E4096B9B2ca170DC818B848e12;
        // students[] = 0xB6b2FeA308dB76BE0a28938AEfc76f5BAf716730;
        // students[] = 0x39BC1b6038757c76aE9E73C9A0207c2feB36a169;
        // students[] = 0x6758EDfd13040f577A00b13eB0b1c49400AACa29;
        students[17] = 0x8ae9B203a0fE7F8167B54856E59cc52135E14FbC;
        // students[] = 0x8C67Bb0AfCEb6750ed89D592A1C0B65EB9D26aBf;
        students[18] = 0xe2CC30cCB1d92d7C7Efb0fd61D5a937586bA0D11;
        students[19] = 0x8Fe7A21fe057F9c31812e5049128a41fea79d066;
        students[20] = 0x8eE84937C2BF37424F0Ba885653d2Bf3cdc77080;

        pool.withdrawMany(students);

        // ========================================
        // ========================================
        // Transfer funds to backup funds manager
        // ========================================
        // ========================================
        uint256 backupFundsManagerPrevBalance = pool.usdt().balanceOf(pool.backupFundsManager());
        pool.transferSlashedToFundsManager(
            // useBackupFundsManager to send USDT to Joel
            true
        );
        uint256 backupFundsManagerAfterBalance = pool.usdt().balanceOf(pool.backupFundsManager());
        uint256 totalSlashedAmount = 945700000;
        require(backupFundsManagerAfterBalance == backupFundsManagerPrevBalance + totalSlashedAmount, "transferred");
        // ========================================
        // ========================================

        require(pool.usdt().balanceOf(address(pool)) == 0, "pool empty");

        vm.stopBroadcast();
    }

    // Adding this to be excluded from forge coverage report
    function testA() public {}
}
