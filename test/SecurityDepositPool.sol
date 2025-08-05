// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SecurityDepositPool} from "../src/SecurityDepositPool.sol";
import {MockERC20} from "./MockERC20.sol";

contract CounterTest is Test {
    SecurityDepositPool public pool;
    MockERC20 public mockUsdc;
    address public instructor = address(0x123);
    address public supervisor = address(0x456);
    uint8 public usdcDecimals = 6;
    uint256 public flatDepositAmount = 70 * 10 ** usdcDecimals; // Assuming USDC has 6 decimals
    uint256 courseEndTime = block.timestamp + 30 days; // Course ends in 30 days

    function setUp() public {
        mockUsdc = new MockERC20("Mock USDC", "USDC", usdcDecimals);
        pool = new SecurityDepositPool(instructor, supervisor, address(mockUsdc), flatDepositAmount, courseEndTime);
    }
}
