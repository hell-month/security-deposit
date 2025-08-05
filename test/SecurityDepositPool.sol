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

    function testWithdrawSucceeds() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        uint256 studentBalanceBefore = mockUsdc.balanceOf(student);
        vm.prank(student);
        pool.withdraw();
        // Student should get their deposit back
        assertEq(mockUsdc.balanceOf(student), studentBalanceBefore + flatDepositAmount);
        // Deposit should be reset
        assertEq(pool.deposits(student), 0);
        // hasDeposited stays true forever becauase
        // the contract is a one-time deposit contract
        assertTrue(pool.hasDeposited(student));
    }

    function testWithdrawFailsIfNoDeposit() public {
        address student = address(0x789);
        vm.prank(student);
        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        vm.expectRevert(bytes4(keccak256("HasNotDeposited()")));
        pool.withdraw();
    }

    function testWithdrawEmitsWithdrawnEvent() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        vm.prank(student);
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(student, flatDepositAmount);
        pool.withdraw();
    }

    function testWithdrawAfterSlashing() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();

        // Owner slashes half the deposit using slashMany
        uint256 slashAmount = flatDepositAmount / 2;
        address[] memory students = new address[](1);
        students[0] = student;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = slashAmount;
        vm.prank(instructor); // Owner
        pool.slashMany(students, amounts);

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        uint256 studentBalanceBefore = mockUsdc.balanceOf(student);
        vm.prank(student);
        pool.withdraw();
        // Student should get only the remaining deposit
        assertEq(mockUsdc.balanceOf(student), studentBalanceBefore + (flatDepositAmount - slashAmount));
        // Deposit should be reset
        assertEq(pool.deposits(student), 0);
        // hasDeposited stays true forever
        assertTrue(pool.hasDeposited(student));
    }
}
