// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title ERC20Token
/// @notice Basic ERC20 token with mint and burn capabilities
contract ERC20Token is ERC20, Ownable, Pausable {
    uint8 private _decimals;

    /// @param name Token name
    /// @param symbol Token symbol
    /// @param decimals_ Number of decimals the token uses
    /// @param initialSupply Initial token supply minted to the owner
    /// @param owner Address that becomes the token owner
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) {
        _decimals = decimals_;
        _transferOwnership(owner);
        _mint(owner, initialSupply * 10**decimals_);
    }

    /// @notice Returns the number of decimals used by the token
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /// @notice Mint new tokens
    /// @param to Recipient of the minted tokens
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /// @notice Burn tokens from the caller
    /// @param amount Amount of tokens to burn
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    /// @notice Burn tokens from another address using allowance
    /// @param account Address to burn tokens from
    /// @param amount Amount of tokens to burn
    function burnFrom(address account, uint256 amount) public {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    /// @notice Pause all token transfers
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Unpause token transfers
    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "ERC20Token: token transfer while paused");
    }
}
