// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// Inheritance
import "./Owned.sol";

// Internal references
import "./interfaces/IOwnerRelayOnOptimism.sol";
import "@eth-optimism/contracts/iOVM/bridge/messaging/iAbs_BaseCrossDomainMessenger.sol";

contract OwnerRelayOnEthereum is Owned {
    address public MESSENGER;
    address public CONTRACT_OVM_OWNER_RELAY_ON_OPTIMISM;

    // ========== CONSTRUCTOR ==========
    constructor(address _owner) Owned(_owner) {}

    function setContractData(address _messenger, address _relayOnOptimism)
        external
        onlyOwner
    {
        MESSENGER = _messenger;
        CONTRACT_OVM_OWNER_RELAY_ON_OPTIMISM = _relayOnOptimism;
    }

    /* ========== INTERNALS ============ */

    function _messenger() private view returns (iAbs_BaseCrossDomainMessenger) {
        return iAbs_BaseCrossDomainMessenger(MESSENGER);
    }

    function _getCrossDomainGasLimit(uint32 crossDomainGasLimit)
        private
        view
        returns (uint32)
    {
        // Use specified crossDomainGasLimit if specified value is not zero.
        // otherwise use the default in SystemSettings.
        return
            crossDomainGasLimit != 0
                ? crossDomainGasLimit
                : uint32(
                    getCrossDomainMessageGasLimit(
                        CrossDomainMessageGasLimits.Relay
                    )
                );
    }

    /* ========== RESTRICTED ========== */

    function initiateRelay(
        address target,
        bytes calldata payload,
        uint32 crossDomainGasLimit // If zero, uses default value in SystemSettings
    ) external onlyOwner {
        IOwnerRelayOnOptimism ownerRelayOnOptimism;
        bytes memory messageData = abi.encodeWithSelector(
            ownerRelayOnOptimism.finalizeRelay.selector,
            target,
            payload
        );

        _messenger().sendMessage(
            CONTRACT_OVM_OWNER_RELAY_ON_OPTIMISM,
            messageData,
            _getCrossDomainGasLimit(crossDomainGasLimit)
        );

        emit RelayInitiated(target, payload);
    }

    function initiateRelayBatch(
        address[] calldata targets,
        bytes[] calldata payloads,
        uint32 crossDomainGasLimit // If zero, uses default value in SystemSettings
    ) external onlyOwner {
        // First check that the length of the arguments match
        require(targets.length == payloads.length, "Argument length mismatch");

        IOwnerRelayOnOptimism ownerRelayOnOptimism;
        bytes memory messageData = abi.encodeWithSelector(
            ownerRelayOnOptimism.finalizeRelayBatch.selector,
            targets,
            payloads
        );

        _messenger().sendMessage(
            CONTRACT_OVM_OWNER_RELAY_ON_OPTIMISM,
            messageData,
            _getCrossDomainGasLimit(crossDomainGasLimit)
        );

        emit RelayBatchInitiated(targets, payloads);
    }

    /* ========== EVENTS ========== */

    event RelayInitiated(address target, bytes payload);
    event RelayBatchInitiated(address[] targets, bytes[] payloads);
}
