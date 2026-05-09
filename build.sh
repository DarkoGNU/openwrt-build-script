#!/bin/bash

### Run like: ./build.sh router.conf
### To build multiple: ./build.sh router.conf accesspoint.conf
# Disclaimers:
# - none :)
###

source functions.sh

if [[ -z "$1" ]]; then
    error "Usage: $0 <config_files>"
    exit 1
fi


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
    wan_mac=$(grep -v '^#' secrets/wan_mac | head -n 1 | tr -d '[:space:]') || true
fi

root_pw_hash=$(grep -v '^#' secrets/root_pw_hash | head -n 1 | tr -d '\n\r')
wifi_password=$(grep -v '^#' secrets/wifi_password | head -n 1 | tr -d '\n\r')

mkdir -p image_files

is_first_run="true"

for PROFILE_CONF in "$@"; do
  (
if [[ ! -f "$PROFILE_CONF" ]]; then
  error "Skipping: $PROFILE_CONF is not a valid file"
  continue
fi

source common.conf
source "$PROFILE_CONF"

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
        wget -O "$builder_archive" "$builder_link"
    fi

    info "Extracting the image builder"
    mkdir -p "$builder_dir"
    tar xf "$builder_archive" --strip=1 -C "./${builder_dir}"

    # info "Deleting the archive"
    # rm "$builder_archive"
fi

###

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

uci set wireless.${1}.ssid='${2}'
uci set wireless.${1}.device="${3}"

uci set wireless.${1}.encryption="sae-mixed"
uci set wireless.${1}.key='${4}'
uci set wireless.${1}.ieee80211w='1' # 1 = Optional, 2 = Required

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

uci set wireless.${1}.ssid='${2}'
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

# Sanitize variables to be injected safely
SSID="${SSID//\'/\'\\\'\'}"
SSID_2G_ALT="${SSID_2G_ALT//\'/\'\\\'\'}"
SSID_5G_ALT="${SSID_5G_ALT//\'/\'\\\'\'}"
SSID_LEGACY="${SSID_LEGACY//\'/\'\\\'\'}"

root_pw_hash="${root_pw_hash//\'/\'\\\'\'}"
wifi_password="${wifi_password//\'/\'\\\'\'}"

### Generate the config

mkdir -p "${builder_dir}"/config/etc/uci-defaults/
chmod 755 "${builder_dir}"/config/etc/uci-defaults/

CONF_FILE="${builder_dir}/config/etc/uci-defaults/99-autoconf"

{
  cat << EOL
#!/bin/sh
exec > /root/autoconf-boot.log 2>&1 # generate log file

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
uci set network.lan.proto="static"

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

# Enable TCP BBR
mkdir -p /etc/sysctl.d
echo "net.core.default_qdisc=fq" > /etc/sysctl.d/99-bbr.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-bbr.conf

EOL

# Optional WAN VLAN
if [[ -n "$WAN_VLAN" ]] && [[ "$WAN_VLAN" != "false" ]]; then
  cat << EOL
# Configure WAN VLAN
uci set network.wan.device="${WAN_PORT}.${WAN_VLAN}"
uci set network.wan6.device="${WAN_PORT}.${WAN_VLAN}"

EOL
fi

# Optional MAC Cloning
if [[ -n "$wan_mac" ]] && [[ $IS_AP == "false" ]]; then
  cat << EOL
# Configure MAC Cloning
uci set network.wan.macaddr="$wan_mac"
uci set network.wan6.macaddr="$wan_mac"

EOL
fi

  cat << EOL
# Wipe default WiFi config completely and regenerate hardware baselines
rm -f /etc/config/wireless
wifi config
while uci -q delete wireless.@wifi-iface[0]; do :; done

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

# SQM Hardware-Agnostic Config
  cat << EOL
# Name the default SQM section as 'wan_sqm'
while uci -q delete sqm.@queue[0]; do :; done
uci set sqm.wan_sqm="queue"

uci set sqm.wan_sqm.interface="$SQM_INTERFACE"
uci set sqm.wan_sqm.download="$DOWNLOAD_SPEED"
uci set sqm.wan_sqm.upload="$UPLOAD_SPEED"

uci set sqm.wan_sqm.linklayer="$LINKLAYER"
uci set sqm.wan_sqm.overhead="$OVERHEAD"
EOL

if [[ $ENABLE_SQM == "true" ]] && [[ $IS_AP == "false" ]]; then
  cat << EOL
uci set sqm.wan_sqm.enabled="1"

EOL
else
  cat << EOL
uci set sqm.wan_sqm.enabled="0"
EOL
fi

if [[ $IS_AP == "false" ]]; then
  cat << EOL
# Disable MSS Clamping (MTU Fix) on the WAN zone
WAN_FW_ZONE=\$(uci show firewall | grep -E "firewall\..+\.name='wan'" | cut -d. -f2 | head -n 1)
if [ -n "\$WAN_FW_ZONE" ]; then
    uci set firewall."\$WAN_FW_ZONE".mtu_fix='0'
fi

EOL

  if [[ $ENABLE_SQM == "true" ]]; then
    cat << EOL
# Disable flow offloading (required for SQM to function)
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'
EOL
  else
    cat << EOL
# Enable flow offloading (maximizes throughput when SQM is disabled)
uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='1'
EOL
  fi
fi

if [[ $IS_AP == "true" ]]; then
  cat << EOL
# Configure an access point
/etc/init.d/sqm disable
/etc/init.d/sqm stop 2>/dev/null || true

/etc/init.d/dnsmasq disable
/etc/init.d/dnsmasq stop 2>/dev/null || true

/etc/init.d/odhcpd disable
/etc/init.d/odhcpd stop 2>/dev/null || true

/etc/init.d/firewall disable
/etc/init.d/firewall stop 2>/dev/null || true

uci set dhcp.lan.ignore="1"
uci set network.wan.auto="0"
uci set network.wan6.auto="0"

uci set network.lan.gateway="$GATEWAY"
uci add_list network.lan.dns="$GATEWAY"

# Bridge physical WAN port to LAN
uci delete network.wan.device
uci delete network.wan6.device

# 1. Dynamically find the section ID for br-lan
BR_SECTION=\$(uci show network | grep -E "network\..+\.name='?br-lan'?$" | cut -d. -f2 | head -n 1)

# 2. Safely add the port if the section was found
if [ -n "\$BR_SECTION" ]; then
    uci add_list network."\$BR_SECTION".ports="$WAN_PORT"
    uci commit network
else
    echo "Error: Could not locate the br-lan device section."
fi

EOL
fi

# Nuke IPv6 if it's not enabled
if [[ $ENABLE_IPV6 == "false" ]]; then
  cat << EOL
uci -q delete network.globals.ula_prefix
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.ndp='disabled'
uci -q delete network.wan6

EOL
fi

  cat << EOL
# Set root password hash
sed -i 's|^root:[^:]*:|root:${root_pw_hash}:|' /etc/shadow

# Double-ensurance for Dropbear permissions
chmod 600 /etc/dropbear/* || true

# And one for uci commit
uci commit

# The end
exit 0

EOL

} > "$CONF_FILE"

chmod 755 "$CONF_FILE"

if [[ -d secrets/ssh ]]; then
    mkdir -p "${builder_dir}"/config/etc/dropbear/
    chmod 700 "${builder_dir}"/config/etc/dropbear/

    # Populate ssh_keys
    shopt -s nullglob
    ssh_keys=(secrets/ssh/*)

    if [[ ${#ssh_keys[@]} -gt 0 ]]; then
      cp secrets/ssh/authorized_keys "${builder_dir}/config/etc/dropbear/" 2>/dev/null || true
      cat /dev/null secrets/ssh/*.pub >> "${builder_dir}/config/etc/dropbear/authorized_keys" 2>/dev/null || true # Append public keys to authorized_keys
      sort -u "${builder_dir}/config/etc/dropbear/authorized_keys" -o "${builder_dir}/config/etc/dropbear/authorized_keys" # Strip any duplicate keys

      # Copy device-specific host keys and remove the hostname suffix
      for host_key in secrets/ssh/*_host_key."${HOSTNAME}"; do
        if [[ -f "$host_key" ]]; then
          dest_name=$(basename "$host_key" | sed "s/\.${HOSTNAME}$//")
          cp "$host_key" "${builder_dir}/config/etc/dropbear/$dest_name"
        fi
      done

      chmod 600 "${builder_dir}/config/etc/dropbear/"*
      shopt -u nullglob
    fi
fi

###

### Actually build the image

info "Compiling image for $HOSTNAME ($PROFILE)..."
cd "${builder_dir}/"

rm -rf images/

if [[ "$REQUIRES_CLEAN" == "true" ]] || [[ "$is_first_run" == "true" ]]; then
  info "Running make clean for $HOSTNAME..."
  make clean
else
  info "Skipping make clean for $HOSTNAME..."
fi

make image PROFILE="$PROFILE" PACKAGES="$PACKAGES $EXTRA_PACKAGES $REMOVED_PACKAGES $EXTRA_REMOVED" EXTRA_IMAGE_NAME="$HOSTNAME" FILES="${PWD}/config/" BIN_DIR="${PWD}/images/"

cd ..
# Copy to the global master output directory
# Gather all common OpenWrt image extensions safely
shopt -s nullglob
compiled_images=("${builder_dir}"/images/*.{bin,itb,img,gz,tar})
shopt -u nullglob

if [[ ${#compiled_images[@]} -gt 0 ]]; then
    cp "${compiled_images[@]}" image_files/
else
    error "No compiled images found for $HOSTNAME"
fi

info "Finished $HOSTNAME! Saved to image_files/"

    ) || { error "Build failed for $PROFILE_CONF"; continue; }

    is_first_run="false"
done

info "All images built successfully. Check the 'image_files' directory"

###
