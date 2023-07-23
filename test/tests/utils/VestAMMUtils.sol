// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "contracts/libraries/MerkleTree.sol";
import "contracts/VestAMM/AelinFeeModule.sol";
import "contracts/VestAMM/interfaces/IVestAMM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VestAMMUtils is Test, IVestAMM {
    /// @dev will need to allow for further customisation for more rigorous testing later
    function getVAmmInfo(address _tokenA, address _tokenB, address _holder) internal view returns (VAmmInfo memory) {
        AmmData memory ammData = AmmData({investmentToken: _tokenA, baseToken: _tokenB});

        LPVestingSchedule memory lpVestingSchedules = LPVestingSchedule({
            vestingPeriod: 0,
            vestingCliffPeriod: 0,
            totalBaseTokens: 1 ether,
            totalLPTokens: 1 ether,
            finalizedDeposit: true,
            investorLPShare: 0
        });

        SingleVestingSchedule[] memory singleVestingSchedules = new SingleVestingSchedule[](1);
        SingleVestingSchedule memory singleVestingSchedule = SingleVestingSchedule({
            rewardToken: address(1),
            singleHolder: _holder,
            totalSingleTokens: 1 ether,
            finalizedDeposit: true,
            isLiquid: true
        });
        singleVestingSchedules[0] = singleVestingSchedule;

        VAmmInfo memory info = VAmmInfo({
            name: "test",
            symbol: "Test",
            ammData: ammData,
            hasLaunchPhase: true,
            investmentPerBase: 1 ether,
            depositWindow: 10 days,
            lpFundingWindow: 15 days,
            mainHolder: _holder,
            lpVestingSchedule: lpVestingSchedules,
            singleVestingSchedules: singleVestingSchedules,
            poolAddress: address(33),
            poolId: 0
        });

        return info;
    }

    function getDealAccess() internal view returns (DealAccess memory) {
        AelinNftGating.NftCollectionRules[] memory nftCollectionRules;
        AelinAllowList.InitData memory allowListInit;
        return IVestAMM.DealAccess(0, "", nftCollectionRules, allowListInit);
    }
}
