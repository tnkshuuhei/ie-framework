// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { HatsEligibilityModule, HatsModule } from "hats-module/src/HatsEligibilityModule.sol";
import { IHypercertToken } from "../interface/IHypercertToken.sol";

contract HypercertsEligibility is HatsEligibilityModule {
    /*//////////////////////////////////////////////////////////////
                          PUBLIC CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// The address of the Hypercerts contract used to check eligibility
    function TOKEN_ADDRESS() public pure returns (address) {
        return _getArgAddress(72);
    }

    /// The length of the TOKEN_IDS & MIN_BALANCES arrays - these MUST be equal.
    function ARRAY_LENGTH() public pure returns (uint256) {
        return _getArgUint256(92);
    }

    /// The Hypercerts token IDs that allow eligibility.
    /// @dev NOTE: Wearer must satisfy only one token ID criteria for eligiblity.
    /// @dev NOTE: the TOKEN_IDS length must match the MIN_BALANCES length
    function TOKEN_IDS() public pure returns (uint256[] memory) {
        return _getArgUint256Array(124, ARRAY_LENGTH());
    }

    /// The minimum balances of units required (for token ID in the corresponding index) for eligibility.
    /// @dev NOTE: Wearer must satisfy only one token ID criteria for eligiblity
    /// @dev NOTE: the TOKEN_IDS length must match the MIN_BALANCES_OF_UNITS length
    function MIN_BALANCES_OF_UNITS() public pure returns (uint256[] memory) {
        return _getArgUint256Array(124 + ARRAY_LENGTH() * 32, ARRAY_LENGTH());
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Deploy the HypercertsEligibility implementation contract and set its version
     * @dev This is only used to deploy the implementation contract, and should not be used to deploy clones
     */
    constructor(string memory _version) HatsModule(_version) { }

    /*//////////////////////////////////////////////////////////////
                        HATS ELIGIBILITY FUNCTION
    //////////////////////////////////////////////////////////////*/
    /**
     * @inheritdoc HatsEligibilityModule
     */
    function getWearerStatus(
        address _wearer,
        uint256 /*_hatId */
    )
        public
        view
        override
        returns (bool eligible, bool standing)
    {
        uint256 len = ARRAY_LENGTH();
        IHypercertToken token = IHypercertToken(TOKEN_ADDRESS());
        uint256[] memory tokenIds = TOKEN_IDS();
        uint256[] memory minBalances = MIN_BALANCES_OF_UNITS();

        for (uint256 i = 0; i < len;) {
            eligible = token.unitsOf(_wearer, tokenIds[i]) >= minBalances[i];
            if (eligible) break;
            unchecked {
                ++i;
            }
        }
        standing = true;
    }
}
