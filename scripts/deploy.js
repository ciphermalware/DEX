const { ethers } = require("hardhat");

async function main() {
    console.log("Starting deployment...");
    
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

    // Deploy DEX contract
    console.log("\nDeploying DEX contract...");
    const DEX = await ethers.getContractFactory("DEX");
    const dex = await DEX.deploy(deployer.address); // Fee recipient is deployer
    await dex.waitForDeployment();
    const dexAddress = await dex.getAddress();
    console.log("DEX deployed to:", dexAddress);

    // Deploy test tokens
    console.log("\nDeploying test tokens...");
    const ERC20Token = await ethers.getContractFactory("ERC20Token");
    
    // Deploy Token A
    const tokenA = await ERC20Token.deploy(
        "TokenA",
        "TKA", 
        18,
        1000000, // 1M tokens
        deployer.address
    );
    await tokenA.waitForDeployment();
    const tokenAAddress = await tokenA.getAddress();
    console.log("TokenA deployed to:", tokenAAddress);
    
    // Deploy Token B
    const tokenB = await ERC20Token.deploy(
        "TokenB",
        "TKB",
        18,
        1000000, // 1M tokens
        deployer.address
    );
    await tokenB.waitForDeployment();
    const tokenBAddress = await tokenB.getAddress();
    console.log("TokenB deployed to:", tokenBAddress);

    // Add tokens to DEX supported list
    console.log("\nAdding tokens to DEX...");
    await dex.addSupportedToken(tokenAAddress);
    await dex.addSupportedToken(tokenBAddress);
    console.log("Tokens added to DEX supported list");

    // Create initial pool
    console.log("\nCreating initial pool...");
    const poolTx = await dex.createPool(tokenAAddress, tokenBAddress);
    await poolTx.wait();
    console.log("Pool created successfully");

    
    const initialLiquidityA = ethers.parseEther("1000");
    const initialLiquidityB = ethers.parseEther("1000");
    
    console.log("\nApproving tokens for liquidity...");
    await tokenA.approve(dexAddress, initialLiquidityA);
    await tokenB.approve(dexAddress, initialLiquidityB);
    
    console.log("Adding initial liquidity...");
    await dex.addLiquidity(
        tokenAAddress,
        tokenBAddress,
        initialLiquidityA,
        initialLiquidityB,
        0, 
        0
    );
    console.log("Initial liquidity added");

    console.log("\n=== Deployment Summary ===");
    console.log("DEX Contract:", dexAddress);
    console.log("TokenA Contract:", tokenAAddress);
    console.log("TokenB Contract:", tokenBAddress);
    console.log("Deployer:", deployer.address);
    
    console.log("\n=== Frontend Configuration ===");
    console.log("Update frontend/web3-integration.js with these addresses:");
    console.log(`DEX_ADDRESS: '${dexAddress}'`);
    console.log(`TOKEN_ADDRESSES: {`);
    console.log(`  'TKA': '${tokenAAddress}',`);
    console.log(`  'TKB': '${tokenBAddress}'`);
    console.log(`}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
