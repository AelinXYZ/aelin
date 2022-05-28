// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import "./MinimalProxyFactory.sol";
import "./AelinUpFrontDealFactory.sol";
import "./interfaces/IAelinUpFrontDeal.sol";
import "./AelinFeeEscrow.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ICryptoPunks.sol";
import "./libraries/NftCheck.sol";

contract AelinUpFrontDeal is AelinERC20, MinimalProxyFactory, IAelinUpFrontDeal {
    using SafeERC20 for IERC20;

    address constant CRYPTO_PUNKS = address(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);
    uint256 constant BASE = 100 * 10**18;
    uint256 constant AELIN_FEE = 2 * 10**18;

    address public purchaseToken;
    uint8 public purchaseTokenDecimals;
    address public poolFactory;

    uint256 public purchaseExpiry;
    uint256 public dealExpiry;
    uint256 public totalAmountAccepted;
    uint256 public totalAmountWithdrawn;

    bool private calledInitialize;

    address public aelinTreasuryAddress;
    address public aelinUpFrontDealLogicAddress;
    address public aelinEscrowLogicAddress;
    AelinFeeEscrow public aelinFeeEscrow;
    address public holder;
    address public futureHolder;

    address public underlyingDealToken;
    uint256 public underlyingDealTokenTotal;
    uint256 public totalUnderlyingClaimed;
    uint256 public underlyingPerDealExchangeRate;
    uint256 public holderFundingExpiry;

    uint256 public vestingCliffExpiry;
    uint256 public vestingCliffPeriod;
    uint256 public vestingPeriod;
    uint256 public vestingExpiry;

    bool public depositComplete;
    mapping(address => uint256) public amountVested;

    mapping(address => uint256) public amountWithdrawn;
    mapping(address => uint256) public allowList;
    mapping(address => NftCollectionRules) public nftCollectionDetails;
    /**
     * @dev For 721, it is used for blacklisting the tokenId of a collection
     * and for 1155, it is used for identifying the eligible tokenIds for
     * participating in the pool
     */
    mapping(address => mapping(uint256 => bool)) public nftId;
    bool public hasNftList;
    bool public hasAllowList;

    string private storedName;
    string private storedSymbol;

    /**
     * @dev the constructor will always be blank due to the MinimalProxyFactory pattern
     * this allows the underlying logic of this contract to only be deployed once
     * and each new pool created is simply a storage wrapper
     */
    constructor() {}

    function initialize(
        UpFrontDealData calldata _upFrontDealData,
        address _aelinUpFrontDealLogicAddress,
        address _aelinTreasuryAddress,
        address _aelinEscrowLogicAddress,
        address upFrontFactory
    ) external initOnce {
        require(
            30 minutes <= _upFrontDealData.purchaseDuration && 30 days >= _upFrontDealData.purchaseDuration,
            "outside purchase expiry window"
        );
        require(365 days >= _upFrontDealData.duration, "max 1 year duration");
        purchaseTokenDecimals = IERC20Decimals(_upFrontDealData.purchaseToken).decimals();
        require(purchaseTokenDecimals <= DEAL_TOKEN_DECIMALS, "too many token decimals");
        require(_upFrontDealData.holder != address(0), "cant pass null holder address");
        require(_upFrontDealData.underlyingDealToken != address(0), "cant pass null token address");
        require(1825 days >= _upFrontDealData.vestingCliffPeriod, "max 5 year cliff");
        require(1825 days >= _upFrontDealData.vestingPeriod, "max 5 year vesting");
        require(
            30 minutes <= _upFrontDealData.holderFundingDuration && 30 days >= _upFrontDealData.holderFundingDuration,
            "30 mins - 30 days for holder"
        );

        storedName = _upFrontDealData.name;
        storedSymbol = _upFrontDealData.symbol;
        poolFactory = msg.sender;

        _setNameSymbolAndDecimals(
            string(abi.encodePacked("aeUfd-", _upFrontDealData.name)),
            string(abi.encodePacked("aeU-", _upFrontDealData.symbol)),
            DEAL_TOKEN_DECIMALS
        );

        purchaseToken = _upFrontDealData.purchaseToken;
        purchaseExpiry = block.timestamp + _upFrontDealData.purchaseDuration;
        dealExpiry = purchaseExpiry + _upFrontDealData.duration;
        aelinEscrowLogicAddress = _aelinEscrowLogicAddress;
        aelinUpFrontDealLogicAddress = _aelinUpFrontDealLogicAddress;
        aelinTreasuryAddress = _aelinTreasuryAddress;

        address[] memory allowListAddresses = _upFrontDealData.allowListAddresses;
        uint256[] memory allowListAmounts = _upFrontDealData.allowListAmounts;

        if (allowListAddresses.length > 0 || allowListAmounts.length > 0) {
            require(
                allowListAddresses.length == allowListAmounts.length,
                "allowListAddresses and allowListAmounts arrays should have the same length"
            );
            for (uint256 i = 0; i < allowListAddresses.length; i++) {
                allowList[allowListAddresses[i]] = allowListAmounts[i];
                emit AllowlistAddress(allowListAddresses[i], allowListAmounts[i]);
            }
            hasAllowList = true;
        }

        NftCollectionRules[] memory nftCollectionRules = _upFrontDealData.nftCollectionRules;

        if (nftCollectionRules.length > 0) {
            // if the first address supports punks or 721, the entire pool only supports 721 or punks
            if (
                nftCollectionRules[0].collectionAddress == CRYPTO_PUNKS ||
                NftCheck.supports721(nftCollectionRules[0].collectionAddress)
            ) {
                for (uint256 i = 0; i < nftCollectionRules.length; i++) {
                    require(
                        nftCollectionRules[i].collectionAddress == CRYPTO_PUNKS ||
                            NftCheck.supports721(nftCollectionRules[i].collectionAddress),
                        "can only contain 721"
                    );
                    nftCollectionDetails[nftCollectionRules[i].collectionAddress] = nftCollectionRules[i];
                    emit PoolWith721(
                        nftCollectionRules[i].collectionAddress,
                        nftCollectionRules[i].purchaseAmount,
                        nftCollectionRules[i].purchaseAmountPerToken
                    );
                }
                hasNftList = true;
            }
            // if the first address supports 1155, the entire pool only supports 1155
            else if (NftCheck.supports1155(nftCollectionRules[0].collectionAddress)) {
                for (uint256 i = 0; i < nftCollectionRules.length; i++) {
                    require(NftCheck.supports1155(nftCollectionRules[i].collectionAddress), "can only contain 1155");
                    nftCollectionDetails[nftCollectionRules[i].collectionAddress] = nftCollectionRules[i];

                    for (uint256 j = 0; j < nftCollectionRules[i].tokenIds.length; j++) {
                        nftId[nftCollectionRules[i].collectionAddress][nftCollectionRules[i].tokenIds[j]] = true;
                    }
                    emit PoolWith1155(
                        nftCollectionRules[i].collectionAddress,
                        nftCollectionRules[i].purchaseAmount,
                        nftCollectionRules[i].purchaseAmountPerToken,
                        nftCollectionRules[i].tokenIds,
                        nftCollectionRules[i].minTokensEligible
                    );
                }
                hasNftList = true;
            } else {
                revert("collection is not compatible");
            }
        }

        holder = _upFrontDealData.holder;
        underlyingDealToken = _upFrontDealData.underlyingDealToken;
        underlyingDealTokenTotal = _upFrontDealData.underlyingDealTokenTotal;
        vestingCliffPeriod = _upFrontDealData.vestingCliffPeriod;
        vestingPeriod = _upFrontDealData.vestingPeriod;

        holderFundingExpiry = block.timestamp + _upFrontDealData.holderFundingDuration;
        vestingCliffExpiry = purchaseExpiry + vestingCliffPeriod;
        vestingExpiry = vestingCliffExpiry + vestingPeriod;

        depositComplete = false;

        /**
         * calculates the amount of underlying deal tokens you get per wrapped deal token accepted
         */
        underlyingPerDealExchangeRate = 1;
        emit SetHolder(_upFrontDealData.holder);

        // additional checks required
        if (_upFrontDealData.depositUnderlyingAmount > 0) {
            depositUnderlying(_upFrontDealData.depositUnderlyingAmount);
        }
    }

    modifier initOnce() {
        require(!calledInitialize, "can only initialize once");
        calledInitialize = true;
        _;
    }

    /**
     * @dev the holder may change their address
     */
    function setHolder(address _holder) external onlyHolder {
        futureHolder = _holder;
    }

    function acceptHolder() external {
        require(msg.sender == futureHolder, "only future holder can access");
        holder = futureHolder;
        emit SetHolder(futureHolder);
    }

    /**
     * @dev the holder finalizes the deal for the pool created by the
     * sponsor by depositing funds using this method.
     *
     * NOTE if the deposit was completed with a transfer instead of this method
     * the deposit still needs to be finalized by calling this method with
     * _underlyingDealTokenAmount set to 0
     */
    function depositUnderlying(uint256 _underlyingDealTokenAmount) public finalizeDeposit lock onlyHolder returns (bool) {
        if (_underlyingDealTokenAmount > 0) {
            uint256 currentBalance = IERC20(underlyingDealToken).balanceOf(address(this));
            IERC20(underlyingDealToken).safeTransferFrom(msg.sender, address(this), _underlyingDealTokenAmount);
            uint256 balanceAfterTransfer = IERC20(underlyingDealToken).balanceOf(address(this));
            uint256 underlyingDealTokenAmount = balanceAfterTransfer - currentBalance;

            emit DepositDealToken(underlyingDealToken, msg.sender, underlyingDealTokenAmount);
        }

        if (IERC20(underlyingDealToken).balanceOf(address(this)) >= underlyingDealTokenTotal) {
            depositComplete = true;

            address aelinEscrowStorageProxy = _cloneAsMinimalProxy(aelinEscrowLogicAddress, "Could not create new escrow");
            aelinFeeEscrow = AelinFeeEscrow(aelinEscrowStorageProxy);
            aelinFeeEscrow.initialize(aelinTreasuryAddress, underlyingDealToken);

            /*
            emit DealFullyFunded(
                aelinPool,
                proRataRedemption.start,
                proRataRedemption.expiry,
                openRedemption.start,
                openRedemption.expiry
            );
            */
            return true;
        }
        return false;
    }

    /**
     * @dev ends the purchase period when deal tokens have sold out,
     * starts vesting period, does not require holder deposit underlying deal token
     */
    function soldOut() internal returns (bool) {
        require();
    }

    modifier finalizeDeposit() {
        require(block.timestamp < holderFundingExpiry, "deposit past deadline");
        require(!depositComplete, "deposit already complete");
        _;
    }

    modifier onlyHolder() {
        require(msg.sender == holder, "only holder can access");
        _;
    }

    event AllowlistAddress(address indexed purchaser, uint256 allowlistAmount);
    event PoolWith721(address indexed collectionAddress, uint256 purchaseAmount, bool purchaseAmountPerToken);
    event PoolWith1155(
        address indexed collectionAddress,
        uint256 purchaseAmount,
        bool purchaseAmountPerToken,
        uint256[] tokenIds,
        uint256[] minTokensEligible
    );
    event DepositDealToken(
        address indexed underlyingDealTokenAddress,
        address indexed depositor,
        uint256 underlyingDealTokenAmount
    );
    event SetHolder(address indexed holder);
}
