// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "contracts/libraries/MerkleTree.sol";
import "contracts/VestAMM/AelinFeeModule.sol";
import "contracts/VestAMM/AelinLibraryList.sol";

import "contracts/VestAMM/interfaces/IVestAMM.sol";
import "contracts/VestAMM/interfaces/IVestAMMLibrary.sol";

contract AelinVestAMMTest is Test {
    uint256 mainnetFork;

    address aelinToken = address(0xa9C125BF4C8bB26f299c00969532B66732b1F758);
    address daiToken = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address aaveToken = address(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
    address usdcToken = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address user = address(0x000137);
    address investor = address(0x000138);

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    event SingleRewardDeposited(
        address indexed holder,
        uint8 vestingScheduleIndex,
        uint8 singleRewardIndex,
        address indexed token,
        uint256 amountPostTransfer
    );

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
    }

    function getCreatePoolData() public returns (IVestAMMLibrary.CreateNewPool memory data) {
        IVestAMMLibrary.CreateNewPool memory data;
        address[] memory tokens = new address[](2);

        tokens[0] = aelinToken;
        tokens[1] = daiToken;

        data.tokens = tokens;

        return data;
    }

    function getVestAMMInfo(
        address poolAddress,
        address investmentToken,
        address baseToken,
        address ammLibrary,
        bytes32 poolId
    ) public returns (IVestAMM.VAmmInfo memory) {
        IVestAMM.AmmData memory ammData = IVestAMM.AmmData(ammLibrary, investmentToken, baseToken);

        IVestAMM.SingleVestingSchedule[] memory single = new IVestAMM.SingleVestingSchedule[](1);
        single[0] = IVestAMM.SingleVestingSchedule(
            aaveToken, // rewardToken
            0, //vestingPeriod
            0, //vestingCliffPeriod
            user, //singleHolder
            0.1 ether, //totalSingleTokens
            0, //claimed;
            false //finalizedDeposit;
        );

        IVestAMM.LPVestingSchedule[] memory lpSchedules = new IVestAMM.LPVestingSchedule[](1);
        lpSchedules[0] = IVestAMM.LPVestingSchedule(
            single, //singleVestingSchedules[]
            0, //vestingPeriod;
            0, //vestingCliffPeriod;
            1 ether, //totalBaseTokens;
            0, // totalLPTokens;
            0, // claimed;
            false, //finalizedDeposit;
            10 //investorLPShare; // 0 - 100
        );

        IVestAMMLibrary.CreateNewPool memory newPool = getCreatePoolData();

        IVestAMM.VAmmInfo memory info = IVestAMM.VAmmInfo(
            ammData,
            true, //bool hasLaunchPhase;
            1 ether, //investmentPerBase;
            10 days, // depositWindow;
            15 days, //lpFundingWindow;
            address(0), //mainHolder;
            IVestAMM.Deallocation.None, // deallocation;
            lpSchedules,
            poolAddress,
            poolId,
            newPool
        );

        return info;
    }

    function getDealAccess() public returns (IVestAMM.DealAccess memory) {
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules;
        AelinAllowList.InitData memory allowListInit;
        return IVestAMM.DealAccess(0, "", nftCollectionRules, allowListInit);
    }

    function getAddLiquidityData(
        address pool,
        uint256 amount0,
        uint256 amount1
    ) public returns (IVestAMMLibrary.AddLiquidity memory data) {
        IVestAMMLibrary.AddLiquidity memory data;
        address[] memory tokens = new address[](2);
        uint[] memory tokensAmtsIn = new uint[](2);

        tokens[0] = aelinToken;
        tokens[1] = daiToken;
        tokensAmtsIn[0] = amount0;
        tokensAmtsIn[1] = amount1;

        data.poolAddress = pool;
        data.tokens = tokens;
        data.tokensAmtsIn = tokensAmtsIn;

        return data;
    }

    function getRemoveLiquidityData(
        address pool,
        address lpToken,
        uint lpTokenAmtIn
    ) public returns (IVestAMMLibrary.RemoveLiquidity memory data) {
        IVestAMMLibrary.RemoveLiquidity memory data;
        address[] memory tokens = new address[](2);

        tokens[0] = aelinToken;
        tokens[1] = daiToken;

        data.poolAddress = pool;
        data.tokens = tokens;
        data.lpTokenAmtIn = lpTokenAmtIn;
        data.lpToken = lpToken;

        return data;
    }
}
