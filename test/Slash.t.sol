// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SlashScript} from "../script/mainnet/Slash.s.sol";
import {ISecurityDepositPool} from "../src/ISecurityDepositPool.sol";
import {SecurityDepositPool} from "../src/SecurityDepositPool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./MockERC20.sol";
import {MockMalformedERC20} from "./MockMalformedERC20.sol";

contract SlashForkTest is Test, ISecurityDepositPool {
    uint8 usdtDecimals = 6;
    uint256 totalSlashedAmount = 945700000;
    address securityDepositPoolOwner = 0x8Fe7A21fe057F9c31812e5049128a41fea79d066;
    SecurityDepositPool pool = SecurityDepositPool(0x94ae95E096fE4C5954840760E0190c27a2ebBDDE);

    function setUp() public {
        string memory rpcUrl = "https://mainnet.infura.io/v3/145e58dedfc1483fb7bcb6909f1c129c";
        uint256 forkId = vm.createFork(rpcUrl);
        vm.selectFork(forkId);
    }

    function testMainnetSlashSuccess() public {
        assertEq(securityDepositPoolOwner, pool.owner());
        vm.startPrank(securityDepositPoolOwner);

        // ========================================
        // ========================================
        // Run slashing
        // ========================================
        // ========================================
        assertEq(pool.totalSlashed(), 0);

        address[] memory students = new address[](21);
        uint256[] memory amounts = new uint256[](21);
        // https://docs.google.com/spreadsheets/d/1LtR6zEHqmUgXdRn0NSkm2pmDreL8w3GBOMDGs7vVUGE/edit?gid=1384484463#gid=1384484463
        students[0] = 0x8eE84937C2BF37424F0Ba885653d2Bf3cdc77080;
        amounts[0] = 54750000;
        students[1] = 0xDc581a5f5328ED03d8737bf09B8Cab4BB85Af707;
        amounts[1] = 73000000;
        students[2] = 0x0B2a6F97aa427d6CC82F8b30D950FddB6614Ce85;
        amounts[2] = 54750000;
        students[3] = 0xD76ce7F02351Ab3E3103ee3b6A64601BEc580c6E;
        amounts[3] = 2000000;
        students[4] = 0x3458B20044F5f20a80ab25af160498A853fDE013;
        amounts[4] = 2000000;
        students[5] = 0x7181C06492B9e9a36fAC1A6204dF8be0BD4E8641;
        amounts[5] = 18250000;
        students[6] = 0x8b57AeFCa35eef5ccA30cE72e262177cf2b95917;
        amounts[6] = 54750000;
        students[7] = 0x3435Bad6F68a6a14a177485b68d233a4074943dB;
        amounts[7] = 54750000;
        students[8] = 0xEA56b22c446A5fbEd33c231feCD42A1d78641119;
        amounts[8] = 40150000;
        students[9] = 0xeFcb13871eCBcF20c528D3209bc236336A35B0F4;
        amounts[9] = 18250000;
        students[10] = 0x302B18b95A2b6345c8ec5D8B67AB84076F507D01;
        amounts[10] = 32850000;
        students[11] = 0x118a6899c241816880458b9953C4D6a8F9445FcB;
        amounts[11] = 73000000;
        students[12] = 0xAcD1D964551a1dEd46EA7CC7A71F0c6Ee4b1C554;
        amounts[12] = 54750000;
        students[13] = 0xC8F77E8Fb65aD25425eCaCB2AD359A186a5125c9;
        amounts[13] = 54750000;
        students[14] = 0xC08a86384BBAaC0C2D0E14961d563088cea31b35;
        amounts[14] = 73000000;
        students[15] = 0xe5d152912c042e9F8Cb4B6658a0b2A8562a7D9FE;
        amounts[15] = 73000000;
        students[16] = 0x25DfF2cC7d63Fcff96aded40bdFf0A7F7f9A562F;
        amounts[16] = 29200000;
        students[17] = 0x1d2073424841569e531Ef1a7C2E7749185412f8D;
        amounts[17] = 54750000;
        students[18] = 0x0833E6e33A5397ED4147bb8cf31aFB0a6055Dd62;
        amounts[18] = 54750000;
        students[19] = 0x99bB0c670B496c107782dad2833c01d1f45429a5;
        amounts[19] = 54750000;
        students[20] = 0x51ff66B7A4b1950ff6C1CA252172eD8040f2A20c;
        amounts[20] = 18250000;

        pool.slashMany(students, amounts);

        // 945.7 USDT
        assertEq(pool.totalSlashed(), totalSlashedAmount);
        // ========================================
        // ========================================

        // ========================================
        // ========================================
        // Transfer funds after the course finalizes
        // ========================================
        // ========================================
        vm.warp(pool.courseFinalizedTime() + 1);
        uint256 backupFundsManagerPrevBalance = pool.usdt().balanceOf(pool.backupFundsManager());
        pool.transferSlashedToFundsManager(
            // useBackupFundsManager to send USDT to Joel
            true
        );
        uint256 backupFundsManagerAfterBalance = pool.usdt().balanceOf(pool.backupFundsManager());
        assertEq(backupFundsManagerAfterBalance, backupFundsManagerPrevBalance + totalSlashedAmount);
        // ========================================
        // ========================================

        vm.stopPrank();

        // ========================================
        // ========================================
        // Withdraw deposit as a course participant
        // ========================================
        // ========================================

        // Zero deduction
        address zeroDeductionStudent = 0x8ae9B203a0fE7F8167B54856E59cc52135E14FbC;
        vm.startPrank(zeroDeductionStudent);
        {
            uint256 prevBalance = pool.usdt().balanceOf(zeroDeductionStudent);
            pool.withdraw();
            uint256 postBalance = pool.usdt().balanceOf(zeroDeductionStudent);
            assertEq(postBalance, prevBalance + pool.flatDepositAmount());
        }
        vm.stopPrank();

        // Some deduction
        // 29200000 deducted
        address someDeductionStudent = 0x25DfF2cC7d63Fcff96aded40bdFf0A7F7f9A562F;
        vm.startPrank(someDeductionStudent);
        {
            uint256 prevBalance = pool.usdt().balanceOf(someDeductionStudent);
            uint256 withdrawnAmount = pool.flatDepositAmount() - 29200000;
            pool.withdraw();
            uint256 postBalance = pool.usdt().balanceOf(someDeductionStudent);
            assertEq(postBalance, prevBalance + withdrawnAmount);
        }
        vm.stopPrank();

        // All deduction
        // Should throw error
        address allDeductionStudent = 0xC08a86384BBAaC0C2D0E14961d563088cea31b35;
        vm.startPrank(allDeductionStudent);
        {
            vm.expectRevert(bytes4(keccak256("NoRemainingDeposit()")));
            pool.withdraw();
        }
        vm.stopPrank();

        // ========================================
        // ========================================
    }
}
