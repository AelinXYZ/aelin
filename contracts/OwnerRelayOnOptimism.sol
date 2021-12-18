// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// Inheritance
import "./TemporarilyOwned.sol";
import "./interfaces/IOwnerRelayOnOptimism.sol";

// Internal references
import "@eth-optimism/contracts/iOVM/bridge/messaging/iAbs_BaseCrossDomainMessenger.sol";

contract OwnerRelayOnOptimism is TemporarilyOwned, IOwnerRelayOnOptimism {
    address public immutable MESSENGER;
    address public immutable CONTRACT_BASE_OWNER_RELAY_ON_ETHEREUM;

    /* ========== CONSTRUCTOR ============ */

    constructor(address _temporaryOwner, uint256 _ownershipDuration)
        TemporarilyOwned(_temporaryOwner, _ownershipDuration)
    {}

    function setContractData(address _messenger, address _relayOnEthereum)
        external
        onlyTemporaryOwner
    {
        MESSENGER = _messenger;
        CONTRACT_BASE_OWNER_RELAY_ON_ETHEREUM = _relayOnEthereum;
    }

    /* ========== INTERNALS ============ */

    function _messenger() private view returns (iAbs_BaseCrossDomainMessenger) {
        return iAbs_BaseCrossDomainMessenger(MESSENGER);
    }

    function _relayCall(address target, bytes memory payload) private {
        // solhint-disable avoid-low-level-calls
        (bool success, bytes memory result) = target.call(payload);

        require(success, string(abi.encode("xChain call failed:", result)));
    }

    function _onlyAllowMessengerAndL1Relayer() internal view {
        iAbs_BaseCrossDomainMessenger messenger = _messenger();

        require(
            msg.sender == address(messenger),
            "Sender is not the messenger"
        );
        require(
            messenger.xDomainMessageSender() ==
                CONTRACT_BASE_OWNER_RELAY_ON_ETHEREUM,
            "L1 sender is not the owner relay"
        );
    }

    modifier onlyMessengerAndL1Relayer() {
        _onlyAllowMessengerAndL1Relayer();
        _;
    }

    /* ========== EXTERNAL ========== */

    function directRelay(address target, bytes calldata payload)
        external
        onlyTemporaryOwner
    {
        _relayCall(target, payload);

        emit DirectRelay(target, payload);
    }

    function finalizeRelay(address target, bytes calldata payload)
        external
        onlyMessengerAndL1Relayer
    {
        _relayCall(target, payload);

        emit RelayFinalized(target, payload);
    }

    function finalizeRelayBatch(
        address[] calldata targets,
        bytes[] calldata payloads
    ) external onlyMessengerAndL1Relayer {
        for (uint256 i = 0; i < targets.length; i++) {
            _relayCall(targets[i], payloads[i]);
        }

        emit RelayBatchFinalized(targets, payloads);
    }

    /* ========== EVENTS ========== */

    event DirectRelay(address target, bytes payload);
    event RelayFinalized(address target, bytes payload);
    event RelayBatchFinalized(address[] targets, bytes[] payloads);
}
