pragma solidity ^0.6.0;

/**
 * @title ICurveAddressProvider
 * @notice Interface for the Curve Address Provider
 * @dev implement interface to interact with the Curve address provider.
 **/
interface ICurveAddressProvider {
    function get_registry() external returns (address);
}
