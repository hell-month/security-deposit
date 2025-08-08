// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {SecurityDepositPool} from "../src/SecurityDepositPool.sol";

contract SecurityDepositPoolHarness is SecurityDepositPool {
    constructor(
        address instructor,
        address fundsManager,
        address backupFundsManager,
        address usdtAddress,
        uint256 flatDepositAmount,
        uint256 courseEndTime
    )
        SecurityDepositPool(instructor, fundsManager, backupFundsManager, usdtAddress, flatDepositAmount, courseEndTime)
    {}

    function withdrawHarness(address student) public {
        _withdraw(student);
    }

    function slashHarness(address student, uint256 amount) public {
        _slash(student, amount);
    }

    // Adding this to be excluded from forge coverage report
    function testA() public {}
}
