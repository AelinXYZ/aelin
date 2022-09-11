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

    // fee bps
    uint256 constant BASE = 10000;
    uint256 constant MAX_SPONSOR_FEE = 1500;
    uint256 constant AELIN_FEE = 200;

    uint256 constant MAX_VESTING_SCHEDULES = 10;

    UpFrontDealData public dealData;
    UpFrontDealConfig public dealConfig;

    address public aelinTreasuryAddress;
    address public aelinEscrowLogicAddress;
    AelinFeeEscrow public aelinFeeEscrow;
    address public dealFactory;

    AelinAllowList.AllowList public allowList;
    AelinNftGating.NftGatingData public nftGating;
    mapping(address => mapping(uint256 => uint256)) public purchaseTokensPerUser;
    mapping(address => mapping(uint256 => uint256)) public poolSharesPerUser;
    mapping(address => mapping(uint256 => uint256)) public dealTokensPerSchedule;
    mapping(address => mapping(uint256 => uint256)) public amountVested;

    uint256 public totalPurchasingAccepted;
    uint256 public totalPoolShares;
    uint256 public totalUnderlyingClaimed;

    bool private underlyingDepositComplete;
    bool private sponsorClaimed;
    bool private holderClaimed;
    bool private feeEscrowClaimed;

    bool private calledInitialize;
    address public futureHolder;

    uint256 public dealStart;
    uint256 public purchaseExpiry;
    uint256[] public vestingCliffExpiry;
    uint256[] public vestingExpiry;

    /**
     * @dev initializes the contract configuration, called from the factory contract when creating a new Up Front Deal
     */
    function initialize(
        UpFrontDealData calldata _dealData,
        UpFrontDealConfig calldata _dealConfig,
        AelinNftGating.NftCollectionRules[] calldata _nftCollectionRules,
        AelinAllowList.InitData calldata _allowListInit,
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
        require(_dealConfig.underlyingDealTokenTotal > 0, "must have nonzero deal tokens");

        require(_dealConfig.vestingSchedule.length > 0, "must have vesting schedule");
        require(_dealConfig.vestingSchedule.length < MAX_VESTING_SCHEDULES, "exceeds max amount of vesting schedules");
        uint8 underlyingTokenDecimals = IERC20Decimals(_dealData.underlyingDealToken).decimals();
        uint256 highestPrice;
        for (uint256 i; i < _dealConfig.vestingSchedule.length; ++i) {
            require(1825 days >= _dealConfig.vestingSchedule[i].vestingCliffPeriod, "max 5 year cliff");
            require(1825 days >= _dealConfig.vestingSchedule[i].vestingPeriod, "max 5 year vesting");
            require(_dealConfig.vestingSchedule[i].purchaseTokenPerDealToken > 0, "invalid deal price");
            if (_dealConfig.vestingSchedule[i].purchaseTokenPerDealToken > highestPrice) {
                highestPrice = _dealConfig.vestingSchedule[i].purchaseTokenPerDealToken;
            }
        }

        uint256 _maxRaise = (highestPrice * _dealConfig.underlyingDealTokenTotal) / 10**underlyingTokenDecimals;
        require(_maxRaise > 0, "max raise too small");
        if (_dealConfig.purchaseRaiseMinimum > 0) {
            require(_dealConfig.purchaseRaiseMinimum <= _maxRaise, "raise minimum is greater than deal total");
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

        require(!(allowList.hasAllowList && nftGating.hasNftList), "cannot have allow list and nft gating");

        vestingCliffExpiry = new uint256[](_dealConfig.vestingSchedule.length);
        vestingExpiry = new uint256[](_dealConfig.vestingSchedule.length);
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
     * @param _depositUnderlyingAmount how many underlying tokens the holder will transfer to the contract
     */
    function depositUnderlyingTokens(uint256 _depositUnderlyingAmount) public onlyHolder {
        address _underlyingDealToken = dealData.underlyingDealToken;

        require(IERC20(_underlyingDealToken).balanceOf(msg.sender) >= _depositUnderlyingAmount, "not enough balance");
        require(!underlyingDepositComplete, "already deposited the total");

        uint256 balanceBeforeTransfer = IERC20(_underlyingDealToken).balanceOf(address(this));
        IERC20(_underlyingDealToken).safeTransferFrom(msg.sender, address(this), _depositUnderlyingAmount);
        uint256 balanceAfterTransfer = IERC20(_underlyingDealToken).balanceOf(address(this));
        uint256 underlyingDealTokenAmount = balanceAfterTransfer - balanceBeforeTransfer;

        if (balanceAfterTransfer >= dealConfig.underlyingDealTokenTotal) {
            underlyingDepositComplete = true;
            purchaseExpiry = block.timestamp + dealConfig.purchaseDuration;
            for (uint256 i; i < dealConfig.vestingSchedule.length; ++i) {
                vestingCliffExpiry[i] = purchaseExpiry + dealConfig.vestingSchedule[i].vestingCliffPeriod;
                vestingExpiry[i] = vestingCliffExpiry[i] + dealConfig.vestingSchedule[i].vestingPeriod;
            }
            emit DealFullyFunded(address(this), block.timestamp, purchaseExpiry, vestingCliffExpiry, vestingExpiry);
        }

        emit DepositDealToken(_underlyingDealToken, msg.sender, underlyingDealTokenAmount);
    }

    /**
     * @dev allows holder to withdraw any excess underlying deal tokens deposited to the contract
     */
    function withdrawExcess() external onlyHolder {
        address _underlyingDealToken = dealData.underlyingDealToken;
        uint256 _underlyingDealTokenTotal = dealConfig.underlyingDealTokenTotal;
        uint256 currentBalance = IERC20(_underlyingDealToken).balanceOf(address(this));
        require(currentBalance > _underlyingDealTokenTotal, "no excess to withdraw");

        uint256 excessAmount = currentBalance - _underlyingDealTokenTotal;
        IERC20(_underlyingDealToken).safeTransfer(msg.sender, excessAmount);

        emit WithdrewExcess(address(this), excessAmount);
    }

    /**
     * @dev accept deal by depositing purchasing tokens which is converted to a mapping which stores the amount of
     * underlying purchased. pool shares have the same decimals as the underlying deal token
     * @param _nftPurchaseList NFTs to use for accepting the deal if deal is NFT gated
     * @param _purchaseTokenAmount how many purchase tokens will be used to purchase deal token shares
     * @param _vestingIndex the vesting schedule related to the purchase
     */
    function acceptDeal(
        AelinNftGating.NftPurchaseList[] calldata _nftPurchaseList,
        uint256 _purchaseTokenAmount,
        uint256 _vestingIndex
    ) external lock {
        require(underlyingDepositComplete, "deal token not yet deposited");
        require(block.timestamp < purchaseExpiry, "not in purchase window");

        address _purchaseToken = dealData.purchaseToken;
        uint256 _underlyingDealTokenTotal = dealConfig.underlyingDealTokenTotal;
        VestingSchedule[] memory vestingSchedule = dealConfig.vestingSchedule;
        require(IERC20(_purchaseToken).balanceOf(msg.sender) >= _purchaseTokenAmount, "not enough purchaseToken");
        require(_vestingIndex < vestingSchedule.length, "index not in bounds");

        if (nftGating.hasNftList || _nftPurchaseList.length > 0) {
            AelinNftGating.purchaseDealTokensWithNft(_nftPurchaseList, nftGating, _purchaseTokenAmount);
        } else if (allowList.hasAllowList) {
            require(_purchaseTokenAmount <= allowList.amountPerAddress[msg.sender], "more than allocation");
            allowList.amountPerAddress[msg.sender] -= _purchaseTokenAmount;
        }

        uint256 balanceBeforeTransfer = IERC20(_purchaseToken).balanceOf(address(this));
        IERC20(_purchaseToken).safeTransferFrom(msg.sender, address(this), _purchaseTokenAmount);
        uint256 balanceAfterTransfer = IERC20(_purchaseToken).balanceOf(address(this));
        uint256 purchaseTokenAmount = balanceAfterTransfer - balanceBeforeTransfer;

        totalPurchasingAccepted += purchaseTokenAmount;
        purchaseTokensPerUser[msg.sender][_vestingIndex] += purchaseTokenAmount;

        // this takes into account the decimal conversion between purchasing token and underlying deal token
        // pool shares having the same amount of decimals as underlying deal tokens
        uint256 poolSharesAmount = (purchaseTokenAmount * 10**(IERC20Decimals(dealData.underlyingDealToken).decimals())) /
            vestingSchedule[_vestingIndex].purchaseTokenPerDealToken;
        require(poolSharesAmount > 0, "purchase amount too small");

        // pool shares directly correspond to the amount of deal tokens that can be minted
        // pool shares held = deal tokens minted as long as no deallocation takes place
        totalPoolShares += poolSharesAmount;
        poolSharesPerUser[msg.sender][_vestingIndex] += poolSharesAmount;

        if (!dealConfig.allowDeallocation) {
            require(totalPoolShares <= _underlyingDealTokenTotal, "purchased amount over total");
        } else if (totalPoolShares > _underlyingDealTokenTotal) {
            // if there is deallocation
            // attempt these computations, if it causes a revert this is overflow protection for purchaserClaim()
            uint256 test = (((poolSharesPerUser[msg.sender][_vestingIndex] * _underlyingDealTokenTotal) / totalPoolShares) *
                (BASE - AELIN_FEE - dealData.sponsorFee)) / BASE;
            test =
                purchaseTokensPerUser[msg.sender][_vestingIndex] -
                ((purchaseTokensPerUser[msg.sender][_vestingIndex] * _underlyingDealTokenTotal) / totalPoolShares);
        }

        emit AcceptDeal(
            msg.sender,
            _vestingIndex,
            purchaseTokenAmount,
            purchaseTokensPerUser[msg.sender][_vestingIndex],
            poolSharesAmount,
            poolSharesPerUser[msg.sender][_vestingIndex]
        );
    }

    /**
     * @dev purchaser calls to claim their deal tokens or refund if the minimum raise does not pass
     */
    function purchaserClaim() public lock purchasingOver {
        uint256 _purchaseRaiseMinimum = dealConfig.purchaseRaiseMinimum;
        uint256 _underlyingDealTokenTotal = dealConfig.underlyingDealTokenTotal;

        uint256 totalRaise;
        bool deallocate = totalPoolShares > _underlyingDealTokenTotal;
        if (deallocate) {
            totalRaise = (totalPurchasingAccepted * _underlyingDealTokenTotal) / totalPoolShares;
        } else {
            totalRaise = totalPurchasingAccepted;
        }

        if (_purchaseRaiseMinimum == 0 || totalRaise > _purchaseRaiseMinimum) {
            uint256 dealTokensForUser;
            uint256 purchaseTokenRefund;

            for (uint256 i; i < dealConfig.vestingSchedule.length; ++i) {
                // Claim Deal Tokens
                if (deallocate) {
                    // adjust for deallocation and mint deal tokens
                    uint256 adjustedDealTokens = (poolSharesPerUser[msg.sender][i] * _underlyingDealTokenTotal) /
                        totalPoolShares;
                    adjustedDealTokens = ((BASE - AELIN_FEE - dealData.sponsorFee) * adjustedDealTokens) / BASE;
                    dealTokensPerSchedule[msg.sender][i] = adjustedDealTokens;
                    dealTokensForUser += adjustedDealTokens;
                    poolSharesPerUser[msg.sender][i] = 0;
                    // refund any purchase tokens that got deallocated
                    purchaseTokenRefund += purchaseTokensPerUser[msg.sender][i];
                    purchaseTokensPerUser[msg.sender][i] = 0;
                } else {
                    // mint deal tokens when there is no deallocation
                    uint256 adjustedDealTokens = ((BASE - AELIN_FEE - dealData.sponsorFee) *
                        poolSharesPerUser[msg.sender][i]) / BASE;
                    dealTokensForUser += adjustedDealTokens;
                    dealTokensPerSchedule[msg.sender][i] = adjustedDealTokens;
                    poolSharesPerUser[msg.sender][i] = 0;
                    purchaseTokensPerUser[msg.sender][i] = 0;
                }
            }
            if (deallocate) {
                purchaseTokenRefund =
                    purchaseTokenRefund -
                    ((purchaseTokenRefund * _underlyingDealTokenTotal) / totalPoolShares);
            }
            if (dealTokensForUser > 0) {
                _mint(msg.sender, dealTokensForUser);
            }
            if (purchaseTokenRefund > 0) {
                IERC20(dealData.purchaseToken).safeTransfer(msg.sender, purchaseTokenRefund);
            }
            emit ClaimDealTokens(msg.sender, dealTokensForUser, purchaseTokenRefund);
        } else {
            // Claim Refund
            uint256 purchaseTokenRefund;
            for (uint256 i; i < dealConfig.vestingSchedule.length; ++i) {
                purchaseTokenRefund += purchaseTokensPerUser[msg.sender][i];
                purchaseTokensPerUser[msg.sender][i] = 0;
                poolSharesPerUser[msg.sender][i] = 0;
                dealTokensPerSchedule[msg.sender][i] = 0;
            }
            IERC20(dealData.purchaseToken).safeTransfer(msg.sender, purchaseTokenRefund);
            emit ClaimDealTokens(msg.sender, 0, purchaseTokenRefund);
        }
    }

    /**
     * @dev sponsor calls once the purchasing period is over if the minimum raise has passed to claim
     * their share of deal tokens
     * NOTE also calls the claim for the protocol fee
     */
    function sponsorClaim() public lock purchasingOver passMinimumRaise onlySponsor {
        require(!sponsorClaimed, "sponsor already claimed");
        sponsorClaimed = true;

        address _sponsor = dealData.sponsor;
        uint256 _underlyingDealTokenTotal = dealConfig.underlyingDealTokenTotal;

        uint256 totalSold = totalPoolShares > _underlyingDealTokenTotal ? _underlyingDealTokenTotal : totalPoolShares;
        uint256 _sponsorFeeAmt = (totalSold * dealData.sponsorFee) / BASE;
        _mint(_sponsor, _sponsorFeeAmt);
        emit SponsorClaim(_sponsor, _sponsorFeeAmt);

        if (!feeEscrowClaimed) {
            feeEscrowClaim();
        }
    }

    /**
     * @dev holder calls once purchasing period is over to claim their raise or
     * underlying deal tokens if the minimum raise has not passed
     * NOTE also calls the claim for the protocol fee
     */
    function holderClaim() public lock purchasingOver onlyHolder {
        require(!holderClaimed, "holder already claimed");
        holderClaimed = true;

        address _holder = dealData.holder;
        address _underlyingDealToken = dealData.underlyingDealToken;
        uint256 _purchaseRaiseMinimum = dealConfig.purchaseRaiseMinimum;
        uint256 _underlyingDealTokenTotal = dealConfig.underlyingDealTokenTotal;

        uint256 totalRaise;
        bool deallocate = totalPoolShares > _underlyingDealTokenTotal;
        if (deallocate) {
            totalRaise = (totalPurchasingAccepted * _underlyingDealTokenTotal) / totalPoolShares;
        } else {
            totalRaise = totalPurchasingAccepted;
        }

        if (_purchaseRaiseMinimum == 0 || totalRaise > _purchaseRaiseMinimum) {
            address _purchaseToken = dealData.purchaseToken;

            if (deallocate) {
                IERC20(_purchaseToken).safeTransfer(_holder, totalRaise);
                emit HolderClaim(_holder, _purchaseToken, totalRaise, _underlyingDealToken, 0, block.timestamp);
            } else {
                // holder receives raise
                uint256 _currentBalance = IERC20(_purchaseToken).balanceOf(address(this));
                IERC20(_purchaseToken).safeTransfer(_holder, _currentBalance);
                // holder receives any leftover underlying deal tokens
                uint256 _underlyingRefund = _underlyingDealTokenTotal - totalPoolShares;
                IERC20(_underlyingDealToken).safeTransfer(_holder, _underlyingRefund);
                emit HolderClaim(
                    _holder,
                    _purchaseToken,
                    _currentBalance,
                    _underlyingDealToken,
                    _underlyingRefund,
                    block.timestamp
                );
            }
            if (!feeEscrowClaimed) {
                feeEscrowClaim();
            }
        } else {
            uint256 _currentBalance = IERC20(_underlyingDealToken).balanceOf(address(this));
            IERC20(_underlyingDealToken).safeTransfer(_holder, _currentBalance);
            emit HolderClaim(_holder, dealData.purchaseToken, 0, _underlyingDealToken, _currentBalance, block.timestamp);
        }
    }

    /**
     * @dev transfers protocol fee of underlying deal tokens to the treasury escrow contract
     */
    function feeEscrowClaim() public purchasingOver {
        if (!feeEscrowClaimed) {
            feeEscrowClaimed = true;
            address _underlyingDealToken = dealData.underlyingDealToken;
            uint256 _underlyingDealTokenTotal = dealConfig.underlyingDealTokenTotal;

            address aelinEscrowStorageProxy = _cloneAsMinimalProxy(aelinEscrowLogicAddress, "Could not create new escrow");
            aelinFeeEscrow = AelinFeeEscrow(aelinEscrowStorageProxy);
            aelinFeeEscrow.initialize(aelinTreasuryAddress, _underlyingDealToken);

            uint256 totalSold;
            if (totalPoolShares > _underlyingDealTokenTotal) {
                totalSold = _underlyingDealTokenTotal;
            } else {
                totalSold = totalPoolShares;
            }
            uint256 aelinFeeAmt = (totalSold * AELIN_FEE) / BASE;
            IERC20(_underlyingDealToken).safeTransfer(address(aelinFeeEscrow), aelinFeeAmt);

            emit FeeEscrowClaim(aelinEscrowStorageProxy, _underlyingDealToken, aelinFeeAmt);
        }
    }

    /**
     * @dev purchaser calls after the purchasing period to claim underlying deal tokens
     * amount based on the vesting schedule
     * @param _vestingIndex the vesting schedule for which to claim from
     */
    function claimUnderlyingPerSchedule(uint256 _vestingIndex) external lock purchasingOver passMinimumRaise {
        require(_vestingIndex < dealConfig.vestingSchedule.length, "index not in bounds");
        uint256 underlyingDealTokensClaimed = claimableUnderlyingTokens(msg.sender, _vestingIndex);
        require(underlyingDealTokensClaimed > 0, "no underlying ready to claim");
        address _underlyingDealToken = dealData.underlyingDealToken;
        amountVested[msg.sender][_vestingIndex] += underlyingDealTokensClaimed;
        dealTokensPerSchedule[msg.sender][_vestingIndex] -= underlyingDealTokensClaimed;
        totalUnderlyingClaimed += underlyingDealTokensClaimed;
        _burn(msg.sender, underlyingDealTokensClaimed);
        IERC20(_underlyingDealToken).safeTransfer(msg.sender, underlyingDealTokensClaimed);
        emit ClaimedUnderlyingDealToken(msg.sender, _underlyingDealToken, underlyingDealTokensClaimed);
    }

    function claimUnderlyingAllSchedules() external lock purchasingOver passMinimumRaise {
        address _underlyingDealToken = dealData.underlyingDealToken;
        uint256 length = dealConfig.vestingSchedule.length;
        uint256 amountClaim;

        for (uint256 i; i < length; ++i) {
            uint256 underlyingDealTokensClaimed = claimableUnderlyingTokens(msg.sender, i);
            amountVested[msg.sender][i] += underlyingDealTokensClaimed;
            amountClaim += underlyingDealTokensClaimed;
            dealTokensPerSchedule[msg.sender][i] -= underlyingDealTokensClaimed;
        }

        require(amountClaim > 0, "no underlying ready to claim");
        _burn(msg.sender, amountClaim);
        totalUnderlyingClaimed += amountClaim;
        IERC20(_underlyingDealToken).safeTransfer(msg.sender, amountClaim);
        emit ClaimedUnderlyingDealToken(msg.sender, _underlyingDealToken, amountClaim);
    }

    /**
     * @dev a view showing the amount of the underlying deal token a purchaser can claim
     * @param _purchaser address to check the quantity of claimable underlying tokens
     * @param _vestingIndex the vesting schedule to get the claimable token amount for
     */
    function claimableUnderlyingTokens(address _purchaser, uint256 _vestingIndex)
        public
        view
        purchasingOver
        returns (uint256)
    {
        uint256 _vestingPeriod = dealConfig.vestingSchedule[_vestingIndex].vestingPeriod;
        uint256 _vestingCliffExpiry = vestingCliffExpiry[_vestingIndex];
        uint256 _vestingExpiry = vestingExpiry[_vestingIndex];
        uint256 underlyingClaimable;

        uint256 maxTime = block.timestamp > _vestingExpiry ? _vestingExpiry : block.timestamp;
        if (
            balanceOf(_purchaser) > 0 &&
            (maxTime > _vestingCliffExpiry || (maxTime == _vestingCliffExpiry && _vestingPeriod == 0))
        ) {
            uint256 timeElapsed = maxTime - _vestingCliffExpiry;
            uint256 _amountVested = amountVested[_purchaser][_vestingIndex];

            underlyingClaimable = _vestingPeriod == 0
                ? dealTokensPerSchedule[_purchaser][_vestingIndex]
                : ((dealTokensPerSchedule[_purchaser][_vestingIndex] + _amountVested) * timeElapsed) /
                    _vestingPeriod -
                    _amountVested;
        }

        return (underlyingClaimable);
    }

    /**
     * @dev the holder may change their address
     * @param _holder address to swap the holder role
     */
    function setHolder(address _holder) external onlyHolder {
        futureHolder = _holder;
    }

    /**
     * @dev futurHolder can call to accept the role of holder
     */
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

    /**
     * @dev get the vesting schedule struct information for a single vesting schedule
     * @param _vestingIndex the index in the dealConfig.vestingSchedule struct array to return the data from
     * @return uint256 purchaseTokenPerDealToken
     * @return uint256 vestingCliffPeriod
     * @return uint256 vestingPeriod
     */
    function getVestingScheduleDetails(uint256 _vestingIndex)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(_vestingIndex < dealConfig.vestingSchedule.length, "index not in bounds");
        IAelinUpFrontDeal.VestingSchedule memory vestingSchedule = dealConfig.vestingSchedule[_vestingIndex];
        return (
            vestingSchedule.purchaseTokenPerDealToken,
            vestingSchedule.vestingCliffPeriod,
            vestingSchedule.vestingPeriod
        );
    }

    /**
     * @dev getPurchaseTokensPerUser
     * @param _address address to check
     * @param _vestingIndex vesting schedule to check
     * @return uint256 purchase tokens used to purchase pool shares for this vesting schedule
     */
    function getPurchaseTokensPerUser(address _address, uint256 _vestingIndex) public view returns (uint256) {
        return (purchaseTokensPerUser[_address][_vestingIndex]);
    }

    /**
     * @dev getPoolSharesPerUser
     * @param _address address to check
     * @param _vestingIndex vesting schedule to check
     * @return uint256 pool shares purchased by user for this vesting schedule
     */
    function getPoolSharesPerUser(address _address, uint256 _vestingIndex) public view returns (uint256) {
        return (poolSharesPerUser[_address][_vestingIndex]);
    }

    /**
     * @dev getDealTokensPerSchedule
     * @param _address address to check
     * @param _vestingIndex vesting schedule to check
     * @return uint256 balance of the user's deal tokens that apply to this vesting schedule
     */
    function getDealTokensPerSchedule(address _address, uint256 _vestingIndex) public view returns (uint256) {
        return (dealTokensPerSchedule[_address][_vestingIndex]);
    }

    /**
     * @dev getAmountVested
     * @param _address address to check
     * @param _vestingIndex vesting schedule to check
     * @return uint256 amount of underlying already claimed for this vesting schedule
     */
    function getAmountVested(address _address, uint256 _vestingIndex) public view returns (uint256) {
        return (amountVested[_address][_vestingIndex]);
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
            dealConfig.purchaseRaiseMinimum == 0 || totalPurchasingAccepted >= dealConfig.purchaseRaiseMinimum,
            "does not pass minimum raise"
        );
        _;
    }
}
