// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

// Inheritance
import "./LegacyOwned.sol";

// Internal references
import "./interfaces/IOwnerRelayOnOptimism.sol";
import "@eth-optimism/contracts/iOVM/bridge/messaging/iAbs_BaseCrossDomainMessenger.sol";

contract OwnerRelayOnEthereum is LegacyOwned {
    address public MESSENGER;
    address public CONTRACT_OVM_OWNER_RELAY_ON_OPTIMISM;
    uint32 public constant MAX_CROSS_DOMAIN_GAS_LIMIT = 8e6;

    // ========== CONSTRUCTOR ==========
    constructor(
        address _owner,
        address _messengerAddress,
        address _relayOnOptimism
    ) public LegacyOwned(_owner) {
        MESSENGER = _messengerAddress;
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
                : MAX_CROSS_DOMAIN_GAS_LIMIT;
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
