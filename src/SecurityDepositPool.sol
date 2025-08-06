// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ISecurityDepositPool.sol";

library Errors {
    error ZeroFundsManagerAddress();
    error ZeroUSDCAddress();
    error ZeroFlatDepositAmount();
    error CourseFinalizedTimeInPast();
    error CourseFinalizedTimeInDistantFuture();

    error AlreadyDeposited();
    error USDCTransferFailed();
    error CourseFinalized();

    error InsufficientDeposit();
    error ArrayLengthMismatch();

    error NoRemainingDeposit();
    error HasNotDeposited();
    error CourseNotFinalized();

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
    address public immutable fundsManager;
    // USDC on Ethereum complies fully with the ERC20 standard,
    // so no need to use .safeTransferFrom() or .safeTransfer()
    IERC20 public immutable usdc;
    uint256 public immutable flatDepositAmount;
    // Timestamp at which the course is supposed to end.
    // Also the time after which deposits can be claimed back
    uint256 public immutable courseFinalizedTime;

    uint256 public totalSlashed;
    bool public isTotalSlashedTransferred;

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

    /**
     * @dev Initializes the contract with instructor, funds manager, USDC token, deposit amount, and course end time.
     * Performs validation on input parameters.
     */
    constructor(
        address _instructor,
        address _fundsManager,
        address _usdc,
        uint256 _flatDepositAmount,
        uint256 _courseFinalizedTime
    ) Ownable(_instructor) {
        if (_fundsManager == address(0)) revert Errors.ZeroFundsManagerAddress();
        if (_usdc == address(0)) revert Errors.ZeroUSDCAddress();
        if (_flatDepositAmount == 0) revert Errors.ZeroFlatDepositAmount();
        // slither-disable-next-line timestamp
        if (_courseFinalizedTime < block.timestamp) revert Errors.CourseFinalizedTimeInPast();
        // slither-disable-next-line timestamp
        if (_courseFinalizedTime > block.timestamp + 60 days) revert Errors.CourseFinalizedTimeInDistantFuture();

        fundsManager = _fundsManager;
        usdc = IERC20(_usdc);
        flatDepositAmount = _flatDepositAmount;
        courseFinalizedTime = _courseFinalizedTime;
    }

    /**
     * @dev Allows a student to deposit a flat USDC collateral before the course ends. Reverts if already deposited.
     */
    function deposit()
        external
        // Ensure the course has not ended (a student can join during the course too)
        beforeCourseFinalized
    {
        // Ensure the student has not already deposited
        if (hasDeposited[msg.sender]) revert Errors.AlreadyDeposited();

        deposits[msg.sender] = flatDepositAmount;
        hasDeposited[msg.sender] = true;
        emit Deposited(msg.sender, flatDepositAmount);

        // USDC contract is trusted
        // slither-disable-next-line reentrancy-no-eth
        bool success = usdc.transferFrom(msg.sender, address(this), flatDepositAmount);
        if (!success) revert Errors.USDCTransferFailed();
    }

    /**
     * @dev Allows a student to withdraw their remaining deposit after the course is finalized.
     */
    function withdraw() external afterCourseFinalized {
        emit Withdrawn(msg.sender);

        _withdraw(msg.sender);
    }

    /**
     * @dev Allows the owner to withdraw deposits for multiple students after the course is finalized.
     *
     * Gas might be a problem if the list of students is too long, but
     * 1. it is expected that the list will be reasonably short, and
     * 2. it can always be called in multiple batches.
     *
     * In the worst case scenario, the user can call withdraw() himself by paying for his own gas.
     */
    function withdrawMany(
        // List of students will be externally indexed
        // to save gas
        address[] calldata students
    ) external onlyOwner afterCourseFinalized {
        emit WithdrawnMany(students);

        for (uint256 i = 0; i < students.length; i++) {
            _withdraw(students[i]);
        }
    }

    /**
     * @dev Allows the owner to slash deposits of multiple students before the course ends.
     * Slashed funds are tracked for later transfer.
     *
     * Gas might be a problem if the list of students is too long, but
     * 1. it is expected that the list will be reasonably short, and
     * 2. it can always be called in multiple batches.
     */
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
        // In fact, the function will revert at beforeCourseFinalized already because
        // transferSlashedToFundsManager() will be called after the course has ended, whereas
        // slashMany() can be called only before the course has ended, so it's safe to comment
        // this out. Leaving it for reference.
        //
        // if (isTotalSlashedTransferred) revert Errors.SlashedAmountAlreadyTransferred();

        // Ensure the lengths of the arrays match
        if (students.length != amounts.length) revert Errors.ArrayLengthMismatch();

        emit SlashedMany(students, amounts);

        for (uint256 i = 0; i < students.length; i++) {
            _slash(students[i], amounts[i]);
        }
    }

    /**
     * @dev Transfers the total slashed amount to the funds manager after the course is finalized.
     * Can only be called once.
     */
    function transferSlashedToFundsManager()
        external
        onlyFundsManagerOrOwner
        // Transferring the slashed amount can only be done after the course has been finalized
        afterCourseFinalized
    {
        // Ensure the slashed amount has not been transferred already.
        // Transferring the slashed amount is a one-time operation in the
        // lifetime of the contract, so if it is already done, can't transfer again.
        if (isTotalSlashedTransferred) revert Errors.SlashedAmountAlreadyTransferred();
        // Ensure there is a slashed amount to transfer
        if (totalSlashed == 0) revert Errors.NoSlashedAmountToTransfer();

        totalSlashed = 0;
        isTotalSlashedTransferred = true;

        uint256 amount = totalSlashed;
        emit SlashedTransferred(fundsManager, amount);

        bool success = usdc.transfer(fundsManager, amount);
        if (!success) revert Errors.USDCTransferFailed();
    }

    /**
     * @dev Internal function to withdraw a student's remaining deposit.
     * Reverts if no deposit or deposit is zero.
     *
     * Any functions that call _withdraw should ensure the course has ended
     */
    function _withdraw(address student) internal {
        // Ensure the student has deposited
        if (!hasDeposited[student]) revert Errors.HasNotDeposited();

        uint256 remainingAmount = deposits[student];
        // If the student has no remaining deposit due to slashing, revert
        if (remainingAmount == 0) revert Errors.NoRemainingDeposit();

        deposits[student] = 0;
        // slither-disable-next-line calls-loop
        bool success = usdc.transfer(student, remainingAmount);
        if (!success) revert Errors.USDCTransferFailed();
    }

    /**
     * @dev Internal function to slash a student's deposit by a given amount.
     * Reverts if insufficient deposit.
     *
     * Any functions that call _slash should ensure the course has not ended.
     */
    function _slash(address student, uint256 amount) internal {
        // Ensure the student has deposited
        if (!hasDeposited[student]) revert Errors.HasNotDeposited();
        // Ensure the amount to slash is valid
        if (deposits[student] < amount) revert Errors.InsufficientDeposit();

        deposits[student] -= amount;
        totalSlashed += amount;
    }
}
