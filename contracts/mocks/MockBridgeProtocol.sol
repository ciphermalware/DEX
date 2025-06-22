// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockBridgeProtocol {
    using SafeERC20 for IERC20;

    event Sent(address token, uint256 amount, uint256 dstChainId, bytes recipient);

    function sendTokens(
        address token,
        uint256 amount,
        uint256 dstChainId,
        bytes calldata recipient
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Sent(token, amount, dstChainId, recipient);
    }
}
