/**
 * @name aave-reserve-data
 * @description Get reserve data.
 * @param teamAddress
 */
task("aave-reserve-data", "Get Lending Pool Reserve Data")
  .addPositionalParam("asset", "Reserve")
  .setAction(async function ({ asset }) {
    const Contract = await ethers.getContractAt("IProtocolDataProvider.sol");
    const contract = Contract.attach(
      "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d"
    );

    const data = await contract.getReserveData(asset);
    console.log(data.liquidityRate.toString());
    console.log(data);
  });
