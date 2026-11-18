// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AgentPassport} from "../src/AgentPassport.sol";
import {AgentTipJar} from "../src/AgentTipJar.sol";
import {MockAgentId} from "./MockAgentId.sol";

contract AgentPassportTest is Test {
    MockAgentId internal agentId;
    AgentPassport internal passport;
    AgentTipJar internal tipJar;

    address internal constant HOLDER = address(0xA11CE);
    address internal constant OTHER = address(0xB0B);
    uint256 internal constant OHRAYY_ID =
        14288174740848976714399194853367668560881175917523252271979436296426985581470;

    function setUp() public {
        agentId = new MockAgentId();
        agentId.register("ohrayy", HOLDER);
        passport = new AgentPassport(address(agentId));
        tipJar = new AgentTipJar(address(agentId));
        vm.deal(HOLDER, 10 ether);
        vm.deal(OTHER, 10 ether);
    }

    // ---- Passport mint ----

    function test_mintSucceedsForHolder() public {
        vm.prank(HOLDER);
        passport.mint("ohrayy");
        assertEq(passport.ownerOf(OHRAYY_ID), HOLDER);
        assertEq(passport.balanceOf(HOLDER), 1);
        assertEq(passport.agentIdLabelOf(OHRAYY_ID), "ohrayy");
        assertEq(passport.mintedAtOf(OHRAYY_ID), block.timestamp);
    }

    function test_mintRevertsForNonHolder() public {
        vm.prank(OTHER);
        vm.expectRevert(AgentPassport.NotAgentIdHolder.selector);
        passport.mint("ohrayy");
    }

    function test_mintRevertsForNonexistentName() public {
        vm.prank(HOLDER);
        vm.expectRevert(AgentPassport.NotAgentIdHolder.selector);
        passport.mint("nama-yang-tidak-ada-xyz");
    }

    function test_mintRevertsForInvalidLabel() public {
        vm.prank(HOLDER);
        vm.expectRevert(AgentPassport.InvalidLabel.selector);
        passport.mint("OHRAYY"); // uppercase not allowed
        vm.prank(HOLDER);
        vm.expectRevert(AgentPassport.InvalidLabel.selector);
        passport.mint("");
    }

    function test_secondMintOfSameAgentIdReverts() public {
        vm.prank(HOLDER);
        passport.mint("ohrayy");
        vm.prank(HOLDER);
        vm.expectRevert();
        passport.mint("ohrayy");
    }

    function test_mintRevertsWhenPaused() public {
        passport.setPaused(true);
        vm.prank(HOLDER);
        vm.expectRevert(AgentPassport.MintPaused.selector);
        passport.mint("ohrayy");
    }

    // ---- Soulbound ----

    function test_transferFromReverts() public {
        vm.prank(HOLDER);
        passport.mint("ohrayy");
        vm.prank(HOLDER);
        vm.expectRevert(AgentPassport.Soulbound.selector);
        passport.transferFrom(HOLDER, OTHER, OHRAYY_ID);
    }

    function test_safeTransferFromReverts() public {
        vm.prank(HOLDER);
        passport.mint("ohrayy");
        vm.prank(HOLDER);
        vm.expectRevert(AgentPassport.Soulbound.selector);
        passport.safeTransferFrom(HOLDER, OTHER, OHRAYY_ID);
    }

    // ---- tokenURI ----

    function test_tokenURIContainsLabelAndMintDate() public {
        vm.warp(1795000000);
        vm.prank(HOLDER);
        passport.mint("ohrayy");
        string memory uri = passport.tokenURI(OHRAYY_ID);
        // data:application/json;base64,... — decode and check contents
        bytes memory decoded = _decodeBase64AfterPrefix(uri);
        string memory json = string(decoded);
        assertTrue(_contains(json, "ohrayy.ai"));
        assertTrue(_contains(json, "1795000000"));
        assertTrue(_contains(json, "Agent Passport"));
        assertTrue(_contains(json, "image.png"));
    }

    // ---- Owner controls ----

    function test_ownerCanPauseAndNonOwnerCannot() public {
        passport.setPaused(true);
        assertTrue(passport.paused());
        vm.prank(OTHER);
        vm.expectRevert();
        passport.setPaused(false);
    }

    function test_ownerCanSetAgentIdContractAndNonOwnerCannot() public {
        passport.setAgentIdContract(address(0x1234));
        assertEq(address(passport.agentId()), address(0x1234));
        vm.prank(OTHER);
        vm.expectRevert();
        passport.setAgentIdContract(address(0x5678));
    }

    // ---- TipJar ----

    function test_tipForwardsFullAmount() public {
        uint256 amount = 0.001 ether;
        uint256 before = HOLDER.balance;
        vm.prank(OTHER);
        tipJar.tip{value: amount}("ohrayy");
        assertEq(HOLDER.balance - before, amount);
        assertEq(address(tipJar).balance, 0);
    }

    function test_tipEmitsEvent() public {
        vm.prank(OTHER);
        vm.expectEmit(true, true, false, true, address(tipJar));
        emit AgentTipJar.Tip(OTHER, HOLDER, "ohrayy", 0.001 ether, block.timestamp);
        tipJar.tip{value: 0.001 ether}("ohrayy");
    }

    function test_tipRevertsBelowMinTip() public {
        vm.prank(OTHER);
        vm.expectRevert(abi.encodeWithSelector(AgentTipJar.TipTooSmall.selector, 0.0001 ether));
        tipJar.tip{value: 0.00001 ether}("ohrayy");
    }

    function test_tipRevertsForNonexistentName() public {
        vm.prank(OTHER);
        vm.expectRevert(AgentTipJar.AgentIdNotFound.selector);
        tipJar.tip{value: 0.001 ether}("nama-yang-tidak-ada-xyz");
    }

    function test_tipRevertsForInvalidLabel() public {
        vm.prank(OTHER);
        vm.expectRevert(AgentTipJar.InvalidLabel.selector);
        tipJar.tip{value: 0.001 ether}("OHRAYY");
    }

    function test_directTransferReverts() public {
        vm.prank(OTHER);
        (bool ok, ) = address(tipJar).call{value: 0.001 ether}("");
        assertFalse(ok);
    }

    function test_ownerCanSetMinTipAndNonOwnerCannot() public {
        tipJar.setMinTip(0.001 ether);
        assertEq(tipJar.minTip(), 0.001 ether);
        vm.prank(OTHER);
        vm.expectRevert();
        tipJar.setMinTip(0.002 ether);
    }

    // ---- helpers ----

    function _decodeBase64AfterPrefix(string memory uri) internal pure returns (bytes memory) {
        bytes memory b = bytes(uri);
        bytes memory prefix = bytes("data:application/json;base64,");
        require(b.length > prefix.length, "bad uri");
        bytes memory payload = new bytes(b.length - prefix.length);
        for (uint256 i = 0; i < payload.length; i++) payload[i] = b[prefix.length + i];
        return _base64Decode(payload);
    }

    function _base64Decode(bytes memory data) internal pure returns (bytes memory) {
        bytes memory table = bytes("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/");
        uint8[256] memory rev;
        for (uint256 i = 0; i < 64; i++) rev[uint8(table[i])] = uint8(i);
        uint256 outLen = (data.length * 3) / 4;
        if (data.length > 0 && data[data.length - 1] == bytes1("=")) outLen--;
        if (data.length > 1 && data[data.length - 2] == bytes1("=")) outLen--;
        bytes memory out = new bytes(outLen);
        uint256 j;
        for (uint256 i = 0; i < data.length; i += 4) {
            uint256 n = (uint256(rev[uint8(data[i])]) << 18)
                | (uint256(rev[uint8(data[i + 1])]) << 12)
                | (uint256(rev[uint8(data[i + 2])]) << 6)
                | uint256(rev[uint8(data[i + 3])]);
            if (j < outLen) out[j++] = bytes1(uint8(n >> 16));
            if (j < outLen) out[j++] = bytes1(uint8(n >> 8));
            if (j < outLen) out[j++] = bytes1(uint8(n));
        }
        return out;
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool found = true;
            for (uint256 k = 0; k < n.length; k++) {
                if (h[i + k] != n[k]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}
