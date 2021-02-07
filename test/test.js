const { expect } = require("chai");
const EthersLib = require("ethers");

const realEthers = EthersLib.ethers;

let loot;

describe("Loot", function () {
  beforeEach(async function () {
    // deploy Loot
    const LootToken = await ethers.getContractFactory("LootToken");
    loot = await LootToken.deploy();
    await loot.deployed();
  });

  describe("Loot Token tests", function () {
    it("should have correct params set", async function () {
      const name = await loot.name();
      expect(name).equal("Loot Token");

      const symbol = await loot.symbol();
      expect(symbol).equal("LOOT");
    });
  });
});
