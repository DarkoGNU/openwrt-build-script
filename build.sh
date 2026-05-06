#!/bin/bash

### Run like: ./build.sh router.conf
# Disclaimers:
# - script assumes WiFi password contains no single quotes ('), if it does - they have to be escaped
###

if [[ -z "$1" ]]; then
    error "Usage: $0 <config_file>"
    exit 1
fi

source "$1"
source functions.sh
source common.sh

### Download and extract the image builder

if [[ $RELEASE == "snapshot" ]]; then
    builder_link="https://downloads.openwrt.org/snapshots/targets/${TARGET}/openwrt-imagebuilder-${TARGET////-}.Linux-x86_64.tar.zst"
else
    builder_link="https://downloads.openwrt.org/releases/${RELEASE}/targets/${TARGET}/openwrt-imagebuilder-${RELEASE}-${TARGET////-}.Linux-x86_64.tar.zst"
fi

builder_archive=$(basename "$builder_link")
builder_dir=builder-${RELEASE}-${TARGET////-}

if [[ ! -d "${builder_dir}" ]]; then
    if [[ ! -e "$builder_archive" ]]; then
        info "Downloading the image builder"
        wget -qO "$builder_archive" "$builder_link"
    fi

    info "Extracting the image builder"
    mkdir -p "$builder_dir"
    tar xf "$builder_archive" --strip=1 -C "./${builder_dir}"

    # info "Deleting the archive"
    # rm "$builder_archive"
fi

###

### Read secrets & set some variables

if [ ! -f secrets/root_pw_hash ]; then
    error "Root password secret not found"
    exit 1;
elif [ ! -f secrets/wifi_password ]; then
    error "WiFi password secret not found"
    exit 1;
fi

wan_mac=""
if [[ -f secrets/wan_mac ]]; then
    wan_mac=$(grep -v '^#' secrets/wan_mac | head -n 1 | tr -d '[:space:]')
fi

root_pw_hash=$(<secrets/root_pw_hash)
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

uci set wireless.${1}.encryption="sae-mixed"
uci set wireless.${1}.key='${4}'

uci set wireless.${1}.bss_transition='1'
uci set wireless.${1}.time_advertisement='2'
uci set wireless.${1}.time_zone='$TIMEZONE'
uci set wireless.${1}.wnm_sleep_mode='1'

uci set wireless.${1}.ieee80211k='1'
uci set wireless.${1}.rrm_neighbor_report='1'
uci set wireless.${1}.rrm_beacon_report='1'

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

uci set wireless.${1}.encryption="psk2"
uci set wireless.${1}.key='${4}'

uci set wireless.${1}.bss_transition='1'
uci set wireless.${1}.time_advertisement='2'
uci set wireless.${1}.time_zone='$TIMEZONE'
uci set wireless.${1}.wnm_sleep_mode='1'

uci set wireless.${1}.ieee80211k='1'
uci set wireless.${1}.rrm_neighbor_report='1'
uci set wireless.${1}.rrm_beacon_report='1'

EOL
}

###

# Wipe old configuration
rm -rf "${builder_dir}/config"

### Generate the config

mkdir -p "${builder_dir}"/config/etc/uci-defaults/
chmod 755 "${builder_dir}"/config/etc/uci-defaults/

CONF_FILE="${builder_dir}/config/etc/uci-defaults/99-autoconf"

{
  cat << EOL
#!/bin/sh

# System info
uci set system.@system[0].hostname="$HOSTNAME"
uci set system.@system[0].zonename="$ZONENAME"
uci set system.@system[0].timezone="$TIMEZONE"

EOL

  if [[ $IS_AP == "false" ]]; then
  echo 'uci set system.@system[0].description="Routes packets and provides WiFi!"'
  else
  echo 'uci set system.@system[0].description="Provides WiFi!"'
  fi
  echo

  cat << EOL
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

# Optional WAN VLAN
if [[ -n "$WAN_VLAN" ]] && [[ "$WAN_VLAN" != "false" ]]; then
  cat << EOL
# Configure WAN VLAN
uci set network.wan.device="wan.${WAN_VLAN}"
uci set network.wan6.device="wan.${WAN_VLAN}"

EOL
fi

# Optional MAC Cloning
if [[ -n "$wan_mac" ]]; then
  cat << EOL
# Configure MAC Cloning
uci set network.wan.macaddr="$wan_mac"
uci set network.wan6.macaddr="$wan_mac"

EOL
fi

  cat << EOL
# Remove default WiFi interfaces
uci del wireless.default_radio0
uci del wireless.default_radio1

EOL

if [[ $ENABLE_2G == "true" ]]; then
echo "# WiFi 2G"
  main_wifi_config \
    main_2g \
    "$SSID" \
    "$radio_2g" \
    "$wifi_password" \
    "$MOBILITY_DOMAIN"
  echo
fi

if [[ $ENABLE_5G == "true" ]]; then
echo "# WiFi 5G"
  main_wifi_config \
    main_5g \
    "$SSID" \
    "$radio_5g" \
    "$wifi_password" \
    "$MOBILITY_DOMAIN"
  echo
fi

if [[ $ENABLE_2G_ALT == "true" ]]; then
echo "# WiFi 2G Alt"
  main_wifi_config \
    alt_2g \
    "$SSID_2G_ALT" \
    "$radio_2g" \
    "$wifi_password" \
    "$MOBILITY_DOMAIN_2G_ALT"
  echo
fi

if [[ $ENABLE_5G_ALT == "true" ]]; then
echo "# WiFi 5G Alt"
  main_wifi_config \
    alt_5g \
    "$SSID_5G_ALT" \
    "$radio_5g" \
    "$wifi_password" \
    "$MOBILITY_DOMAIN_5G_ALT"
  echo
fi

if [[ $ENABLE_2G_LEGACY == "true" ]]; then
echo "# WiFi 2G Legacy"
  legacy_wifi_config \
    legacy_2g \
    "$SSID_LEGACY" \
    "$radio_2g" \
    "$wifi_password"
  echo
fi

if [[ $ENABLE_5G_LEGACY == "true" ]]; then
echo "# WiFi 5G Legacy"
  legacy_wifi_config \
    legacy_5g \
    "$SSID_LEGACY" \
    "$radio_5g" \
    "$wifi_password"
  echo
fi

if [[ $ENABLE_2G == "true" ]] || [[ $ENABLE_2G_ALT == "true" ]] || [[ $ENABLE_2G_LEGACY == "true" ]]; then
  cat << EOL
# General WiFi 2G config
uci set wireless.${radio_2g}.disabled="0"
uci set wireless.${radio_2g}.country="$country_2g"
uci set wireless.${radio_2g}.channel="$CHANNEL_2G"
uci set wireless.${radio_2g}.htmode="$MODE_2G"

EOL
fi

if [[ $ENABLE_5G == "true" ]] || [[ $ENABLE_5G_ALT == "true" ]] || [[ $ENABLE_5G_LEGACY == "true" ]]; then
  cat << EOL
# General WiFi 5G config
uci set wireless.${radio_5g}.disabled="0"
uci set wireless.${radio_5g}.country="$country_5g"
uci set wireless.${radio_5g}.channel="$CHANNEL_5G"
uci set wireless.${radio_5g}.htmode="$MODE_5G"

EOL
fi

if [[ $ENABLE_SQM == "true" ]] && [[ $IS_AP == "false" ]]; then
  cat << EOL
# SQM
uci set sqm.eth1.enabled="1"

EOL
else
  cat << EOL
# SQM
uci set sqm.eth1.enabled="0"

EOL
fi

  cat << EOL
uci set sqm.eth1.interface="wan"
uci set sqm.eth1.download="$DOWNLOAD_SPEED"
uci set sqm.eth1.upload="$UPLOAD_SPEED"

EOL

if [[ $IS_AP == "true" ]]; then
  cat << EOL
# Configure an access point
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

  cat << EOL
# Set root password hash
sed -i "s|^root:[^:]*:|root:${root_pw_hash}:|" /etc/shadow

# Double-ensurance for Dropbear permissions
chmod 600 /etc/dropbear/*

# And uci commit double-ensurance
uci commit

# The end
exit 0

EOL

} > "$CONF_FILE"

chmod 755 "$CONF_FILE"

if [[ -d secrets/ssh ]]; then
    mkdir -p "${builder_dir}"/config/etc/dropbear/
    chmod 700 "${builder_dir}"/config/etc/dropbear/

    if ls secrets/ssh/* 1> /dev/null 2>&1; then
      cp secrets/ssh/* "${builder_dir}"/config/etc/dropbear/
      chmod 600 "${builder_dir}"/config/etc/dropbear/*
    fi
fi

###

### Actually build the image

cd "${builder_dir}/"

rm -rf images/
make clean
make image PROFILE="$PROFILE" PACKAGES="$PACKAGES $REMOVED_PACKAGES" EXTRA_IMAGE_NAME="$HOSTNAME" FILES="${PWD}/config/" BIN_DIR="${PWD}/images/"

cd ..
mkdir -p images/
cp "${builder_dir}"/images/*.bin images/

###

info "Image building completed. Enjoy!"
