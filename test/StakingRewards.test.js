const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakingRewards", function () {
    let stakingToken, rewardsToken, staking, owner, user;

    beforeEach(async function () {
        [owner, user] = await ethers.getSigners();

        const ERC20Token = await ethers.getContractFactory("ERC20Token");
        stakingToken = await ERC20Token.deploy("StakeToken", "STK", 18, 1000000, owner.address);
        rewardsToken = await ERC20Token.deploy("RewardToken", "RWD", 18, 1000000, owner.address);

        const StakingRewards = await ethers.getContractFactory("StakingRewards");
        staking = await StakingRewards.deploy(
            await stakingToken.getAddress(),
            await rewardsToken.getAddress()
        );
    });

    it("should stake and earn rewards", async function () {
        const stakingAddress = await staking.getAddress();

        await stakingToken.transfer(user.address, ethers.parseEther("100"));
        await stakingToken.connect(user).approve(stakingAddress, ethers.parseEther("100"));

        await rewardsToken.transfer(stakingAddress, ethers.parseEther("100"));
        await staking.notifyRewardAmount(ethers.parseEther("100"));

        await staking.connect(user).stake(ethers.parseEther("10"));

        await ethers.provider.send("evm_increaseTime", [3600]);
        await ethers.provider.send("evm_mine");

        await staking.connect(user).getReward();
        expect(await rewardsToken.balanceOf(user.address)).to.be.gt(0n);
    });
});
