pragma solidity =0.6.10;

import "./IDSProxy.sol";

interface IDSProxyFactory {
    event Created(
        address indexed sender,
        address indexed owner,
        address proxy,
        address cache
    );

    function isProxy(address proxy) external returns (bool);

    function build() external returns (IDSProxy proxy);

    function build(address owner) external returns (IDSProxy proxy);
}

interface IDSProxyCache {
    // mapping(bytes32 => address) cache;

    function read(bytes calldata _code) external view returns (address);

    function write(bytes calldata _code) external returns (address target);
}
