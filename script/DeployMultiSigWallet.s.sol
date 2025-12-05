// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

import {HelperConfig} from "./HelperConfig.s.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";

contract DeployMultiSigWallet is Script {
    function deployContract() public returns (MultiSigWallet, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        MultiSigWallet multiSigWallet = new MultiSigWallet(
            config.owners,
            config.noOfConfirmations
        );
        vm.stopBroadcast();

        return (multiSigWallet, helperConfig);
    }

    function run() public returns (MultiSigWallet, HelperConfig) {
        return deployContract();
    }
}
