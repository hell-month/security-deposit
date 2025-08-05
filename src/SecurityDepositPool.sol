// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library Errors {
    // Constructor errors
    error ZeroSupervisorAddress();
    error ZeroUSDCAddress();
    error ZeroDepositAmount();

    // Deposit errors
    error AlreadyDeposited();
    error USDCTransferFailed();

    // Slash errors
    error NotOwner();
    error InsufficientDeposit();

    // Take errors
    error NoRemainingDeposit();
    error HasNotDeposited();

    // Supervisor errors
    error NotSupervisor();
    error NoSlashedAmountToTransfer();
    error SlashedAmountAlreadyTransferred();
}

contract SecurityDepositPool is Ownable {
    address public supervisor;
    IERC20 public usdc;
    uint256 public flatDepositAmount;
    uint256 public totalSlashed;
    bool public isTotalSlashedTransferred;

    mapping(address => uint256) public deposits;
    mapping(address => bool) public hasDeposited;

    modifier onlySupervisor() {
        if (msg.sender != supervisor) revert Errors.NotSupervisor();
        _;
    }

    constructor(address _owner, address _supervisor, address _usdc, uint256 _flatDepositAmount) Ownable(_owner) {
        if (_supervisor == address(0)) revert Errors.ZeroSupervisorAddress();
        if (_usdc == address(0)) revert Errors.ZeroUSDCAddress();
        if (_flatDepositAmount == 0) revert Errors.ZeroDepositAmount();

        supervisor = _supervisor;
        usdc = IERC20(_usdc);
        flatDepositAmount = _flatDepositAmount;
    }

    function deposit() external {
        if (hasDeposited[msg.sender]) revert Errors.AlreadyDeposited();

        bool success = usdc.transferFrom(msg.sender, address(this), flatDepositAmount);
        if (!success) revert Errors.USDCTransferFailed();

        deposits[msg.sender] = flatDepositAmount;
        hasDeposited[msg.sender] = true;
    }

    function slashMany(address[] calldata students, uint256[] calldata amounts) external onlyOwner {
        if (students.length != amounts.length) revert Errors.NotOwner();

        for (uint256 i = 0; i < students.length; i++) {
            slash(students[i], amounts[i]);
        }
    }

    function take() external {
        if (!hasDeposited[msg.sender]) revert Errors.HasNotDeposited();

        uint256 remainingAmount = deposits[msg.sender];
        if (remainingAmount == 0) revert Errors.NoRemainingDeposit();

        deposits[msg.sender] = 0;
        bool success = usdc.transfer(msg.sender, remainingAmount);
        if (!success) revert Errors.USDCTransferFailed();
    }

    function transferDepositBackToAll(
        // List of students will be externally indexed
        address[] calldata students
    ) external onlyOwner {
        for (uint256 i = 0; i < students.length; i++) {
            address student = students[i];
            if (!hasDeposited[student]) revert Errors.HasNotDeposited();

            uint256 amount = deposits[student];
            if (amount == 0) continue; // Skip if no deposit

            deposits[student] = 0;
            bool success = usdc.transfer(student, amount);
            if (!success) revert Errors.USDCTransferFailed();
        }
    }

    function transferSlashedToSupervisor() external onlySupervisor {
        if (totalSlashed == 0) revert Errors.NoSlashedAmountToTransfer();
        if (isTotalSlashedTransferred) revert Errors.SlashedAmountAlreadyTransferred();

        uint256 amount = totalSlashed;
        totalSlashed = 0;
        bool success = usdc.transfer(supervisor, amount);
        if (!success) revert Errors.USDCTransferFailed();

        isTotalSlashedTransferred = true;
    }

    function slash(address student, uint256 amount) internal {
        if (!hasDeposited[student]) revert Errors.HasNotDeposited();
        if (deposits[student] < amount) revert Errors.InsufficientDeposit();

        deposits[student] -= amount;
        totalSlashed += amount;
    }
}
