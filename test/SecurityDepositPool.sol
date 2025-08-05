// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SecurityDepositPool} from "../src/SecurityDepositPool.sol";
import {ISecurityDepositPool} from "../src/ISecurityDepositPool.sol";
import {MockERC20} from "./MockERC20.sol";

contract SecurityDepositPoolTest is Test, ISecurityDepositPool {
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

    function testDepositSucceeds() public {
        address student = address(0x789);
        // Mint USDC to student and approve pool
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);

        // Deposit
        vm.prank(student);
        pool.deposit();

        // Check deposit recorded
        assertEq(pool.deposits(student), flatDepositAmount);
        assertTrue(pool.hasDeposited(student));
        // Check contract balance
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount);
    }

    function testDepositFailsIfAlreadyDeposited() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);

        // First deposit
        vm.prank(student);
        pool.deposit();

        // Second deposit should revert
        vm.prank(student);
        vm.expectRevert(bytes4(keccak256("AlreadyDeposited()")));
        pool.deposit();
    }

    function testDepositFailsIfCourseEnded() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        vm.prank(student);
        vm.expectRevert(bytes4(keccak256("CourseEnded()")));
        pool.deposit();
    }

    function testDepositFailsIfNoApproval() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);

        vm.prank(student);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)", address(pool), 0, flatDepositAmount
            )
        );

        pool.deposit();
    }

    function testDepositEmitsDepositedEvent() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);

        vm.prank(student);
        vm.expectEmit(true, false, false, true);
        emit Deposited(student, flatDepositAmount);
        pool.deposit();
    }
}
