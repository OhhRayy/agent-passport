# Agent Passport

Soulbound passport + tip-by-name for Binance Agent ID holders on BNB Chain.

Built for the **Binance Agent ID Hackathon** (18 Nov – 9 Dec 2026).

## What it is

Every Binance Agent ID (e.g. `ohrayy.ai`) is an ERC-721 token on BNB Smart
Chain. **Agent Passport** turns that identity into two on-chain utilities:

1. **AgentPassport** — a free, soulbound (non-transferable) ERC-721 passport,
   one per Agent ID. Minting proves you own the Agent ID, on-chain.
2. **AgentTipJar** — tip any Agent ID holder by name (`ohrayy`, not a
   `0x...` address). Zero fee: the full tip is forwarded to the holder.

No fees, no token sale, no promised returns. Minting is free (gas only);
tips go 100% to the recipient.

## How Agent ID is used

SPACE ID Agent ID is an ERC-721 registry on BSC (chain 56):

- Contract: `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`
- `name()` = "SPACE ID Agent ID", `symbol()` = "AI"
- **Token ID rule:** `tokenId = uint256(keccak256(bytes(label)))` — the label
  is the name without the `.ai` suffix (e.g. `"ohrayy"`).
- Any `.ai` name resolves to an address with **one** `eth_call`:
  `ownerOf(uint256(keccak256(bytes(label))))`. If the name does not exist,
  `ownerOf` reverts.
- The passport tokenId **is** the Agent ID tokenId, so "1 passport per
  Agent ID" is enforced by ERC-721 uniqueness itself — no extra registry.

Verified on-chain 18 Nov 2026: `ownerOf(keccak256("ohrayy"))` =
`0xD6768Ff0aC2Acc72bF650283928c1f682217caBA` (Agent ID `ohrayy.ai`).

## Contracts

| Contract | Description |
|---|---|
| `AgentPassport` | ERC-721 "Agent Passport" (`APASS`), soulbound. `mint(string label)` — free, only if `msg.sender` owns the Agent ID for `label`. `tokenURI` is fully on-chain (`data:application/json;base64`) and reuses the official Agent ID artwork. |
| `AgentTipJar` | `tip(string label)` payable — forwards the **full** `msg.value` to the Agent ID owner. Minimum tip 0.0001 BNB (anti-spam). Direct BNB transfers revert; the contract never holds funds, so there is no withdraw. |

### Key functions (dApp ABI surface)

```solidity
// AgentPassport
mint(string calldata agentIdLabel)
tokenURI(uint256 tokenId) -> string
balanceOf(address) -> uint256
ownerOf(uint256) -> address
agentIdLabelOf(uint256) -> string
mintedAtOf(uint256) -> uint256

// AgentTipJar
tip(string calldata agentIdLabel) payable
minTip() -> uint256
event Tip(address indexed from, address indexed to, string agentIdLabel, uint256 amount, uint256 timestamp)
```

### Owner permissions

The deployer is the initial owner of both contracts (OpenZeppelin `Ownable`).
Every owner function, and what it can and cannot do:

| Function | Contract | What it can do | What it CANNOT do |
|---|---|---|---|
| `setPaused(bool)` | AgentPassport | Emergency-pause minting | Affect existing passports, move or burn any token |
| `setAgentIdContract(address)` | AgentPassport | Point at a replacement Agent ID registry if SPACE ID ever migrates it | Mint passports, move tokens, touch funds |
| `setMinTip(uint256)` | AgentTipJar | Change the minimum tip (default 0.0001 BNB) | Take a fee, redirect tips, withdraw anything |
| `transferOwnership(address)` | Both | Hand ownership to a new address | Mint, move tokens, or access funds (there are none to access) |

Neither contract can hold BNB: the passport charges nothing, and the tip jar
forwards 100% of every tip in the same call. There is no `withdraw`
function anywhere, no fee parameter, and no burn function.

## Contract addresses

> **TBD — NOT deployed yet.** Contracts are written, tested, and measured on
> a local chain only. Addresses will be filled in here after the deployer
> wallet is funded and deployment is approved.

| Contract | BSC mainnet address |
|---|---|
| AgentPassport | TBD |
| AgentTipJar | TBD |
| Agent ID registry | `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` |

## Tests

```bash
forge test                                                  # unit tests (mock Agent ID)
forge test --match-path test/AgentPassport.fork.t.sol \
  --fork-url https://bsc-dataseed.binance.org/              # fork tests vs the real registry
```

23 tests, all passing (18 unit + 5 fork). The fork tests prove the real
gating works: mint succeeds when pranking the real `ohrayy` holder
(`0xD6768Ff0aC2Acc72bF650283928c1f682217caBA`) and reverts for a random
non-holder and for a nonexistent name.

## Deploy

```bash
# Dry run (no broadcast)
forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.binance.org/

# Deploy to BSC mainnet (needs a funded deployer key; DO NOT run before approval)
forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.binance.org/ \
  --broadcast --private-key $PRIVATE_KEY
```

### Deployment gas (measured on local anvil, chain 56)

| Contract | Gas used |
|---|---|
| AgentPassport | 3,194,212 |
| AgentTipJar | 822,188 |
| **Total** | **4,016,400** |

| Gas price | Total cost |
|---|---|
| 0.05 gwei (observed BSC, 18 Nov 2026) | **0.00020082 BNB** |
| 1 gwei | 0.0040164 BNB |

The deployer wallet holds ~0.000427 BNB: that **covers** deployment at
0.05 gwei (leaving ~0.000226 BNB), but at 1 gwei a top-up of ~0.0036 BNB
would be needed.

## Hackathon context

Entry for the Binance Agent ID Hackathon. The project is live on BSC,
uses Agent ID as its identity layer (every passport and every tip is
resolved through the Agent ID registry), and is fully open-source under
MIT. The dApp (static site) lives in a separate repo/directory and is
merged here later.

## License

MIT — see [LICENSE](LICENSE).
