// SPDX-License-Identifier: MIT
pragma solidity =0.6.10;
// pragma experimental ABIEncoderV2;

import "./tokens/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/curve/IStableSwap.sol";
import "./interfaces/curve/ICurveRegistryMinimal.sol";
import "./interfaces/curve/ICurveAddressProvider.sol";
// import "./interfaces/aave/IDebtToken.sol";
import "./interfaces/aave/ILendingPoolMinimal.sol";
import "./interfaces/aave/ILendingPoolAddressesProviderMinimal.sol";
import "./interfaces/aave/IProtocolDataProviderMinimal.sol";

contract StableYieldVaultBase {
    // Libraries
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Public Variables
    IERC20 public token;
    IERC20 public aToken;
    uint256 public collateralSwapMaxShareMint = 30000000000000000000; // Maxiumum 30 shares minted for swapping collateral lending position
    uint16 public referralCode = 0x0; // Referal rewards account identificaiton number.

    // Acceptable Tokens to Deposit into Aave
    mapping(address => bool) public approvedTokens;

    /***********************************|
    |     		Smart Contracts           |
    |__________________________________*/
    /**
     * @dev Aave : Dynamic addresses are used to handle deployments to multiple chains (i.e. mainnet/kovan)
     */
    ILendingPool public lendingPool;
    IProtocolDataProvider public dataProvider;
    ILendingPoolAddressesProvider public addressProvider;

    // Curve
    ICurveAddressProvider public curveAddressProvider =
        ICurveAddressProvider(0x0000000022D53366457F9d5E68Ec105046FC4383);
    ICurveRegistry public curveRegistry =
        ICurveRegistry(0x7D86446dDb609eD0F5f8684AcF30380a356b2B4c);

    /****************************************|
    |               Events                   |
    |_______________________________________*/
    // User
    event DepositCollateral(uint256 amount, uint256 shares, address user);
    event WithdrawCollateral(uint256 amount, uint256 shares, address user);

    // Vault
    event VaultCollateralSwap(
        address tokenFrom,
        address tokenTo,
        uint256 apyFrom,
        uint256 apyTo,
        uint256 feeAmount,
        address user,
        uint256 timestamp
    );

    // Curve
    event AssetSwap(
        int128 token0,
        int128 token1,
        uint256 amount0,
        uint256 amount1,
        address pool
    );

    /***********************************|
    |     		    Constructor           |
    |__________________________________*/
    /**
     * @dev Setup StableYield Smart Contracts
     */
    constructor(
        address _startingToken,
        address _addressProvider,
        address _dataProvider,
        address[] memory _approvedTokens
    ) public {
        for (uint256 i = 0; i < _approvedTokens.length; i++) {
            approvedTokens[_approvedTokens[i]] = true;
        }
        // Setup Network Smart Contracts
        addressProvider = ILendingPoolAddressesProvider(_addressProvider);
        dataProvider = IProtocolDataProvider(_dataProvider);
        lendingPool = ILendingPool(addressProvider.getLendingPool());

        // Setup Initial Token
        require(approvedTokens[_startingToken] = true, "unsupported-asset");
        token = IERC20(_startingToken);
        token.approve(address(lendingPool), type(uint256).max);
        (address aTokenAddress, , ) =
            dataProvider.getReserveTokensAddresses(address(token));
        aToken = IERC20(aTokenAddress);
    }

    /**
     * @dev Revert direct payments to the vault.
     */
    receive() external payable {
        revert("Not Payable");
    }

    /**
     * @dev Update global LendingPool reference.
     */
    function updateLendingPool() public {
        lendingPool = ILendingPool(addressProvider.getLendingPool());
    }
}
