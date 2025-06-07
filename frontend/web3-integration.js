// Basic configuration for interacting with the smart contracts
// I have to replace the placeholder addresses with the real deployed addresses

const DEX_ADDRESS = "0xYourDexAddress";
const ROUTER_ADDRESS = "0xYourRouterAddress";

// Simplified ABIs used by the frontend
const DEX_ABI = [
  "function addLiquidity(address tokenA,address tokenB,uint256 amountADesired,uint256 amountBDesired,uint256 amountAMin,uint256 amountBMin) returns (uint256 amountA,uint256 amountB,uint256 liquidity)",
  "function removeLiquidity(address tokenA,address tokenB,uint256 liquidity,uint256 amountAMin,uint256 amountBMin) returns (uint256 amountA,uint256 amountB)",
  "function swapExactTokensForTokens(uint256 amountIn,uint256 amountOutMin,address tokenIn,address tokenOut) returns (uint256 amountOut)",
  "function getAmountOut(uint256 amountIn,address tokenIn,address tokenOut) view returns (uint256)"
];

const ROUTER_ABI = [
  "function swapExactTokensForTokens(uint256 amountIn,uint256 amountOutMin,address[] path,uint256 deadline) returns (uint256 amountOut)",
  "function getAmountsOut(uint256 amountIn,address[] path) view returns (uint256[] amounts)",
  "function getAmountsIn(uint256 amountOut,address[] path) view returns (uint256[] amounts)"
];

const ERC20_ABI = [
  "function approve(address spender,uint256 amount) returns (bool)",
  "function balanceOf(address owner) view returns (uint256)",
  "function decimals() view returns (uint8)"
];

let provider;
let signer;
let dex;
let router;

async function connectWallet() {
  if (!window.ethereum) {
    alert("MetaMask not detected");
    return;
  }
  provider = new ethers.BrowserProvider(window.ethereum);
  await provider.send("eth_requestAccounts", []);
  signer = await provider.getSigner();
  dex = new ethers.Contract(DEX_ADDRESS, DEX_ABI, signer);
  router = new ethers.Contract(ROUTER_ADDRESS, ROUTER_ABI, signer);
  document.getElementById("walletAddress").textContent = await signer.getAddress();
  document.getElementById("connectWallet").style.display = "none";
  document.getElementById("walletInfo").style.display = "flex";
}

window.dexApi = {
  connectWallet,
  get signer() { return signer; },
  get dex() { return dex; },
  get router() { return router; }
};
