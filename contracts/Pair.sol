// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title Pair
/// @notice Handles a single token pair and implements core AMM logic
contract Pair is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    address public immutable token0;
    address public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidityBalances;

    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public feePercent = 30; // 0.3% fee
    address public feeRecipient;

    event LiquidityAdded(address indexed user, uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(address indexed user, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);

    constructor(address _token0, address _token1, address _feeRecipient) {
        require(_token0 != _token1, "Pair: identical tokens");
        require(_token0 != address(0) && _token1 != address(0), "Pair: zero address");
        require(_feeRecipient != address(0), "Pair: zero fee recipient");
        (token0, token1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);
        feeRecipient = _feeRecipient;
    }

    function setFeePercent(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= 1000, "Pair: fee too high");
        uint256 oldFee = feePercent;
        feePercent = _feePercent;
        emit FeeUpdated(oldFee, _feePercent);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Pair: zero address");
        address oldRecipient = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(oldRecipient, _feeRecipient);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused returns (uint256 amount0, uint256 amount1, uint256 liquidity) {
        require(amount0Desired > 0 && amount1Desired > 0, "Pair: invalid amounts");

        if (reserve0 == 0 && reserve1 == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            require(liquidity > 0, "Pair: insufficient liquidity minted");
        } else {
            uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "Pair: insufficient amount1");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
                require(amount0Optimal <= amount0Desired && amount0Optimal >= amount0Min, "Pair: insufficient amount0");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
            liquidity = Math.min((amount0 * totalLiquidity) / reserve0, (amount1 * totalLiquidity) / reserve1);
        }

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        reserve0 += amount0;
        reserve1 += amount1;

        totalLiquidity += liquidity;
        liquidityBalances[msg.sender] += liquidity;

        emit LiquidityAdded(msg.sender, amount0, amount1, liquidity);
    }

    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused returns (uint256 amount0, uint256 amount1) {
        require(liquidity > 0, "Pair: invalid liquidity amount");
        require(liquidityBalances[msg.sender] >= liquidity, "Pair: insufficient liquidity");
        require(totalLiquidity > 0, "Pair: no liquidity");

        amount0 = (liquidity * reserve0) / totalLiquidity;
        amount1 = (liquidity * reserve1) / totalLiquidity;

        require(amount0 >= amount0Min && amount1 >= amount1Min, "Pair: insufficient output amount");

        totalLiquidity -= liquidity;
        liquidityBalances[msg.sender] -= liquidity;
        reserve0 -= amount0;
        reserve1 -= amount1;

        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, amount0, amount1, liquidity);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(amountIn > 0, "Pair: invalid input amount");
        require(tokenIn == token0 || tokenIn == token1, "Pair: invalid token");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - feePercent);

        if (tokenIn == token0) {
            require(reserve1 > 0, "Pair: insufficient liquidity");
            amountOut = (amountInWithFee * reserve1) / (reserve0 * FEE_DENOMINATOR + amountInWithFee);
            require(amountOut >= amountOutMin, "Pair: insufficient output");
            require(amountOut < reserve1, "Pair: insufficient liquidity");

            IERC20(token0).safeTransferFrom(msg.sender, address(this), amountIn);
            IERC20(token1).safeTransfer(msg.sender, amountOut);

            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            require(reserve0 > 0, "Pair: insufficient liquidity");
            amountOut = (amountInWithFee * reserve0) / (reserve1 * FEE_DENOMINATOR + amountInWithFee);
            require(amountOut >= amountOutMin, "Pair: insufficient output");
            require(amountOut < reserve0, "Pair: insufficient liquidity");

            IERC20(token1).safeTransferFrom(msg.sender, address(this), amountIn);
            IERC20(token0).safeTransfer(msg.sender, amountOut);

            reserve1 += amountIn;
            reserve0 -= amountOut;
        }

        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256) {
        require(amountIn > 0, "Pair: invalid input amount");
        require(tokenIn == token0 || tokenIn == token1, "Pair: invalid token");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - feePercent);
        if (tokenIn == token0) {
            require(reserve1 > 0, "Pair: insufficient liquidity");
            return (amountInWithFee * reserve1) / (reserve0 * FEE_DENOMINATOR + amountInWithFee);
        } else {
            require(reserve0 > 0, "Pair: insufficient liquidity");
            return (amountInWithFee * reserve0) / (reserve1 * FEE_DENOMINATOR + amountInWithFee);
        }
    }

    function _getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) internal view returns (uint256) {
        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - feePercent);
        return (numerator / denominator) + 1;
    }

    function getAmountIn(uint256 amountOut, address tokenIn) external view returns (uint256) {
        require(amountOut > 0, "Pair: invalid output amount");
        require(tokenIn == token0 || tokenIn == token1, "Pair: invalid token");

        if (tokenIn == token0) {
            require(amountOut < reserve1, "Pair: insufficient liquidity");
            return _getAmountIn(amountOut, reserve0, reserve1);
        } else {
            require(amountOut < reserve0, "Pair: insufficient liquidity");
            return _getAmountIn(amountOut, reserve1, reserve0);
        }
    }
}
