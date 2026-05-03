{ pkgs, ... }:

{
  home.packages = with pkgs; [
    git tmux htop btop ripgrep fd fzf
    nmap metasploit burpsuite hashcat john wireshark-qt ghidra sqlmap ffuf
    radare2 bettercap aircrack-ng android-tools
  ];
}
