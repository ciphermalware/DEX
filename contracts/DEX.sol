// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./LiquidityToken.sol";
import "./interfaces/IBridgeAdapter.sol";

contract DEX is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;
    struct Pool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        mapping(address => uint256) liquidityBalances;
        bool exists;
        address lpToken;
    }

    mapping(bytes32 => Pool) public pools;
    bytes32[] public poolIds;
    mapping(address => bool) public supportedTokens;
    
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public feePercent = 30; // 0.3% fee (30/10000)
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public protocolFeePercent = 5; // 5% of trading fees go to protocol
    address public feeRecipient;
    IBridgeAdapter public bridgeAdapter;

    event PoolCreated(address indexed tokenA, address indexed tokenB, bytes32 poolId);
    event LiquidityAdded(address indexed user, bytes32 poolId, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed user, bytes32 poolId, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, bytes32 poolId, address tokenIn, uint256 amountIn, uint256 amountOut);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event TokenSupported(address indexed token);
    event TokenUnsupported(address indexed token);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event BridgeAdapterUpdated(address oldAdapter, address newAdapter);

    constructor(address _feeRecipient) {
        require(_feeRecipient != address(0), "DEX: Invalid fee recipient");
        feeRecipient = _feeRecipient;
    }

    modifier validTokenPair(address tokenA, address tokenB) {
        require(tokenA != address(0) && tokenB != address(0), "DEX: Zero address");
        require(tokenA != tokenB, "DEX: Identical tokens");
        require(supportedTokens[tokenA] && supportedTokens[tokenB], "DEX: Unsupported token");
        _;
    }

    modifier poolExists(bytes32 poolId) {
        require(pools[poolId].exists, "DEX: Pool does not exist");
        _;
    }

    // Owner functions
    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "DEX: Zero address");
        require(token.isContract(), "DEX: Not a contract");
        supportedTokens[token] = true;
        emit TokenSupported(token);
    }

    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
        emit TokenUnsupported(token);
    }

    function setFeePercent(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= 1000, "DEX: Fee too high"); // Max 10%
        uint256 oldFee = feePercent;
        feePercent = _feePercent;
        emit FeeUpdated(oldFee, _feePercent);
    }

    function setProtocolFeePercent(uint256 _protocolFeePercent) external onlyOwner {
        require(_protocolFeePercent <= 2000, "DEX: Protocol fee too high"); // Max 20%
        protocolFeePercent = _protocolFeePercent;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "DEX: Invalid fee recipient");
        address oldRecipient = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(oldRecipient, _feeRecipient);
    }

     function setBridgeAdapter(address adapter) external onlyOwner {
        address old = address(bridgeAdapter);
        bridgeAdapter = IBridgeAdapter(adapter);
        emit BridgeAdapterUpdated(old, adapter);
    }


     function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }

    function getPoolId(address tokenA, address tokenB) public pure returns (bytes32) {
        require(tokenA != tokenB, "DEX: Identical tokens");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(token0, token1));
    }

    function createPool(address tokenA, address tokenB) 
        external 
        validTokenPair(tokenA, tokenB) 
        whenNotPaused 
        returns (bytes32) 
    {        
        bytes32 poolId = getPoolId(tokenA, tokenB);
        require(!pools[poolId].exists, "DEX: Pool already exists");

        Pool storage pool = pools[poolId];
        (pool.tokenA, pool.tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pool.exists = true;
        
        poolIds.push(poolId);
        
        emit PoolCreated(tokenA, tokenB, poolId);
        return poolId;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external 
      nonReentrant 
      validTokenPair(tokenA, tokenB) 
      whenNotPaused 
      returns (uint256 amountA, uint256 amountB, uint256 liquidity) 
    {
        require(amountADesired > 0 && amountBDesired > 0, "DEX: Invalid amounts");
        
        bytes32 poolId = getPoolId(tokenA, tokenB);
        
        if (!pools[poolId].exists) {
            createPool(tokenA, tokenB);
        }
        
        Pool storage pool = pools[poolId];
        
        if (pool.reserveA == 0 && pool.reserveB == 0) {
            // First liquidity provision
            amountA = amountADesired;
            amountB = amountBDesired;
            liquidity = Math.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            require(liquidity > 0, "DEX: Insufficient liquidity minted");
        } else {
            // Calculate optimal amounts
            uint256 amountBOptimal = (amountADesired * pool.reserveB) / pool.reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "DEX: Insufficient B amount");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountBDesired * pool.reserveA) / pool.reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "DEX: Insufficient A amount");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
            
            liquidity = Math.min((amountA * pool.totalLiquidity) / pool.reserveA, 
                               (amountB * pool.totalLiquidity) / pool.reserveB);
        }

        // Determine which token is which in the pool and transfer
        if (pool.tokenA == tokenA) {
            IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
            IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);
            pool.reserveA += amountA;
            pool.reserveB += amountB;
        } else {
            IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountB);
            IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountA);
            pool.reserveA += amountB;
            pool.reserveB += amountA;
        }

        pool.totalLiquidity += liquidity;
        pool.liquidityBalances[msg.sender] += liquidity;

        emit LiquidityAdded(msg.sender, poolId, amountA, amountB, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external 
      nonReentrant 
      validTokenPair(tokenA, tokenB) 
      whenNotPaused 
      returns (uint256 amountA, uint256 amountB) 
    {
        require(liquidity > 0, "DEX: Invalid liquidity amount");
        
        bytes32 poolId = getPoolId(tokenA, tokenB);
        Pool storage pool = pools[poolId];
        
        require(pool.exists, "DEX: Pool does not exist");
        require(pool.liquidityBalances[msg.sender] >= liquidity, "DEX: Insufficient liquidity");
        require(pool.totalLiquidity > 0, "DEX: No liquidity");

        amountA = (liquidity * pool.reserveA) / pool.totalLiquidity;
        amountB = (liquidity * pool.reserveB) / pool.totalLiquidity;

        require(amountA > 0 && amountB > 0, "DEX: Insufficient liquidity burned");

        pool.totalLiquidity -= liquidity;
        pool.liquidityBalances[msg.sender] -= liquidity;
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;

        if (pool.tokenA == tokenA) {
            require(amountA >= amountAMin && amountB >= amountBMin, "DEX: Insufficient output amount");
            IERC20(tokenA).safeTransfer(msg.sender, amountA);
            IERC20(tokenB).safeTransfer(msg.sender, amountB);
        } else {
            require(amountB >= amountAMin && amountA >= amountBMin, "DEX: Insufficient output amount");
            IERC20(tokenA).safeTransfer(msg.sender, amountB);
            IERC20(tokenB).safeTransfer(msg.sender, amountA);
            // Swap amounts for return values to match input token order
            (amountA, amountB) = (amountB, amountA);
        }

        emit LiquidityRemoved(msg.sender, poolId, amountA, amountB, liquidity);
    }

    function _swapExactTokensForTokensTo(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        address to
    ) internal returns (uint256 amountOut) {
        require(amountIn > 0, "DEX: Invalid input amount");
        
        bytes32 poolId = getPoolId(tokenIn, tokenOut);
        Pool storage pool = pools[poolId];
        require(pool.exists, "DEX: Pool does not exist");

        // Calculate output amount with fee
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - feePercent);
        uint256 protocolFee = 0;
        
        if (pool.tokenA == tokenIn) {
            require(pool.reserveB > 0, "DEX: Insufficient liquidity");
            amountOut = (amountInWithFee * pool.reserveB) / (pool.reserveA * FEE_DENOMINATOR + amountInWithFee);
            require(amountOut >= amountOutMin, "DEX: Insufficient output amount");
            require(amountOut < pool.reserveB, "DEX: Insufficient liquidity");
            
            // Calculate protocol fee
            protocolFee = (amountIn * feePercent * protocolFeePercent) / (FEE_DENOMINATOR * FEE_DENOMINATOR);
            
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
            IERC20(tokenOut).safeTransfer(to, amountOut);
            
            // Transfer protocol fee
            if (protocolFee > 0) {
                IERC20(tokenIn).safeTransfer(feeRecipient, protocolFee);
            }
            
            pool.reserveA += amountIn - protocolFee;
            pool.reserveB -= amountOut;
        } else {
            require(pool.reserveA > 0, "DEX: Insufficient liquidity");
            amountOut = (amountInWithFee * pool.reserveA) / (pool.reserveB * FEE_DENOMINATOR + amountInWithFee);
            require(amountOut >= amountOutMin, "DEX: Insufficient output amount");
            require(amountOut < pool.reserveA, "DEX: Insufficient liquidity");
            
            // Calculate protocol fee
            protocolFee = (amountIn * feePercent * protocolFeePercent) / (FEE_DENOMINATOR * FEE_DENOMINATOR);
            
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
            IERC20(tokenOut).safeTransfer(to, amountOut);
            
            // Transfer protocol fee
            if (protocolFee > 0) {
                IERC20(tokenIn).safeTransfer(feeRecipient, protocolFee);
            }
            
            pool.reserveB += amountIn - protocolFee;
            pool.reserveA -= amountOut;
        }

        emit Swap(to, poolId, tokenIn, amountIn, amountOut);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut
    ) external nonReentrant validTokenPair(tokenIn, tokenOut) whenNotPaused returns (uint256 amountOut) {
        return _swapExactTokensForTokensTo(amountIn, amountOutMin, tokenIn, tokenOut, msg.sender);
    }

    function swapAndBridge(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        string calldata bridgeName,
        uint256 dstChainId,
        bytes calldata recipient
    ) external nonReentrant validTokenPair(tokenIn, tokenOut) whenNotPaused returns (uint256 amountOut) {
        require(address(bridgeAdapter) != address(0), "DEX: bridge adapter not set");
        amountOut = _swapExactTokensForTokensTo(amountIn, amountOutMin, tokenIn, tokenOut, address(this));
        IERC20(tokenOut).approve(address(bridgeAdapter), amountOut);
        bridgeAdapter.bridgeTokens(bridgeName, tokenOut, amountOut, dstChainId, recipient);
    }

function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address tokenIn,
        address tokenOut
    ) external
      nonReentrant
      validTokenPair(tokenIn, tokenOut)
      whenNotPaused
      returns (uint256 amountIn)
    {
        require(amountOut > 0, "DEX: Invalid output amount");

        bytes32 poolId = getPoolId(tokenIn, tokenOut);
        Pool storage pool = pools[poolId];
        require(pool.exists, "DEX: Pool does not exist");

        if (pool.tokenA == tokenIn) {
            require(amountOut < pool.reserveB, "DEX: Insufficient liquidity");
            amountIn = _getAmountIn(amountOut, pool.reserveA, pool.reserveB);
        } else {
            require(amountOut < pool.reserveA, "DEX: Insufficient liquidity");
            amountIn = _getAmountIn(amountOut, pool.reserveB, pool.reserveA);
        }

        require(amountIn <= amountInMax, "DEX: Excessive input amount");

        uint256 protocolFee = (amountIn * feePercent * protocolFeePercent) / (FEE_DENOMINATOR * FEE_DENOMINATOR);

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        if (protocolFee > 0) {
            IERC20(tokenIn).safeTransfer(feeRecipient, protocolFee);
        }

        if (pool.tokenA == tokenIn) {
            pool.reserveA += amountIn - protocolFee;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountIn - protocolFee;
            pool.reserveA -= amountOut;
        }

        emit Swap(msg.sender, poolId, tokenIn, amountIn, amountOut);
    }

    function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut)
        external
        view
        validTokenPair(tokenIn, tokenOut)
        returns (uint256)

    {
        require(amountIn > 0, "DEX: Invalid input amount");
        
        bytes32 poolId = getPoolId(tokenIn, tokenOut);
        Pool storage pool = pools[poolId];
        require(pool.exists, "DEX: Pool does not exist");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - feePercent);
        
        if (pool.tokenA == tokenIn) {
            require(pool.reserveB > 0, "DEX: Insufficient liquidity");
            return (amountInWithFee * pool.reserveB) / (pool.reserveA * FEE_DENOMINATOR + amountInWithFee);
        } else {
            require(pool.reserveA > 0, "DEX: Insufficient liquidity");
            return (amountInWithFee * pool.reserveA) / (pool.reserveB * FEE_DENOMINATOR + amountInWithFee);
        }
    }
function _getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) internal view returns (uint256) {
        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - feePercent);
        return (numerator / denominator) + 1;
    }

    function getAmountIn(uint256 amountOut, address tokenIn, address tokenOut)
        external
        view
        validTokenPair(tokenIn, tokenOut)
        returns (uint256)
    {
        require(amountOut > 0, "DEX: Invalid output amount");

        bytes32 poolId = getPoolId(tokenIn, tokenOut);
        Pool storage pool = pools[poolId];
        require(pool.exists, "DEX: Pool does not exist");

        if (pool.tokenA == tokenIn) {
            require(amountOut < pool.reserveB, "DEX: Insufficient liquidity");
            return _getAmountIn(amountOut, pool.reserveA, pool.reserveB);
        } else {
            require(amountOut < pool.reserveA, "DEX: Insufficient liquidity");
            return _getAmountIn(amountOut, pool.reserveB, pool.reserveA);
        }
    }
    function getPoolInfo(address tokenA, address tokenB) 
        external 
        view 
        validTokenPair(tokenA, tokenB) 
        returns (uint256 reserveA, uint256 reserveB, uint256 totalLiquidity) 
    {
        bytes32 poolId = getPoolId(tokenA, tokenB);
        Pool storage pool = pools[poolId];
        
        if (pool.tokenA == tokenA) {
            return (pool.reserveA, pool.reserveB, pool.totalLiquidity);
        } else {
            return (pool.reserveB, pool.reserveA, pool.totalLiquidity);
        }
    }

    function getUserLiquidity(address tokenA, address tokenB, address user) 
        external 
        view 
        validTokenPair(tokenA, tokenB) 
        returns (uint256) 
    {
        bytes32 poolId = getPoolId(tokenA, tokenB);
        return pools[poolId].liquidityBalances[user];
    }

    function getPoolCount() external view returns (uint256) {
        return poolIds.length;
    }

    function getPoolByIndex(uint256 index) external view returns (
        address tokenA,
        address tokenB,
        uint256 reserveA,
        uint256 reserveB,
        uint256 totalLiquidity
    ) {
        require(index < poolIds.length, "DEX: Index out of bounds");
        bytes32 poolId = poolIds[index];
        Pool storage pool = pools[poolId];
        return (pool.tokenA, pool.tokenB, pool.reserveA, pool.reserveB, pool.totalLiquidity);
    }

    function isTokenSupported(address token) external view returns (bool) {
        return supportedTokens[token];
    }
}
