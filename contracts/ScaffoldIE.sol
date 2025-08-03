// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29;

import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { ISplitMain } from "./interfaces/ISplitMain.sol";
import { IHatsModuleFactory } from "./interfaces/IHatsModuleFactory.sol";
import { IHatsHatCreatorModule } from "./Hats/IHatCreatorModule.sol";
import { IHatsTimeControlModule } from "./Hats/ITimeControlModule.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IScaffoldIE } from "./interfaces/IScaffoldIE.sol";

contract ScaffoldIE is IScaffoldIE {
    struct Module {
        address impl;
        uint256 hatId;
        bytes initData;
    }

    IHats public hats;
    ISplitMain public splits;
    IHatsModuleFactory public hatsModuleFactory;
    IHatsHatCreatorModule public hatCreatorModuleImpl;
    IHatsTimeControlModule public timeControlModuleImpl;

    address public owner;

    uint256 public poolCount;
    uint256 public topHatId;

    // poolId => poolConfig
    mapping(uint256 => PoolConfig) public pools;

    // poolId => managerHatId
    mapping(uint256 => uint256) public poolIdToManagerHat;

    // poolId => splits contract address
    mapping(uint256 => address) public poolIdToSplitsContract;

    // TODO: remove this mapping.
    // this is not necessary for other than protocol guild case.

    // poolId => time control module address
    mapping(uint256 => address) public poolIdToTimeControlModule;

    // poolId => recipient hat ID
    mapping(uint256 => uint256) public poolIdToRecipientHat;

    constructor(
        address _owner,
        address _hats,
        address _splits,
        string memory _topHatMetadata,
        string memory _topHatImageURL,
        IHatsModuleFactory _hatsModuleFactory,
        address _hatCreatorModuleImpl,
        address _timeControlModuleImpl
    ) {
        hats = IHats(_hats);
        splits = ISplitMain(_splits);

        // mint tophat to this contract
        // https://github.com/hats-protocol/hats-protocol/blob/b23340f825a2cdf9f5758462f8161d7076ad7f6f/src/Hats.sol#L168
        topHatId = hats.mintTopHat(address(this), _topHatMetadata, _topHatImageURL);
        // TODO: manage owner address on tophat and correcponding hat
        owner = _owner;

        hatsModuleFactory = _hatsModuleFactory;
        hatCreatorModuleImpl = IHatsHatCreatorModule(_hatCreatorModuleImpl);
        timeControlModuleImpl = IHatsTimeControlModule(_timeControlModuleImpl);
    }

    // TODO: split into multiple functions
    function createPool(bytes memory _data /*, Module[] memory _modules*/ ) external returns (uint256) {
        (
            address admin,
            Recipient[] memory recipients,
            uint32[] memory initialAllocations,
            string memory managerHatMetadata,
            string memory managerHatImageURL,
            string memory evaluatorHatMetadata,
            string memory recipientHatMetadata,
            address[] memory evaluators
        ) = abi.decode(_data, (address, Recipient[], uint32[], string, string, string, string, address[]));

        poolCount++;

        // create manager hats under the top hat
        uint256 managerHatId = hats.createHat(
            topHatId, // parent hatId
            managerHatMetadata, // should be ipfs://cid for data (e.g.
                // https://ipfs.io/ipfs/bafkreigbzej36xhwpu2qt7zzmdv3yei446e2mmgv7u7hl4dfrz3dswwd6y)
            2, // max supply is the number of modules (TODO: change to actual max supply) (evaluator + recipient hats)
            0x0000000000000000000000000000000000004A75,
            0x0000000000000000000000000000000000004A75,
            true,
            managerHatImageURL
        );
        poolIdToManagerHat[poolCount] = managerHatId;

        // deploy hat creator module and mint it to the manager hat
        address hatCreatorModule = hatsModuleFactory.createHatsModule(
            address(hatCreatorModuleImpl), managerHatId, "", abi.encode(managerHatId), 0
        );
        hats.mintHat(managerHatId, hatCreatorModule);

        // create time control module and mint it to the manager hat
        address timeControlModule = hatsModuleFactory.createHatsModule(
            address(timeControlModuleImpl), managerHatId, "", abi.encode(managerHatId), 0
        );
        hats.mintHat(managerHatId, timeControlModule);

        // Store the time control module address for this pool
        poolIdToTimeControlModule[poolCount] = timeControlModule;

        // create modules and mint
        // for (uint256 i = 0; i < _modules.length; i++) {
        //     Module memory module = _modules[i];
        //     address moduleAddress =
        //         hatsModuleFactory.createHatsModule(module.impl, module.hatId, "", module.initData, 0);
        //     hats.mintHat(managerHatId, moduleAddress);
        // }

        // TODO: make sure that in total initialAllocations is 100%
        // Extract recipient addresses

        address[] memory extractedRecipientAddresses = _extractRecipientAddresses(recipients);
        address splitsContract = splits.createSplit(extractedRecipientAddresses, initialAllocations, 0, address(this));
        poolIdToSplitsContract[poolCount] = splitsContract;

        // create evaluator hat

        uint256 evaluatorHatId = IHatsHatCreatorModule(hatCreatorModule).createHat(
            managerHatId,
            evaluatorHatMetadata,
            uint32(evaluators.length),
            0x0000000000000000000000000000000000004A75, // eligibility (TODO: change to actual eligibility)
            0x0000000000000000000000000000000000004A75, // toggle (TODO: change to actual toggle)
            true,
            "" // imageURL
        );

        // create recipient hats
        uint256 recipientHatId = IHatsHatCreatorModule(hatCreatorModule).createHat(
            managerHatId,
            recipientHatMetadata,
            uint32(recipients.length),
            0x0000000000000000000000000000000000004A75, // eligibility (TODO: change to actual eligibility)
            0x0000000000000000000000000000000000004A75, // toggle (TODO: change to actual toggle)
            true,
            "" // imageURL
        );

        // Store the recipient hat ID for this pool
        poolIdToRecipientHat[poolCount] = recipientHatId;
        // mint evaluator hats
        for (uint256 i = 0; i < evaluators.length; i++) {
            address evaluator = evaluators[i];
            IHatsTimeControlModule(timeControlModule).mintHat(evaluatorHatId, evaluator, block.timestamp);
        }

        // mint recipient hats
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i].recipient;
            IHatsTimeControlModule(timeControlModule).mintHat(recipientHatId, recipient, block.timestamp);
        }

        PoolConfig memory pool = PoolConfig({
            admin: admin,
            recipients: recipients,
            initialAllocations: initialAllocations,
            evaluators: evaluators,
            splitsContract: splitsContract
        });
        pools[poolCount] = pool;
        // Extract recipient addresses for event

        emit PoolCreated(poolCount, managerHatId, splitsContract, evaluatorHatId, recipientHatId);
        return poolCount;
    }

    function evaluate(uint256 _poolId) external returns (uint32[] memory) {
        address splitsContract = poolIdToSplitsContract[_poolId];
        Recipient[] memory recipients = pools[_poolId].recipients;

        // Extract recipient addresses
        address[] memory extractedRecipientAddresses = _extractRecipientAddresses(recipients);

        address timeControlModule = poolIdToTimeControlModule[_poolId];

        // Calculate time-weighted allocations using Protocol Labs formula
        uint32[] memory percentAllocations = _calculateTimeWeightedAllocations(_poolId, recipients, timeControlModule);

        splits.updateSplit(splitsContract, extractedRecipientAddresses, percentAllocations, 0);
        return percentAllocations;
    }

    function getPoolIdToTimeControlModule(uint256 _poolId) external view returns (address) {
        return poolIdToTimeControlModule[_poolId];
    }

    function getPoolIdToRecipientHat(uint256 _poolId) external view returns (uint256) {
        return poolIdToRecipientHat[_poolId];
    }

    function getPoolIdToSplitsContract(uint256 _poolId) external view returns (address) {
        return poolIdToSplitsContract[_poolId];
    }

    function getPoolIdToManagerHat(uint256 _poolId) external view returns (uint256) {
        return poolIdToManagerHat[_poolId];
    }

    function getHatsModuleFactory() external view returns (address) {
        return address(hatsModuleFactory);
    }

    function getHatCreatorModuleImpl() external view returns (address) {
        return address(hatCreatorModuleImpl);
    }

    function getTimeControlModuleImpl() external view returns (address) {
        return address(timeControlModuleImpl);
    }

    function _calculateTimeWeightedAllocations(
        uint256 _poolId,
        Recipient[] memory _recipients,
        address _timeControlModule
    )
        internal
        view
        returns (uint32[] memory)
    {
        uint256[] memory timeMultipliers = new uint256[](_recipients.length);
        uint256 totalMultiplier = 0;

        // Get the recipient hat ID for this pool
        uint256 recipientHatId = _getRecipientHatId(_poolId);

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

    function _getRecipientHatId(uint256 _poolId) internal view returns (uint256) {
        uint256 recipientHatId = poolIdToRecipientHat[_poolId];
        return recipientHatId;
    }

    function _extractRecipientAddresses(Recipient[] memory recipients) internal pure returns (address[] memory) {
        address[] memory recipientAddresses = new address[](recipients.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            recipientAddresses[i] = recipients[i].recipient;
        }
        return recipientAddresses;
    }

    function _getHatsTimeFrameMultiplier(
        uint256 _poolId,
        address _wearer,
        uint256 _hatId
    )
        internal
        view
        returns (uint256)
    {
        address timeControlModule = poolIdToTimeControlModule[_poolId];
        uint256 wearingElapsedTime = IHatsTimeControlModule(timeControlModule).getWearingElapsedTime(_wearer, _hatId);
        return Math.sqrt(wearingElapsedTime);
    }
}
