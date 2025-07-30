// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title LiquidityLocker
/// @notice Allows users to lock ERC20 tokens for a
///  period of time. This can be used to encourage long term liquidity
///  provision on the DEX.
contract LiquidityLocker is Ownable {
    using SafeERC20 for IERC20;

    struct Lock {
        uint256 amount;
        uint256 unlockTime;
    }

    // token => user => locks
    mapping(address => mapping(address => Lock[])) private _locks;

    event TokensLocked(address indexed user, address indexed token, uint256 amount, uint256 unlockTime);
    event TokensUnlocked(address indexed user, address indexed token, uint256 amount);
    event LockExtended(address indexed user, address indexed token, uint256 index, uint256 newUnlockTime);
    event LockAmountIncreased(address indexed user, address indexed token, uint256 index, uint256 amount);

    /// @notice Lock tokens until a future time
    /// @param token Address of the token to lock
    /// @param amount Amount of tokens to lock
    /// @param duration Time in seconds to lock the tokens for
    function lock(address token, uint256 amount, uint256 duration) external {
        require(amount > 0, "LiquidityLocker: zero amount");
        require(duration > 0, "LiquidityLocker: zero duration");
        uint256 unlockTime = block.timestamp + duration;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _locks[token][msg.sender].push(Lock(amount, unlockTime));
        emit TokensLocked(msg.sender, token, amount, unlockTime);
    }

/// @notice Increase the amount locked in an existing lock
    /// @param token Address of the locked token
    /// @param index Index of the lock entry
    /// @param amount Additional amount to add to the lock
    function increaseLockAmount(address token, uint256 index, uint256 amount) external {
        require(amount > 0, "LiquidityLocker: zero amount");
        Lock storage userLock = _locks[token][msg.sender][index];
        require(userLock.amount > 0, "LiquidityLocker: no lock");
        require(block.timestamp < userLock.unlockTime, "LiquidityLocker: already unlocked");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        userLock.amount += amount;
        emit LockAmountIncreased(msg.sender, token, index, amount);
    }

    /// @notice Extend the unlock time of an existing lock
    /// @param token Address of the locked token
    /// @param index Index of the lock entry
    /// @param additionalDuration Additional time in seconds to extend the lock
    function extendLock(address token, uint256 index, uint256 additionalDuration) external {
        require(additionalDuration > 0, "LiquidityLocker: zero duration");
        Lock storage userLock = _locks[token][msg.sender][index];
        require(userLock.amount > 0, "LiquidityLocker: no lock");
        require(block.timestamp < userLock.unlockTime, "LiquidityLocker: already unlocked");
        userLock.unlockTime += additionalDuration;
        emit LockExtended(msg.sender, token, index, userLock.unlockTime);
    }

    /// @notice Unlock previously locked tokens
    /// @param token Address of the locked token
    /// @param index Index of the lock entry to unlock
    function unlock(address token, uint256 index) external {
        Lock storage userLock = _locks[token][msg.sender][index];
        require(userLock.amount > 0, "LiquidityLocker: no lock");
        require(block.timestamp >= userLock.unlockTime, "LiquidityLocker: not unlocked");

        uint256 amount = userLock.amount;
        userLock.amount = 0; // prevent reentrancy
        IERC20(token).safeTransfer(msg.sender, amount);
        emit TokensUnlocked(msg.sender, token, amount);
    }

    /// @notice View locks for a user
    /// @param token Address of the token
    /// @param user Address of the user
    function getLocks(address token, address user) external view returns (Lock[] memory) {
        return _locks[token][user];
    }

    /// @notice Rescue tokens mistakenly sent to this contract
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}
