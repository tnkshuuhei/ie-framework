// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";

import { BaseIEStrategy } from "./BaseIEStrategy.sol";
import { ISplitMain } from "../interfaces/ISplitMain.sol";
import { IHatsModuleFactory } from "../interfaces/IHatsModuleFactory.sol";
import { IHatsHatCreatorModule } from "../interfaces/IHatCreatorModule.sol";
import { IHatsTimeControlModule } from "../interfaces/ITimeControlModule.sol";

contract ProtocolGuild is BaseIEStrategy {
    constructor(address _scaffoldIE) BaseIEStrategy(_scaffoldIE, "ProtocolGuildStrategy") { }

    enum RecipientType {
        FullTime,
        PartTime
    }

    struct Recipient {
        address recipient;
        RecipientType recipientType;
    }

    IHatsTimeControlModule public timeControlModuleImpl;
    Recipient[] public members;

    uint256 public topHatId;
    uint256 public recipientHatId;
    uint256 public evaluatorHatId;
    address public splitsContract;
    address public timeControlModule;

    event Evaluated(address[] memberAddresses, uint32[] allocations);

    function createIE(bytes memory _data) external override returns (uint256) {
        _beforeCreateIE(_data);
        topHatId = _createIE(_data);
        _afterCreateIE(_data);

        return topHatId;
    }

    function evaluate(bytes memory _data) external override returns (bytes memory) {
        return _evaluate(_data);
    }

    function _evaluate(bytes memory) internal override returns (bytes memory) {
        address[] memory memberAddresses = _extractRecipientAddresses(members);
        uint32[] memory allocations = _calculateTimeWeightedAllocations(members, timeControlModule);

        ISplitMain(scaffoldIE.getSplits()).updateSplit(splitsContract, memberAddresses, allocations, 0);

        emit Evaluated(memberAddresses, allocations);

        return abi.encode(memberAddresses, allocations);
    }

    function _createIE(bytes memory _data) internal override returns (uint256) {
        (
            address _timeControlModuleImpl,
            Recipient[] memory recipients,
            string memory _topHatMetadata,
            string memory _topHatImageURL,
            string memory _managerHatMetadata,
            string memory _managerHatImageURL,
            string memory _evaluatorMetadata,
            string memory _recipientHatMetadata,
            address[] memory _evaluators
        ) = abi.decode(_data, (address, Recipient[], string, string, string, string, string, string, address[]));
        timeControlModuleImpl = IHatsTimeControlModule(_timeControlModuleImpl);

        IHats hats = IHats(scaffoldIE.getHats());

        topHatId = hats.mintTopHat(address(this), _topHatMetadata, _topHatImageURL);
        // mint tophat to this contract
        // https://github.com/hats-protocol/hats-protocol/blob/b23340f825a2cdf9f5758462f8161d7076ad7f6f/src/Hats.sol#L168

        // create manager hats under the top hat
        uint256 managerHatId = hats.createHat(
            topHatId, // parent hatId
            _managerHatMetadata, // should be ipfs://cid for data (e.g.
                // https://ipfs.io/ipfs/bafkreigbzej36xhwpu2qt7zzmdv3yei446e2mmgv7u7hl4dfrz3dswwd6y)
            2, // max supply is the number of modules (TODO: change to actual max supply) (evaluator + recipient hats)
            0x0000000000000000000000000000000000004A75,
            0x0000000000000000000000000000000000004A75,
            true,
            _managerHatImageURL
        );

        address hatCreatorModule = IHatsModuleFactory(scaffoldIE.getHatsModuleFactory()).createHatsModule(
            scaffoldIE.getHatCreatorModuleImpl(), managerHatId, "", abi.encode(managerHatId), 0
        );
        hats.mintHat(managerHatId, hatCreatorModule);

        timeControlModule = IHatsModuleFactory(scaffoldIE.getHatsModuleFactory()).createHatsModule(
            address(timeControlModuleImpl), managerHatId, "", abi.encode(managerHatId), 0
        );
        hats.mintHat(managerHatId, timeControlModule);

        evaluatorHatId = IHatsHatCreatorModule(hatCreatorModule).createHat(
            managerHatId,
            _evaluatorMetadata,
            uint32(_evaluators.length),
            0x0000000000000000000000000000000000004A75, // TODO: change to actual eligibility
            0x0000000000000000000000000000000000004A75, // TODO: change to actual toggle
            true, // mutable
            "" // imageURL
        );

        recipientHatId = IHatsHatCreatorModule(hatCreatorModule).createHat(
            managerHatId,
            _recipientHatMetadata,
            uint32(recipients.length),
            0x0000000000000000000000000000000000004A75, // TODO: change to actual eligibility
            0x0000000000000000000000000000000000004A75, // TODO: change to actual toggle
            true, // mutable
            "" // imageURL
        );

        for (uint256 i = 0; i < _evaluators.length; i++) {
            address evaluator = _evaluators[i];
            IHatsTimeControlModule(timeControlModule).mintHat(evaluatorHatId, evaluator, block.timestamp);
        }

        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i].recipient;
            IHatsTimeControlModule(timeControlModule).mintHat(recipientHatId, recipient, block.timestamp);
        }

        splitsContract = ISplitMain(scaffoldIE.getSplits()).createSplit(
            _extractRecipientAddresses(recipients),
            _calculateTimeWeightedAllocations(recipients, timeControlModule),
            0,
            address(this)
        );

        // TODO : remove this. This is a temporary fix to avoid memory allocation issues
        // This is not a gas efficient solution.
        members = new Recipient[](recipients.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            members[i] = recipients[i];
        }
        return topHatId;
    }

    function _calculateTimeWeightedAllocations(
        Recipient[] memory _recipients,
        address _timeControlModule
    )
        internal
        view
        returns (uint32[] memory)
    {
        uint256[] memory timeMultipliers = new uint256[](_recipients.length);
        uint256 totalMultiplier = 0;

        // Calculate time multipliers for each recipient using Protocol Labs formula (sqrt(wearing_time))
        for (uint256 i = 0; i < _recipients.length; i++) {
            uint256 wearingElapsedTime = IHatsTimeControlModule(_timeControlModule).getWearingElapsedTime(
                _recipients[i].recipient, recipientHatId
            );
            uint256 multiplier =
                Math.sqrt(wearingElapsedTime * (_recipients[i].recipientType == RecipientType.FullTime ? 100 : 50));
            timeMultipliers[i] = multiplier;
            totalMultiplier += multiplier;
        }

        // Convert to percentage allocations (basis points)
        uint32[] memory percentAllocations = new uint32[](_recipients.length);

        if (totalMultiplier > 0) {
            uint256 totalAllocated = 0;
            for (uint256 i = 0; i < _recipients.length; i++) {
                // Calculate percentage using OpenZeppelin's mulDiv for better precision
                // (multiplier * 1e6) / totalMultiplier
                percentAllocations[i] = uint32(Math.mulDiv(timeMultipliers[i], 1_000_000, totalMultiplier));
                totalAllocated += percentAllocations[i];
            }
            // Distribute remainder to first recipient to ensure sum equals 1_000_000
            if (totalAllocated < 1_000_000) {
                percentAllocations[0] += uint32(1_000_000 - totalAllocated);
            }
        } else {
            // If no time has been worn, distribute equally
            uint32 equalAllocation = uint32(1_000_000 / _recipients.length);
            for (uint256 i = 0; i < _recipients.length; i++) {
                percentAllocations[i] = equalAllocation;
            }
            // Distribute remainder to first recipient
            percentAllocations[0] += uint32(1_000_000 % _recipients.length);
        }

        return percentAllocations;
    }

    function _extractRecipientAddresses(Recipient[] memory recipients) internal pure returns (address[] memory) {
        address[] memory recipientAddresses = new address[](recipients.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            recipientAddresses[i] = recipients[i].recipient;
        }
        return recipientAddresses;
    }
}
