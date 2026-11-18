// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title AgentTipJar
/// @notice Tip any Agent ID holder by name. Zero fee: the full msg.value
///         is forwarded to the Agent ID owner in the same call.
/// @dev The contract never holds funds, so there is no withdraw function.
///      Direct BNB transfers are rejected; BNB can only arrive via tip().
interface IAgentId {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract AgentTipJar is Ownable {
    error InvalidLabel();
    error AgentIdNotFound();
    error TipTooSmall(uint256 minTip);
    error DirectTransferNotAllowed();
    error TipFailed();

    IAgentId public agentId;
    uint256 public minTip = 0.0001 ether;

    event Tip(
        address indexed from,
        address indexed to,
        string agentIdLabel,
        uint256 amount,
        uint256 timestamp
    );
    event MinTipSet(uint256 minTip);

    constructor(address agentIdContract) Ownable(msg.sender) {
        agentId = IAgentId(agentIdContract);
    }

    /// @notice Tip the owner of `agentIdLabel` (without the ".ai" suffix).
    ///         The full msg.value is forwarded to the recipient.
    function tip(string calldata agentIdLabel) external payable {
        uint256 tokenId = _validateAndTokenId(agentIdLabel);
        address recipient = address(0);
        try agentId.ownerOf(tokenId) returns (address owner) {
            recipient = owner;
        } catch {
            revert AgentIdNotFound();
        }
        if (msg.value < minTip) revert TipTooSmall(minTip);
        (bool ok, ) = recipient.call{value: msg.value}("");
        if (!ok) revert TipFailed();
        emit Tip(msg.sender, recipient, agentIdLabel, msg.value, block.timestamp);
    }

    /// @notice Direct BNB transfers are not accepted; use tip() so the
    ///         funds always reach a named Agent ID holder.
    receive() external payable {
        revert DirectTransferNotAllowed();
    }

    fallback() external payable {
        revert DirectTransferNotAllowed();
    }

    // ---- Owner functions ----

    /// @notice Update the minimum tip (anti-spam floor). Default 0.0001 ether.
    function setMinTip(uint256 _minTip) external onlyOwner {
        minTip = _minTip;
        emit MinTipSet(_minTip);
    }

    // ---- Internal ----

    /// @dev Validates a label (1-64 bytes, [a-z0-9-]) and returns its tokenId.
    function _validateAndTokenId(string calldata label) internal pure returns (uint256) {
        bytes calldata b = bytes(label);
        if (b.length == 0 || b.length > 64) revert InvalidLabel();
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            bool ok = (c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39) || c == 0x2d;
            if (!ok) revert InvalidLabel();
        }
        return uint256(keccak256(bytes(label)));
    }
}
