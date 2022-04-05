//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/* Library Imports */
import {
    AddressAliasHelper
} from "../../lib/optimism/packages/contracts/contracts/standards/AddressAliasHelper.sol";


/**
 * @title Withdrawer
 * @notice The Withdrawer contract facilitates sending both ETH value and data from L2 to L1.
 * It is predeployed in the L2 state at address 0x4200000000000000000000000000000000000015.
 */
contract Withdrawer {
    /// @notice A unique value hashed with each withdrawal.
    uint256 public nonce;

    /// @notice A mapping listing withdrawals which have been initiated herein.
    mapping(bytes32 => bool) public withdrawals;

    /**
     * @notice Emitted any time a withdrawal is initiated.
     * @param nonce Unique value corresponding to each withdrawal.
     * @param sender The L2 account address which initiated the withdrawal.
     * @param target The L1 account address the call will be send to.
     * @param value The ETH value submitted for withdrawal, to be forwarded to the target.
     * @param gasLimit The minimum amount of gas that must be provided when withdrawing on L1.
     * @param data The data to be forwarded to the target on L1.
     */
    event WithdrawalInitiated(
        uint256 indexed nonce,
        address indexed sender,
        address indexed target,
        uint256 value,
        uint256 gasLimit,
        bytes data
    );

    /**
     * @notice Initiates a withdrawal to execute on L1.
     * @param _target Address to call on L1 execution.
     * @param _gasLimit GasLimit to provide on L1.
     * @param _data Data to forward to L1 target.
     */
    function initiateWithdrawal(
        address _target,
        uint256 _gasLimit,
        bytes calldata _data
    ) external payable {

        address from = msg.sender;
        // Transform the from-address to its L1 alias if the caller is a contract.
        if (msg.sender != tx.origin) {
            from = AddressAliasHelper.undoL1ToL2Alias(msg.sender);
        }
        bytes32 withdrawalHash = keccak256(
            abi.encode(nonce, msg.sender, _target, msg.value, _gasLimit, _data)
        );
        withdrawals[withdrawalHash] = true;
        nonce++;

        emit WithdrawalInitiated(nonce, msg.sender, _target, msg.value, _gasLimit, _data);
    }

    /**
     * @notice Removes all ETH held in this contract from the state, by deploying a contract which
     * immediately self destructs.
     * For simplicity, this call is not incentivized as it costs very little to run.
     * Inspired by https://etherscan.io/address/0xb69fba56b2e67e7dda61c8aa057886a8d1468575#code
     */
    function burn() external {
        assembly {
            // Put this code into memory at the scratch space (first word).
            // 30 - address(this)
            // ff - selfdestruct
            mstore(0, 0x30ff)

            // Transfer all funds to a new contract that will selfdestruct
            // and destroy all the ether it holds in the process.
            pop(
                create(
                    balance(address()), // Fund the new contract with the balance of this one.
                    30, // offset
                    2 // size
                )
            )
        }
    }
}
