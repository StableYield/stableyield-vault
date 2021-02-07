# StableYield

The StableYield application is a multi-featured decentralized finance application, designed to facilitate stable returns using ETH and stablecoins like DAI, USDC, USDT, and others.

### StableYield Vault

The primary smart contract is the StableYieldVault. The vault's primary focus is to maximize yield for stablecoin deposits.

- Deposit stablecoin from approved list.
- Receive shares representing stake in the vault.
- Collateral automatically swapped to highest yielding stabletoken.
- Burn shares and withdraw principal, plus earned interest.

#### Credit Delegation

The more advanced vault, includes credit delegation, allowing multiple users to issue an uncollaterized loan to single user.

The vault includes code from the Moloch smart contracts to facilitate the proposal submission, sponsorship and voting.

### Creditline Factory

The Creditline smart contracts help facilitate loans with unique collaterization assets. Under the hood the credit delegation funconality is implemented to enable withdrawls from the Aave protocol. In addition, ERC20 and ERC721 staking contract are included to to allow lenders to use some form of collateral to ensure the loan.

It's up to loaner to decide their level of risk and value the asset, as no price feeds are used to determine the value of the collaterized asset.
