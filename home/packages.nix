{ pkgs, ... }:

{
  home.packages = with pkgs; [
    git tmux htop btop ripgrep fd fzf
    nmap metasploit burpsuite hashcat john wireshark-qt ghidra-bin sqlmap ffuf
    radare2 bettercap aircrack-ng empire responder android-tools
  ];
}
