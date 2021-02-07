// SPDX-License-Identifier: WTFPL
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Staking {
    using SafeMath for uint256;
    IERC20 public ERC20;

    constructor(address _ERC20) public {
        ERC20 = IERC20(_ERC20);
    }

    uint256 private _totalSupply;
    mapping(address => uint256) public _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function _stake(uint256 amount) internal {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        ERC20.transferFrom(msg.sender, address(this), amount);
    }

    function _withdraw(uint256 amount) internal {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        ERC20.transfer(msg.sender, amount);
    }
}
