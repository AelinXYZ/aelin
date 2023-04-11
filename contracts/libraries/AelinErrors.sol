// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

/**
 * @dev Reverts if `condition` is false, with a revert reason containing `errorCode`. Only codes up to 999 are
 * supported.
 */
function _require(bool condition, uint256 errorCode) pure {
    if (!condition) _revert(errorCode);
}

/**
 * @dev Reverts with a revert reason containing `errorCode`. Only codes up to 999 are supported.
 */
function _revert(uint256 errorCode) pure {
    // We're going to dynamically create a revert string based on the error code, with the following format:
    // 'AELIN#{errorCode}'
    // where the code is left-padded with zeroes to three digits (so they range from 000 to 999).
    //
    // We don't have revert strings embedded in the contract to save bytecode size: it takes much less space to store a
    // number (8 to 16 bits) than the individual string characters.
    //
    // The dynamic string creation algorithm that follows could be implemented in Solidity, but assembly allows for a
    // much denser implementation, again saving bytecode size. Given this function unconditionally reverts, this is a
    // safe place to rely on it without worrying about how its usage might affect e.g. memory contents.
    assembly {
        // First, we need to compute the ASCII representation of the error code. We assume that it is in the 0-999
        // range, so we only need to convert three digits. To convert the digits to ASCII, we add 0x30, the value for
        // the '0' character.

        let units := add(mod(errorCode, 10), 0x30)

        errorCode := div(errorCode, 10)
        let tenths := add(mod(errorCode, 10), 0x30)

        errorCode := div(errorCode, 10)
        let hundreds := add(mod(errorCode, 10), 0x30)

        // With the individual characters, we can now construct the full string. The "BAL#" part is a known constant
        // (0x41454c494e23): we simply shift this by 24 (to provide space for the 3 bytes of the error code), and add the
        // characters to it, each shifted by a multiple of 8.
        // The revert reason is then shifted left by 184 bits (256 minus the length of the string, 9 characters * 8 bits
        // per character = 72) to locate it in the most significant part of the 256 slot (the beginning of a byte
        // array).

        let revertReason := shl(184, add(0x41454c494e23000000, add(add(units, shl(8, tenths)), shl(16, hundreds))))

        // We can now encode the reason in memory, which can be safely overwritten as we're about to revert. The encoded
        // message will have the following layout:
        // [ revert reason identifier ] [ string location offset ] [ string length ] [ string contents ]

        // The Solidity revert reason identifier is 0x08c739a0, the function selector of the Error(string) function. We
        // also write zeroes to the next 28 bytes of memory, but those are about to be overwritten.
        mstore(0x0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        // Next is the offset to the location of the string, which will be placed immediately after (20 bytes away).
        mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
        // The string length is fixed: 9 characters.
        mstore(0x24, 9)
        // Finally, the string itself is stored.
        mstore(0x44, revertReason)

        // Even if the string is only 7 bytes long, we need to return a full 32 byte slot containing it. The length of
        // the encoded message is therefore 4 + 32 + 32 + 32 = 100.
        revert(0, 100)
    }
}

library Errors {
    // TODO: Define ranges and improve naming
    uint256 internal constant POOL_DOESNT_EXIST = 100;
    uint256 internal constant ALLOWLIST_AND_NFT_NOT_ALLOWED = 100;
    uint256 internal constant ALLOWLIST_AND_MERKLE_NOT_ALLOWED = 100;
    uint256 internal constant NFT_AND_MERKLE_NOT_ALLOWED = 100;

    uint256 internal constant SCHEDULE_DOESNT_EXIST = 100;

    uint256 internal constant IPFS_HASH_NEEDED = 100;
    uint256 internal constant INVALID_HOLDER = 100;
    uint256 internal constant INVALID_REWARD_TOKEN = 100;
    uint256 internal constant ONLY_OWNER = 100;
    uint256 internal constant ONLY_HOLDER = 100;
    uint256 internal constant NULL_ADDRESS_NOT_ALLOWED = 100;

    uint256 internal constant DEPOSIT_FINILIZED = 100;
    uint256 internal constant NO_LP_TOKENS = 100;

    uint256 internal constant NOT_ENOUGH_BALANCE = 100;
    uint256 internal constant BALANCE_TOO_LOW = 100;
    uint256 internal constant MORE_THAN_ALLOWATION = 100;
    uint256 internal constant MUST_PASS_AMOUNT = 100;

    uint256 internal constant BASE_ALREADY_DEPOSITED = 100;

    uint256 internal constant NEW_LIQUIDITY_ONLY = 100;
    uint256 internal constant EXISTING_LIQUIDITY_ONLY = 100;

    uint256 internal constant TOO_MANY_VESTING_PERIODS = 100;
    uint256 internal constant TOO_MANY_SINGLE_REWARDS = 100;
    uint256 internal constant VESTING_CLIFF_TOO_LONG = 100;
    uint256 internal constant VESTING_PERIOD_TOO_LONG = 100;

    uint256 internal constant ALLOCATE_TOKENS = 100;
    uint256 internal constant CLAIMED_START_NOT_ZERO = 100;
    uint256 internal constant MAX_SHARE_INVESTOR = 100;
    uint256 internal constant MIN_SHARE_INVESTOR = 100;

    uint256 internal constant REWARDS_TOKEN_NEEDED = 100;
    uint256 internal constant AMOUNT_CLAIMENT_NOT_ZERO = 100;

    uint256 internal constant INIT_ONLY_ONCE = 100;
    uint256 internal constant DEPOSIT_COMPLETED = 100;
    uint256 internal constant DEAL_NOT_CANCELLED = 100;
    uint256 internal constant DEAL_CANCELLED = 100;

    uint256 internal constant NOT_FUNDING_WINDOW = 100;
    uint256 internal constant NOT_DEPOSIT_WINDOW = 100;
    uint256 internal constant NOT_WITHDRAW_WINDOW = 100;

    uint256 internal constant PURCHASE_MORE_THAN_TOTAL = 100;
    uint256 internal constant LOCKED = 100;
}
