// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SecurityDepositPoolHarness} from "./SecurityDepositPoolHarness.sol";
import {ISecurityDepositPool} from "../src/ISecurityDepositPool.sol";
import {MockERC20} from "./MockERC20.sol";

contract SecurityDepositPoolTest is Test, ISecurityDepositPool {
    SecurityDepositPoolHarness public pool;
    MockERC20 public mockUsdc;
    address public instructor = address(0x123);
    address public fundsManager = address(0x456);
    uint8 public usdcDecimals = 6;
    uint256 public flatDepositAmount = 70 * 10 ** usdcDecimals; // Assuming USDC has 6 decimals
    uint256 courseEndTime = block.timestamp + 30 days; // Course ends in 30 days

    function setUp() public {
        mockUsdc = new MockERC20("Mock USDC", "USDC", usdcDecimals);
        pool = new SecurityDepositPoolHarness(
            instructor, fundsManager, address(mockUsdc), flatDepositAmount, courseEndTime
        );
    }

    /**
     *
     * Constructor
     *
     */
    function testConstructorSucceeds() public {
        address instructor_ = address(0x111);
        address fundsManager_ = address(0x222);
        address usdc_ = address(0x333);
        uint256 flatDepositAmount_ = 100 * 10 ** usdcDecimals;
        uint256 courseFinalizedTime_ = block.timestamp + 10 days;
        SecurityDepositPoolHarness pool_ =
            new SecurityDepositPoolHarness(instructor_, fundsManager_, usdc_, flatDepositAmount_, courseFinalizedTime_);
        assertEq(pool_.owner(), instructor_);
        assertEq(pool_.fundsManager(), fundsManager_);
        assertEq(address(pool_.usdc()), usdc_);
        assertEq(pool_.flatDepositAmount(), flatDepositAmount_);
        assertEq(pool_.courseFinalizedTime(), courseFinalizedTime_);
    }

    function testConstructorFailsIfZeroFundsManager() public {
        address instructor_ = address(0x111);
        address usdc_ = address(0x333);
        uint256 flatDepositAmount_ = 100 * 10 ** usdcDecimals;
        uint256 courseFinalizedTime_ = block.timestamp + 10 days;
        vm.expectRevert(bytes4(keccak256("ZeroFundsManagerAddress()")));
        new SecurityDepositPoolHarness(instructor_, address(0), usdc_, flatDepositAmount_, courseFinalizedTime_);
    }

    function testConstructorFailsIfZeroUSDC() public {
        address instructor_ = address(0x111);
        address fundsManager_ = address(0x222);
        uint256 flatDepositAmount_ = 100 * 10 ** usdcDecimals;
        uint256 courseFinalizedTime_ = block.timestamp + 10 days;
        vm.expectRevert(bytes4(keccak256("ZeroUSDCAddress()")));
        new SecurityDepositPoolHarness(instructor_, fundsManager_, address(0), flatDepositAmount_, courseFinalizedTime_);
    }

    function testConstructorFailsIfZeroFlatDepositAmount() public {
        address instructor_ = address(0x111);
        address fundsManager_ = address(0x222);
        address usdc_ = address(0x333);
        uint256 courseFinalizedTime_ = block.timestamp + 10 days;
        vm.expectRevert(bytes4(keccak256("ZeroFlatDepositAmount()")));
        new SecurityDepositPoolHarness(instructor_, fundsManager_, usdc_, 0, courseFinalizedTime_);
    }

    function testConstructorFailsIfCourseFinalizedTimeInPast() public {
        address instructor_ = address(0x111);
        address fundsManager_ = address(0x222);
        address usdc_ = address(0x333);
        uint256 flatDepositAmount_ = 100 * 10 ** usdcDecimals;
        uint256 courseFinalizedTime_ = block.timestamp - 1;
        vm.expectRevert(bytes4(keccak256("CourseFinalizedTimeInPast()")));
        new SecurityDepositPoolHarness(instructor_, fundsManager_, usdc_, flatDepositAmount_, courseFinalizedTime_);
    }

    function testConstructorFailsIfCourseFinalizedTimeInDistantFuture() public {
        address instructor_ = address(0x111);
        address fundsManager_ = address(0x222);
        address usdc_ = address(0x333);
        uint256 flatDepositAmount_ = 100 * 10 ** usdcDecimals;
        uint256 courseFinalizedTime_ = block.timestamp + 61 days;
        vm.expectRevert(bytes4(keccak256("CourseFinalizedTimeInDistantFuture()")));
        new SecurityDepositPoolHarness(instructor_, fundsManager_, usdc_, flatDepositAmount_, courseFinalizedTime_);
    }

    /**
     *
     * Deposit
     *
     */
    function testDepositSucceeds() public {
        address student = address(0x789);
        // Mint USDC to student and approve pool
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);

        // Deposit
        vm.prank(student);
        pool.deposit();
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount);

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
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount);

        // Second deposit should revert
        vm.prank(student);
        vm.expectRevert(bytes4(keccak256("AlreadyDeposited()")));
        pool.deposit();
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount);
    }

    function testDepositFailsIfCourseFinalized() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        vm.prank(student);
        vm.expectRevert(bytes4(keccak256("CourseFinalized()")));
        pool.deposit();
        assertEq(mockUsdc.balanceOf(address(pool)), 0);
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
        assertEq(mockUsdc.balanceOf(address(pool)), 0);
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
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount);
    }

    /**
     *
     * Withdraw
     *
     */
    function testWithdrawFailsIfCourseNotFinalized() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();

        // Do NOT warp time; course is still ongoing
        vm.prank(student);
        vm.expectRevert(bytes4(keccak256("CourseNotFinalized()")));
        pool.withdraw();
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount);
    }

    function testWithdrawSucceeds() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount);

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        uint256 studentBalanceBefore = mockUsdc.balanceOf(student);
        assertEq(studentBalanceBefore, 0);

        vm.prank(student);
        pool.withdraw();
        // Student should get their deposit back
        assertEq(mockUsdc.balanceOf(student), flatDepositAmount);
        // Check contract balance
        assertEq(mockUsdc.balanceOf(address(pool)), 0);
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
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount);

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        vm.prank(student);
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(student);
        pool.withdraw();
        assertEq(mockUsdc.balanceOf(address(pool)), 0);
    }

    function testWithdrawAfterSlashing() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount);

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
        assertEq(studentBalanceBefore, 0);
        vm.prank(student);
        pool.withdraw();
        // Student should get only the remaining deposit
        assertEq(mockUsdc.balanceOf(student), flatDepositAmount - slashAmount);
        // Check contract balance. Slashed amount should remain in the pool until
        // transferred to the fundsManager
        assertEq(mockUsdc.balanceOf(address(pool)), slashAmount);
        // Deposit should be reset
        assertEq(pool.deposits(student), 0);
        // hasDeposited stays true forever
        assertTrue(pool.hasDeposited(student));
    }

    function testWithdrawFailsIfSlashedToZero() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount);

        // Owner slashes 100% of the deposit using slashMany
        uint256 slashAmount = flatDepositAmount;
        address[] memory students = new address[](1);
        students[0] = student;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = slashAmount;
        vm.prank(instructor); // Owner
        pool.slashMany(students, amounts);

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        vm.prank(student);
        vm.expectRevert(bytes4(keccak256("NoRemainingDeposit()")));
        pool.withdraw();

        // Withdraw fails. Slashed amount remains in the pool
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount);
    }

    /**
     *
     * Withdraw Many
     *
     */
    function testWithdrawManySucceeds() public {
        address student1 = address(0x789);
        address student2 = address(0xABC);
        mockUsdc.mint(student1, flatDepositAmount);
        mockUsdc.mint(student2, flatDepositAmount);
        vm.prank(student1);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student2);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student1);
        pool.deposit();
        vm.prank(student2);
        pool.deposit();
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount * 2);

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        address[] memory students = new address[](2);
        students[0] = student1;
        students[1] = student2;
        uint256 student1BalanceBefore = mockUsdc.balanceOf(student1);
        uint256 student2BalanceBefore = mockUsdc.balanceOf(student2);

        vm.prank(instructor); // Only owner can call
        pool.withdrawMany(students);

        // Both students should get their deposit back
        assertEq(mockUsdc.balanceOf(student1), student1BalanceBefore + flatDepositAmount);
        assertEq(mockUsdc.balanceOf(student2), student2BalanceBefore + flatDepositAmount);
        // Contract balance should be zero
        assertEq(mockUsdc.balanceOf(address(pool)), 0);
        // Deposits should be reset
        assertEq(pool.deposits(student1), 0);
        assertEq(pool.deposits(student2), 0);
        // hasDeposited stays true forever
        assertTrue(pool.hasDeposited(student1));
        assertTrue(pool.hasDeposited(student2));
    }

    function testWithdrawManyEmitsWithdrawnManyEvent() public {
        address student1 = address(0x789);
        address student2 = address(0xABC);
        mockUsdc.mint(student1, flatDepositAmount);
        mockUsdc.mint(student2, flatDepositAmount);
        vm.prank(student1);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student2);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student1);
        pool.deposit();
        vm.prank(student2);
        pool.deposit();
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount * 2);

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        address[] memory students = new address[](2);
        students[0] = student1;
        students[1] = student2;

        vm.prank(instructor); // Only owner can call
        vm.expectEmit(true, true, false, false);
        emit WithdrawnMany(students);
        pool.withdrawMany(students);
    }

    function testWithdrawManyFailsIfNotOwner() public {
        address student1 = address(0x789);
        address student2 = address(0xABC);
        mockUsdc.mint(student1, flatDepositAmount);
        mockUsdc.mint(student2, flatDepositAmount);
        vm.prank(student1);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student2);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student1);
        pool.deposit();
        vm.prank(student2);
        pool.deposit();
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount * 2);

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        address[] memory students = new address[](2);
        students[0] = student1;
        students[1] = student2;

        // Try to call withdrawMany as a non-owner (student1)
        vm.prank(student1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", student1));
        pool.withdrawMany(students);
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount * 2);
    }

    function testWithdrawManyFailsIfCourseNotFinalized() public {
        address student1 = address(0x789);
        address student2 = address(0xABC);
        mockUsdc.mint(student1, flatDepositAmount);
        mockUsdc.mint(student2, flatDepositAmount);
        vm.prank(student1);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student2);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student1);
        pool.deposit();
        vm.prank(student2);
        pool.deposit();
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount * 2);

        address[] memory students = new address[](2);
        students[0] = student1;
        students[1] = student2;

        // Do NOT warp time; course is still ongoing
        vm.prank(instructor); // Only owner can call
        vm.expectRevert(bytes4(keccak256("CourseNotFinalized()")));
        pool.withdrawMany(students);

        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount * 2);
    }

    function testWithdrawManyWithPartialSlashing() public {
        address student1 = address(0x789);
        address student2 = address(0xABC);
        mockUsdc.mint(student1, flatDepositAmount);
        mockUsdc.mint(student2, flatDepositAmount);
        vm.prank(student1);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student2);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student1);
        pool.deposit();
        vm.prank(student2);
        pool.deposit();
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount * 2);

        // Owner slashes half the deposit of student1
        uint256 slashAmount1 = flatDepositAmount / 2;
        address[] memory studentsToSlash = new address[](1);
        studentsToSlash[0] = student1;
        uint256[] memory amountsToSlash = new uint256[](1);
        amountsToSlash[0] = slashAmount1;
        vm.prank(instructor);
        pool.slashMany(studentsToSlash, amountsToSlash);

        // Check balances after slashing
        assertEq(pool.deposits(student1), flatDepositAmount - slashAmount1);
        assertEq(pool.deposits(student2), flatDepositAmount);
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount * 2);

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        address[] memory students = new address[](2);
        students[0] = student1;
        students[1] = student2;
        uint256 student1BalanceBefore = mockUsdc.balanceOf(student1);
        uint256 student2BalanceBefore = mockUsdc.balanceOf(student2);
        assertEq(student1BalanceBefore, 0);
        assertEq(student2BalanceBefore, 0);

        vm.prank(instructor);
        pool.withdrawMany(students);

        // Student1 should get only the remaining deposit
        assertEq(mockUsdc.balanceOf(student1), (flatDepositAmount - slashAmount1));
        // Student2 should get full deposit
        assertEq(mockUsdc.balanceOf(student2), flatDepositAmount);
        // Pool balance should be only the slashed amount
        assertEq(mockUsdc.balanceOf(address(pool)), slashAmount1);
        // Deposits should be reset
        assertEq(pool.deposits(student1), 0);
        assertEq(pool.deposits(student2), 0);
        // hasDeposited stays true forever
        assertTrue(pool.hasDeposited(student1));
        assertTrue(pool.hasDeposited(student2));
    }

    /**
     *
     * Slash Many
     *
     */
    struct SlashManySetup {
        address student1;
        address student2;
    }

    function slashManySetup() internal returns (SlashManySetup memory setup) {
        address student1 = address(0x789);
        address student2 = address(0xABC);
        mockUsdc.mint(student1, flatDepositAmount);
        mockUsdc.mint(student2, flatDepositAmount);
        vm.prank(student1);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student2);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student1);
        pool.deposit();
        vm.prank(student2);
        pool.deposit();
        assertEq(pool.deposits(student1), flatDepositAmount);
        assertEq(pool.deposits(student2), flatDepositAmount);
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount * 2);

        setup.student1 = student1;
        setup.student2 = student2;
        return setup;
    }

    function testSlashManySucceeds() public {
        SlashManySetup memory setup = slashManySetup();
        address student1 = setup.student1;
        address student2 = setup.student2;

        // Owner slashes different amounts for each student
        uint256 slashAmount1 = flatDepositAmount / 2;
        uint256 slashAmount2 = flatDepositAmount / 3;
        address[] memory students = new address[](2);
        students[0] = student1;
        students[1] = student2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = slashAmount1;
        amounts[1] = slashAmount2;
        vm.prank(instructor);
        pool.slashMany(students, amounts);

        // Check deposits after slashing
        assertEq(pool.deposits(student1), flatDepositAmount - slashAmount1);
        assertEq(pool.deposits(student2), flatDepositAmount - slashAmount2);
        // Check totalSlashed
        assertEq(pool.totalSlashed(), slashAmount1 + slashAmount2);
        // Pool balance remains unchanged until withdrawal
        assertEq(mockUsdc.balanceOf(address(pool)), flatDepositAmount * 2);
    }

    function testSlashManyEmitsSlashedManyEvent() public {
        address student1 = address(0x789);
        address student2 = address(0xABC);
        mockUsdc.mint(student1, flatDepositAmount);
        mockUsdc.mint(student2, flatDepositAmount);
        vm.prank(student1);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student2);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student1);
        pool.deposit();
        vm.prank(student2);
        pool.deposit();

        uint256 slashAmount1 = flatDepositAmount / 2;
        uint256 slashAmount2 = flatDepositAmount / 3;
        address[] memory students = new address[](2);
        students[0] = student1;
        students[1] = student2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = slashAmount1;
        amounts[1] = slashAmount2;

        vm.prank(instructor);
        vm.expectEmit(true, true, false, false);
        emit SlashedMany(students, amounts);
        pool.slashMany(students, amounts);
    }

    function testSlashManyFailsIfArrayLengthMismatch() public {
        SlashManySetup memory setup = slashManySetup();
        address student1 = setup.student1;
        address student2 = setup.student2;

        // Owner tries to slash with mismatched arrays
        address[] memory students = new address[](2);
        students[0] = student1;
        students[1] = student2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flatDepositAmount / 2;
        vm.prank(instructor);
        vm.expectRevert(bytes4(keccak256("ArrayLengthMismatch()")));
        pool.slashMany(students, amounts);
    }

    function testSlashManyFailsAfterCourseFinalized() public {
        SlashManySetup memory setup = slashManySetup();
        address student1 = setup.student1;
        address student2 = setup.student2;

        // Owner slashes both students
        uint256 slashAmount1 = flatDepositAmount / 2;
        uint256 slashAmount2 = flatDepositAmount / 3;
        address[] memory students = new address[](2);
        students[0] = student1;
        students[1] = student2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = slashAmount1;
        amounts[1] = slashAmount2;
        vm.prank(instructor);
        pool.slashMany(students, amounts);

        // Warp time past course end
        vm.warp(block.timestamp + 31 days);

        // Try to call slashMany again, should revert
        vm.prank(instructor);
        vm.expectRevert(bytes4(keccak256("CourseFinalized()")));
        pool.slashMany(students, amounts);
    }

    function testSlashManyFailsIfNotOwner() public {
        SlashManySetup memory setup = slashManySetup();
        address student1 = setup.student1;
        address student2 = setup.student2;

        uint256 slashAmount1 = flatDepositAmount / 2;
        uint256 slashAmount2 = flatDepositAmount / 3;
        address[] memory students = new address[](2);
        students[0] = student1;
        students[1] = student2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = slashAmount1;
        amounts[1] = slashAmount2;

        // Try to call slashMany as a non-owner (student1)
        vm.prank(student1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", student1));
        pool.slashMany(students, amounts);
    }

    /**
     *
     * Transfer Slashed To Funds Manager
     *
     */
    function testTransferSlashedToFundsManagerSucceeds() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();
        // Slash deposit
        address[] memory students = new address[](1);
        students[0] = student;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flatDepositAmount / 2;
        vm.prank(instructor);
        pool.slashMany(students, amounts);
        // Warp time past course end
        vm.warp(block.timestamp + 31 days);
        // Transfer slashed funds
        uint256 slashedAmount = flatDepositAmount / 2;
        uint256 fundsManagerBalanceBefore = mockUsdc.balanceOf(fundsManager);
        vm.prank(fundsManager);
        pool.transferSlashedToFundsManager();
        // Funds manager should receive slashed amount
        assertEq(mockUsdc.balanceOf(fundsManager), fundsManagerBalanceBefore + slashedAmount);
        // totalSlashed should be zero
        assertEq(pool.totalSlashed(), 0);
        // isTotalSlashedTransferred should be true
        assertTrue(pool.isTotalSlashedTransferred());
    }

    function testTransferSlashedToFundsManagerFailsIfNotFundsManagerOrOwner() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();
        address[] memory students = new address[](1);
        students[0] = student;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flatDepositAmount / 2;
        vm.prank(instructor);
        pool.slashMany(students, amounts);
        vm.warp(block.timestamp + 31 days);
        address notAllowed = address(0x999);
        vm.prank(notAllowed);
        vm.expectRevert(abi.encodeWithSignature("NotFundsManagerOrOwner()"));
        pool.transferSlashedToFundsManager();
    }

    function testTransferSlashedToFundsManagerFailsIfCourseNotFinalized() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();
        address[] memory students = new address[](1);
        students[0] = student;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flatDepositAmount / 2;
        vm.prank(instructor);
        pool.slashMany(students, amounts);
        // Do NOT warp time
        vm.prank(fundsManager);
        vm.expectRevert(bytes4(keccak256("CourseNotFinalized()")));
        pool.transferSlashedToFundsManager();
    }

    function testTransferSlashedToFundsManagerFailsIfNoSlashedAmount() public {
        // Warp time past course end
        vm.warp(block.timestamp + 31 days);
        vm.prank(fundsManager);
        vm.expectRevert(bytes4(keccak256("NoSlashedAmountToTransfer()")));
        pool.transferSlashedToFundsManager();
    }

    function testTransferSlashedToFundsManagerFailsIfAlreadyTransferred() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();
        address[] memory students = new address[](1);
        students[0] = student;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flatDepositAmount / 2;
        vm.prank(instructor);
        pool.slashMany(students, amounts);
        vm.warp(block.timestamp + 31 days);
        vm.prank(fundsManager);
        pool.transferSlashedToFundsManager();
        // Try again
        vm.prank(fundsManager);
        vm.expectRevert(bytes4(keccak256("SlashedAmountAlreadyTransferred()")));
        pool.transferSlashedToFundsManager();
    }

    /**
     *
     * Withdraw Harness
     *
     * Since this function is internal and not guarded by
     * afterCourseFinalized modifier, we don't need to warp time
     *
     */
    function testWithdrawFailsIfHasNotDeposited() public {
        address student = address(0x789);

        vm.prank(student);
        vm.expectRevert(bytes4(keccak256("HasNotDeposited()")));
        pool.withdrawHarness(student);
    }

    function testWithdrawFailsIfNoRemainingDeposit() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();

        // Slash 100% of deposit
        address[] memory students = new address[](1);
        students[0] = student;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flatDepositAmount;
        vm.prank(instructor);
        pool.slashMany(students, amounts);

        vm.prank(student);
        vm.expectRevert(bytes4(keccak256("NoRemainingDeposit()")));
        pool.withdrawHarness(student);
    }

    function testWithdrawSucceedsWithPartialDeposit() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();

        // Slash half of deposit
        address[] memory students = new address[](1);
        students[0] = student;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flatDepositAmount / 2;
        vm.prank(instructor);
        pool.slashMany(students, amounts);

        uint256 studentBalanceBefore = mockUsdc.balanceOf(student);
        assertEq(studentBalanceBefore, 0);
        vm.prank(student);
        pool.withdrawHarness(student);
        // Student should get only the remaining deposit
        assertEq(mockUsdc.balanceOf(student), flatDepositAmount / 2);
        // Deposit should be reset
        assertEq(pool.deposits(student), 0);
    }

    function testWithdrawSucceedsWithFullDeposit() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();

        uint256 studentBalanceBefore = mockUsdc.balanceOf(student);
        assertEq(studentBalanceBefore, 0);
        vm.prank(student);
        pool.withdrawHarness(student);
        // Student should get their full deposit back
        assertEq(mockUsdc.balanceOf(student), flatDepositAmount);
        // Deposit should be reset
        assertEq(pool.deposits(student), 0);
    }

    /**
     *
     * Slash Harness
     *
     * Since this function is internal and not guarded by
     * beforeCourseFinalized modifier, we don't need to warp time
     *
     */
    function testSlashHarnessSucceeds() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();

        // Slash half the deposit
        uint256 slashAmount = flatDepositAmount / 2;
        pool.slashHarness(student, slashAmount);

        // Deposit should be reduced
        assertEq(pool.deposits(student), flatDepositAmount - slashAmount);
        // totalSlashed should increase
        assertEq(pool.totalSlashed(), slashAmount);
    }

    function testSlashHarnessFailsIfHasNotDeposited() public {
        address student = address(0x789);
        uint256 slashAmount = 1 ether;
        vm.expectRevert(bytes4(keccak256("HasNotDeposited()")));
        pool.slashHarness(student, slashAmount);
    }

    function testSlashHarnessFailsIfInsufficientDeposit() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();

        // Try to slash more than deposited
        uint256 slashAmount = flatDepositAmount + 1;
        vm.expectRevert(bytes4(keccak256("InsufficientDeposit()")));
        pool.slashHarness(student, slashAmount);
    }

    function testSlashHarnessMultipleCalls() public {
        address student = address(0x789);
        mockUsdc.mint(student, flatDepositAmount);
        vm.prank(student);
        mockUsdc.approve(address(pool), flatDepositAmount);
        vm.prank(student);
        pool.deposit();

        // Slash a portion
        uint256 slashAmount1 = flatDepositAmount / 3;
        pool.slashHarness(student, slashAmount1);
        assertEq(pool.deposits(student), flatDepositAmount - slashAmount1);
        assertEq(pool.totalSlashed(), slashAmount1);

        // Slash another portion
        uint256 slashAmount2 = flatDepositAmount / 6;
        pool.slashHarness(student, slashAmount2);
        assertEq(pool.deposits(student), flatDepositAmount - slashAmount1 - slashAmount2);
        assertEq(pool.totalSlashed(), slashAmount1 + slashAmount2);
    }
}
