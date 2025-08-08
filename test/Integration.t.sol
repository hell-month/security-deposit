// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SecurityDepositPoolHarness} from "./SecurityDepositPoolHarness.sol";
import {ISecurityDepositPool} from "../src/ISecurityDepositPool.sol";
import {MockERC20} from "./MockERC20.sol";
import {MockMalformedERC20} from "./MockMalformedERC20.sol";

contract IntegrationTest is Test, ISecurityDepositPool {
    SecurityDepositPoolHarness public pool;
    MockERC20 public mockUsdt;
    address public instructor = address(0x123);
    address public fundsManager = address(0x456);
    address public backupFundsManager = address(0x789);
    uint8 public usdtDecimals = 6;
    uint256 public flatDepositAmount = 100 * 10 ** usdtDecimals; // 100 USDT
    uint256 courseEndTime = block.timestamp + 30 days;

    // Array of 12 students for testing
    address[12] public students;

    function setUp() public {
        mockUsdt = new MockERC20("Mock USDT", "USDT", usdtDecimals);
        pool = new SecurityDepositPoolHarness(
            instructor, fundsManager, backupFundsManager, address(mockUsdt), flatDepositAmount, courseEndTime
        );

        // Initialize student addresses
        for (uint256 i = 0; i < 12; i++) {
            students[i] = address(uint160(0x1000 + i));
        }
    }

    function _setupStudentDeposits() internal {
        // 10 students deposit
        for (uint256 i = 0; i < 10; i++) {
            mockUsdt.mint(students[i], flatDepositAmount);
            vm.prank(students[i]);
            mockUsdt.approve(address(pool), flatDepositAmount);
            vm.prank(students[i]);
            pool.deposit();

            assertEq(pool.deposits(students[i]), flatDepositAmount);
            assertTrue(pool.hasDeposited(students[i]));
        }

        assertEq(mockUsdt.balanceOf(address(pool)), flatDepositAmount * 10);
    }

    function _testErrorConditions() internal {
        // Test double deposit
        mockUsdt.mint(students[0], flatDepositAmount);
        vm.prank(students[0]);
        mockUsdt.approve(address(pool), flatDepositAmount);
        vm.prank(students[0]);
        vm.expectRevert(bytes4(keccak256("AlreadyDeposited()")));
        pool.deposit();

        // Clean up extra USDT
        mockUsdt.burn(students[0], flatDepositAmount);
    }

    function _performSlashing() internal returns (uint256) {
        address[] memory slashStudents = new address[](4);
        uint256[] memory slashAmounts = new uint256[](4);

        slashStudents[0] = students[0];
        slashAmounts[0] = (flatDepositAmount * 33) / 100; // 33%

        slashStudents[1] = students[1];
        slashAmounts[1] = (flatDepositAmount * 377) / 1000; // 37.7%

        slashStudents[2] = students[2];
        slashAmounts[2] = flatDepositAmount; // 100%

        slashStudents[3] = students[3];
        slashAmounts[3] = (flatDepositAmount * 625) / 1000; // 62.5%

        uint256 totalSlashed = slashAmounts[0] + slashAmounts[1] + slashAmounts[2] + slashAmounts[3];

        vm.prank(instructor);
        pool.slashMany(slashStudents, slashAmounts);

        assertEq(pool.totalSlashed(), totalSlashed);
        return totalSlashed;
    }

    function _performWithdrawals() internal {
        // Individual withdrawals (students 4, 5, 6)
        for (uint256 i = 4; i <= 6; i++) {
            uint256 poolBefore = mockUsdt.balanceOf(address(pool));
            uint256 balanceBefore = mockUsdt.balanceOf(students[i]);
            vm.prank(students[i]);
            pool.withdraw();
            assertEq(mockUsdt.balanceOf(students[i]), balanceBefore + flatDepositAmount);
            assertEq(mockUsdt.balanceOf(address(pool)), poolBefore - flatDepositAmount);
        }

        // Test double withdrawal
        vm.prank(students[4]);
        vm.expectRevert(bytes4(keccak256("NoRemainingDeposit()")));
        pool.withdraw();

        // Test withdrawal by fully slashed student
        vm.prank(students[2]);
        vm.expectRevert(bytes4(keccak256("NoRemainingDeposit()")));
        pool.withdraw();

        // Batch withdrawal by instructor
        uint256 poolBefore_ = mockUsdt.balanceOf(address(pool));

        address[] memory batchStudents = new address[](6);
        batchStudents[0] = students[0]; // 67% remaining (33% slashed)
        batchStudents[1] = students[1]; // 62.3% remaining (37.7% slashed)
        batchStudents[2] = students[3]; // 37.5% remaining (62.5% slashed)
        batchStudents[3] = students[7]; // 100% remaining (not slashed)
        batchStudents[4] = students[8]; // 100% remaining (not slashed)
        batchStudents[5] = students[9]; // 100% remaining (not slashed)

        vm.prank(instructor);
        pool.withdrawMany(batchStudents);

        // Verify withdrawals
        assertEq(
            mockUsdt.balanceOf(address(pool)),
            poolBefore_ - (flatDepositAmount - (flatDepositAmount * 33) / 100)
                - (flatDepositAmount - (flatDepositAmount * 377) / 1000)
                - (flatDepositAmount - (flatDepositAmount * 625) / 1000) - flatDepositAmount - flatDepositAmount
                - flatDepositAmount
        );

        assertEq(mockUsdt.balanceOf(students[0]), flatDepositAmount - (flatDepositAmount * 33) / 100);
        assertEq(mockUsdt.balanceOf(students[1]), flatDepositAmount - (flatDepositAmount * 377) / 1000);
        assertEq(mockUsdt.balanceOf(students[3]), flatDepositAmount - (flatDepositAmount * 625) / 1000);
        assertEq(mockUsdt.balanceOf(students[7]), flatDepositAmount);
        assertEq(mockUsdt.balanceOf(students[8]), flatDepositAmount);
        assertEq(mockUsdt.balanceOf(students[9]), flatDepositAmount);
    }

    function _transferSlashedFunds(uint256 totalSlashed) internal {
        uint256 fundsManagerBefore = mockUsdt.balanceOf(fundsManager);
        uint256 poolBefore = mockUsdt.balanceOf(address(pool));

        vm.prank(fundsManager);
        pool.transferSlashedToFundsManager(false);

        assertEq(mockUsdt.balanceOf(fundsManager), fundsManagerBefore + totalSlashed);
        assertEq(pool.totalSlashed(), 0);
        assertTrue(pool.isTotalSlashedTransferred());
        assertEq(mockUsdt.balanceOf(address(pool)), poolBefore - totalSlashed);

        // Test double transfer
        vm.prank(fundsManager);
        vm.expectRevert(bytes4(keccak256("SlashedAmountAlreadyTransferred()")));
        pool.transferSlashedToFundsManager(false);
    }

    function _verifyFinalState() internal {
        // Pool should be empty
        assertEq(mockUsdt.balanceOf(address(pool)), 0);

        // Verify conservation
        uint256 totalStudentBalances = 0;
        for (uint256 i = 0; i < 10; i++) {
            totalStudentBalances += mockUsdt.balanceOf(students[i]);
        }

        uint256 totalDistributed = totalStudentBalances + mockUsdt.balanceOf(fundsManager);
        assertEq(totalDistributed, flatDepositAmount * 10, "Total USDT should be conserved");
    }

    function testFullCourseLifecycle() public {
        // Phase 1: Student deposits
        _setupStudentDeposits();

        // Phase 2: Test error conditions
        _testErrorConditions();

        // Phase 3: Slashing operations
        uint256 totalSlashed = _performSlashing();

        // Phase 4: Course ends and withdrawals
        vm.warp(courseEndTime + 1 days);
        _performWithdrawals();

        // Phase 5: Transfer slashed funds
        _transferSlashedFunds(totalSlashed);

        // Phase 6: Final verification
        _verifyFinalState();
    }

    function testFullCourseLifecycleTransferSlashedFirst() public {
        // Phase 1: Student deposits
        _setupStudentDeposits();

        // Phase 2: Test error conditions
        _testErrorConditions();

        // Phase 3: Slashing operations
        uint256 totalSlashed = _performSlashing();

        // Phase 4: Course ends and transfer slashed funds
        vm.warp(courseEndTime + 1 days);
        _transferSlashedFunds(totalSlashed);

        // Phase 5: Withdrawals
        _performWithdrawals();

        // Phase 6: Final verification
        _verifyFinalState();
    }

    function testFullCourseLifecycleTransferAndWithdrawMixed() public {
        // Phase 1: Student deposits
        _setupStudentDeposits();

        // Phase 2: Test error conditions
        _testErrorConditions();

        // Phase 3: Slashing operations
        uint256 totalSlashed = _performSlashing();

        // Phase 4: Course ends and mixed order of withdrawals and transfer of slashed funds in the middle
        vm.warp(courseEndTime + 1 days);

        // Initial pool balance check
        uint256 initialPoolBalance = mockUsdt.balanceOf(address(pool));
        assertEq(initialPoolBalance, flatDepositAmount * 10, "Pool should have all deposits initially");

        // First batch of individual withdrawals (students 4, 5)
        for (uint256 i = 4; i <= 5; i++) {
            uint256 poolBefore = mockUsdt.balanceOf(address(pool));
            uint256 balanceBefore = mockUsdt.balanceOf(students[i]);
            vm.prank(students[i]);
            pool.withdraw();
            assertEq(mockUsdt.balanceOf(students[i]), balanceBefore + flatDepositAmount);
            assertEq(mockUsdt.balanceOf(address(pool)), poolBefore - flatDepositAmount);
        }

        // Check pool balance after first withdrawals
        uint256 poolAfterFirstWithdrawals = mockUsdt.balanceOf(address(pool));
        assertEq(
            poolAfterFirstWithdrawals,
            initialPoolBalance - (2 * flatDepositAmount),
            "Pool balance after first withdrawals"
        );

        // Transfer slashed funds in the middle of withdrawals
        uint256 fundsManagerBefore = mockUsdt.balanceOf(fundsManager);
        uint256 poolBeforeTransfer = mockUsdt.balanceOf(address(pool));

        vm.prank(fundsManager);
        pool.transferSlashedToFundsManager(false);

        assertEq(mockUsdt.balanceOf(fundsManager), fundsManagerBefore + totalSlashed);
        assertEq(pool.totalSlashed(), 0);
        assertTrue(pool.isTotalSlashedTransferred());
        assertEq(mockUsdt.balanceOf(address(pool)), poolBeforeTransfer - totalSlashed);

        // Check pool balance after slashed transfer
        uint256 poolAfterSlashedTransfer = mockUsdt.balanceOf(address(pool));
        assertEq(poolAfterSlashedTransfer, poolBeforeTransfer - totalSlashed, "Pool balance after slashed transfer");

        // Continue with more individual withdrawals (student 6)
        uint256 poolBefore6 = mockUsdt.balanceOf(address(pool));
        uint256 balanceBefore6 = mockUsdt.balanceOf(students[6]);
        vm.prank(students[6]);
        pool.withdraw();
        assertEq(mockUsdt.balanceOf(students[6]), balanceBefore6 + flatDepositAmount);
        assertEq(mockUsdt.balanceOf(address(pool)), poolBefore6 - flatDepositAmount);

        // Test error conditions in the middle
        vm.prank(students[4]); // Already withdrew
        vm.expectRevert(bytes4(keccak256("NoRemainingDeposit()")));
        pool.withdraw();

        vm.prank(students[2]); // Fully slashed
        vm.expectRevert(bytes4(keccak256("NoRemainingDeposit()")));
        pool.withdraw();

        // Batch withdrawal by instructor for remaining students
        uint256 poolBeforeBatch = mockUsdt.balanceOf(address(pool));

        address[] memory batchStudents = new address[](6);
        batchStudents[0] = students[0]; // 67 remaining (33% slashed)
        batchStudents[1] = students[1]; // 62.3 remaining (37.7% slashed)
        batchStudents[2] = students[3]; // 37.5 remaining (62.5% slashed)
        batchStudents[3] = students[7]; // 100 remaining (not slashed)
        batchStudents[4] = students[8]; // 100 remaining (not slashed)
        batchStudents[5] = students[9]; // 100 remaining (not slashed)

        vm.prank(instructor);
        pool.withdrawMany(batchStudents);

        // Verify individual student balances after batch withdrawal
        assertEq(
            mockUsdt.balanceOf(students[0]),
            flatDepositAmount - (flatDepositAmount * 33) / 100,
            "Student 0 balance (67% remaining)"
        );
        assertEq(
            mockUsdt.balanceOf(students[1]),
            flatDepositAmount - (flatDepositAmount * 377) / 1000,
            "Student 1 balance (62.3% remaining)"
        );
        assertEq(
            mockUsdt.balanceOf(students[3]),
            flatDepositAmount - (flatDepositAmount * 625) / 1000,
            "Student 3 balance (37.5% remaining)"
        );
        assertEq(mockUsdt.balanceOf(students[7]), flatDepositAmount, "Student 7 balance (100% remaining)");
        assertEq(mockUsdt.balanceOf(students[8]), flatDepositAmount, "Student 8 balance (100% remaining)");
        assertEq(mockUsdt.balanceOf(students[9]), flatDepositAmount, "Student 9 balance (100% remaining)");

        // Verify pool balance after batch withdrawal
        uint256 expectedBatchWithdrawal = (flatDepositAmount - (flatDepositAmount * 33) / 100) // Student 0: 67% remaining
            + (flatDepositAmount - (flatDepositAmount * 377) / 1000) // Student 1: 62.3% remaining
            + (flatDepositAmount - (flatDepositAmount * 625) / 1000) // Student 3: 37.5% remaining
            + (3 * flatDepositAmount); // Students 7, 8, 9: 100% remaining each
        assertEq(
            mockUsdt.balanceOf(address(pool)),
            poolBeforeBatch - expectedBatchWithdrawal,
            "Pool balance after batch withdrawal"
        );

        // Test double transfer of slashed funds
        vm.prank(fundsManager);
        vm.expectRevert(bytes4(keccak256("SlashedAmountAlreadyTransferred()")));
        pool.transferSlashedToFundsManager(false);

        // Phase 6: Final verification
        _verifyFinalState();
    }

    function testMalformedERC20AndErrors() public {
        MockMalformedERC20 malformedUsdt = new MockMalformedERC20("Malformed USDT", "USDT", usdtDecimals);
        SecurityDepositPoolHarness malformedPool = new SecurityDepositPoolHarness(
            instructor, fundsManager, backupFundsManager, address(malformedUsdt), flatDepositAmount, courseEndTime
        );

        // Setup successful deposits first
        for (uint256 i = 0; i < 5; i++) {
            malformedUsdt.mint(students[i], flatDepositAmount);
            vm.prank(students[i]);
            malformedUsdt.approve(address(malformedPool), flatDepositAmount);
            vm.prank(students[i]);
            malformedPool.deposit();
        }

        // Test deposit failure
        malformedUsdt.setFailTransferFrom(true);
        malformedUsdt.mint(students[5], flatDepositAmount);
        vm.prank(students[5]);
        malformedUsdt.approve(address(malformedPool), flatDepositAmount);
        vm.prank(students[5]);
        vm.expectRevert();
        malformedPool.deposit();

        // Reset and perform slashing
        malformedUsdt.setFailTransferFrom(false);
        address[] memory slashStudents = new address[](2);
        uint256[] memory slashAmounts = new uint256[](2);
        slashStudents[0] = students[0];
        slashAmounts[0] = flatDepositAmount / 2;
        slashStudents[1] = students[1];
        slashAmounts[1] = flatDepositAmount;

        vm.prank(instructor);
        malformedPool.slashMany(slashStudents, slashAmounts);

        // Move to after course end
        vm.warp(courseEndTime + 1 days);

        // Test withdrawal failure
        malformedUsdt.setFailTransfer(true);
        vm.prank(students[2]);
        vm.expectRevert();
        malformedPool.withdraw();

        // Test transfer failure
        vm.prank(fundsManager);
        vm.expectRevert();
        malformedPool.transferSlashedToFundsManager(false);

        // Reset and verify success
        malformedUsdt.setFailTransfer(false);
        vm.prank(students[2]);
        malformedPool.withdraw();
        assertEq(malformedUsdt.balanceOf(students[2]), flatDepositAmount);

        // Test various error conditions
        vm.prank(students[11]); // Never deposited
        vm.expectRevert(bytes4(keccak256("HasNotDeposited()")));
        malformedPool.withdraw();

        vm.prank(students[1]); // Fully slashed
        vm.expectRevert(bytes4(keccak256("NoRemainingDeposit()")));
        malformedPool.withdraw();

        vm.prank(students[0]); // Unauthorized
        vm.expectRevert(bytes4(keccak256("NotFundsManagerOrOwner()")));
        malformedPool.transferSlashedToFundsManager(false);
    }
}
