// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IBridgeProtocol {
    function sendTokens(
        address token,
        uint256 amount,
        uint256 dstChainId,
        bytes calldata recipient
    ) external;
}

/// @title BridgeAdapter
/// @notice Allows routing token transfers through multiple bridge protocols
contract BridgeAdapter is Ownable {
    using SafeERC20 for IERC20;

    struct BridgeInfo {
        address adapter;
        bool enabled;
    }

    mapping(string => BridgeInfo) public bridges;
    string[] private bridgeList;

    event BridgeAdded(string name, address adapter);
    event BridgeDisabled(string name);
    event TokensBridged(string indexed name, address indexed user, address token, uint256 amount, uint256 dstChainId, bytes recipient);


    /// @notice Register a new bridge implementation
    /// @param name Identifier for the bridge
    /// @param adapter Address of the bridge adapter contract
    function addBridge(string calldata name, address adapter) external onlyOwner {
        require(adapter != address(0), "BridgeAdapter: invalid adapter");
        require(bridges[name].adapter == address(0), "BridgeAdapter: exists");
        bridges[name] = BridgeInfo(adapter, true);
        bridgeList.push(name);
        emit BridgeAdded(name, adapter);
    }

    /// @notice Disable an existing bridge
    /// @param name Identifier of the bridge to disable
    function disableBridge(string calldata name) external onlyOwner {
        require(bridges[name].adapter != address(0), "BridgeAdapter: not found");
        bridges[name].enabled = false;
        emit BridgeDisabled(name);
    }

    /// @notice List all registered bridge names
    /// @return Array of bridge identifiers
    function listBridges() external view returns (string[] memory) {
        return bridgeList;
    }

    /// @notice Bridge tokens using a configured adapter
    /// @param name Identifier of the bridge to use
    /// @param token Address of the token to bridge
    /// @param amount Amount of tokens to bridge
    /// @param dstChainId Destination chain identifier
    /// @param recipient Encoded recipient on the destination chain
    function bridgeTokens(
        string calldata name,
        address token,
        uint256 amount,
        uint256 dstChainId,
        bytes calldata recipient
    ) external {
        BridgeInfo memory info = bridges[name];
        require(info.enabled, "BridgeAdapter: disabled");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(info.adapter, amount);
        IBridgeProtocol(info.adapter).sendTokens(token, amount, dstChainId, recipient);
        emit TokensBridged(name, msg.sender, token, amount, dstChainId, recipient);
    }
}
