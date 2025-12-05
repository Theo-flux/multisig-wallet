// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

abstract contract ConfigConstant {
    error HelperConfig__InvalidChainID();

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant NO_OF_CONFIRMERS = 3;
}

contract HelperConfig is ConfigConstant, Script {
    struct NetworkConfig {
        address[] owners;
        uint256 noOfConfirmations;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) private networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    function getConfigByChain(
        uint256 _chainId
    ) public returns (NetworkConfig memory) {
        if (_chainId == ETH_SEPOLIA_CHAIN_ID) return getOrCreateAnvilConfig();
        else if (_chainId == LOCAL_CHAIN_ID) return getOrCreateAnvilConfig();
        else revert HelperConfig__InvalidChainID();
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        address[] memory owners = vm.envAddress("SEPOLIA_ADDR", ",");
        return
            NetworkConfig({
                owners: owners,
                noOfConfirmations: NO_OF_CONFIRMERS
            });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        address[] memory owners = vm.envAddress("ANVIL_ADDR", ",");

        localNetworkConfig = NetworkConfig({
            owners: owners,
            noOfConfirmations: NO_OF_CONFIRMERS
        });
        return localNetworkConfig;
    }

    function getConfig() external returns (NetworkConfig memory) {
        return getConfigByChain(block.chainid);
    }
}
