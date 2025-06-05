// UI interactions for BasicDEX

const connectBtn = document.getElementById("connectWallet");
const swapBtn = document.getElementById("swapButton");
const addLiqBtn = document.getElementById("addLiquidityButton");
const removeLiqBtn = document.getElementById("removeLiquidityButton");
const refreshBtn = document.getElementById("refreshPools");

if (connectBtn) connectBtn.addEventListener("click", () => dexApi.connectWallet());

async function swapTokens() {
  const tokenIn = document.getElementById("tokenIn").value;
  const tokenOut = document.getElementById("tokenOut").value;
  const amountIn = document.getElementById("swapAmountIn").value;
  if (!amountIn || !tokenIn || !tokenOut) return;
  const amount = ethers.parseUnits(amountIn, 18);
  const tokenContract = new ethers.Contract(tokenIn, ERC20_ABI, dexApi.signer);
  await tokenContract.approve(DEX_ADDRESS, amount);
  await dexApi.dex.swapExactTokensForTokens(amount, 0, tokenIn, tokenOut);
}

if (swapBtn) swapBtn.addEventListener("click", swapTokens);

// Placeholder functions for liquidity management
async function addLiquidity() {
  const tokenA = document.getElementById("liquidityTokenA").value;
  const tokenB = document.getElementById("liquidityTokenB").value;
  const amountA = document.getElementById("liquidityAmountA").value;
  const amountB = document.getElementById("liquidityAmountB").value;
  if (!tokenA || !tokenB || !amountA || !amountB) return;
  const amtA = ethers.parseUnits(amountA, 18);
  const amtB = ethers.parseUnits(amountB, 18);
  const tokenAContract = new ethers.Contract(tokenA, ERC20_ABI, dexApi.signer);
  const tokenBContract = new ethers.Contract(tokenB, ERC20_ABI, dexApi.signer);
  await tokenAContract.approve(DEX_ADDRESS, amtA);
  await tokenBContract.approve(DEX_ADDRESS, amtB);
  await dexApi.dex.addLiquidity(tokenA, tokenB, amtA, amtB, 0, 0);
}

if (addLiqBtn) addLiqBtn.addEventListener("click", addLiquidity);

if (removeLiqBtn) {
  removeLiqBtn.addEventListener("click", () => alert("Remove liquidity not implemented in demo"));
}

if (refreshBtn) {
  refreshBtn.addEventListener("click", () => alert("Refresh pools not implemented in demo"));
}
