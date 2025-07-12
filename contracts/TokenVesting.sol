// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenVesting
/// @notice Token vesting contract releasing tokens linearly to a beneficiary
contract TokenVesting is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public immutable beneficiary;

    uint256 public immutable start;
    uint256 public immutable cliff;
    uint256 public immutable duration;
    uint256 public released;

    event TokensReleased(uint256 amount);

    constructor(
        address _token,
        address _beneficiary,
        uint256 _start,
        uint256 _cliffDuration,
        uint256 _duration
    ) {
        require(_beneficiary != address(0), "TokenVesting: zero beneficiary");
        require(_cliffDuration <= _duration, "TokenVesting: cliff > duration");
        token = IERC20(_token);
        beneficiary = _beneficiary;
        start = _start;
        cliff = _start + _cliffDuration;
        duration = _duration;
    }

    /// @notice Release vested tokens to the beneficiary
    function release() external {
        uint256 releasable = vestedAmount(block.timestamp) - released;
        require(releasable > 0, "TokenVesting: no tokens");
        released += releasable;
        token.safeTransfer(beneficiary, releasable);
        emit TokensReleased(releasable);
    }

    /// @notice Calculate total vested amount at a given timestamp
    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        uint256 totalBalance = token.balanceOf(address(this)) + released;
        if (timestamp < cliff) {
            return 0;
        } else if (timestamp >= start + duration) {
            return totalBalance;
        } else {
            return (totalBalance * (timestamp - start)) / duration;
        }
    }
}
