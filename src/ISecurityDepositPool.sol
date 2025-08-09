// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

interface ISecurityDepositPool {
    event Deposited(address indexed student, uint256 amount);
    event SlashedMany(address[] students, uint256[] amounts);
    event Withdrawn(address indexed student);
    event WithdrawnMany(address[] students);
    event SlashedTransferred(address indexed fundsManager, uint256 amount);
}
