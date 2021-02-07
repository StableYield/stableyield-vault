pragma solidity ^0.6.0;

/**
 * @title ICurveRegistry
 * @notice Interface for the Curve Registry
 * @dev implement interface to interact with the Curve protocol.
 **/
interface ICurveRegistry {
    function find_pool_for_coins(address _from, address _to)
        external
        view
        returns (address);

    function find_pool_for_coins(
        address _from,
        address _to,
        uint256 i
    ) external view returns (address);

    function get_n_coins(address _pool)
        external
        view
        returns (uint256[] memory);

    function get_coins(address _pool) external view returns (address[] memory);

    function get_underlying_coins(address _pool)
        external
        view
        returns (address[] memory);

    function get_decimals(address _pool)
        external
        view
        returns (address[] memory);

    function get_underlying_decimals(address _pool)
        external
        view
        returns (uint256[] memory);

    function get_rates(address _pool) external view returns (uint256[] memory);

    function get_gauges(address _pool)
        external
        view
        returns (address[] memory, int128[] memory);

    function get_balances(address _pool)
        external
        view
        returns (uint256[] memory);

    function get_underlying_balances(address _pool)
        external
        view
        returns (uint256[] memory);

    function get_virtual_price_from_lp_token(address _token)
        external
        view
        returns (uint256);

    function get_A(address _pool) external view returns (uint256);

    function get_parameters(address _pool)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            uint256,
            uint256,
            uint256
        );

    function get_fees(address _pool) external view returns (uint256[] memory);

    function get_admin_balances(address _pool)
        external
        view
        returns (uint256[] memory);

    function get_coin_indices(
        address _pool,
        address _from,
        address _to
    )
        external
        view
        returns (
            uint256,
            uint256,
            bool
        );

    function estimated_gas_used(
        address _from,
        address _to,
        uint256 i
    ) external view returns (uint256);

    function address_provider() external view returns (address);

    function gauge_controller() external view returns (address);

    function pool_list(address arg0) external view returns (address);

    function pool_count() external view returns (uint256);

    function get_pool_from_lp_token(address arg0)
        external
        view
        returns (address);

    function get_lp_token(address arg0) external view returns (address);
}
