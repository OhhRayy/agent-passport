// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AgentPassport} from "../src/AgentPassport.sol";
import {AgentTipJar} from "../src/AgentTipJar.sol";

/// @notice Fork tests against the REAL SPACE ID Agent ID registry on BSC.
///         Run with: forge test --match-path test/AgentPassport.fork.t.sol
///         --fork-url https://bsc-dataseed.binance.org/
/// @dev Verified on-chain 18 Nov 2026: label "ohrayy" -> tokenId
///      14288174740848976714399194853367668560881175917523252271979436296426985581470,
///      owned by 0xD6768Ff0aC2Acc72bF650283928c1f682217caBA (Agent ID ohrayy.ai).
contract AgentPassportForkTest is Test {
    address internal constant AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;
    address internal constant FAHMI = 0xD6768Ff0aC2Acc72bF650283928c1f682217caBA;
    address internal constant RANDOM = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);
    uint256 internal constant OHRAYY_ID =
        14288174740848976714399194853367668560881175917523252271979436296426985581470;

    AgentPassport internal passport;
    AgentTipJar internal tipJar;

    function setUp() public {
        passport = new AgentPassport(AGENT_ID);
        tipJar = new AgentTipJar(AGENT_ID);
    }

    function test_fork_realAgentIdOwnerIsFahmi() public view {
        // Sanity: the fork really sees the on-chain registry state.
        (bool ok, bytes memory ret) = AGENT_ID.staticcall(
            abi.encodeWithSignature("ownerOf(uint256)", OHRAYY_ID)
        );
        assertTrue(ok);
        assertEq(abi.decode(ret, (address)), FAHMI);
    }

    function test_fork_mintSucceedsForRealHolder() public {
        vm.prank(FAHMI);
        passport.mint("ohrayy");
        assertEq(passport.ownerOf(OHRAYY_ID), FAHMI);
        assertEq(passport.agentIdLabelOf(OHRAYY_ID), "ohrayy");
    }

    function test_fork_mintRevertsForRandomNonHolder() public {
        vm.prank(RANDOM);
        vm.expectRevert(AgentPassport.NotAgentIdHolder.selector);
        passport.mint("ohrayy");
    }

    function test_fork_mintRevertsForNonexistentName() public {
        vm.prank(FAHMI);
        vm.expectRevert(AgentPassport.NotAgentIdHolder.selector);
        passport.mint("nama-yang-pasti-tidak-ada-xyz123");
    }

    function test_fork_tipForwardsToRealHolder() public {
        uint256 amount = 0.001 ether;
        uint256 before = FAHMI.balance;
        vm.deal(RANDOM, 1 ether);
        vm.prank(RANDOM);
        tipJar.tip{value: amount}("ohrayy");
        assertEq(FAHMI.balance - before, amount);
        assertEq(address(tipJar).balance, 0);
    }
}
