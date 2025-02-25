//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/* Testing utilities */
import { DSTest } from "../../lib/ds-test/src/test.sol";
import { Vm } from "../../lib/forge-std/src/Vm.sol";

/* Target contract dependencies */
import { L2OutputOracle } from "../L1/L2OutputOracle.sol";
import { WithdrawalVerifier } from "../L1/libraries/Lib_WithdrawalVerifier.sol";

/* Target contract */
import { WithdrawalsRelay } from "../L1/abstracts/WithdrawalsRelay.sol";


contract Target is WithdrawalsRelay {
    constructor(L2OutputOracle _l2Oracle, uint256 _finalizationPeriod)
        WithdrawalsRelay(_l2Oracle, _finalizationPeriod)
    {}
}

contract WithdrawalsRelay_finalizeWithdrawalTransaction_Test is DSTest {
    event TransactionDeposited(
        address indexed from,
        address indexed to,
        uint256 mint,
        uint256 value,
        uint256 gasLimit,
        bool isCreation,
        bytes data
    );

    // Utilities
    Vm vm = Vm(HEVM_ADDRESS);
    bytes32 nonZeroHash = keccak256(abi.encode("NON_ZERO"));

    // Dependencies
    L2OutputOracle oracle;

    // Oracle constructor arguments
    address sequencer = 0x000000000000000000000000000000000000AbBa;
    uint256 submissionInterval = 1800;
    uint256 l2BlockTime = 2;
    bytes32 genesisL2Output = keccak256(abi.encode(0));
    uint256 historicalTotalBlocks = 100;

    // Test target
    Target wr;

    // Target constructor arguments
    address withdrawalsPredeploy = 0x4200000000000000000000000000000000000015;

    // Cache of timestamps
    uint256 startingBlockTimestamp;
    uint256 appendedTimestamp;

    // By default the first block has timestamp zero, which will cause underflows in the tests,
    // so we jump ahead to the exact time that I wrote this line.
    uint256 initTime = 1648757197;

    // Withdrawal call parameters
    uint256 wdNonce = 0;
    address wdSender = 0xDe3829A23DF1479438622a08a116E8Eb3f620BB5;
    address wdTarget = 0x1111111111111111111111111111111111111111;
    uint256 wdValue = 0;
    uint256 wdGasLimit = 50_000;
    bytes wdData =
        hex"111111111111111111111111111111111111111111111111111111111111111111111111111111111111";

    // Generate an output that we can work with. We can use whatever values we want
    // except for the withdrawerStorageRoot. This one was generated by running the withdrawer.spec.ts
    // test script against Geth.
    bytes32 version = bytes32(hex"00");
    bytes32 stateRoot = keccak256(abi.encode(1));
    bytes32 withdrawerStorageRoot =
        0xb8576230d94535779ec872748df80a094fcad002a8fc2b37c5b8fe250b384be6; // eth_getProof (storageHash)
    bytes32 latestBlockhash = keccak256(abi.encode(2));

    // This proof was generated by running
    // make devnet-up
    // Then in another terminal
    // packages/contracts/test/withdrawer.spec.ts
    // Invalid large internal hash
    bytes withdrawalProof =
        hex"f879b853f8518080a04fc5f13ab2f9ba0c2da88b0151ab0e7cf4d85d08cca45ccd923c6ab76323eb28808080808080a0fc935bb380a99df15c4aae91dacba616986d33af599d458d5388fa5fec3ac80780808080808080a3e2a036125dacbefad1d42a65c3425f7b5c8b559dac475adb31578315e77ec70a3f9701";

    // we'll set this value in the `setUp` function and cache it here for reuse in each test
    WithdrawalVerifier.OutputRootProof outputRootProof;

    constructor() {
        // Move time forward so we have a non-zero starting timestamp
        vm.warp(initTime);

        // Deploy the L2OutputOracle and transfer owernship to the sequencer
        oracle = new L2OutputOracle(
            submissionInterval,
            l2BlockTime,
            genesisL2Output,
            historicalTotalBlocks,
            initTime,
            sequencer
        );
        startingBlockTimestamp = block.timestamp;

        wr = new Target(oracle, 7 days);
    }

    function setUp() external {
        vm.warp(initTime);
        bytes32 outputRoot = keccak256(
            abi.encode(version, stateRoot, withdrawerStorageRoot, latestBlockhash)
        );

        uint256 nextTimestamp = oracle.nextTimestamp();
        // Warp to 1 second after the timestamp we'll append
        vm.warp(nextTimestamp + 1);
        vm.prank(sequencer);
        oracle.appendL2Output(outputRoot, nextTimestamp, 0, 0);

        // cache the appendedTimestamp
        appendedTimestamp = nextTimestamp;
        outputRootProof = WithdrawalVerifier.OutputRootProof({
            version: version,
            stateRoot: stateRoot,
            withdrawerStorageRoot: withdrawerStorageRoot,
            latestBlockhash: latestBlockhash
        });
    }

    function test_verifyWithdrawal() external {
        // Warp to after the finality window
        vm.warp(appendedTimestamp + 7 days);
        wr.finalizeWithdrawalTransaction(
            wdNonce,
            wdSender,
            wdTarget,
            wdValue,
            wdGasLimit,
            wdData,
            appendedTimestamp,
            outputRootProof,
            withdrawalProof
        );
    }

    function test_cannotVerifyRecentWithdrawal() external {
        // This call should fail because the output root we're using was appended 1 second ago.
        vm.expectRevert(abi.encodeWithSignature("NotYetFinal()"));
        wr.finalizeWithdrawalTransaction(
            wdNonce,
            wdSender,
            wdTarget,
            wdValue,
            wdGasLimit,
            wdData,
            appendedTimestamp,
            outputRootProof,
            hex"ffff"
        );
    }

    function test_cannotVerifyInvalidProof() external {
        // This call should fail because the output proof is modified
        vm.warp(appendedTimestamp + 7 days);
        vm.expectRevert(abi.encodeWithSignature("InvalidOutputRootProof()"));
        WithdrawalVerifier.OutputRootProof memory invalidOutpuRootProof = outputRootProof;
        invalidOutpuRootProof.latestBlockhash = 0;
        wr.finalizeWithdrawalTransaction(
            wdNonce,
            wdSender,
            wdTarget,
            wdValue,
            wdGasLimit,
            wdData,
            appendedTimestamp,
            invalidOutpuRootProof,
            hex"ffff"
        );
    }
}
