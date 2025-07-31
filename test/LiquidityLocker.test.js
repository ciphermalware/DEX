const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LiquidityLocker", function () {
    let token, locker, owner, user;

    beforeEach(async function () {
        [owner, user] = await ethers.getSigners();

        const ERC20Token = await ethers.getContractFactory("ERC20Token");
        token = await ERC20Token.deploy("LockToken", "LCK", 18, 1000000, owner.address);

        const LiquidityLocker = await ethers.getContractFactory("LiquidityLocker");
        locker = await LiquidityLocker.deploy();
    });

    it("should allow extending and increasing locks", async function () {
        const lockerAddr = await locker.getAddress();
        await token.transfer(user.address, ethers.parseEther("100"));
        await token.connect(user).approve(lockerAddr, ethers.parseEther("20"));

        await locker.connect(user).lock(await token.getAddress(), ethers.parseEther("10"), 60);
        await locker.connect(user).extendLock(await token.getAddress(), 0, 60);

        await token.connect(user).approve(lockerAddr, ethers.parseEther("10"));
        await locker.connect(user).increaseLockAmount(await token.getAddress(), 0, ethers.parseEther("10"));

        await ethers.provider.send("evm_increaseTime", [120]);
        await ethers.provider.send("evm_mine");

        await expect(locker.connect(user).unlock(await token.getAddress(), 0))
            .to.emit(locker, "TokensUnlocked");

        const balance = await token.balanceOf(user.address);
        expect(balance).to.equal(ethers.parseEther("100"));
    });
});
