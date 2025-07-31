// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29;

import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { ISplitMain } from "./interfaces/ISplitMain.sol";
import { IHatsModuleFactory } from "./interfaces/IHatsModuleFactory.sol";
import { IHatsHatCreatorModule } from "./Hats/IHatCreatorModule.sol";
import { IHatsTimeControlModule } from "./Hats/ITimeControlModule.sol";

contract IE {
    struct PoolConfig {
        address admin;
        address[] recipients;
        uint32[] initialAllocations;
        address[] evaluators;
    }

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

    uint256 private poolCount;
    uint256 public topHatId;

    // poolId => poolConfig
    mapping(uint256 => PoolConfig) public pools;

    // poolId => managerHatId
    mapping(uint256 => uint256) public poolToManagerHat;

    // poolId => splits contract address
    mapping(uint256 => address) public splitsContracts;

    event PoolCreated(
        uint256 poolId,
        uint256 managerHatId,
        address splitsContract,
        uint256 evaluatorHatId,
        uint256 recipientHatId,
        address[] evaluators,
        address[] recipients
    );

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

        topHatId = hats.mintTopHat(_owner, _topHatMetadata, _topHatImageURL);
        hatsModuleFactory = _hatsModuleFactory;
        hatCreatorModuleImpl = IHatsHatCreatorModule(_hatCreatorModuleImpl);
        timeControlModuleImpl = IHatsTimeControlModule(_timeControlModuleImpl);
    }

    // TODO: split into multiple functions
    function createPool(bytes memory _data /*, Module[] memory _modules*/ ) external {
        (
            address admin,
            address[] memory recipients,
            uint32[] memory initialAllocations,
            string memory managerHatMetadata,
            string memory managerHatImageURL,
            string memory evaluatorHatMetadata,
            string memory recipientHatMetadata,
            address[] memory evaluators
        ) = abi.decode(_data, (address, address[], uint32[], string, string, string, string, address[]));
        PoolConfig memory pool = PoolConfig({
            admin: admin,
            recipients: recipients,
            initialAllocations: initialAllocations,
            evaluators: evaluators
        });
        poolCount++;
        pools[poolCount] = pool;

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
        poolToManagerHat[poolCount] = managerHatId;

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

        // create modules and mint
        // for (uint256 i = 0; i < _modules.length; i++) {
        //     Module memory module = _modules[i];
        //     address moduleAddress =
        //         hatsModuleFactory.createHatsModule(module.impl, module.hatId, "", module.initData, 0);
        //     hats.mintHat(managerHatId, moduleAddress);
        // }

        // TODO: make sure that in total initialAllocations is 100%
        address splitsContract = splits.createSplit(recipients, initialAllocations, 0, admin);
        splitsContracts[poolCount] = splitsContract;

        // create evaluator hat

        uint256 evaluatorHatId = IHatsHatCreatorModule(hatCreatorModule).createHat(
            managerHatId,
            evaluatorHatMetadata,
            1,
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
        // mint evaluator hats
        for (uint256 i = 0; i < evaluators.length; i++) {
            address evaluator = evaluators[i];
            IHatsTimeControlModule(timeControlModule).mintHat(evaluatorHatId, evaluator, block.timestamp);
        }

        // mint recipient hats
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            IHatsTimeControlModule(timeControlModule).mintHat(recipientHatId, recipient, block.timestamp);
        }
    }

    // function to evaluate
    // function to update splits contract
}
