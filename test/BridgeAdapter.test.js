const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BridgeAdapter", function () {
    let token, bridgeProtocol, adapter, owner, user;

    beforeEach(async function () {
        [owner, user] = await ethers.getSigners();

        const ERC20Token = await ethers.getContractFactory("ERC20Token");
        token = await ERC20Token.deploy("BridgeToken", "BRG", 18, 1000000, owner.address);

        const MockBridge = await ethers.getContractFactory("MockBridgeProtocol");
        bridgeProtocol = await MockBridge.deploy();

        const BridgeAdapter = await ethers.getContractFactory("BridgeAdapter");
        adapter = await BridgeAdapter.deploy();
        await adapter.addBridge("mock", await bridgeProtocol.getAddress());

        await token.transfer(user.address, ethers.parseEther("100"));
    });

    it("should bridge tokens via adapter", async function () {
        const amount = ethers.parseEther("10");
        await token.connect(user).approve(await adapter.getAddress(), amount);
        await expect(
            adapter.connect(user).bridgeTokens(
                "mock",
                await token.getAddress(),
                amount,
                1,
                ethers.zeroPadBytes(user.address, 32)
            )
        ).to.emit(adapter, "TokensBridged");
    });
});
