// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title GovernanceToken
/// @notice ERC20 token with voting capabilities for protocol governance
contract GovernanceToken is ERC20Votes, Ownable, Pausable {
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param initialSupply Amount minted to the owner
    /// @param owner Address that receives the initial supply and becomes owner
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) ERC20Permit(name) {
        _transferOwnership(owner);
        _mint(owner, initialSupply);
    }

    /// @notice Pause all token transfers
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause token transfers
    function unpause() external onlyOwner {
        _unpause();
    }

    // The following functions are overrides required by Solidity.
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function _mint(address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, value);
    }

    function _burn(address from, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(from, value);
    }
}
