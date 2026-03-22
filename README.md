# 🎚️ LEGENDDOTS: RED TEAM COMMAND & CONTROL

<p align="center">
  <img src="https://neovim.io/logos/neovim-logo.png" width="220" alt="Neovim Logo">
</p>

<p align="center">
  <strong>"Minimalism is a defensive posture."</strong><br>
  <em>A hardened, Lua-powered identity configuration for cross-platform operations.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Gentoo-purple?style=for-the-badge&logo=gentoo&logoColor=white">
  <img src="https://img.shields.io/badge/Guix-white?style=for-the-badge&logo=gnu&logoColor=black">
  <img src="https://img.shields.io/badge/Neovim-06b6d4?style=for-the-badge&logo=neovim&logoColor=white">
  <img src="https://img.shields.io/badge/Lua-2c2d72?style=for-the-badge&logo=lua&logoColor=white">
  <img src="https://img.shields.io/badge/Alacritty-FF4F00?style=for-the-badge&logo=alacritty&logoColor=white">
  <img src="https://img.shields.io/badge/Zsh-black?style=for-the-badge&logo=zsh&logoColor=white">
</p>

---

## ⚡ The Manifesto
This repository contains a high-performance environment optimized for **Red Team operations** and **system engineering**. It is designed to run natively on Hardened Gentoo, Arch Linux, and Termux (Mobile C2).

Every byte is curated. No telemetry. No Electron-based bloat. Just pure, deterministic execution.

---

## 🛠️ Core Components

### 🖥️ Neovim C2 Dashboard
The primary interface for system manipulation and reconnaissance:
- `[f]` **Fuzzy Finder** — High-speed filesystem indexing.
- `[g]` **The Lab (Git)** — Integrated `lazygit` for persistence management.
- `[l]` **LFS Book** — Transactional access to the LFS manual via `w3m`.
- `[c]` **Identity Config** — Self-optimizing `init.lua` environment.
- `[n]` **Network Recon** — Terminal buffer `nmap` integration.

### 🐚 The Shell (Zsh)
- **Plugin Management:** Powered by `zinit`.
- **Feedback Loop:** Integrated with the `mommy` praise-engine for positive operational reinforcement.
- **Portability:** Path-agnostic logic for both phone and desktop environments.

### 📟 Terminal (Alacritty)
- **Configuration:** `alacritty.toml` (v0.13+ syntax).
- **Aesthetic:** TokyoNight-Night with 95% tactical transparency.

---

## 🚫 The Wall of Shame
```text
+-----------------------+
|       F U C K         |
|      V S  C O D E     |
+-----------------------+
```
If your editor collects metadata on your keystrokes, you don't own your machine. You are a guest on it.

---

## 🚀 Deployment

```bash
git clone https://github.com/legendarymsr/legenddots.git ~/.config/legenddots
```

*Operational Note: Relative line numbers are enabled. If you cannot calculate line-jumps, stick to a GUI.*