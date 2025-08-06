// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockMalformedERC20 is ERC20 {
    uint8 _decimals;
    bool failTransferFrom = false;
    bool failTransfer = false;

    constructor(string memory name, string memory symbol, uint8 __decimals) ERC20(name, symbol) {
        _decimals = __decimals;
        _mint(msg.sender, 1_000_000 * 10 ** _decimals);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (failTransferFrom) {
            return false;
        }

        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if (failTransfer) {
            return false;
        }

        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function setFailTransferFrom(bool _fail) external {
        failTransferFrom = _fail;
    }

    function setFailTransfer(bool _fail) external {
        failTransfer = _fail;
    }

    // Adding this to be excluded from forge coverage report
    function testA() public {}
}
