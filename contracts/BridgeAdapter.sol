// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

    function addBridge(string calldata name, address adapter) external onlyOwner {
        require(adapter != address(0), "BridgeAdapter: invalid adapter");
        require(bridges[name].adapter == address(0), "BridgeAdapter: exists");
        bridges[name] = BridgeInfo(adapter, true);
        bridgeList.push(name);
        emit BridgeAdded(name, adapter);
    }

    function disableBridge(string calldata name) external onlyOwner {
        require(bridges[name].adapter != address(0), "BridgeAdapter: not found");
        bridges[name].enabled = false;
        emit BridgeDisabled(name);
    }

    function listBridges() external view returns (string[] memory) {
        return bridgeList;
    }

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
