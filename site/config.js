// Agent Passport — konfigurasi dApp
// Semua alamat kontrak masih PLACEHOLDER sampai kontrak di-deploy.
// Ganti nilai di bawah dengan alamat hasil deploy, lalu isi deployBlock.
// Alamat placeholder 0x000...000 membuat UI menampilkan "kontrak belum di-deploy".

const CONFIG = {
  chainId: 56, // BSC mainnet
  rpcUrl: "https://bsc-dataseed.binance.org/",

  // SPACE ID Agent ID (ERC-721), sudah live di BSC
  agentIdContract: "0x60b9262456de011f7d15a54cdd8c48baaa8b022f",

  // Placeholder — isi setelah deploy
  passportContract: "0x0000000000000000000000000000000000000000",
  tipJarContract: "0x0000000000000000000000000000000000000000",

  // Blok deploy kontrak (0 = belum di-deploy; isi setelah deploy agar
  // eth_getLogs leaderboard hanya membaca dari blok yang relevan)
  passportDeployBlock: 0,
  tipJarDeployBlock: 0,

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
