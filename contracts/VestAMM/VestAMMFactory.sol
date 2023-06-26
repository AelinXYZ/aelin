// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./VestAMM.sol";
import "./AelinFeeModule.sol";
import "../libraries/AelinNftGating.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../libraries/AelinAllowList.sol";
import {IVestAMM} from "./interfaces/IVestAMM.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAelinLibraryList {
    function libraryList(address _library) external view returns (bool);
}

contract VestAMMDealFactory is IVestAMM {
    // using SafeERC20 for IERC20;

    address public immutable VEST_AMM_LOGIC;
    address public immutable AELIN_FEE_MODULE;
    address public immutable AELIN_MULTI_REWARDS;
    address public immutable VEST_DAO_FEES = 0x0000000000000000000000000000000000000000;
    IAelinLibraryList public immutable AELIN_LIBRARY_LIST;

    constructor(address _aelinLibraryList) {
        VEST_AMM_LOGIC = address(new VestAMM());
        AELIN_FEE_MODULE = address(new AelinFeeModule());
        AELIN_LIBRARY_LIST = IAelinLibraryList(_aelinLibraryList);
    }

    function createVestAMM(
        // AmmData calldata _ammData,
        VAmmInfo calldata _vAmmInfo,
        DealAccess calldata _dealAccess
    ) external returns (address vAmmAddress) {
        // Use customs errors
        require(AELIN_LIBRARY_LIST.libraryList(_vAmmInfo.ammData.ammLibrary), "invalid AMM library");

        vAmmAddress = Clones.clone(VEST_AMM_LOGIC);

        VestAMM(vAmmAddress).initialize(_vAmmInfo, _dealAccess, AELIN_FEE_MODULE, AELIN_MULTI_REWARDS);

        // TODO
        // emit NewVestAMM(_vAmmInfo, _dealAccess);
    }
}
