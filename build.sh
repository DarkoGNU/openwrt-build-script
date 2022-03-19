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
HOSTNAME="Router"
IS_HOTSPOT="false"

# SQM
ENABLE_SQM="true"
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

if [[ $EXIT_ON_FAIL == "true" ]]; then
    set -e
fi

info () { echo -e "\e[32m[INFO]\e[0m ${1}" ; }
error () { echo -e "\e[31m[INFO]\e[0m ${1}" ; }

###

### Download the image builder

if [[ $BUILDER_REDOWNLOAD == "true" || ! -d "builder/" ]]; then
    if [[ $RELEASE == "snapshot" ]]; then
        builder_link="https://downloads.openwrt.org/snapshots/targets/${TARGET}/openwrt-imagebuilder-${TARGET////-}.Linux-x86_64.tar.xz"
    else
        builder_link="https://downloads.openwrt.org/releases/${RELEASE}/targets/${TARGET}/openwrt-imagebuilder-${RELEASE}-${TARGET////-}.Linux-x86_64.tar.xz"
    fi

    info "Downloading the image builder"
    wget -O builder.tar.xz $builder_link

    info "Extracting the image builder"
    mkdir builder
    tar xf builder.tar.xz --strip=1 -C ./builder

    info "Deleting the archive"
    rm builder.tar.xz
fi

###

### Install dependencies

if [[ $INSTALL_DEPENDENCIES == "true" ]]; then
    if [[ -e /etc/arch-release ]]; then
        os="arch"
    else
        error "Your operating system is unsupported"
        exit 1
    fi

    if [[ $os == "arch" ]]; then
        info "Installing dependencies for Arch Linux"
        # Officialy required
        sudo pacman -S --needed --noconfirm base-devel ncurses zlib gawk git gettext openssl libxslt wget unzip python
        # Additional
        sudo pacman -S --needed --noconfirm rsync ca-certificates
    fi
fi

###

### Read secrets & set some variables

if [ ! -f secrets/root_password ]; then
    error "Root password secret not found"
    exit 1;
elif [ ! -f secrets/wifi_password ]; then
    error "WiFi password secret not found"
    exit 1;
fi

root_password=$(<secrets/root_password)
wifi_password=$(<secrets/wifi_password)

radio_2g="radio${RADIO_2G}"
default_radio_2g="default_${radio_2g}"

radio_5g="radio${RADIO_5G}"
default_radio_5g="default_${radio_5g}"

###

### Generate the config

rm -rf builder/config
mkdir -p builder/config/etc/uci-defaults

cat > builder/config/etc/uci-defaults/99-autoconf << EOL
#!/bin/sh

# System info
uci set system.@system[0].hostname="$HOSTNAME"
uci set system.@system[0].zonename="$ZONENAME"
uci set system.@system[0].timezone="$TIMEZONE"

if [ $IS_HOTSPOT == "false" ]; then
    uci set system.@system[0].description="Routes packets and provides WiFi!"
else
    uci set system.@system[0].description="Provides WiFi!"
fi

# Root password
echo -e "${root_password}\n${root_password}" | passwd

# LUCI theme
uci set luci.main.mediaurlbase="/luci-static/$THEME"

# Redirect to HTTPS
uci set uhttpd.main.redirect_https="on"

# LAN interface
uci set network.lan.ipaddr="$ADDRESS"

uci add_list dhcp.lan.dhcp_option="6,$DNS_1,$DNS_2"
uci add_list dhcp.lan.dns="$DNS6_1"
uci add_list dhcp.lan.dns="$DNS6_2"

# WAN interface
uci set network.wan.peerdns="0"
uci add_list network.wan.dns="$DNS_1"
uci add_list network.wan.dns="$DNS_2"

# WAN6 interface
uci set network.wan6.peerdns="0"
uci add_list network.wan6.dns="$DNS6_1"
uci add_list network.wan6.dns="$DNS6_2"

# WiFi 2G
uci set wireless.${default_radio_2g}.ssid="$SSID"
uci set wireless.${radio_2g}.channel="$CHANNEL_2G"
uci set wireless.${radio_2g}.htmode="$MODE_2G"

uci set wireless.${default_radio_2g}.encryption="sae-mixed"
uci set wireless.${default_radio_2g}.key="$wifi_password"

uci set wireless.${default_radio_2g}.ieee80211r="1"
uci set wireless.${default_radio_2g}.ft_over_ds="1"
uci set wireless.${default_radio_2g}.ft_psk_generate_local="1"
uci set wireless.${default_radio_2g}.mobility_domain="$MOBILITY_DOMAIN"

uci set wireless.${radio_2g}.disabled="0"

# WiFi 5G
uci set wireless.${default_radio_5g}.ssid="$SSID"
uci set wireless.${radio_5g}.channel="$CHANNEL_5G"
uci set wireless.${radio_5g}.htmode="$MODE_5G"

uci set wireless.${default_radio_5g}.encryption="sae-mixed"
uci set wireless.${default_radio_5g}.key="$wifi_password"

uci set wireless.${default_radio_5g}.ieee80211r="1"
uci set wireless.${default_radio_5g}.ft_over_ds="1"
uci set wireless.${default_radio_5g}.ft_psk_generate_local="1"
uci set wireless.${default_radio_5g}.mobility_domain="$MOBILITY_DOMAIN"

uci set wireless.${radio_5g}.disabled="0"

# SQM
if [ $ENABLE_SQM == "true" && $IS_HOTSPOT == "false" ]; then
    uci set sqm.eth1.enabled="1"
else
    uci set sqm.eth1.enabled="0"
fi

uci set sqm.eth1.interface="wan"
uci set sqm.eth1.download="$DOWNLOAD_SPEED"
uci set sqm.eth1.upload="$UPLOAD_SPEED"

# Configure a hotspot
if [ $IS_HOTSPOT == "true" ]; then
    /etc/init.d/sqm disable
    /etc/init.d/sqm stop

    /etc/init.d/dnsmasq disable
    /etc/init.d/dnsmasq stop

    /etc/init.d/odhcpd disable
    /etc/init.d/odhcpd stop

    uci set dhcp.lan.ignore="1"
    uci set network.wan.auto="0"
    uci set network.wan6.auto="0"

    uci set network.lan.gateway="$GATEWAY"
    uci add_list network.lan.dns="$GATEWAY"
fi

# Apply changes
uci commit

# Reload stuff
/etc/init.d/network reload
/etc/init.d/sqm reload

# The end
exit 0

EOL

###
