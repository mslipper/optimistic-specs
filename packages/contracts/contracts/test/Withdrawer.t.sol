//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import { DSTest } from "../../lib/ds-test/src/test.sol";
import { Vm } from "../../lib/forge-std/src/Vm.sol";
import { Withdrawer } from "../L2/Withdrawer.sol";

import {
    AddressAliasHelper
} from "../../lib/optimism/packages/contracts/contracts/standards/AddressAliasHelper.sol";
import {
    Lib_RLPWriter
} from "../../lib/optimism/packages/contracts/contracts/libraries/rlp/Lib_RLPWriter.sol";
import {
    Lib_Bytes32Utils
} from "../../lib/optimism/packages/contracts/contracts/libraries/utils/Lib_Bytes32Utils.sol";


contract WithdrawerTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);
    address immutable ZERO_ADDRESS = address(0);
    address immutable NON_ZERO_ADDRESS = address(1);
    uint256 immutable NON_ZERO_VALUE = 100;
    uint256 immutable ZERO_VALUE = 0;
    uint256 immutable NON_ZERO_GASLIMIT = 50000;
    bytes NON_ZERO_DATA = hex"1111";

    event WithdrawalInitiated(
        uint256 indexed nonce,
        address indexed sender,
        address indexed target,
        uint256 value,
        uint256 gasLimit,
        bytes data
    );

    Withdrawer wd;

    function setUp() public virtual {
        wd = new Withdrawer();
    }

    // burn test

    // Test: initiateWithdrawal should emit the correct log when called by a contract
    function test_initiateWithdrawal_fromContract() external {
        vm.expectEmit(true, true, true, true);
        emit WithdrawalInitiated(
            0,
            AddressAliasHelper.undoL1ToL2Alias(address(this)),
            NON_ZERO_ADDRESS,
            NON_ZERO_VALUE,
            NON_ZERO_GASLIMIT,
            NON_ZERO_DATA
        );

        wd.initiateWithdrawal{ value: NON_ZERO_VALUE }(
            NON_ZERO_ADDRESS,
            NON_ZERO_GASLIMIT,
            NON_ZERO_DATA
        );
    }

    // Test: initiateWithdrawal should emit the correct log when called by an EOA
    function test_initiateWithdrawal_fromEOA() external {
        // EOA emulation
        vm.prank(address(this), address(this));
        vm.expectEmit(true, true, true, true);
        emit WithdrawalInitiated(
            0,
            address(this),
            NON_ZERO_ADDRESS,
            NON_ZERO_VALUE,
            NON_ZERO_GASLIMIT,
            NON_ZERO_DATA
        );

        wd.initiateWithdrawal{ value: NON_ZERO_VALUE }(
            NON_ZERO_ADDRESS,
            NON_ZERO_GASLIMIT,
            NON_ZERO_DATA
        );
    }
}

contract WithdawerBurnTest is WithdrawerTest {

    function setUp() public override {
        // fund a new withdrawer
        super.setUp();
        wd.initiateWithdrawal{ value: NON_ZERO_VALUE }(
            NON_ZERO_ADDRESS,
            NON_ZERO_GASLIMIT,
            NON_ZERO_DATA
        );
    }

    // Test: burn should destroy the ETH held in the contract
    function test_burn() external {
        // Sanity check that setUp worked as expected.
        assertEq(address(wd).balance, NON_ZERO_VALUE);

        wd.burn();

        // Calculate the address of the contract that will selfdestruct at the end of this tx.
        // Based on https://github.com/ethereum-optimism/contracts/blob/532b9a743cf34d66e812cbf1d9f28c452b52e1bd/contracts/optimistic-ethereum/libraries/utils/Lib_EthUtils.sol#L145
        bytes[] memory encoded = new bytes[](2);
        encoded[0] = Lib_RLPWriter.writeAddress(address(wd)); // creator
        encoded[1] = Lib_RLPWriter.writeUint(0); // nonce
        bytes memory encodedList = Lib_RLPWriter.writeList(encoded);
        address created = Lib_Bytes32Utils.toAddress(keccak256(encodedList));

        // The Withdrawer should have no balance
        assertEq(address(wd).balance, 0);

        // The created contract should have its balance
        assertEq(created.balance, NON_ZERO_VALUE);

    }

}
