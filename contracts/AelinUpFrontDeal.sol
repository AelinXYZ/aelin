// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AelinFeeEscrow} from "./AelinFeeEscrow.sol";
import {AelinVestingToken} from "./AelinVestingToken.sol";
import {MinimalProxyFactory} from "./MinimalProxyFactory.sol";
import {AelinAllowList} from "./libraries/AelinAllowList.sol";
import {AelinNftGating} from "./libraries/AelinNftGating.sol";
import {MerkleTree} from "./libraries/MerkleTree.sol";
import {IAelinUpFrontDeal} from "./interfaces/IAelinUpFrontDeal.sol";
import {IERC20Extended} from "./interfaces/IERC20Extended.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AelinUpFrontDeal is MinimalProxyFactory, IAelinUpFrontDeal, AelinVestingToken {
    using SafeERC20 for IERC20;

    uint256 public constant BASE = 100 * 10 ** 18;
    uint256 public constant MAX_SPONSOR_FEE = 15 * 10 ** 18;
    uint256 public constant AELIN_FEE = 2 * 10 ** 18;
    uint256 public constant MAX_VESTING_SCHEDULES = 10;

    UpFrontDealData public dealData;
    UpFrontDealConfig public dealConfig;

    address public aelinTreasuryAddress;
    address public aelinEscrowLogicAddress;
    AelinFeeEscrow public aelinFeeEscrow;
    address public dealFactory;

    MerkleTree.TrackClaimed private trackClaimed;
    AelinAllowList.AllowList public allowList;
    AelinNftGating.NftGatingData public nftGating;

    //User => vestingIndex => amount
    mapping(address => mapping(uint256 => uint256)) public purchaseTokensPerUser;
    mapping(address => mapping(uint256 => uint256)) public poolSharesPerUser;

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
    uint256[] public vestingCliffExpiries;
    uint256[] public vestingExpiries;

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
        require(_dealData.purchaseToken != _dealData.underlyingDealToken, "purchase & underlying the same");
        require(_dealData.purchaseToken != address(0), "cant pass null purchase address");
        require(_dealData.underlyingDealToken != address(0), "cant pass null underlying addr");
        require(_dealData.holder != address(0), "cant pass null holder address");

        require(_dealConfig.purchaseDuration >= 30 minutes && _dealConfig.purchaseDuration <= 30 days, "not within limit");
        require(_dealData.sponsorFee <= MAX_SPONSOR_FEE, "exceeds max sponsor fee");

        uint256 numberOfVestingSchedules = _dealConfig.vestingSchedules.length;

        require(numberOfVestingSchedules > 0, "no vesting schedules");
        require(numberOfVestingSchedules <= MAX_VESTING_SCHEDULES, "too many vesting schedules");

        //sets as the first vesting schedule value initially but updates in the loop later
        uint256 lowestPrice = _dealConfig.vestingSchedules[0].purchaseTokenPerDealToken;

        for (uint256 i; i < numberOfVestingSchedules; i++) {
            require(_dealConfig.vestingSchedules[i].vestingCliffPeriod <= 1825 days, "max 5 year cliff");
            require(_dealConfig.vestingSchedules[i].vestingPeriod <= 1825 days, "max 5 year vesting");
            require(_dealConfig.vestingSchedules[i].purchaseTokenPerDealToken > 0, "invalid deal price");

            if (_dealConfig.vestingSchedules[i].purchaseTokenPerDealToken < lowestPrice) {
                lowestPrice = _dealConfig.vestingSchedules[i].purchaseTokenPerDealToken;
            }
        }

        require(_dealConfig.underlyingDealTokenTotal > 0, "must have nonzero deal tokens");

        uint8 underlyingTokenDecimals = IERC20Extended(_dealData.underlyingDealToken).decimals();

        if (_dealConfig.purchaseRaiseMinimum > 0) {
            uint256 minDealTotal = (lowestPrice * _dealConfig.underlyingDealTokenTotal) / 10 ** underlyingTokenDecimals;
            require(minDealTotal >= _dealConfig.purchaseRaiseMinimum, "raise min > deal total");
        }

        // store pool and deal details as state variables
        dealData = _dealData;
        dealConfig = _dealConfig;

        vestingCliffExpiries = new uint256[](numberOfVestingSchedules);
        vestingExpiries = new uint256[](numberOfVestingSchedules);

        dealStart = block.timestamp;

        dealFactory = msg.sender;

        // the deal token has the same amount of decimals as the underlying deal token,
        // eventually making them 1:1 redeemable
        _setNameAndSymbol(
            string(abi.encodePacked("aeUpFrontDeal-", _dealData.name)),
            string(abi.encodePacked("aeUD-", _dealData.symbol))
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

        require(!(allowList.hasAllowList && nftGating.hasNftList), "cant have allow list & nft");
        require(!(allowList.hasAllowList && dealData.merkleRoot != 0), "cant have allow list & merkle");
        require(!(nftGating.hasNftList && dealData.merkleRoot != 0), "cant have nft & merkle");
        require(!(bytes(dealData.ipfsHash).length == 0 && dealData.merkleRoot != 0), "merkle needs ipfs hash");
    }

    function _startPurchasingPeriod(
        uint256 _purchaseDuration,
        IAelinUpFrontDeal.VestingSchedule[] memory _vestingSchedules
    ) internal {
        underlyingDepositComplete = true;
        purchaseExpiry = block.timestamp + _purchaseDuration;

        for (uint256 i; i < _vestingSchedules.length; i++) {
            vestingCliffExpiries[i] = purchaseExpiry + _vestingSchedules[i].vestingCliffPeriod;
            vestingExpiries[i] = vestingCliffExpiries[i] + _vestingSchedules[i].vestingPeriod;
        }

        emit DealFullyFunded(address(this), block.timestamp, purchaseExpiry, vestingCliffExpiries, vestingExpiries);
    }

    modifier initOnce() {
        require(!calledInitialize, "can only init once");
        calledInitialize = true;
        _;
    }

    /**
     * @dev method for holder to deposit underlying deal tokens
     * all underlying deal tokens must be deposited for the purchasing period to start
     * if tokens were deposited directly, this method must still be called to start the purchasing period
     * @param _depositUnderlyingAmount how many underlying tokens the holder will transfer to the contract
     */
    function depositUnderlyingTokens(uint256 _depositUnderlyingAmount) external onlyHolder {
        address _underlyingDealToken = dealData.underlyingDealToken;

        require(IERC20(_underlyingDealToken).balanceOf(msg.sender) >= _depositUnderlyingAmount, "not enough balance");
        require(!underlyingDepositComplete, "already deposited the total");

        uint256 balanceBeforeTransfer = IERC20(_underlyingDealToken).balanceOf(address(this));
        IERC20(_underlyingDealToken).safeTransferFrom(msg.sender, address(this), _depositUnderlyingAmount);
        uint256 balanceAfterTransfer = IERC20(_underlyingDealToken).balanceOf(address(this));
        uint256 underlyingDealTokenAmount = balanceAfterTransfer - balanceBeforeTransfer;

        if (balanceAfterTransfer >= dealConfig.underlyingDealTokenTotal) {
            _startPurchasingPeriod(dealConfig.purchaseDuration, dealConfig.vestingSchedules);
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
     * @param _merkleData Merkle Proof data to prove investors allocation
     * @param _purchaseTokenAmount how many purchase tokens will be used to purchase deal token shares
     * @param _vestingIndex the vesting schedule index for which to claim from
     */
    function acceptDeal(
        AelinNftGating.NftPurchaseList[] calldata _nftPurchaseList,
        MerkleTree.UpFrontMerkleData calldata _merkleData,
        uint256 _purchaseTokenAmount,
        uint256 _vestingIndex
    ) external nonReentrant {
        require(underlyingDepositComplete, "underlying deposit incomplete");
        require(block.timestamp < purchaseExpiry, "not in purchase window");
        require(_vestingIndex < dealConfig.vestingSchedules.length, "index not in bounds");

        address _purchaseToken = dealData.purchaseToken;
        uint256 _underlyingDealTokenTotal = dealConfig.underlyingDealTokenTotal;
        uint256 _purchaseTokenPerDealToken = dealConfig.vestingSchedules[_vestingIndex].purchaseTokenPerDealToken;
        require(IERC20(_purchaseToken).balanceOf(msg.sender) >= _purchaseTokenAmount, "not enough purchaseToken");

        if (nftGating.hasNftList || _nftPurchaseList.length > 0) {
            AelinNftGating.purchaseDealTokensWithNft(_nftPurchaseList, nftGating, _purchaseTokenAmount);
        } else if (allowList.hasAllowList) {
            require(_purchaseTokenAmount <= allowList.amountPerAddress[msg.sender], "more than allocation");
            allowList.amountPerAddress[msg.sender] -= _purchaseTokenAmount;
        } else if (dealData.merkleRoot != 0) {
            MerkleTree.purchaseMerkleAmount(_merkleData, trackClaimed, _purchaseTokenAmount, dealData.merkleRoot);
        }

        uint256 balanceBeforeTransfer = IERC20(_purchaseToken).balanceOf(address(this));
        IERC20(_purchaseToken).safeTransferFrom(msg.sender, address(this), _purchaseTokenAmount);
        //Stack too deep
        //uint256 balanceAfterTransfer = IERC20(_purchaseToken).balanceOf(address(this));
        uint256 purchaseTokenAmount = IERC20(_purchaseToken).balanceOf(address(this)) - balanceBeforeTransfer;

        totalPurchasingAccepted += purchaseTokenAmount;
        purchaseTokensPerUser[msg.sender][_vestingIndex] += purchaseTokenAmount;

        uint8 underlyingTokenDecimals = IERC20Extended(dealData.underlyingDealToken).decimals();

        // this takes into account the decimal conversion between purchasing token and underlying deal token
        // pool shares having the same amount of decimals as underlying deal tokens
        uint256 poolSharesAmount = (purchaseTokenAmount * 10 ** underlyingTokenDecimals) / _purchaseTokenPerDealToken;
        require(poolSharesAmount > 0, "purchase amount too small");

        // pool shares directly correspond to the amount of deal tokens that can be minted
        // pool shares held = deal tokens minted as long as no deallocation takes place
        totalPoolShares += poolSharesAmount;
        poolSharesPerUser[msg.sender][_vestingIndex] += poolSharesAmount;

        if (!dealConfig.allowDeallocation) {
            require(totalPoolShares <= _underlyingDealTokenTotal, "purchased amount > total");
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
    function purchaserClaim(uint256 _vestingIndex) external nonReentrant purchasingOver {
        require(poolSharesPerUser[msg.sender][_vestingIndex] > 0, "no pool shares to claim with");

        address _purchaseToken = dealData.purchaseToken;
        uint256 _purchaseRaiseMinimum = dealConfig.purchaseRaiseMinimum;

        if (_purchaseRaiseMinimum == 0 || totalPurchasingAccepted > _purchaseRaiseMinimum) {
            uint256 _underlyingDealTokenTotal = dealConfig.underlyingDealTokenTotal;
            // Claim Deal Tokens
            bool deallocate = totalPoolShares > _underlyingDealTokenTotal;
            uint256 adjustedShareAmountForUser;
            uint256 precisionAdjustedRefund;

            if (deallocate) {
                // adjust for deallocation and mint deal tokens
                adjustedShareAmountForUser =
                    (((poolSharesPerUser[msg.sender][_vestingIndex] * _underlyingDealTokenTotal) / totalPoolShares) *
                        (BASE - AELIN_FEE - dealData.sponsorFee)) /
                    BASE;

                // refund any purchase tokens that got deallocated
                uint256 purchasingRefund = purchaseTokensPerUser[msg.sender][_vestingIndex] -
                    ((purchaseTokensPerUser[msg.sender][_vestingIndex] * _underlyingDealTokenTotal) / totalPoolShares);

                precisionAdjustedRefund = purchasingRefund > IERC20(_purchaseToken).balanceOf(address(this))
                    ? IERC20(_purchaseToken).balanceOf(address(this))
                    : purchasingRefund;

                // Transfer purchase token refund
                IERC20(_purchaseToken).safeTransfer(msg.sender, precisionAdjustedRefund);
            } else {
                // mint deal tokens when there is no deallocation
                adjustedShareAmountForUser =
                    ((BASE - AELIN_FEE - dealData.sponsorFee) * poolSharesPerUser[msg.sender][_vestingIndex]) /
                    BASE;
            }
            poolSharesPerUser[msg.sender][_vestingIndex] = 0;
            purchaseTokensPerUser[msg.sender][_vestingIndex] = 0;

            // mint vesting token and create schedule
            _mintVestingToken(msg.sender, adjustedShareAmountForUser, purchaseExpiry);
            emit ClaimDealTokens(msg.sender, adjustedShareAmountForUser, precisionAdjustedRefund);
        } else {
            // Claim Refund
            uint256 refundAmount = purchaseTokensPerUser[msg.sender][_vestingIndex];
            purchaseTokensPerUser[msg.sender][_vestingIndex] = 0;
            poolSharesPerUser[msg.sender][_vestingIndex] = 0;
            IERC20(_purchaseToken).safeTransfer(msg.sender, refundAmount);
            emit ClaimDealTokens(msg.sender, 0, refundAmount);
        }
    }

    /**
     * @dev sponsor calls once the purchasing period is over if the minimum raise has passed to claim
     * their share of deal tokens
     * NOTE also calls the claim for the protocol fee
     */
    function sponsorClaim() external nonReentrant purchasingOver passMinimumRaise onlySponsor {
        require(!sponsorClaimed, "sponsor already claimed");
        sponsorClaimed = true;

        address _sponsor = dealData.sponsor;
        uint256 _underlyingDealTokenTotal = dealConfig.underlyingDealTokenTotal;

        uint256 totalSold = totalPoolShares > _underlyingDealTokenTotal ? _underlyingDealTokenTotal : totalPoolShares;
        uint256 _sponsorFeeAmt = (totalSold * dealData.sponsorFee) / BASE;

        // mint vesting token and create schedule
        _mintVestingToken(_sponsor, _sponsorFeeAmt, purchaseExpiry);
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
    function holderClaim() external nonReentrant purchasingOver onlyHolder {
        require(!holderClaimed, "holder already claimed");
        holderClaimed = true;

        address _holder = dealData.holder;
        address _underlyingDealToken = dealData.underlyingDealToken;
        address _purchaseToken = dealData.purchaseToken;
        uint256 _purchaseRaiseMinimum = dealConfig.purchaseRaiseMinimum;

        if (_purchaseRaiseMinimum == 0 || totalPurchasingAccepted > _purchaseRaiseMinimum) {
            uint256 _underlyingDealTokenTotal = dealConfig.underlyingDealTokenTotal;

            bool deallocate = totalPoolShares > _underlyingDealTokenTotal;

            if (deallocate) {
                uint256 _underlyingTokenDecimals = IERC20Extended(_underlyingDealToken).decimals();

                uint256 _totalIntendedRaise;

                //is this correct? triple-check
                for (uint256 i; i < dealConfig.vestingSchedules.length; i++) {
                    _totalIntendedRaise +=
                        (dealConfig.vestingSchedules[i].purchaseTokenPerDealToken * _underlyingDealTokenTotal) /
                        10 ** _underlyingTokenDecimals;
                }

                uint256 precisionAdjustedRaise = _totalIntendedRaise > IERC20(_purchaseToken).balanceOf(address(this))
                    ? IERC20(_purchaseToken).balanceOf(address(this))
                    : _totalIntendedRaise;

                IERC20(_purchaseToken).safeTransfer(_holder, precisionAdjustedRaise);
                emit HolderClaim(_holder, _purchaseToken, precisionAdjustedRaise, _underlyingDealToken, 0, block.timestamp);
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
            emit HolderClaim(_holder, _purchaseToken, 0, _underlyingDealToken, _currentBalance, block.timestamp);
        }
    }

    /**
     * @dev transfers protocol fee of underlying deal tokens to the treasury escrow contract
     */
    function feeEscrowClaim() public purchasingOver passMinimumRaise {
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
     * @dev ERC721 deal token holder calls after the purchasing period to claim underlying deal tokens
     * amount based on the vesting schedule
     * @param _tokenId the token ID to check the quantity of claimable underlying tokens
     * @param _vestingIndex the vesting index schedule for which to claim from
     */
    function claimUnderlying(uint256 _tokenId, uint256 _vestingIndex) external returns (uint256) {
        return _claimUnderlying(msg.sender, _tokenId, _vestingIndex);
    }

    /**
     * @dev claims every vesting schedule specified for each token Id specified
     * @param _tokenIds the token ID to check the quantity of claimable underlying tokens
     * @param _vestingIndices the vesting index schedule for which to claim from
     */
    function claimUnderlyingMultipleEntries(
        uint256[] memory _tokenIds,
        uint256[] memory _vestingIndices
    ) external returns (uint256) {
        uint256 totalClaimed;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            for (uint256 j = 0; j < _vestingIndices.length; j++) {
                totalClaimed += _claimUnderlying(msg.sender, _tokenIds[i], _vestingIndices[j]);
            }
        }
        return totalClaimed;
    }

    function _claimUnderlying(address _owner, uint256 _tokenId, uint256 _vestingIndex) internal returns (uint256) {
        require(ownerOf(_tokenId) == _owner, "must be owner to claim");
        require(_vestingIndex < dealConfig.vestingSchedules.length, "index out of bounds");
        uint256 claimableAmount = claimableUnderlyingTokens(_tokenId, _vestingIndex);
        if (claimableAmount == 0) {
            return 0;
        }
        if (block.timestamp >= vestingExpiries[_vestingIndex]) {
            _burnVestingToken(_tokenId);
        } else {
            vestingDetails[_tokenId].lastClaimedAt = block.timestamp;
        }
        address _underlyingDealToken = dealData.underlyingDealToken;
        totalUnderlyingClaimed += claimableAmount;
        IERC20(_underlyingDealToken).safeTransfer(_owner, claimableAmount);
        emit ClaimedUnderlyingDealToken(_owner, _tokenId, _underlyingDealToken, claimableAmount);
        return claimableAmount;
    }

    /**
     * @dev a view showing the amount of the underlying deal token a ERC721 deal token holder can claim
     * @param _tokenId the token ID to check the quantity of claimable underlying tokens
     * @param _vestingIndex the vesting index schedule for which to claim from
     */
    function claimableUnderlyingTokens(uint256 _tokenId, uint256 _vestingIndex) public view returns (uint256) {
        VestingDetails memory details = vestingDetails[_tokenId];
        uint256 precisionAdjustedUnderlyingClaimable;

        if (details.lastClaimedAt > 0) {
            uint256 maxTime = block.timestamp > vestingExpiries[_vestingIndex]
                ? vestingExpiries[_vestingIndex]
                : block.timestamp;
            uint256 minTime = details.lastClaimedAt > vestingCliffExpiries[_vestingIndex]
                ? details.lastClaimedAt
                : vestingCliffExpiries[_vestingIndex];
            uint256 vestingPeriod = dealConfig.vestingSchedules[_vestingIndex].vestingPeriod;

            if (
                (maxTime > vestingCliffExpiries[_vestingIndex] && minTime <= vestingExpiries[_vestingIndex]) ||
                (maxTime == vestingCliffExpiries[_vestingIndex] && vestingPeriod == 0)
            ) {
                uint256 underlyingClaimable = vestingPeriod == 0
                    ? details.share
                    : (details.share * (maxTime - minTime)) / vestingPeriod;

                // This could potentially be the case where the last user claims a slightly smaller amount if there is some precision loss
                // although it will generally never happen as solidity rounds down so there should always be a little bit left
                address _underlyingDealToken = dealData.underlyingDealToken;
                precisionAdjustedUnderlyingClaimable = underlyingClaimable >
                    IERC20(_underlyingDealToken).balanceOf(address(this))
                    ? IERC20(_underlyingDealToken).balanceOf(address(this))
                    : underlyingClaimable;
            }
        }
        return precisionAdjustedUnderlyingClaimable;
    }

    /**
     * @dev the holder may change their address
     * @param _holder address to swap the holder role
     */
    function setHolder(address _holder) external onlyHolder {
        require(_holder != address(0), "holder cant be null");
        futureHolder = _holder;
        emit HolderSet(_holder);
    }

    /**
     * @dev futurHolder can call to accept the role of holder
     */
    function acceptHolder() external {
        require(msg.sender == futureHolder, "only future holder can access");
        dealData.holder = futureHolder;
        emit HolderAccepted(futureHolder);
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
    function getAllowList(address _userAddress) public view returns (address[] memory, uint256[] memory, uint256, bool) {
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
     * @return IdRange[] for ERC721, an array of token Id ranges
     * @return uint256[] for ERC1155, included token IDs for this collection
     * @return uint256[] for ERC1155, min number of tokens required for participating
     */
    function getNftCollectionDetails(
        address _collection
    ) public view returns (uint256, address, AelinNftGating.IdRange[] memory, uint256[] memory, uint256[] memory) {
        return (
            nftGating.nftCollectionDetails[_collection].purchaseAmount,
            nftGating.nftCollectionDetails[_collection].collectionAddress,
            nftGating.nftCollectionDetails[_collection].idRanges,
            nftGating.nftCollectionDetails[_collection].tokenIds,
            nftGating.nftCollectionDetails[_collection].minTokensEligible
        );
    }

    /**
     * @dev returns various details about the NFT gating storage
     * @param _collection NFT collection address to check
     * @param _nftId if _collection is ERC721 check if this ID has been used, if ERC1155 check if this ID is included
     * @return bool if _collection is ERC721 true if this ID has been used, if ERC1155 true if this ID is included
     * @return bool returns hasNftList, true if this deal has a valid NFT gating list
     */
    function getNftGatingDetails(address _collection, uint256 _nftId) public view returns (bool, bool) {
        return (nftGating.nftId[_collection][_nftId], nftGating.hasNftList);
    }

    /**
     * @dev returns various details about the vesting schedule
     * @param _vestingIndex the vesting index schedule for which to claim from
     * @return uint256 the purchaseTokenPerDealToken for the vesting schedule selected
     * @return uint256 the vestingCliffPeriod for the vesting schedule selected
     * @return uint256 the vestingPeriod for the vesting schedule selected
     */
    function getVestingScheduleDetails(uint256 _vestingIndex) public view returns (uint256, uint256, uint256) {
        require(_vestingIndex < dealConfig.vestingSchedules.length, "index out of bounds");
        return (
            dealConfig.vestingSchedules[_vestingIndex].purchaseTokenPerDealToken,
            dealConfig.vestingSchedules[_vestingIndex].vestingCliffPeriod,
            dealConfig.vestingSchedules[_vestingIndex].vestingPeriod
        );
    }

    /**
     * @dev returns the number of vesting schedules that exist for this deal
     * @return uint256 the length of the vesting schedules array
     */
    function getNumberOfVestingSchedules() public view returns (uint256) {
        return dealConfig.vestingSchedules.length;
    }

    /**
     * @dev hasPurchasedMerkle
     * @param _index index of leaf node/ address to check
     */
    function hasPurchasedMerkle(uint256 _index) public view returns (bool) {
        return MerkleTree.hasPurchasedMerkle(trackClaimed, _index);
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
        require(underlyingDepositComplete, "underlying deposit incomplete");
        require(block.timestamp > purchaseExpiry, "purchase period not over");
        _;
    }

    modifier passMinimumRaise() {
        require(
            dealConfig.purchaseRaiseMinimum == 0 || totalPurchasingAccepted > dealConfig.purchaseRaiseMinimum,
            "does not pass min raise"
        );
        _;
    }
}
