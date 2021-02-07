pragma solidity ^0.6.0;

/**
 * @title IStableSwap
 * @notice Interface for the Curve Finance Stable Swap
 * @dev implement interface to interact with the Curve protocol.
 **/
interface IStableSwap {
    function get_virtual_price() external view returns (uint256);

    function calc_token_amount(uint256[] calldata amounts, bool deposit)
        external
        view
        returns (uint256);

    function add_liquidity(uint256[] calldata amounts, bool min_mint_amount)
        external
        returns (uint256);

    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function get_dx(
        int128 i,
        int128 j,
        uint256 dy
    ) external view returns (uint256);

    function get_dy_underlying(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function get_dx_underlying(
        int128 i,
        int128 j,
        uint256 dy
    ) external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dep
    ) external;

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external;

    function remove_liquidity(uint256 _amount, uint256[] calldata min_amounts)
        external;
}
