#!/bin/bash

source functions.sh

### Determine the operating system

if [[ -e /etc/arch-release ]]; then
    os="arch"
elif [[ -e /etc/redhat-release ]]; then
    os="rhel"
elif grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    os="ubuntu"
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
elif [[ $os == "ubuntu" ]]; then
    info "Installing dependencies for Ubuntu"
    sudo apt update
    sudo apt install build-essential clang flex bison g++ gawk \
    gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev \
    python3-setuptools rsync swig unzip zlib1g-dev file wget    
fi

###
