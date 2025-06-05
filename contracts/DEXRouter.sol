// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IDex {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut
    ) external returns (uint256 amountOut);
}

/// @title DEXRouter
/// @notice Simple router contract that enables multi hop swaps using the DEX
contract DEXRouter {
    using SafeERC20 for IERC20;

    IDex public immutable dex;

    event MultiHopSwap(address indexed user, address[] path, uint256 amountIn, uint256 amountOut);

    constructor(address _dex) {
        require(_dex != address(0), "DEXRouter: zero address");
        dex = IDex(_dex);
    }

    /// @notice Perform a multi hop swap across several pools
    /// @param amountIn Amount of the first token to swap
    /// @param amountOutMin Minimum amount of the last token expected
    /// @param path Array of token addresses. path[0] is tokenIn and last element is tokenOut
    /// @return amountOut Amount of the final token received
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path
    ) external returns (uint256 amountOut) {
        require(path.length >= 2, "DEXRouter: invalid path");
        uint256 amount = amountIn;

        // Transfer the first token from user to this router
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amount);

        for (uint256 i = 0; i < path.length - 1; i++) {
            IERC20(path[i]).safeApprove(address(dex), amount);
            amount = dex.swapExactTokensForTokens(
                amount,
                i == path.length - 2 ? amountOutMin : 0,
                path[i],
                path[i + 1]
            );
        }

        IERC20(path[path.length - 1]).safeTransfer(msg.sender, amount);
        emit MultiHopSwap(msg.sender, path, amountIn, amount);
        return amount;
    }
}
