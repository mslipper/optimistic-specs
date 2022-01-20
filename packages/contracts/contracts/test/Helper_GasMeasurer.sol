// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import 'hardhat/console.sol';

contract HelperGasMeasurer {
    function measureCallGas(address _target, bytes memory _data)
        external
        payable
        returns (uint256)
    {
        uint256 gasBefore;
        uint256 gasAfter;

        uint256 calldataStart;
        uint256 calldataLength;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldataStart := add(_data, 0x20)
            calldataLength := mload(_data)
        }
        bool success;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            gasBefore := gas()
            success := call(gas(), _target, callvalue(), calldataStart, calldataLength, 0, 0)
            gasAfter := gas()
        }
        require(success, "Call failed, but calls we want to measure gas for should succeed!");

        return gasBefore - gasAfter;
    }
}
