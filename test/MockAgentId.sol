// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal ERC-721 mock of the SPACE ID Agent ID registry.
///         tokenId = uint256(keccak256(bytes(label))) — same rule as mainnet.
contract MockAgentId {
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    function register(string calldata label, address owner) external {
        uint256 tokenId = uint256(keccak256(bytes(label)));
        require(_owners[tokenId] == address(0), "already registered");
        _owners[tokenId] = owner;
        _balances[owner] += 1;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "nonexistent token");
        return owner;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    function tokenURI(uint256 tokenId) external pure returns (string memory) {
        return string(abi.encodePacked("https://agentid.prd.space.id/metadata/", _toHex(tokenId), ".json"));
    }

    function _toHex(uint256 v) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory out = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            out[63 - i * 2] = alphabet[v & 0xf];
            out[62 - i * 2] = alphabet[(v >> 4) & 0xf];
            v >>= 8;
        }
        return string(out);
    }
}
