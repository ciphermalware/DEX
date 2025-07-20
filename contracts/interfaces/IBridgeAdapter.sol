// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IBridgeAdapter {
    function bridgeTokens(
        string calldata bridgeName,
        address token,
        uint256 amount,
        uint256 dstChainId,
        bytes calldata recipient
    ) external;
}
