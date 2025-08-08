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
        address fundsManager = 0x120Dc801A7970Cd5EfEe971530C18b1A4a978609;
        // Backup funds manager address
        address backupFundsManager = 0x0B4A4cac95D730159500dFAd51a5aCa670F97f32;
        usdt = new MockUSDT("Mock USDT", "USDT", 6);
        // 73 USDT
        uint256 flatDepositAmount = 73 * 10 ** 6;
        // Just for testing
        uint256 courseEndTime = block.timestamp + 1 hours;
        usdt.mint(instructor, 1000 * 10 ** 6);
        pool = new SecurityDepositPool(
            instructor, fundsManager, backupFundsManager, address(usdt), flatDepositAmount, courseEndTime
        );

        vm.stopBroadcast();
    }

    // Adding this to be excluded from forge coverage report
    function testA() public {}
}
