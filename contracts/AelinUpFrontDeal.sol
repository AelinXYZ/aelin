// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./AelinERC20.sol";
import "./MinimalProxyFactory.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AelinDeal} from "./AelinDeal.sol";
import {AelinPool} from "./AelinPool.sol";
import {AelinFeeEscrow} from "./AelinFeeEscrow.sol";
import {IAelinUpFrontDeal} from "./interfaces/IAelinUpFrontDeal.sol";
import "./libraries/AelinNftGating.sol";
import "./libraries/AelinAllowList.sol";

contract AelinUpFrontDeal is AelinERC20, MinimalProxyFactory, IAelinUpFrontDeal {
    using SafeERC20 for IERC20;

    uint256 constant BASE = 100 * 10**18;
    uint256 constant MAX_SPONSOR_FEE = 15 * 10**18;
    uint256 constant AELIN_FEE = 2 * 10**18;

    UpFrontDealData public dealData;
    UpFrontDealConfig public dealConfig;

    address public aelinTreasuryAddress;
    address public aelinEscrowLogicAddress;
    AelinFeeEscrow public aelinFeeEscrow;
    address public dealFactory;

    bool private calledInitialize;
    address public futureHolder;

    AelinAllowList.AllowList public allowList;
    AelinNftGating.NftGatingData public nftGating;
    mapping(address => uint256) public purchaseTokensPerUser;
    mapping(address => uint256) public poolSharesPerUser;
    mapping(address => uint256) public amountVested;

    uint256 public totalPurchasingAccepted;
    uint256 public totalPoolShares;
    uint256 public totalUnderlyingClaimed;

    bool private underlyingDepositComplete;
    bool private holderClaimed;
    bool private feeEscrowClaimed;

    uint256 public dealStart;
    uint256 public purchaseExpiry;
    uint256 public vestingCliffExpiry;
    uint256 public vestingExpiry;

    function initialize(
        UpFrontDealData calldata _dealData,
        UpFrontDealConfig calldata _dealConfig,
        AelinNftGating.NftCollectionRules[] calldata _nftCollectionRules,
        AelinAllowList.InitData calldata _allowListInit,
        address _dealCreator,
        address _aelinTreasuryAddress,
        address _aelinEscrowLogicAddress
    ) external initOnce {
        // pool initialization checks
        require(_dealData.purchaseToken != address(0), "cant pass null purchase token address");
        require(_dealData.underlyingDealToken != address(0), "cant pass null underlying token address");
        require(_dealData.holder != address(0), "cant pass null holder address");

        require(_dealConfig.purchaseDuration >= 30 minutes && _dealConfig.purchaseDuration <= 30 days, "not within limit");
        require(_dealData.sponsorFee <= MAX_SPONSOR_FEE, "exceeds max sponsor fee");

        uint8 purchaseTokenDecimals = IERC20Decimals(_dealData.purchaseToken).decimals();
        require(purchaseTokenDecimals <= DEAL_TOKEN_DECIMALS, "purchase token not compatible");

        require(1825 days >= _dealConfig.vestingCliffPeriod, "max 5 year cliff");
        require(1825 days >= _dealConfig.vestingPeriod, "max 5 year vesting");

        require(_dealConfig.underlyingDealTokenTotal > 0, "must have nonzero deal tokens");
        require(_dealConfig.purchaseTokenPerDealToken > 0, "invalid deal price");

        uint8 underlyingTokenDecimals = IERC20Decimals(_dealData.underlyingDealToken).decimals();
        if (_dealConfig.purchaseRaiseMinimum > 0) {
            uint256 _totalIntendedRaise = (_dealConfig.purchaseTokenPerDealToken * _dealConfig.underlyingDealTokenTotal) /
                10**underlyingTokenDecimals;
            require(_totalIntendedRaise > 0, "intended raise too small");
            require(_dealConfig.purchaseRaiseMinimum <= _totalIntendedRaise, "raise minimum is greater than deal total");
        }

        // store pool and deal details as state variables
        dealData = _dealData;
        dealConfig = _dealConfig;
        dealStart = block.timestamp;

        dealFactory = msg.sender;

        // the deal token has the same amount of decimals as the underlying deal token,
        // eventually making them 1:1 redeemable
        _setNameSymbolAndDecimals(
            string(abi.encodePacked("aeUpFrontDeal-", _dealData.name)),
            string(abi.encodePacked("aeUD-", _dealData.symbol)),
            underlyingTokenDecimals
        );

        aelinEscrowLogicAddress = _aelinEscrowLogicAddress;
        aelinTreasuryAddress = _aelinTreasuryAddress;

        // Allow list logic
        // check if there's allowlist and amounts,
        // if yes, store it to `allowList` and emit a single event with the addresses and amounts
        AelinAllowList.initialize(_allowListInit, allowList);

        // NftCollection logic
        // check if the deal is nft gated
        // if yes, store it in `nftCollectionDetails` and `nftId` and emit respective events for 721 and 1155
        AelinNftGating.initialize(_nftCollectionRules, nftGating);

        // deposit underlying token logic
        // check if the underlying token balance is more than 0, meaning the factory contract passed tokens from the creator
        if (IERC20(_dealData.underlyingDealToken).balanceOf(address(this)) > 0) {
            uint256 currentDealTokenTotal = IERC20(_dealData.underlyingDealToken).balanceOf(address(this));
            if (currentDealTokenTotal >= _dealConfig.underlyingDealTokenTotal) {
                underlyingDepositComplete = true;
                purchaseExpiry = block.timestamp + dealConfig.purchaseDuration;
                vestingCliffExpiry = purchaseExpiry + dealConfig.vestingCliffPeriod;
                vestingExpiry = vestingCliffExpiry + dealConfig.vestingPeriod;
                emit DealFullyFunded(address(this), block.timestamp, purchaseExpiry, vestingCliffExpiry, vestingExpiry);
            }

            emit DepositDealToken(_dealData.underlyingDealToken, _dealCreator, currentDealTokenTotal);
        }
    }

    modifier initOnce() {
        require(!calledInitialize, "can only initialize once");
        calledInitialize = true;
        _;
    }

    /**
     * @dev method for holder to deposit underlying deal tokens
     * all underlying deal tokens must be deposited for the purchasing period to start
     * if tokens were deposited directly, this method must still be called to start the purchasing period
     */
    function depositUnderlyingTokens(uint256 _depositUnderlyingAmount) public onlyHolder {
        UpFrontDealData memory _dealData = dealData;
        UpFrontDealConfig memory _dealConfig = dealConfig;

        require(
            IERC20(_dealData.underlyingDealToken).balanceOf(msg.sender) >= _depositUnderlyingAmount,
            "not enough balance"
        );
        require(!underlyingDepositComplete, "already deposited the total");

        uint256 balanceBeforeTransfer = IERC20(_dealData.underlyingDealToken).balanceOf(address(this));
        IERC20(_dealData.underlyingDealToken).safeTransferFrom(msg.sender, address(this), _depositUnderlyingAmount);
        uint256 balanceAfterTransfer = IERC20(_dealData.underlyingDealToken).balanceOf(address(this));
        uint256 underlyingDealTokenAmount = balanceAfterTransfer - balanceBeforeTransfer;

        if (balanceAfterTransfer >= _dealConfig.underlyingDealTokenTotal) {
            underlyingDepositComplete = true;
            purchaseExpiry = block.timestamp + _dealConfig.purchaseDuration;
            vestingCliffExpiry = purchaseExpiry + _dealConfig.vestingCliffPeriod;
            vestingExpiry = vestingCliffExpiry + _dealConfig.vestingPeriod;
            emit DealFullyFunded(address(this), block.timestamp, purchaseExpiry, vestingCliffExpiry, vestingExpiry);
        }

        emit DepositDealToken(_dealData.underlyingDealToken, msg.sender, underlyingDealTokenAmount);
    }

    /**
     * @dev allows holder to withdraw any excess underlying deal tokens deposited to the contract
     */
    function withdrawExcess() external onlyHolder {
        UpFrontDealData memory _dealData = dealData;
        UpFrontDealConfig memory _dealConfig = dealConfig;
        uint256 currentBalance = IERC20(_dealData.underlyingDealToken).balanceOf(address(this));
        require(currentBalance > _dealConfig.underlyingDealTokenTotal, "no excess to withdraw");

        uint256 excessAmount = currentBalance - _dealConfig.underlyingDealTokenTotal;
        IERC20(_dealData.underlyingDealToken).safeTransfer(msg.sender, excessAmount);

        emit WithdrewExcess(address(this), excessAmount);
    }

    /**
     * @dev accept deal by depositing purchasing tokens which is converted to a mapping which stores the amount of
     * underlying purchased. pool shares have the same decimals as the underlying deal token
     */
    function acceptDeal(AelinNftGating.NftPurchaseList[] calldata _nftPurchaseList, uint256 _purchaseTokenAmount)
        external
        lock
    {
        UpFrontDealData memory _dealData = dealData;
        UpFrontDealConfig memory _dealConfig = dealConfig;
        require(underlyingDepositComplete, "deal token not yet deposited");
        require(block.timestamp < purchaseExpiry, "not in purchase window");
        require(IERC20(_dealData.purchaseToken).balanceOf(msg.sender) >= _purchaseTokenAmount, "not enough purchaseToken");
        uint256 purchaseTokenAmount;

        if (_nftPurchaseList.length > 0) {
            purchaseTokenAmount = AelinNftGating.purchaseDealTokensWithNft(
                _nftPurchaseList,
                nftGating,
                _purchaseTokenAmount
            );
        } else if (allowList.hasAllowList) {
            require(_purchaseTokenAmount <= allowList.amountPerAddress[msg.sender], "more than allocation");
            allowList.amountPerAddress[msg.sender] -= _purchaseTokenAmount;
        }
        uint256 balanceBeforeTransfer = IERC20(_dealData.purchaseToken).balanceOf(address(this));
        IERC20(_dealData.purchaseToken).safeTransferFrom(msg.sender, address(this), _purchaseTokenAmount);
        uint256 balanceAfterTransfer = IERC20(_dealData.purchaseToken).balanceOf(address(this));
        purchaseTokenAmount = balanceAfterTransfer - balanceBeforeTransfer;

        totalPurchasingAccepted += purchaseTokenAmount;
        purchaseTokensPerUser[msg.sender] += purchaseTokenAmount;

        uint8 underlyingTokenDecimals = IERC20Decimals(_dealData.underlyingDealToken).decimals();
        uint256 poolSharesAmount;

        // this takes into account the decimal conversion between purchasing token and underlying deal token
        // pool shares having the same amount of decimals as underlying deal tokens
        poolSharesAmount = (purchaseTokenAmount * 10**underlyingTokenDecimals) / _dealConfig.purchaseTokenPerDealToken;
        require(poolSharesAmount > 0, "purchase amount too small");

        // pool shares directly correspond to the amount of deal tokens that can be minted
        // pool shares held = deal tokens minted as long as no deallocation takes place
        totalPoolShares += poolSharesAmount;
        poolSharesPerUser[msg.sender] += poolSharesAmount;

        if (!_dealConfig.allowDeallocation) {
            require(totalPoolShares <= _dealConfig.underlyingDealTokenTotal, "purchased amount over total");
        }

        emit AcceptDeal(
            msg.sender,
            purchaseTokenAmount,
            purchaseTokensPerUser[msg.sender],
            poolSharesAmount,
            poolSharesPerUser[msg.sender]
        );
    }

    /**
     * @dev purchaser calls to claim their deal tokens or refund if the minimum raise does not pass
     */
    function purchaserClaim() public lock purchasingOver {
        UpFrontDealData memory _dealData = dealData;
        UpFrontDealConfig memory _dealConfig = dealConfig;

        require(poolSharesPerUser[msg.sender] > 0, "no pool shares to claim with");

        if (_dealConfig.purchaseRaiseMinimum == 0 || totalPurchasingAccepted > _dealConfig.purchaseRaiseMinimum) {
            // Claim Deal Tokens
            bool _deallocate = totalPoolShares > _dealConfig.underlyingDealTokenTotal;

            if (_deallocate) {
                // adjust for deallocation and mint deal tokens
                uint256 _amountOverTotal = totalPoolShares - _dealConfig.underlyingDealTokenTotal;
                uint256 _adjustedDealTokensForUser = ((BASE - AELIN_FEE - _dealData.sponsorFee) *
                    poolSharesPerUser[msg.sender] *
                    _amountOverTotal) /
                    totalPoolShares /
                    10**18;
                poolSharesPerUser[msg.sender] = 0;

                // refund any purchase tokens that got deallocated
                uint256 purchaseTokensAmount = purchaseTokensPerUser[msg.sender];
                uint256 _underlyingTokenDecimals = IERC20Decimals(_dealData.underlyingDealToken).decimals();
                uint256 _totalIntendedRaise = (_dealConfig.purchaseTokenPerDealToken *
                    _dealConfig.underlyingDealTokenTotal) / 10**_underlyingTokenDecimals;
                uint256 _amountOverRaise = totalPurchasingAccepted - _totalIntendedRaise;
                uint256 _purchasingRefund = (100 * purchaseTokensAmount * _amountOverRaise) / totalPurchasingAccepted;
                purchaseTokensPerUser[msg.sender] = 0;

                // mint deal tokens and transfer purchase token refund
                _mint(msg.sender, _adjustedDealTokensForUser);
                IERC20(_dealData.purchaseToken).safeTransfer(msg.sender, _purchasingRefund);

                emit ClaimDealTokens(msg.sender, _adjustedDealTokensForUser, _purchasingRefund);
            } else {
                // mint deal tokens when there is no deallocation
                uint256 _adjustedDealTokensForUser = ((BASE - AELIN_FEE - _dealData.sponsorFee) *
                    poolSharesPerUser[msg.sender]) / 10**18;
                poolSharesPerUser[msg.sender] = 0;
                purchaseTokensPerUser[msg.sender] = 0;
                _mint(msg.sender, _adjustedDealTokensForUser);
                emit ClaimDealTokens(msg.sender, _adjustedDealTokensForUser, 0);
            }
        } else {
            // Claim Refund
            uint256 _currentBalance = purchaseTokensPerUser[msg.sender];
            purchaseTokensPerUser[msg.sender] = 0;
            poolSharesPerUser[msg.sender] = 0;
            IERC20(_dealData.purchaseToken).safeTransfer(msg.sender, _currentBalance);
            emit ClaimDealTokens(msg.sender, 0, _currentBalance);
        }
    }

    /**
     * @dev sponsor calls once the purchasing period is over if the minimum raise has passed to claim
     * their share of deal tokens
     * NOTE also calls the claim for the protocol fee
     */
    function sponsorClaim() public lock purchasingOver passMinimumRaise onlySponsor {
        UpFrontDealData memory _dealData = dealData;
        UpFrontDealConfig memory _dealConfig = dealConfig;
        uint256 _sponsorFeeAmt = (_dealConfig.underlyingDealTokenTotal * _dealData.sponsorFee) / BASE;
        _mint(_dealData.sponsor, _sponsorFeeAmt);
        emit SponsorClaim(_dealData.sponsor, _sponsorFeeAmt);

        feeEscrowClaim();
    }

    /**
     * @dev holder calls once purchasing period is over to claim their raise or
     * underlying deal tokens if the minimum raise has not passed
     * NOTE also calls the claim for the protocol fee
     */
    function holderClaim() public lock purchasingOver onlyHolder {
        UpFrontDealData memory _dealData = dealData;
        UpFrontDealConfig memory _dealConfig = dealConfig;

        require(!holderClaimed, "holder has already claimed");

        if (_dealConfig.purchaseRaiseMinimum == 0 || totalPurchasingAccepted > _dealConfig.purchaseRaiseMinimum) {
            bool _deallocate = totalPoolShares > _dealConfig.underlyingDealTokenTotal;

            if (_deallocate) {
                uint256 _underlyingTokenDecimals = IERC20Decimals(_dealData.underlyingDealToken).decimals();
                uint256 _totalIntendedRaise = (_dealConfig.purchaseTokenPerDealToken *
                    _dealConfig.underlyingDealTokenTotal) / 10**_underlyingTokenDecimals;
                IERC20(_dealData.purchaseToken).safeTransfer(_dealData.holder, _totalIntendedRaise);
                emit HolderClaim(_dealData.holder, _dealData.purchaseToken, _totalIntendedRaise, block.timestamp);
            } else {
                // holder receives raise
                uint256 _currentBalance = IERC20(_dealData.purchaseToken).balanceOf(address(this));
                IERC20(_dealData.purchaseToken).safeTransfer(_dealData.holder, _currentBalance);
                emit HolderClaim(_dealData.holder, _dealData.purchaseToken, _currentBalance, block.timestamp);
                // holder receives any leftover underlying deal tokens
                uint256 _underlyingRefund = _dealConfig.underlyingDealTokenTotal - totalPoolShares;
                IERC20(_dealData.underlyingDealToken).safeTransfer(_dealData.holder, _underlyingRefund);
                emit HolderClaim(_dealData.holder, _dealData.underlyingDealToken, _underlyingRefund, block.timestamp);
            }
        } else {
            uint256 _currentBalance = IERC20(_dealData.underlyingDealToken).balanceOf(address(this));
            IERC20(_dealData.purchaseToken).safeTransfer(_dealData.holder, _currentBalance);
            emit HolderClaim(_dealData.holder, _dealData.underlyingDealToken, _currentBalance, block.timestamp);
        }

        feeEscrowClaim();

        holderClaimed = true;
    }

    /**
     * @dev transfers protocol fee of underlying deal tokens to the treasury escrow contract
     */
    function feeEscrowClaim() public lock purchasingOver {
        UpFrontDealData memory _dealData = dealData;
        UpFrontDealConfig memory _dealConfig = dealConfig;

        if (!feeEscrowClaimed) {
            address aelinEscrowStorageProxy = _cloneAsMinimalProxy(aelinEscrowLogicAddress, "Could not create new escrow");
            aelinFeeEscrow = AelinFeeEscrow(aelinEscrowStorageProxy);
            aelinFeeEscrow.initialize(aelinTreasuryAddress, _dealData.underlyingDealToken);

            uint256 aelinFeeAmt = (_dealConfig.underlyingDealTokenTotal * AELIN_FEE) / BASE;
            IERC20(_dealData.underlyingDealToken).safeTransfer(address(aelinFeeEscrow), aelinFeeAmt);
        }

        feeEscrowClaimed = true;
    }

    /**
     * @dev purchaser calls after the purchasing period to claim underlying deal tokens
     * amount based on the vesting schedule
     */
    function claimUnderlying() external lock purchasingOver passMinimumRaise {
        UpFrontDealData memory _dealData = dealData;

        uint256 underlyingDealTokensClaimed = claimableUnderlyingTokens(msg.sender);
        if (underlyingDealTokensClaimed > 0) {
            amountVested[msg.sender] += underlyingDealTokensClaimed;
            _burn(msg.sender, underlyingDealTokensClaimed);
            IERC20(_dealData.underlyingDealToken).safeTransfer(msg.sender, underlyingDealTokensClaimed);
            totalUnderlyingClaimed += underlyingDealTokensClaimed;
            emit ClaimedUnderlyingDealToken(msg.sender, _dealData.underlyingDealToken, underlyingDealTokensClaimed);
        }
    }

    /**
     * @dev a view showing the amount of the underlying deal token a purchaser gets in return
     */
    function claimableUnderlyingTokens(address purchaser) public view returns (uint256) {
        UpFrontDealConfig memory _dealConfig = dealConfig;

        uint256 underlyingClaimable = 0;

        uint256 maxTime = block.timestamp > vestingExpiry ? vestingExpiry : block.timestamp;
        if (
            balanceOf(purchaser) > 0 &&
            (maxTime > vestingCliffExpiry || (maxTime == vestingCliffExpiry && _dealConfig.vestingPeriod == 0))
        ) {
            uint256 timeElapsed = maxTime - vestingCliffExpiry;

            underlyingClaimable = _dealConfig.vestingPeriod == 0
                ? balanceOf(purchaser)
                : ((balanceOf(purchaser) + amountVested[purchaser]) * timeElapsed) /
                    _dealConfig.vestingPeriod -
                    amountVested[purchaser];
        }

        return (underlyingClaimable);
    }

    /**
     * @dev the holder may change their address
     */
    function setHolder(address _holder) external onlyHolder {
        futureHolder = _holder;
    }

    function acceptHolder() external {
        require(msg.sender == futureHolder, "only future holder can access");
        dealData.holder = futureHolder;
        emit SetHolder(futureHolder);
    }

    /**
     * @dev a function that any Ethereum address can call to vouch for a pool's legitimacy
     */
    function vouch() external {
        emit Vouch(msg.sender);
    }

    /**
     * @dev a function that any Ethereum address can call to disavow for a pool's legitimacy
     */
    function disavow() external {
        emit Disavow(msg.sender);
    }

    /**
     * @dev returns allow list information
     * @param _userAddress address to use in returning the amountPerAddress
     * @return address[] returns array of addresses included in the allow list
     * @return uint256[] returns array of allow list amounts for the address matching the index of allowListAddresses
     * @return uint256 allow list amount for _userAddress input
     * @return bool true if this deal has an allow list
     */
    function getAllowList(address _userAddress)
        public
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256,
            bool
        )
    {
        return (
            allowList.allowListAddresses,
            allowList.allowListAmounts,
            allowList.amountPerAddress[_userAddress],
            allowList.hasAllowList
        );
    }

    /**
     * @dev returns NFT collection details for the input collection address
     * @param _collection NFT collection address to get the collection details for
     * @return uint256 purchase amount, if 0 then unlimited purchase
     * @return address collection address used for configuration
     * @return bool if true then purchase amount is per token, if false then purchase amount is per user
     * @return uint256[] for ERC1155, included token IDs for this collection
     * @return uint256[] for ERC1155, min number of tokens required for participating
     */
    function getNftCollectionDetails(address _collection)
        public
        view
        returns (
            uint256,
            address,
            bool,
            uint256[] memory,
            uint256[] memory
        )
    {
        return (
            nftGating.nftCollectionDetails[_collection].purchaseAmount,
            nftGating.nftCollectionDetails[_collection].collectionAddress,
            nftGating.nftCollectionDetails[_collection].purchaseAmountPerToken,
            nftGating.nftCollectionDetails[_collection].tokenIds,
            nftGating.nftCollectionDetails[_collection].minTokensEligible
        );
    }

    /**
     * @dev returns various details about the NFT gating storage
     * @param _collection NFT collection address to check
     * @param _wallet user address to check
     * @param _nftId if _collection is ERC721 or CryptoPunks check if this ID has been used, if ERC1155 check if this ID is included
     * @return bool true if the _wallet has already been used to claim this _collection
     * @return bool if _collection is ERC721 or CryptoPunks true if this ID has been used, if ERC1155 true if this ID is included
     * @return bool returns hasNftList, true if this deal has a valid NFT gating list
     */
    function getNftGatingDetails(
        address _collection,
        address _wallet,
        uint256 _nftId
    )
        public
        view
        returns (
            bool,
            bool,
            bool
        )
    {
        return (
            nftGating.nftWalletUsedForPurchase[_collection][_wallet],
            nftGating.nftId[_collection][_nftId],
            nftGating.hasNftList
        );
    }

    function getPurchaseTokensPerUser(address _address) public view returns (uint256) {
        return (purchaseTokensPerUser[_address]);
    }

    function getPoolSharesPerUser(address _address) public view returns (uint256) {
        return (poolSharesPerUser[_address]);
    }

    function getAmountVested(address _address) public view returns (uint256) {
        return (amountVested[_address]);
    }

    modifier onlyHolder() {
        require(msg.sender == dealData.holder, "must be holder");
        _;
    }

    modifier onlySponsor() {
        require(msg.sender == dealData.sponsor, "must be sponsor");
        _;
    }

    modifier purchasingOver() {
        require(underlyingDepositComplete, "underlying deposit not complete");
        require(block.timestamp > purchaseExpiry, "purchase period not over");
        _;
    }

    modifier passMinimumRaise() {
        require(
            dealConfig.purchaseRaiseMinimum == 0 || totalPurchasingAccepted > dealConfig.purchaseRaiseMinimum,
            "does not pass minimum raise"
        );
        _;
    }
}
