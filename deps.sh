#!/bin/bash

source functions.sh

### Determine the operating system

if [[ -e /etc/arch-release ]]; then
    os="arch"
elif [[ -e /etc/redhat-release ]]; then
    os="rhel"
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
elif [[ $os == "rhel" ]]; then
    info "Installing dependencies for Red Hat Enterprise Linux"
    sudo dnf install git gawk gettext ncurses-devel zlib-devel \
    openssl-devel libxslt wget which @c-development @development-tools \
    @development-libs zlib-static which python3
fi

###
