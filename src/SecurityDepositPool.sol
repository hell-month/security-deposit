// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ISecurityDepositPool.sol";

library Errors {
    // Constructor errors
    error ZeroFundsManagerAddress();
    error ZeroUSDCAddress();
    error ZeroDepositAmount();

    // Deposit errors
    error AlreadyDeposited();
    error USDCTransferFailed();
    error CourseFinalized();

    // Slash errors
    error InsufficientDeposit();
    error ArrayLengthMismatch();

    // Take errors
    error NoRemainingDeposit();
    error HasNotDeposited();
    error CourseNotFinalized();

    // FundsManager errors
    error NotFundsManagerOrOwner();
    error NoSlashedAmountToTransfer();
    error SlashedAmountAlreadyTransferred();
}

/**
 * @title SecurityDepositPool
 * @notice This contract manages the security deposits for a course.
 * It allows students to deposit USDC, slashes deposits based on the
 * discretion of the owner (instructor), and facilitates the return of
 * deposits after the course ends.
 */
contract SecurityDepositPool is Ownable, ISecurityDepositPool {
    address public fundsManager;
    // USDC on Ethereum complies fully with the ERC20 standard,
    // so no need to use .safeTransferFrom() or .safeTransfer()
    IERC20 public usdc;
    uint256 public flatDepositAmount;
    uint256 public totalSlashed;
    bool public isTotalSlashedTransferred;
    // Timestamp at which the course is supposed to end.
    // Also the time after which deposits can be claimed back
    uint256 public courseFinalizedTime;

    mapping(address => uint256) public deposits;
    mapping(address => bool) public hasDeposited;

    modifier onlyFundsManagerOrOwner() {
        if (msg.sender != fundsManager && msg.sender != owner()) revert Errors.NotFundsManagerOrOwner();
        _;
    }

    // Asserts that the function is called after the course has been finalized
    modifier afterCourseFinalized() {
        // If current time is before course's end time, revert
        if (block.timestamp < courseFinalizedTime) revert Errors.CourseNotFinalized();
        _;
    }

    // Asserts that the function is called before the course has been finalized
    modifier beforeCourseFinalized() {
        // If current time is after course's end time, revert
        if (block.timestamp >= courseFinalizedTime) revert Errors.CourseFinalized();
        _;
    }

    constructor(
        address _instructor,
        address _fundsManager,
        address _usdc,
        uint256 _flatDepositAmount,
        uint256 _courseFinalizedTime
    ) Ownable(_instructor) {
        if (_fundsManager == address(0)) revert Errors.ZeroFundsManagerAddress();
        if (_usdc == address(0)) revert Errors.ZeroUSDCAddress();
        if (_flatDepositAmount == 0) revert Errors.ZeroDepositAmount();

        fundsManager = _fundsManager;
        usdc = IERC20(_usdc);
        flatDepositAmount = _flatDepositAmount;
        courseFinalizedTime = _courseFinalizedTime;
    }

    function deposit()
        external
        // Ensure the course has not ended (a student can join during the course too)
        beforeCourseFinalized
    {
        // Ensure the student has not already deposited
        if (hasDeposited[msg.sender]) revert Errors.AlreadyDeposited();

        bool success = usdc.transferFrom(msg.sender, address(this), flatDepositAmount);
        if (!success) revert Errors.USDCTransferFailed();

        deposits[msg.sender] = flatDepositAmount;
        hasDeposited[msg.sender] = true;

        emit Deposited(msg.sender, flatDepositAmount);
    }

    function withdraw() external afterCourseFinalized {
        _withdraw(msg.sender);

        emit Withdrawn(msg.sender);
    }

    function withdrawMany(
        // List of students will be externally indexed
        // to save gas
        address[] calldata students
    ) external onlyOwner afterCourseFinalized {
        for (uint256 i = 0; i < students.length; i++) {
            _withdraw(students[i]);
        }

        emit WithdrawnMany(students);
    }

    function slashMany(address[] calldata students, uint256[] calldata amounts)
        external
        onlyOwner
        // If the course has ended, slashing is not allowed anymore
        beforeCourseFinalized
    {
        // Transferring the slashed amount is one-time operation.
        // If it is already done, can't slash anymore because the slashed funds
        // can't be transferred anymore.
        //
        // In fact, the function will revert at beforeCourseFinalized because
        // transferSlashedToFundsManager() will be called after the course has ended, whereas
        // slashMany() can be called only before the course has ended.
        if (isTotalSlashedTransferred) revert Errors.SlashedAmountAlreadyTransferred();
        // Ensure the lengths of the arrays match
        if (students.length != amounts.length) revert Errors.ArrayLengthMismatch();

        for (uint256 i = 0; i < students.length; i++) {
            _slash(students[i], amounts[i]);
        }

        emit SlashedMany(students, amounts);
    }

    function transferSlashedToFundsManager()
        external
        onlyFundsManagerOrOwner
        // Transferring the slashed amount can only be done after the course has been finalized
        afterCourseFinalized
    {
        // Ensure there is a slashed amount to transfer
        if (totalSlashed == 0) revert Errors.NoSlashedAmountToTransfer();
        // Ensure the slashed amount has not been transferred already.
        // Transferring the slashed amount is a one-time operation in the
        // lifetime of the contract, so if it is already done, can't transfer again
        if (isTotalSlashedTransferred) revert Errors.SlashedAmountAlreadyTransferred();

        uint256 amount = totalSlashed;
        totalSlashed = 0;
        bool success = usdc.transfer(fundsManager, amount);
        if (!success) revert Errors.USDCTransferFailed();

        isTotalSlashedTransferred = true;

        emit SlashedTransferred(fundsManager, amount);
    }

    // Any functions that call withdraw should ensure the course has ended
    function _withdraw(address student) internal {
        // Ensure the student has deposited
        if (!hasDeposited[student]) revert Errors.HasNotDeposited();

        uint256 remainingAmount = deposits[student];
        // If the student has no remaining deposit due to slashing, revert
        if (remainingAmount == 0) revert Errors.NoRemainingDeposit();

        deposits[student] = 0;
        bool success = usdc.transfer(student, remainingAmount);
        if (!success) revert Errors.USDCTransferFailed();
    }

    // Any functions that call slash should ensure the course has not ended
    function _slash(address student, uint256 amount) internal {
        // Ensure the student has deposited
        if (!hasDeposited[student]) revert Errors.HasNotDeposited();
        // Ensure the amount to slash is valid
        if (deposits[student] < amount) revert Errors.InsufficientDeposit();

        deposits[student] -= amount;
        totalSlashed += amount;
    }
}
