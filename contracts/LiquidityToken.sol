// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title LiquidityToken
/// @notice ERC20 token representing shares in a DEX liquidity pool
/// The DEX contract owns the token and can mint/burn to track liquidity
contract LiquidityToken is ERC20, Ownable {
    /// @param name Token name
    /// @param symbol Token symbol
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /// @notice Mint pool tokens
    /// @param to Recipient address
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Burn pool tokens from an address
    /// @param from Address to burn from
    /// @param amount Amount to burn
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}

