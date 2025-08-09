// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {SecurityDepositPool} from "../../src/SecurityDepositPool.sol";

contract SecurityDepositPoolScript is Script {
    SecurityDepositPool public pool;
    // USDT contract address on Ethereum mainnet
    // https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7
    address usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Joel https://etherscan.io/address/0x8Fe7A21fe057F9c31812e5049128a41fea79d066
        address instructor = 0x8Fe7A21fe057F9c31812e5049128a41fea79d066;
        // BRL https://etherscan.io/address/0x2a063d9C09a5C5fAdB53d67F298D650f371bADb5
        address fundsManager = 0x2a063d9C09a5C5fAdB53d67F298D650f371bADb5;
        // Backup funds manager address. We're gonna use the slashed funds ourselves anyways,
        // so it's ok to set it to the instructor address
        address backupFundsManager = instructor;
        // 73 USDT
        uint256 flatDepositAmount = 73 * 10 ** 6;

        // Approx deployment time = Sat Aug 09 2025 23:00:00 GMT+0900
        // Math.floor(new Date("2025-10-04T23:00:00+09:00").getTime() / 1000)
        uint256 courseEndTime = 1759586400;
        // Sanity check
        // 7 weeks till Oct 04, so must be 58 days away at max
        require(courseEndTime < block.timestamp + 60 days, "Course end time too late");
        require(courseEndTime > block.timestamp, "Course end time too early");
        pool = new SecurityDepositPool(
            instructor, fundsManager, backupFundsManager, usdt, flatDepositAmount, courseEndTime
        );

        vm.stopBroadcast();
    }

    // Adding this to be excluded from forge coverage report
    function testA() public {}
}
