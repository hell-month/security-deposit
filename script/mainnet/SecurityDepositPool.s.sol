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

        address instructor = 0x8Fe7A21fe057F9c31812e5049128a41fea79d066;
        // BRL
        address fundsManager = 0x2a063d9C09a5C5fAdB53d67F298D650f371bADb5;
        // Backup funds manager address. We're gonna use the slashed funds ourselves anyways,
        // so it's ok to set it to the instructor address
        address backupFundsManager = instructor;
        // 73 USDT
        uint256 flatDepositAmount = 73 * 10 ** 6;
        // Current approx time =
        uint256 courseEndTime = block.timestamp + 24 hours;
        pool = new SecurityDepositPool(
            instructor, fundsManager, backupFundsManager, address(usdt), flatDepositAmount, courseEndTime
        );

        vm.stopBroadcast();
    }

    // Adding this to be excluded from forge coverage report
    function testA() public {}
}
