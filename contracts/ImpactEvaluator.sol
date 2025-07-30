// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29;

import { IReward } from "./interfaces/IReward.sol";
import { IHats } from "hats-protocol/interfaces/IHats.sol";
import { ISplitMain } from "./interfaces/ISplitMain.sol";
import { IHatsModuleFactory } from "./interfaces/IHatsModuleFactory.sol";

contract IE {
    struct PoolConfig {
        address admin;
        address[] recipients;
        address[] moudules;
        string name;
        string managerHatMetadata;
        string managerHatImageURL;
    }

    struct Module {
        address impl;
        uint256 hatId;
        bytes initData;
    }

    IHats private immutable hats;
    ISplitMain private immutable splits;
    IHatsModuleFactory private immutable hatsModuleFactory;

    uint256 private poolCount;
    uint256 public topHatId;

    // TODO: add modules to the event
    event PoolCreated(uint256 indexed poolId, address indexed admin, address[] recipients);

    mapping(uint256 => PoolConfig) private pools;

    constructor(
        address _owner,
        address _hats,
        address _splits,
        string memory _topHatMetadata,
        string memory _topHatImageURL,
        IHatsModuleFactory _hatsModuleFactory
    ) {
        hats = IHats(_hats);
        splits = ISplitMain(_splits);

        topHatId = hats.mintTopHat(_owner, _topHatMetadata, _topHatImageURL);
        hatsModuleFactory = _hatsModuleFactory;
    }

    function createPool(bytes memory _data, Module[] memory _modules) external {
        PoolConfig memory pool = abi.decode(_data, (PoolConfig));
        poolCount++;
        pools[poolCount] = pool;

        // create manager hats under the top hat
        uint256 managerHatId = hats.createHat(
            topHatId, // parent hatId
            pool.managerHatMetadata, // should be ipfs://cid for data (e.g.
                // https://ipfs.io/ipfs/bafkreigbzej36xhwpu2qt7zzmdv3yei446e2mmgv7u7hl4dfrz3dswwd6y)
            uint32(_modules.length), // max supply is the number of modules
            0x0000000000000000000000000000000000004A75,
            0x0000000000000000000000000000000000004A75,
            true,
            pool.managerHatImageURL
        );

        // create modules and mint
        for (uint256 i = 0; i < _modules.length; i++) {
            Module memory module = _modules[i];
            address moduleAddress =
                hatsModuleFactory.createHatsModule(module.impl, module.hatId, "", module.initData, 0);
            hats.mintHat(managerHatId, moduleAddress);
        }

        emit PoolCreated(poolCount, pool.admin, pool.recipients);
    }
}
