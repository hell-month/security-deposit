// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SecurityDepositPool} from "../src/SecurityDepositPool.sol";

contract SecurityDepositPoolHarness is SecurityDepositPool {
    constructor(
        address instructor,
        address supervisor,
        address usdcAddress,
        uint256 flatDepositAmount,
        uint256 courseEndTime
    ) SecurityDepositPool(instructor, supervisor, usdcAddress, flatDepositAmount, courseEndTime) {}

    function withdraw(address student) public {
        _withdraw(student);
    }

    function slash(address student, uint256 amount) public {
        _slash(student, amount);
    }
}
