#!/bin/bash

### General config

# Exit on failure?
EXIT_ON_FAIL="true"

# Install dependencies?
INSTALL_DEPENDENCIES="false"

# Redownload the image builder?
BUILDER_REDOWNLOAD="false"

###

### Image config

# Addresses
GATEWAY="192.168.1.1"
ADDRESS="192.168.1.1"
IS_HOTSPOT="false"
DEVICE_NAME="Router"

# SQM
SQM_ENABLE="true"
DOWNLOAD_SPEED="0"
UPLOAD_SPEED="16000"

# WiFi - common config
SSID="Fiber"
MOBILITY_DOMAIN="abba"

# WiFi - 2GHz
ENABLE_2G="true"
CHANNEL_2G="1"
MODE_2G="HE20"
RADIO_2G="0"

# WiFi - 5GHz
ENABLE_5G="true"
CHANNEL_5G="36"
MODE_5G="HE80"
RADIO_5G="1"

# Time zone
ZONENAME="Europe/Warsaw"
TIMEZONE="CET-1CEST,M3.5.0,M10.5.0/3"

# DNS
DNS_1="1.1.1.1"
DNS_2="1.0.0.1"
DNS6_1="2606:4700:4700::1111"
DNS6_2="2606:4700:4700::1001"

# Target device
RELEASE="snapshot"
TARGET="ramips/mt7621"
PROFILE="totolink_x5000r"

# Packages & theme
PACKAGES="luci-ssl luci-app-sqm"
THEME="bootstrap-dark"

###

### Exit on failure & pretty printing

if [[ ${EXIT_ON_FAIL} == "true" ]]; then
    set -e
fi

info () { echo -e "\e[32m[INFO]\e[0m ${1}" ; }
error () { echo -e "\e[31m[INFO]\e[0m ${1}" ; }

###

### Download the image builder

if [[ ${BUILDER_REDOWNLOAD} == "true" || ! -d "builder/" ]]; then
    if [[ $RELEASE == "snapshot" ]]; then
        image_link="https://downloads.openwrt.org/snapshots/targets/${TARGET}/openwrt-imagebuilder-${TARGET////-}.Linux-x86_64.tar.xz"
    else
        image_link="https://downloads.openwrt.org/releases/${RELEASE}/targets/${TARGET}/openwrt-imagebuilder-${RELEASE}-${TARGET////-}.Linux-x86_64.tar.xz"
    fi
fi

info "Downloading the image builder"
wget -O builder.tar.xz ${image_link}

info "Extracting the image builder"
mkdir builder
tar xf builder.tar.xz --strip=1 -C ./builder

info "Deleting the archive"
rm builder.tar.xz

###

### Install dependencies

if [[ ${INSTALL_DEPENDENCIES} == "true" ]]; then
    if [[ -e /etc/arch-release ]]; then
        os="arch"
    else
        info "Your operating system is unsupported"
        exit 1
    fi

    if [[ ${os} == "arch" ]]; then
        info "Installing dependencies for Arch Linux"
        # Officialy required
        sudo pacman -S --needed --noconfirm base-devel ncurses zlib gawk git gettext openssl libxslt wget unzip python
        # Additional
        sudo pacman -S --needed --noconfirm rsync ca-certificates
    fi
fi

###
