// Agent Passport — konfigurasi dApp
// Kontrak sudah di-deploy di BSC mainnet 2026-11-18 (lihat alamat di bawah).

const CONFIG = {
  chainId: 56, // BSC mainnet
  rpcUrl: "https://bsc-dataseed.binance.org/",

  // SPACE ID Agent ID (ERC-721), sudah live di BSC
  agentIdContract: "0x60b9262456de011f7d15a54cdd8c48baaa8b022f",

  // Deployed 2026-11-18 (BSC mainnet)
  passportContract: "0x278807630Cf4f4ac1725bd9Fd8E5D4AbeA7F588F",
  tipJarContract: "0xBD39d75710CB91291f1AB42BbFA10D2dc1F1048E",

  // Blok deploy kontrak
  passportDeployBlock: 134325653,
  tipJarDeployBlock: 134325980,

  // ABI minimal yang dipakai dApp
  agentIdAbi: [
    "function balanceOf(address owner) view returns (uint256)",
    "function ownerOf(uint256 tokenId) view returns (address)"
  ],
  passportAbi: [
    "function mint(string agentIdLabel)",
    "function tokenURI(uint256 tokenId) view returns (string)",
    "function balanceOf(address owner) view returns (uint256)",
    "function ownerOf(uint256 tokenId) view returns (address)",
    "function agentIdLabelOf(uint256 tokenId) view returns (string)",
    "function mintedAtOf(uint256 tokenId) view returns (uint256)",
    "event PassportMinted(address indexed holder, uint256 indexed agentIdTokenId, string agentIdLabel, uint256 mintedAt)"
  ],
  tipJarAbi: [
    "function tip(string agentIdLabel) payable",
    "function minTip() view returns (uint256)",
    "event Tip(address indexed from, address indexed to, string agentIdLabel, uint256 amount, uint256 timestamp)"
  ]
};
