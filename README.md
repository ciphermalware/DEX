# Decentralized Exchange

This project shows a basic decentralized exchange built with Solidity smart contracts. It lets users swap tokens, add liquidity and earn fees in the process. 
Furthermore I have added more features like staking, token locking and cross chain bridges.


## Main Features

- **Token Swaps and Pools** – `DEX.sol` keeps pools of two tokens, lets users add or remove liquidity and takes a fee
- **Multi Hop Swaps** – `DEXRouter.sol` routes trades through several pools so a user can swap any supported pair of tokens
- **Pair Contracts** – `PairFactory.sol` creates dedicated `Pair.sol` contracts. Each pair tracks its own reserves and issues `LiquidityToken` shares
- **Bridge Support** – `BridgeAdapter.sol` holds connectors to different bridge protocols so swapped tokens can move to other chains
- **Fee Treasury** – `FeeCollector.sol` stores protocol fees and lets owner withdraw them
- **Liquidity Locking** – `LiquidityLocker.sol` allows users to lock LP tokens for a chosen time to show long term commitment
- **Staking Rewards** – `StakingRewards.sol` lets users stake a token and earn rewards over time
- **Token Tools** – `ERC20Token.sol` is a simple token for testing  `GovernanceToken.sol` adds voting power and `TokenVesting.sol` releases tokens on a schedule
