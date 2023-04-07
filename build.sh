#!/bin/bash

source functions.sh
source common.sh

### Download the image builder

rm -rf builder

if [[ $RELEASE == "snapshot" ]]; then
    builder_link="https://downloads.openwrt.org/snapshots/targets/${TARGET}/openwrt-imagebuilder-${TARGET////-}.Linux-x86_64.tar.xz"
else
    builder_link="https://downloads.openwrt.org/releases/${RELEASE}/targets/${TARGET}/openwrt-imagebuilder-${RELEASE}-${TARGET////-}.Linux-x86_64.tar.xz"
fi

info "Downloading the image builder"
wget -O builder.tar.xz "$builder_link"

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
radio_5g="radio${RADIO_5G}"

country_2g="$COUNTRY"
country_5g="$COUNTRY"

###

### Additional functions

main_wifi_config () {
# Argument 1  - interface name
# Argument 2 - SSID
# Argument 3 - radio
# Argument 4 - password
# Argument 5 - mobility domain
cat << EOL
uci set wireless.${1}="wifi-iface"
uci set wireless.${1}.network="lan"
uci set wireless.${1}.mode="ap"

uci set wireless.${1}.ssid="${2}"
uci set wireless.${1}.device="${3}"

uci set wireless.${1}.encryption="psk2"
uci set wireless.${1}.key="${4}"

uci set wireless.${1}.ieee80211r="1"
uci set wireless.${1}.ft_over_ds="1"
uci set wireless.${1}.ft_psk_generate_local="1"
uci set wireless.${1}.mobility_domain="${5}"

EOL
}

legacy_wifi_config () {
# Argument 1  - interface name
# Argument 2 - SSID
# Argument 3 - radio
# Argument 4 - password
cat << EOL
uci set wireless.${1}="wifi-iface"
uci set wireless.${1}.network="lan"
uci set wireless.${1}.mode="ap"

uci set wireless.${1}.ssid="${2}"
uci set wireless.${1}.device="${3}"

uci set wireless.${1}.encryption="psk-mixed"
uci set wireless.${1}.key="${4}"

EOL
}

###

### Generate the config

mkdir -p builder/config/etc/uci-defaults/
chmod 755 builder/config/etc/uci-defaults/

cat > builder/config/etc/uci-defaults/99-autoconf << EOL
#!/bin/sh

apply () {
    # Apply changes
    uci commit

    # Reload stuff
    /etc/init.d/network reload
    /etc/init.d/sqm reload
}

# System info
uci set system.@system[0].hostname="$HOSTNAME"
uci set system.@system[0].zonename="$ZONENAME"
uci set system.@system[0].timezone="$TIMEZONE"

EOL

if [[ $IS_HOTSPOT == "false" ]]; then
cat >> builder/config/etc/uci-defaults/99-autoconf << EOL
uci set system.@system[0].description="Routes packets and provides WiFi!"

EOL
else
cat >> builder/config/etc/uci-defaults/99-autoconf << EOL
uci set system.@system[0].description="Provides WiFi!"

EOL
fi

cat >> builder/config/etc/uci-defaults/99-autoconf << EOL
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

EOL

cat >> builder/config/etc/uci-defaults/99-autoconf << EOL
# Remove default WiFi interfaces
uci del wireless.default_radio0
uci del wireless.default_radio1

EOL

if [[ $ENABLE_2G == "true" ]]; then
echo "# WiFi 2G" >> builder/config/etc/uci-defaults/99-autoconf
printf "$(main_wifi_config \
    main_2g \
    $SSID \
    $radio_2g \
    $wifi_password \
    $MOBILITY_DOMAIN)\n\n" \
    >> builder/config/etc/uci-defaults/99-autoconf
fi

if [[ $ENABLE_5G == "true" ]]; then
echo "# WiFi 5G" >> builder/config/etc/uci-defaults/99-autoconf
printf "$(main_wifi_config \
    main_5g \
    $SSID \
    $radio_5g \
    $wifi_password \
    $MOBILITY_DOMAIN)\n\n" \
    >> builder/config/etc/uci-defaults/99-autoconf
fi

if [[ $ENABLE_2G_ALT == "true" ]]; then
echo "# WiFi 2G Alt" >> builder/config/etc/uci-defaults/99-autoconf
printf "$(main_wifi_config \
    alt_2g \
    $SSID_2G_ALT \
    $radio_2g \
    $wifi_password \
    $MOBILITY_DOMAIN_2G_ALT)\n\n" \
    >> builder/config/etc/uci-defaults/99-autoconf
fi

if [[ $ENABLE_5G_ALT == "true" ]]; then
echo "# WiFi 5G Alt" >> builder/config/etc/uci-defaults/99-autoconf
printf "$(main_wifi_config \
    alt_5g \
    $SSID_5G_ALT \
    $radio_5g \
    $wifi_password \
    $MOBILITY_DOMAIN_5G_ALT)\n\n" \
    >> builder/config/etc/uci-defaults/99-autoconf
fi

if [[ $ENABLE_2G_LEGACY == "true" ]]; then
echo "# WiFi 2G Legacy" >> builder/config/etc/uci-defaults/99-autoconf
printf "$(legacy_wifi_config \
    legacy_2g \
    $SSID_LEGACY \
    $radio_2g \
    $wifi_password)\n\n" \
    >> builder/config/etc/uci-defaults/99-autoconf
fi

if [[ $ENABLE_5G_LEGACY == "true" ]]; then
echo "# WiFi 5G Legacy" >> builder/config/etc/uci-defaults/99-autoconf
printf "$(legacy_wifi_config \
    legacy_5g \
    $SSID_LEGACY \
    $radio_5g \
    $wifi_password)\n\n" \
    >> builder/config/etc/uci-defaults/99-autoconf
fi

if [[ $ENABLE_2G == "true" ]] || [[ $ENABLE_2G_ALT == "true" ]] || [[ $ENABLE_2G_LEGACY == "true" ]]; then
cat >> builder/config/etc/uci-defaults/99-autoconf << EOL
# General WiFi 2G config
uci set wireless.${radio_2g}.disabled="0"
uci set wireless.${radio_2g}.country="$country_2g"
uci set wireless.${radio_2g}.channel="$CHANNEL_2G"
uci set wireless.${radio_2g}.htmode="$MODE_2G"

EOL
fi

if [[ $ENABLE_5G == "true" ]] || [[ $ENABLE_5G_ALT == "true" ]] || [[ $ENABLE_5G_LEGACY == "true" ]]; then
cat >> builder/config/etc/uci-defaults/99-autoconf << EOL
# General WiFi 5G config
uci set wireless.${radio_5g}.disabled="0"
uci set wireless.${radio_5g}.country="$country_5g"
uci set wireless.${radio_5g}.channel="$CHANNEL_5G"
uci set wireless.${radio_5g}.htmode="$MODE_5G"

EOL
fi

if [[ $ENABLE_SQM == "true" ]] && [[ $IS_HOTSPOT == "false" ]]; then
cat >> builder/config/etc/uci-defaults/99-autoconf << EOL
# SQM
uci set sqm.eth1.enabled="1"

EOL
else
cat >> builder/config/etc/uci-defaults/99-autoconf << EOL
uci set sqm.eth1.enabled="0"

EOL
fi

cat >> builder/config/etc/uci-defaults/99-autoconf << EOL
uci set sqm.eth1.interface="wan"
uci set sqm.eth1.download="$DOWNLOAD_SPEED"
uci set sqm.eth1.upload="$UPLOAD_SPEED"

EOL

if [[ $IS_HOTSPOT == "true" ]]; then
cat >> builder/config/etc/uci-defaults/99-autoconf << EOL
# Configure a hotspot
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

EOL
fi

cat >> builder/config/etc/uci-defaults/99-autoconf << EOL
# Make sure all changes are applied
apply

# The end
exit 0

EOL

chmod 755 builder/config/etc/uci-defaults/99-autoconf

if [[ -d secrets/ssh ]]; then
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
