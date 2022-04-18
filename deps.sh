#!/bin/bash

source common.sh

### Determine the operating system

if [[ -e /etc/arch-release ]]; then
    os="arch"
else
    error "Your operating system is unsupported"
    exit 1
fi

###

### Install dependencies

if [[ $os == "arch" ]]; then
    info "Installing dependencies for Arch Linux"
    sudo pacman -S --needed --noconfirm \
    base-devel ncurses zlib gawk git gettext openssl libxslt wget unzip python \
    rsync ca-certificates
fi

###
