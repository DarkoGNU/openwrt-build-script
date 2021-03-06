#!/bin/bash

source common.sh

### Download the image builder

rm -rf builder

if [[ $RELEASE == "snapshot" ]]; then
    builder_link="https://downloads.openwrt.org/snapshots/targets/${TARGET}/openwrt-imagebuilder-${TARGET////-}.Linux-x86_64.tar.xz"
else
    builder_link="https://downloads.openwrt.org/releases/${RELEASE}/targets/${TARGET}/openwrt-imagebuilder-${RELEASE}-${TARGET////-}.Linux-x86_64.tar.xz"
fi

info "Downloading the image builder"
wget -O builder.tar.xz $builder_link

info "Extracting the image builder"
mkdir -p builder
tar xf builder.tar.xz --strip=1 -C ./builder

info "Deleting the archive"
rm builder.tar.xz

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

mkdir -p builder/config/etc/uci-defaults/
chmod 755 builder/config/etc/uci-defaults/

# That's a pretty weird solution!
# Reason - it's adapted from a simple uci-defaults script,
# where all the variables were configured directly in the script.
# I'll make it prettier one day

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
if [ $ENABLE_2G == "true" ]; then
    uci set wireless.${default_radio_2g}.ssid="$SSID"
    uci set wireless.${radio_2g}.country="$COUNTRY_2G"
    uci set wireless.${radio_2g}.channel="$CHANNEL_2G"
    uci set wireless.${radio_2g}.htmode="$MODE_2G"

    uci set wireless.${default_radio_2g}.encryption="psk2"
    uci set wireless.${default_radio_2g}.key="$wifi_password"

    uci set wireless.${default_radio_2g}.ieee80211r="1"
    uci set wireless.${default_radio_2g}.ft_over_ds="1"
    uci set wireless.${default_radio_2g}.ft_psk_generate_local="1"
    uci set wireless.${default_radio_2g}.mobility_domain="$MOBILITY_DOMAIN"

    uci set wireless.${radio_2g}.disabled="0"
fi

# WiFi 5G
if [ $ENABLE_5G == "true" ]; then
    uci set wireless.${default_radio_5g}.ssid="$SSID"
    uci set wireless.${radio_5g}.country="$COUNTRY_5G"
    uci set wireless.${radio_5g}.channel="$CHANNEL_5G"
    uci set wireless.${radio_5g}.htmode="$MODE_5G"

    uci set wireless.${default_radio_5g}.encryption="psk2"
    uci set wireless.${default_radio_5g}.key="$wifi_password"

    uci set wireless.${default_radio_5g}.ieee80211r="1"
    uci set wireless.${default_radio_5g}.ft_over_ds="1"
    uci set wireless.${default_radio_5g}.ft_psk_generate_local="1"
    uci set wireless.${default_radio_5g}.mobility_domain="$MOBILITY_DOMAIN"

    uci set wireless.${radio_5g}.disabled="0"
fi

# SQM
if [ $ENABLE_SQM == "true" ] && [ $IS_HOTSPOT == "false" ]; then
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

chmod 755 builder/config/etc/uci-defaults/99-autoconf

if [ -d secrets/ssh ]; then
    mkdir -p builder/config/etc/dropbear/
    chmod 700 builder/config/etc/dropbear/

    cp secrets/ssh/* builder/config/etc/dropbear/
    chmod 600 builder/config/etc/dropbear/*
fi

###

### Actually build the image

cd builder/

rm -rf images/
make clean
make image PROFILE="$PROFILE" PACKAGES="$PACKAGES" EXTRA_IMAGE_NAME="$HOSTNAME" FILES="${PWD}/config/" BIN_DIR="${PWD}/images/"

cd ..
mkdir -p images/
cp builder/images/*.bin images/

###

info "Image building completed. Enjoy!"
