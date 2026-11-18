// Agent Passport dApp — plain static JS, ethers v6 via CDN.
// Semua transaksi dikonfirmasi pengguna di dompetnya sendiri.
// TIDAK ada direktori / pencarian nama-ke-alamat: tip hanya menyelesaikan
// nama yang diketik pengguna untuk mengirim pembayaran itu.

const $ = (id) => document.getElementById(id);
const ZERO = "0x0000000000000000000000000000000000000000";
const isDeployed = (addr) => addr && addr.toLowerCase() !== ZERO;

let provider = null;      // BrowserProvider (dompet pengguna)
let signer = null;
let account = null;
let readProvider = null;  // JsonRpcProvider publik untuk baca event
let agentIdContract = null;
let passportContract = null;
let tipJarContract = null;
let verifiedLabel = null; // label yang sudah diverifikasi milik pengguna
let tipRecipient = null;   // { label, address } hasil preview tip
let minTipWei = null;

function shortAddr(a) { return a.slice(0, 6) + "…" + a.slice(-4); }
function show(el, on) { el.classList.toggle("hidden", !on); }
function setText(id, txt) { $(id).textContent = txt; }
function fmtDate(ts) { return new Date(Number(ts) * 1000).toLocaleString("id-ID"); }
function fmtBnb(wei) { return Number(ethers.formatEther(wei)).toLocaleString("id-ID", { maximumFractionDigits: 6 }); }

// Nama Agent ID -> tokenId: uint256(keccak256(bytes(label)))
function labelToTokenId(label) {
  return BigInt(ethers.keccak256(ethers.toUtf8Bytes(label)));
}
function normalizeLabel(raw) {
  let s = (raw || "").trim().toLowerCase();
  if (s.endsWith(".ai")) s = s.slice(0, -3);
  return s;
}

// ---------- Setup ----------
function initReadContracts() {
  readProvider = new ethers.JsonRpcProvider(CONFIG.rpcUrl, CONFIG.chainId);
  agentIdContract = new ethers.Contract(CONFIG.agentIdContract, CONFIG.agentIdAbi, readProvider);
  if (isDeployed(CONFIG.passportContract)) {
    passportContract = new ethers.Contract(CONFIG.passportContract, CONFIG.passportAbi, readProvider);
  }
  if (isDeployed(CONFIG.tipJarContract)) {
    tipJarContract = new ethers.Contract(CONFIG.tipJarContract, CONFIG.tipJarAbi, readProvider);
  }
}

async function resolveAgentIdOwner(label) {
  // Mengembalikan alamat pemilik, atau null bila nama belum terdaftar (ownerOf revert).
  try {
    return await agentIdContract.ownerOf(labelToTokenId(label));
  } catch (e) {
    return null;
  }
}

// ---------- 1. Connect wallet ----------
async function connectWallet() {
  if (!window.ethereum) {
    setText("walletStatus", "Tidak ada dompet terdeteksi. Buka halaman ini dari browser dompet kamu (mis. di aplikasi dompet) lalu coba lagi.");
    return;
  }
  try {
    provider = new ethers.BrowserProvider(window.ethereum);
    const accounts = await provider.send("eth_requestAccounts", []);
    account = accounts[0];
    signer = await provider.getSigner();

    const net = await provider.getNetwork();
    if (Number(net.chainId) !== CONFIG.chainId) {
      setText("chainStatus", "Jaringan bukan BSC (56). Mencoba pindah jaringan…");
      show($("chainStatus"), true);
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: "0x" + CONFIG.chainId.toString(16) }]
        });
        setText("chainStatus", "Jaringan: BSC (56).");
      } catch (e) {
        setText("chainStatus", "Gagal pindah ke BSC. Silakan pindah jaringan ke BSC (56) secara manual di dompet kamu.");
        return;
      }
    } else {
      setText("chainStatus", "Jaringan: BSC (56).");
      show($("chainStatus"), true);
    }

    setText("walletStatus", "Terhubung: " + shortAddr(account));
    $("connectBtn").textContent = "Terhubung";
    $("connectBtn").disabled = true;
    show($("passportCard"), true);
    await checkAgentId();
    await loadMinTip();
    await refreshLeaderboard();
  } catch (e) {
    console.error(e);
    setText("walletStatus", "Gagal menghubungkan dompet. Coba lagi.");
  }
}

// ---------- 2. Agent ID status + mint ----------
async function checkAgentId() {
  setText("agentIdStatus", "Memeriksa Agent ID…");
  show($("verifyBox"), false);
  show($("mintBox"), false);
  show($("myPassportBox"), false);
  show($("noAgentIdBox"), false);

  let bal;
  try {
    bal = await agentIdContract.balanceOf(account);
  } catch (e) {
    console.error(e);
    setText("agentIdStatus", "Gagal memeriksa Agent ID. Coba refresh halaman.");
    return;
  }

  if (bal === 0n) {
    setText("agentIdStatus", "Alamat ini tidak punya Agent ID.");
    show($("noAgentIdBox"), true);
    return;
  }

  setText("agentIdStatus", "Alamat ini punya Agent ID.");
  show($("verifyBox"), true);

  // Sudah punya Passport?
  if (passportContract) {
    try {
      const myBal = await passportContract.balanceOf(account);
      if (myBal > 0n) {
        // Token Passport memakai tokenId yang sama dengan Agent ID.
        // Coba baca label dari token pertama: cari dari label yang sudah diverifikasi
        // tidak mungkin tanpa label, jadi dApp membaca lewat event PassportMinted.
        const events = await passportContract.queryFilter(
          passportContract.filters.PassportMinted(account),
          CONFIG.passportDeployBlock || 0
        );
        if (events.length > 0) {
          const last = events[events.length - 1];
          show($("verifyBox"), false);
          show($("myPassportBox"), true);
          setText("myPassportName", last.args.agentIdLabel + ".ai");
          setText("myPassportDate", fmtDate(last.args.mintedAt));
          return;
        }
      }
    } catch (e) {
      console.error("Gagal memeriksa Passport:", e);
    }
  } else {
    show($("notDeployedPassport"), true);
  }
}

async function verifyName() {
  const label = normalizeLabel($("labelInput").value);
  if (!label) { setText("verifyResult", "Isi dulu nama Agent ID kamu."); return; }
  setText("verifyResult", "Memeriksa…");
  const owner = await resolveAgentIdOwner(label);
  if (!owner) {
    setText("verifyResult", "Nama ini belum terdaftar sebagai Agent ID.");
    return;
  }
  if (owner.toLowerCase() !== account.toLowerCase()) {
    setText("verifyResult", "Nama ini bukan Agent ID kamu. Nama ini milik " + shortAddr(owner) + ".");
    return;
  }
  verifiedLabel = label;
  setText("verifiedName", "Terverifikasi: " + label + ".ai milik kamu.");
  show($("mintBox"), true);
  setText("verifyResult", "");
  $("mintBtn").disabled = !isDeployed(CONFIG.passportContract);
  if (!isDeployed(CONFIG.passportContract)) show($("notDeployedPassport"), true);
}

async function mintPassport() {
  if (!verifiedLabel) { setText("mintStatus", "Verifikasi dulu nama Agent ID kamu."); return; }
  if (!isDeployed(CONFIG.passportContract)) {
    setText("mintStatus", "Kontrak Passport belum di-deploy.");
    return;
  }
  setText("mintStatus", "Mengirim transaksi… konfirmasi di dompet kamu.");
  try {
    const contract = new ethers.Contract(CONFIG.passportContract, CONFIG.passportAbi, signer);
    const tx = await contract.mint(verifiedLabel);
    setText("mintStatus", "Transaksi dikirim: " + tx.hash + " — menunggu konfirmasi…");
    const receipt = await tx.wait();
    if (receipt.status === 1) {
      setText("mintStatus", "Berhasil! Passport untuk " + verifiedLabel + ".ai sudah di-mint.");
      show($("mintBox"), false);
      await checkAgentId();
      await refreshLeaderboard();
    } else {
      setText("mintStatus", "Transaksi gagal di jaringan. Coba lagi.");
    }
  } catch (e) {
    console.error(e);
    setText("mintStatus", parseMintError(e));
  }
}

function parseMintError(e) {
  const msg = (e && (e.reason || e.message || "")) + "";
  if (/already/i.test(msg)) return "Kamu sudah mint Passport untuk Agent ID ini.";
  if (/not.*owner|not your|bukan/i.test(msg)) return "Nama ini bukan Agent ID kamu.";
  if (e && e.code === "ACTION_REJECTED") return "Transaksi dibatalkan di dompet.";
  return "Gagal mint Passport. Coba lagi.";
}

// ---------- 3. Tip ----------
async function loadMinTip() {
  if (!tipJarContract) { setText("minTipLabel", "0,0001"); return; }
  try {
    minTipWei = await tipJarContract.minTip();
    setText("minTipLabel", fmtBnb(minTipWei));
  } catch (e) {
    console.error(e);
    setText("minTipLabel", "0,0001");
  }
}

async function previewTip() {
  const label = normalizeLabel($("tipNameInput").value);
  if (!label) { setText("tipStatus", "Isi dulu nama Agent ID penerima."); return; }
  const amountStr = $("tipAmountInput").value;
  if (!amountStr || Number(amountStr) <= 0) { setText("tipStatus", "Isi jumlah tip dalam BNB."); return; }

  let amountWei;
  try { amountWei = ethers.parseEther(amountStr); } catch (e) { setText("tipStatus", "Jumlah tidak valid."); return; }

  const min = minTipWei ?? ethers.parseEther("0.0001");
  if (amountWei < min) {
    setText("tipStatus", "Jumlah di bawah minimum (" + fmtBnb(min) + " BNB).");
    return;
  }

  setText("tipStatus", "Memeriksa penerima…");
  const owner = await resolveAgentIdOwner(label);
  if (!owner) {
    setText("tipStatus", "Nama .ai ini belum terdaftar.");
    show($("tipPreview"), false);
    return;
  }
  tipRecipient = { label, address: owner, amountWei };
  setText("tipPreviewName", label + ".ai");
  setText("tipPreviewAddr", shortAddr(owner) + " (" + owner + ")");
  setText("tipPreviewOk", "terverifikasi pegang Agent ID");
  show($("tipPreview"), true);
  setText("tipStatus", "");
}

async function sendTip() {
  if (!tipRecipient) { setText("tipStatus", "Cek penerima dulu."); return; }
  if (!isDeployed(CONFIG.tipJarContract)) {
    setText("tipStatus", "Kontrak TipJar belum di-deploy.");
    return;
  }
  if (!signer) { setText("tipStatus", "Hubungkan dompet dulu."); return; }
  setText("tipStatus", "Mengirim tip… konfirmasi di dompet kamu.");
  try {
    const contract = new ethers.Contract(CONFIG.tipJarContract, CONFIG.tipJarAbi, signer);
    const tx = await contract.tip(tipRecipient.label, { value: tipRecipient.amountWei });
    setText("tipStatus", "Transaksi dikirim: " + tx.hash + " — menunggu konfirmasi…");
    const receipt = await tx.wait();
    if (receipt.status === 1) {
      setText("tipStatus", "Tip terkirim! " + fmtBnb(tipRecipient.amountWei) + " BNB ke " + tipRecipient.label + ".ai.");
      show($("tipPreview"), false);
      tipRecipient = null;
      await refreshLeaderboard();
    } else {
      setText("tipStatus", "Transaksi gagal di jaringan. Coba lagi.");
    }
  } catch (e) {
    console.error(e);
    if (e && e.code === "ACTION_REJECTED") setText("tipStatus", "Transaksi dibatalkan di dompet.");
    else if (/below|minimum|min/i.test(e.reason || e.message || "")) setText("tipStatus", "Jumlah di bawah minimum.");
    else setText("tipStatus", "Gagal mengirim tip. Coba lagi.");
  }
}

// ---------- 4. Leaderboard ----------
async function refreshLeaderboard() {
  if (!isDeployed(CONFIG.passportContract) && !isDeployed(CONFIG.tipJarContract)) {
    show($("leaderboardEmpty"), true);
    show($("leaderboardBody"), false);
    setText("leaderboardStatus", "");
    return;
  }
  show($("leaderboardEmpty"), false);
  show($("leaderboardBody"), true);
  setText("leaderboardStatus", "Memuat…");
  try {
    let holders = new Set();
    let tipCount = 0;
    let tipTotal = 0n;
    let recentTips = [];
    let recentMints = [];

    if (passportContract) {
      const mints = await passportContract.queryFilter(
        passportContract.filters.PassportMinted(),
        CONFIG.passportDeployBlock || 0
      );
      mints.forEach((ev) => holders.add(ev.args.holder.toLowerCase()));
      recentMints = mints.slice(-10).reverse();
    }
    if (tipJarContract) {
      const tips = await tipJarContract.queryFilter(
        tipJarContract.filters.Tip(),
        CONFIG.tipJarDeployBlock || 0
      );
      tipCount = tips.length;
      tips.forEach((ev) => { tipTotal += BigInt(ev.args.amount); });
      recentTips = tips.slice(-10).reverse();
    }

    setText("statHolders", String(holders.size));
    setText("statTipCount", String(tipCount));
    setText("statTipBnb", fmtBnb(tipTotal));

    $("recentTips").innerHTML = recentTips.length
      ? recentTips.map((ev) =>
          `<li>${shortAddr(ev.args.from)} → <strong>${ev.args.agentIdLabel}.ai</strong> — ${fmtBnb(ev.args.amount)} BNB<br><span class="muted">${fmtDate(ev.args.timestamp)}</span></li>`
        ).join("")
      : `<li class="muted">Belum ada tip.</li>`;

    $("recentMints").innerHTML = recentMints.length
      ? recentMints.map((ev) =>
          `<li><strong>${ev.args.agentIdLabel}.ai</strong> — ${shortAddr(ev.args.holder)}<br><span class="muted">${fmtDate(ev.args.mintedAt)}</span></li>`
        ).join("")
      : `<li class="muted">Belum ada mint.</li>`;

    setText("leaderboardStatus", "Terakhir diperbarui: " + new Date().toLocaleTimeString("id-ID"));
  } catch (e) {
    console.error(e);
    setText("leaderboardStatus", "Gagal memuat leaderboard. Coba Refresh.");
  }
}

// ---------- Wiring ----------
document.addEventListener("DOMContentLoaded", () => {
  initReadContracts();
  $("connectBtn").addEventListener("click", connectWallet);
  $("verifyBtn").addEventListener("click", verifyName);
  $("mintBtn").addEventListener("click", mintPassport);
  $("previewTipBtn").addEventListener("click", previewTip);
  $("sendTipBtn").addEventListener("click", sendTip);
  $("refreshBtn").addEventListener("click", refreshLeaderboard);
  // Leaderboard juga dimuat walau dompet belum terhubung (kontrak placeholder -> pesan).
  refreshLeaderboard();
  // Auto-refresh leaderboard tiap 30 detik.
  setInterval(refreshLeaderboard, 30000);
});
