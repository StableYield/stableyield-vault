const ETH_A_ILK = "ETH-A";
const ETH_B_ILK = "ETH-B";
const USDC_A_ILK = "USDC-A";

/**
 * @name deploy
 * @description Deploys contracts with basic setup.
 * @param teamAddress
 */
task("maker-ilks", "Generate Maker ILKS", async function () {
  const eth_a_ilk = ethers.utils.formatBytes32String(ETH_A_ILK);
  const eth_b_ilk = ethers.utils.formatBytes32String(ETH_B_ILK);
  const usdc_ilk = ethers.utils.formatBytes32String(USDC_A_ILK);
  console.log("ETH-A", eth_a_ilk);
  console.log("ETH-B", eth_b_ilk);
  // console.log(usdc_ilk, "usdc_ilk");
});
