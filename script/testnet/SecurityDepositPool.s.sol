// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {SecurityDepositPool} from "../../src/SecurityDepositPool.sol";
import {MockUSDT} from "./MockUSDT.sol";

contract SecurityDepositPoolScript is Script {
    SecurityDepositPool public pool;
    MockUSDT usdt;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address instructor = 0x120Dc801A7970Cd5EfEe971530C18b1A4a978609;
        // Just for testing. In production, this should be diff from the instructor address
        address fundsManager = 0x0B4A4cac95D730159500dFAd51a5aCa670F97f32;
        // Backup funds manager address
        address backupFundsManager = 0xCB321E2b70ad18aEA3098d5388eda36036Bd77E0;

        // an array of addresses that will get mock USDT
        address[] memory testAddresses = new address[](5);
        testAddresses[0] = 0x0B4A4cac95D730159500dFAd51a5aCa670F97f32;
        testAddresses[1] = 0x120Dc801A7970Cd5EfEe971530C18b1A4a978609;
        testAddresses[2] = 0xCB321E2b70ad18aEA3098d5388eda36036Bd77E0;
        testAddresses[3] = 0xF1d8ca81c335d414Fe9D01Df70304C8362DaF5bf;
        testAddresses[4] = 0x39BC1b6038757c76aE9E73C9A0207c2feB36a169; // JY

        usdt = new MockUSDT("Mock USDT", "USDT", 6);
        // 73 USDT
        uint256 flatDepositAmount = 73 * 10 ** 6;
        // Mint USDT to the test addresses
        for (uint256 i = 0; i < testAddresses.length; i++) {
            usdt.mint(testAddresses[i], flatDepositAmount);
        }

        // Just for testing
        uint256 courseEndTime = block.timestamp + 24 hours;
        pool = new SecurityDepositPool(
            instructor, fundsManager, backupFundsManager, address(usdt), flatDepositAmount, courseEndTime
        );

        vm.stopBroadcast();
    }

    // Adding this to be excluded from forge coverage report
    function testA() public {}
}
