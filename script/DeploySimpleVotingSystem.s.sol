// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {SimpleVotingSystem} from "../src/SimplevotingSystem.sol";

contract DeploySimpleVotingSystem is Script {
    function run() external returns (SimpleVotingSystem) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        SimpleVotingSystem votingSystem = new SimpleVotingSystem();

        vm.stopBroadcast();

        console2.log("SimpleVotingSystem deployed at:", address(votingSystem));

        return votingSystem;
    }
}
