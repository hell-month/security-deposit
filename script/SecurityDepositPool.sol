// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {SecurityDepositPool} from "../src/SecurityDepositPool.sol";

contract SecurityDepositPoolScript is Script {
    SecurityDepositPool public pool;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // counter = new Counter();

        vm.stopBroadcast();
    }

    // Adding this to be excluded from forge coverage report
    function testA() public {}
}
