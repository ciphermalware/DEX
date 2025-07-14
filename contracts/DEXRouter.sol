// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IDex {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut
    ) external returns (uint256 amountOut);

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256);

    function getAmountIn(
        uint256 amountOut,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256);
}

/// @title DEXRouter
/// @notice Simple router contract that enables multi-hop swaps using the DEX
contract DEXRouter is Ownable {
    using SafeERC20 for IERC20;

    IDex public immutable dex;

    event MultiHopSwap(address indexed user, address[] path, uint256 amountIn, uint256 amountOut);

    constructor(address _dex) Ownable() {
        require(_dex != address(0), "DEXRouter: zero address");
        dex = IDex(_dex);
    }

    /// @notice Perform a multi-hop swap across several pools
    /// @param amountIn Amount of the first token to swap
    /// @param amountOutMin Minimum amount of the last token expected
    /// @param path Array of token addresses. path[0] is tokenIn and last element is tokenOut
    /// @return amountOut Amount of the final token received
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        require(path.length >= 2, "DEXRouter: invalid path");
        require(block.timestamp <= deadline, "DEXRouter: expired");
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

    /// @notice Quote the amounts out for a multi-hop swap
    /// @param amountIn Amount of the first token
    /// @param path Array of token addresses
    /// @return amounts Array of output amounts for each hop
    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "DEXRouter: invalid path");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i = 0; i < path.length - 1; i++) {
            amounts[i + 1] = dex.getAmountOut(amounts[i], path[i], path[i + 1]);
        }
    }

    /// @notice Quote the amounts in for a multi-hop swap
    /// @param amountOut Desired amount of the final token
    /// @param path Array of token addresses
    /// @return amounts Array of input amounts for each hop
    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "DEXRouter: invalid path");
        amounts = new uint256[](path.length);
        amounts[path.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            amounts[i - 1] = dex.getAmountIn(amounts[i], path[i - 1], path[i]);
        }
    }

    /// @notice Rescue tokens accidentally sent to this router
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "DEXRouter: zero address");
        IERC20(token).safeTransfer(owner(), amount);
    }
}
