pragma solidity =0.6.10;

interface IDSProxy {
    function execute(address _target, bytes calldata _data)
        external
        payable
        returns (bytes32 response);
}
