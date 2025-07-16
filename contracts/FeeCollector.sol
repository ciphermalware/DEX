// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title FeeCollector
/// @notice Simple treasury contract to collect protocol fees and allow the owner to withdraw them
contract FeeCollector is Ownable {
    using SafeERC20 for IERC20;

    event FeesWithdrawn(address indexed token, address indexed to, uint256 amount);
    event EtherWithdrawn(address indexed to, uint256 amount);

    receive() external payable {}

    /// @notice Withdraw ERC20 fees to a recipient address
    /// @param token Address of the token
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "FeeCollector: zero address");
        IERC20(token).safeTransfer(to, amount);
        emit FeesWithdrawn(token, to, amount);
    }

    /// @notice Withdraw native ether to a recipient address
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function withdrawEther(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "FeeCollector: zero address");
        (bool success, ) = to.call{value: amount}("");
        require(success, "FeeCollector: failed to send ether");
        emit EtherWithdrawn(to, amount);
    }
}
