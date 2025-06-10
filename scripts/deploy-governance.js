const { ethers } = require("hardhat");

async function main() {
    console.log("Deploying GovernanceToken...");
    const [deployer] = await ethers.getSigners();
    console.log("Using account:", deployer.address);

    const GovernanceToken = await ethers.getContractFactory("GovernanceToken");
    const gov = await GovernanceToken.deploy(
        "GovernanceToken",
        "GOV",
        ethers.parseEther("1000000"),
        deployer.address
    );
    await gov.waitForDeployment();

    console.log("GovernanceToken deployed to:", await gov.getAddress());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
