// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title AgentPassport
/// @notice Soulbound ERC-721 passport bound 1:1 to a SPACE ID Agent ID.
///         One Agent ID can hold at most one passport: the passport tokenId
///         IS the Agent ID tokenId (uint256(keccak256(bytes(label)))),
///         so ERC-721 uniqueness enforces the "1 per Agent ID" rule.
/// @dev Minting is free (gas only). The contract never holds BNB.
interface IAgentId {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract AgentPassport is ERC721, Ownable {
    using Strings for uint256;

    error InvalidLabel();
    error NotAgentIdHolder();
    error MintPaused();
    error Soulbound();

    IAgentId public agentId;
    bool public paused;

    struct Passport {
        string label;
        uint256 mintedAt;
    }

    mapping(uint256 => Passport) private _passports;

    event PassportMinted(
        address indexed holder,
        uint256 indexed agentIdTokenId,
        string agentIdLabel,
        uint256 mintedAt
    );
    event PausedSet(bool paused);
    event AgentIdContractSet(address indexed agentIdContract);

    constructor(address agentIdContract) ERC721("Agent Passport", "APASS") Ownable(msg.sender) {
        agentId = IAgentId(agentIdContract);
    }

    /// @notice Mint the passport for your own Agent ID label (without the ".ai" suffix).
    /// @dev Reverts unless msg.sender owns the Agent ID for `label`.
    function mint(string calldata agentIdLabel) external {
        if (paused) revert MintPaused();
        uint256 tokenId = _validateAndTokenId(agentIdLabel);
        address holder = address(0);
        try agentId.ownerOf(tokenId) returns (address owner) {
            holder = owner;
        } catch {
            revert NotAgentIdHolder();
        }
        if (holder != msg.sender) revert NotAgentIdHolder();
        _passports[tokenId] = Passport({label: agentIdLabel, mintedAt: block.timestamp});
        _safeMint(msg.sender, tokenId);
        emit PassportMinted(msg.sender, tokenId, agentIdLabel, block.timestamp);
    }

    /// @notice The Agent ID label (without ".ai") stored for a passport tokenId.
    function agentIdLabelOf(uint256 tokenId) external view returns (string memory) {
        return _passports[tokenId].label;
    }

    /// @notice The block timestamp at which a passport tokenId was minted.
    function mintedAtOf(uint256 tokenId) external view returns (uint256) {
        return _passports[tokenId].mintedAt;
    }

    /// @notice On-chain metadata. Image reuses the official Agent ID artwork
    ///         (https://agentid-nft.prd.space.id/prd/{tokenId}/image.png).
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        Passport memory p = _passports[tokenId];
        string memory json = string(
            abi.encodePacked(
                '{"name":"Agent Passport \u2014 ',
                p.label,
                '.ai","description":"Soulbound passport proving ownership of the Binance Agent ID ',
                p.label,
                '.ai. Non-transferable, one per Agent ID.","image":"https://agentid-nft.prd.space.id/prd/',
                tokenId.toString(),
                '/image.png","attributes":[{"trait_type":"Agent ID","value":"',
                p.label,
                '.ai"},{"trait_type":"Mint date","display_type":"date","value":',
                p.mintedAt.toString(),
                '},{"trait_type":"Holder","value":"',
                Strings.toHexString(ownerOf(tokenId)),
                '"}]}'
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @notice Soulbound: transfers are rejected. Minting is the only
    ///         state change that moves a token (from address(0)).
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) revert Soulbound();
        return super._update(to, tokenId, auth);
    }

    // ---- Owner functions ----

    /// @notice Emergency pause for minting only. Does not affect existing passports.
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedSet(_paused);
    }

    /// @notice Migration guard: point at a new Agent ID contract if SPACE ID
    ///         ever replaces the registry. Only callable by the owner.
    function setAgentIdContract(address agentIdContract) external onlyOwner {
        agentId = IAgentId(agentIdContract);
        emit AgentIdContractSet(agentIdContract);
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
