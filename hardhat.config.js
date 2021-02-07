require("dotenv").config();
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require("hardhat-contract-sizer");
require("./hardhat/hardhat.maker");
require("./hardhat/hardhat.aave");

function getConfig() {
  return config.networks[network.name];
}

/**
 * @name deploy-stableyield-vault
 * @description Deploys CreditLineFactory contracts.
 */
task(
  "deploy-stableyield-vault",
  "Deploy StableYield Vault smart contract"
).setAction(async function () {
  const config = getConfig();
  const StableYieldVault = await ethers.getContractFactory(
    "StableYieldVaultWithCreditDelegation"
  );
  const contract = await StableYieldVault.deploy(
    config.tokens.DAI, // Starting Token == DAI
    config.contracts.addressProvider, // _addressProvider
    config.contracts.dataProvider, // _dataProvider
    [
      config.tokens.DAI,
      config.tokens.USDC,
      config.tokens.USDT,
      config.tokens.TUSD,
      config.tokens.SUSD,
      config.tokens.BUSD,
    ] // _approvedTokens
  );
  await contract.deployed();
  console.log("StableYieldVault:", contract.address);
});

/**
 * @name deploy-stableyield
 * @description Deploy StableYield contract.
 * @param teamAddress
 */
task("deploy-stableyield", "Deploy StableYield smart contract").setAction(
  async function () {
    const StableYield = await ethers.getContractFactory("StableYield");
    const contract = await StableYield.deploy();
    await contract.deployed();
    console.log("StableYield:", contract.address);
  }
);

/**
 * @name increase-time
 * @description Deploys contracts with basic setup.
 * @param teamAddress
 */
task("increase-time", "Increase the blockchain timestamp")
  .addPositionalParam("time", "Token Name")
  .setAction(async function ({ time }) {
    const jsonProvider = new ethers.providers.JsonRpcProvider(
      "http://127.0.0.1:8544/"
    );
    const tx = await jsonProvider.send("evm_setNextBlockTimestamp", [
      Number(time),
    ]);
    console.log(tx);
  });

/**
 * @name blocknumber
 * @description Deploys contracts with basic setup.
 * @param teamAddress
 */
task("blocknumber", "Increase the blockchain timestamp").setAction(
  async function ({ time }) {
    const jsonProvider = new ethers.providers.JsonRpcProvider(
      "http://127.0.0.1:8544/"
    );
    // console.log(jsonProvider, "provider");
    const blocknumber = await jsonProvider.getBlockNumber();
    console.log(blocknumber);
  }
);

module.exports = {
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  defaultNetwork: "development",
  networks: {
    hardhat: {
      gasPrice: 10000000,
      allowUnlimitedContractSize: true,
      chainId: 0x01,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 11741278,
      },
    },
    development: {
      url: `http://127.0.0.1:8544/`,
      gasPrice: 1000000000,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
      contracts: {
        addressProvider: "0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5",
        dataProvider: "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d",
      },
      tokens: {
        DAI: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
        USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        USDT: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
        TUSD: "0x0000000000085d4780B73119b644AE5ecd22b376",
        SUSD: "0x57Ab1ec28D129707052df4dF418D58a2D46d5f51",
        BUSD: "0x4Fabb145d64652a948d72533023f6E7A623C7C53",
      },
    },
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
      gasPrice: 1000000000,
      gasLimit: 10000000,
    },
    kovan: {
      url: `https://eth-kovan.alchemyapi.io/v2/${process.env.ALCHEMY_KEY_KOVAN}`,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
      contracts: {
        addressProvider: "0x88757f2f99175387ab4c6a4b3067c77a695b0349",
        dataProvider: "0x3c73A5E5785cAC854D468F727c606C07488a29D6",
      },
      tokens: {
        DAI: "0xff795577d9ac8bd7d90ee22b6c1703490b6512fd",
        USDC: "0xe22da380ee6b445bb8273c81944adeb6e8450422",
        USDT: "0x13512979ade267ab5100878e2e0f485b568328a4",
        TUSD: "0x016750ac630f711882812f24dba6c95b9d35856d",
        SUSD: "0x99b267b9d96616f906d53c26decf3c5672401282",
        BUSD: "0x4c6e1efc12fdfd568186b7baec0a43fffb4bcccf",
      },
    },
    mainnet: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
      gasPrice: 1000000000,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
  },

  solidity: {
    compilers: [
      {
        version: "0.6.6",
      },
      {
        version: "0.6.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 10,
      },
    },
  },
};
