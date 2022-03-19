#!/bin/bash

source common.sh

if [ -e /etc/arch-release ]; then
    OS="arch"
else
    info "Your operating system is unsupported"
    exit 1
fi

if [ ${OS} == "arch" ]; then
    info "Installing dependencies for Arch Linux"
    # Officialy required
    sudo pacman -S --needed --noconfirm base-devel ncurses zlib gawk git gettext openssl libxslt wget unzip python
    # Additional
    sudo pacman -S --needed --noconfirm rsync
fi
