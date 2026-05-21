#!/bin/sh
# auto-launch installer when root logs into tty1
if [ "$(id -u)" -eq 0 ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec caulk-install
fi
