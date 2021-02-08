const { expect } = require("chai");
const EthersLib = require("ethers");

const realEthers = EthersLib.ethers;

let loot;

describe("StableYield", function () {
  beforeEach(async function () {
    // deploy StableYield
    const LootToken = await ethers.getContractFactory(
      "StableYieldVaultWithCreditDelegation"
    );
    loot = await LootToken.deploy();
    await loot.deployed();
  });

  describe("StableYield tests", function () {
    it("should have correct params set", async function () {
      const name = await loot.name();
      expect(name).equal("StableYieldVault");

      const symbol = await loot.symbol();
      expect(symbol).equal("SYV");
    });
  });
});
