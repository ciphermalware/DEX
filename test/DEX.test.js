const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DEX Contract", function () {
    let dex, tokenA, tokenB, owner, user1, user2;
    
    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();
        
        // Deploy DEX
        const DEX = await ethers.getContractFactory("DEX");
        dex = await DEX.deploy(owner.address);
        
        // Deploy test tokens
        const ERC20Token = await ethers.getContractFactory("ERC20Token");
        tokenA = await ERC20Token.deploy("TokenA", "TKA", 18, 1000000, owner.address);
        tokenB = await ERC20Token.deploy("TokenB", "TKB", 18, 1000000, owner.address);
        
        // Add tokens to supported list
        await dex.addSupportedToken(await tokenA.getAddress());
        await dex.addSupportedToken(await tokenB.getAddress());
        
        // Transfer tokens to users
        await tokenA.transfer(user1.address, ethers.parseEther("1000"));
        await tokenB.transfer(user1.address, ethers.parseEther("1000"));
        await tokenA.transfer(user2.address, ethers.parseEther("1000"));
        await tokenB.transfer(user2.address, ethers.parseEther("1000"));
    });

    describe("Pool Creation", function () {
        it("Should create a pool successfully", async function () {
            const tokenAAddr = await tokenA.getAddress();
            const tokenBAddr = await tokenB.getAddress();
            
            await expect(dex.createPool(tokenAAddr, tokenBAddr))
                .to.emit(dex, "PoolCreated");
            
            const [reserveA, reserveB, totalLiquidity] = await dex.getPoolInfo(tokenAAddr, tokenBAddr);
            expect(totalLiquidity).to.equal(0);
        });

        it("Should not create duplicate pools", async function () {
            const tokenAAddr = await tokenA.getAddress();
            const tokenBAddr = await tokenB.getAddress();
            
            await dex.createPool(tokenAAddr, tokenBAddr);
            
            await expect(dex.createPool(tokenAAddr, tokenBAddr))
                .to.be.revertedWith("DEX: Pool already exists");
        });
    });

    describe("Liquidity Management", function () {
        beforeEach(async function () {
            const tokenAAddr = await tokenA.getAddress();
            const tokenBAddr = await tokenB.getAddress();
            const dexAddr = await dex.getAddress();
            
            // Approve tokens
            await tokenA.connect(user1).approve(dexAddr, ethers.parseEther("100"));
            await tokenB.connect(user1).approve(dexAddr, ethers.parseEther("100"));
        });

        it("Should add liquidity successfully", async function () {
            const tokenAAddr = await tokenA.getAddress();
            const tokenBAddr = await tokenB.getAddress();
            
            await expect(dex.connect(user1).addLiquidity(
                tokenAAddr,
                tokenBAddr,
                ethers.parseEther("10"),
                ethers.parseEther("10"),
                0,
                0
            )).to.emit(dex, "LiquidityAdded");
        });
    });

    describe("Token Swapping", function () {
        beforeEach(async function () {
            const tokenAAddr = await tokenA.getAddress();
            const tokenBAddr = await tokenB.getAddress();
            const dexAddr = await dex.getAddress();
            
            // Add initial liquidity
            await tokenA.connect(user1).approve(dexAddr, ethers.parseEther("100"));
            await tokenB.connect(user1).approve(dexAddr, ethers.parseEther("100"));
            
            await dex.connect(user1).addLiquidity(
                tokenAAddr,
                tokenBAddr,
                ethers.parseEther("100"),
                ethers.parseEther("100"),
                0,
                0
            );
        });

        it("Should swap tokens successfully", async function () {
            const tokenAAddr = await tokenA.getAddress();
            const tokenBAddr = await tokenB.getAddress();
            const dexAddr = await dex.getAddress();
            
            await tokenA.connect(user2).approve(dexAddr, ethers.parseEther("10"));
            
            await expect(dex.connect(user2).swapExactTokensForTokens(
                ethers.parseEther("1"),
                0,
                tokenAAddr,
                tokenBAddr
            )).to.emit(dex, "Swap");
        });
        
        it("Should quote input amount", async function () {
            const tokenAAddr = await tokenA.getAddress();
            const tokenBAddr = await tokenB.getAddress();

            const amountOut = ethers.parseEther("1");
            const amountIn = await dex.getAmountIn(amountOut, tokenAAddr, tokenBAddr);
            expect(amountIn).to.be.gt(0n);
        });

        it("Should swap tokens for exact output", async function () {
            const tokenAAddr = await tokenA.getAddress();
            const tokenBAddr = await tokenB.getAddress();
            const dexAddr = await dex.getAddress();

            const amountOut = ethers.parseEther("1");
            const amountIn = await dex.getAmountIn(amountOut, tokenAAddr, tokenBAddr);

            await tokenA.connect(user2).approve(dexAddr, ethers.parseEther("10"));

            await expect(dex.connect(user2).swapTokensForExactTokens(
                amountOut,
                ethers.parseEther("10"),
                tokenAAddr,
                tokenBAddr
            )).to.emit(dex, "Swap");

            const userBalance = await tokenB.balanceOf(user2.address);
            expect(userBalance).to.be.gte(ethers.parseEther("1000") + amountOut);
        });
    });

    describe("Access Control", function () {
        it("Should allow owner to pause/unpause", async function () {
            await dex.pause();
            expect(await dex.paused()).to.be.true;
            
            await dex.unpause();
            expect(await dex.paused()).to.be.false;
        });

        it("Should not allow non-owner to pause", async function () {
            await expect(dex.connect(user1).pause())
                .to.be.revertedWith("Ownable: caller is not the owner");
        });
    });
});
