// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AgentPassport} from "../src/AgentPassport.sol";
import {AgentTipJar} from "../src/AgentTipJar.sol";

/// @notice Deploy AgentPassport + AgentTipJar to BNB Smart Chain (chain 56).
///         DO NOT broadcast to mainnet until the deployer wallet is funded
///         and the owner (Fahmi) has approved the deployment.
///         Dry run:  forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.binance.org/
///         Deploy:   forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.binance.org/ \
///                       --broadcast --verify --verifier blockscout \
///                       --verifier-url https://api.bscscan.com/api --private-key $PRIVATE_KEY
contract Deploy is Script {
    address internal constant AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F; // SPACE ID Agent ID, BSC

    function run() external {
        require(block.chainid == 56, "Deploy script targets BSC mainnet (chain 56) only");
        vm.startBroadcast();
        AgentPassport passport = new AgentPassport(AGENT_ID);
        AgentTipJar tipJar = new AgentTipJar(AGENT_ID);
        vm.stopBroadcast();
        console.log("AgentPassport:", address(passport));
        console.log("AgentTipJar:  ", address(tipJar));
        console.log("Agent ID:     ", AGENT_ID);
    }
}
