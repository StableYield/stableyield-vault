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
}
