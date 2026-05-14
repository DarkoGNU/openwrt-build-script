#!/bin/bash

### Run like: ./build.sh router.conf
### To build multiple: ./build.sh router.conf accesspoint.conf
# Disclaimers:
# - none :)
###

source functions.sh

CONFIG_ONLY="false"
if [[ "$1" == "--config-only" ]]; then
  CONFIG_ONLY="true"
  shift
fi

if [[ -z "$1" ]]; then
    error "Usage: $0 [--config-only] <config_files>"
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
uci set wireless.${1}.ft_over_ds="$FT_OVER_DS"
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

# Translate "true" / "false" to 0/1 for UCI
FLOW_OFFLOADING=$([[ "$FLOW_OFFLOADING" == "true" ]] && echo "1" || echo "0")
FLOW_OFFLOADING_HW=$([[ "$FLOW_OFFLOADING_HW" == "true" ]] && echo "1" || echo "0")
FT_OVER_DS=$([[ "$FT_OVER_DS" == "true" ]] && echo "1" || echo "0")

# Translate packet steering config
if [[ "$PACKET_STEERING" == "enabled_all" ]]; then
  PACKET_STEERING="2"
elif [[ "$PACKET_STEERING" == "enabled" ]]; then
  PACKET_STEERING="1"
else
  PACKET_STEERING="0"
fi

### Generate the config

mkdir -p "${builder_dir}"/config/etc/uci-defaults/
chmod 755 "${builder_dir}"/config/etc/uci-defaults/

CONF_FILE="${builder_dir}/config/etc/uci-defaults/99-autoconf"

{
  cat << EOL
#!/bin/sh

# 1. Find the next available log number (00, 01, 02...)
i=0
while [ -f "/root/autoconf-boot_\$(printf "%02d" "\$i").log" ]; do
    i=$((i + 1))
done
LOG_FILE="/root/autoconf-boot_\$(printf "%02d" "\$i").log"

# 2. Log precise timestamp at the top
echo "=== Script executed at: \$(date +'%Y-%m-%d %H:%M:%S') ===" > "\$LOG_FILE"

# 3. Redirect all further output to append to the new log file
exec >> "\$LOG_FILE" 2>&1

# 4. Override uci to log its arguments quietly
uci() {
    echo ">>> uci \$*"
    command uci "\$@"
}

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

# Flow offloading
uci set firewall.@defaults[0].flow_offloading='$FLOW_OFFLOADING'
uci set firewall.@defaults[0].flow_offloading_hw='$FLOW_OFFLOADING_HW'

EOL

  cat << EOL
# Packet steering
uci set network.globals.packet_steering='$PACKET_STEERING'

EOL

if [[ "$STEERING_FLOWS" != "disabled" ]]; then
  cat << EOL
# Steering flows (RPS)
uci set network.globals.steering_flows='$STEERING_FLOWS'

EOL
else
  cat << EOL
# Ensure Steering flows (RPS) are disabled
uci -q del network.globals.steering_flows

EOL
fi

# Apply the CPU affinity mask if steering is set to 'enabled_all' (which translates to 2)
if [[ "$PACKET_STEERING" != "0" ]] && [[ "$STEERING_AFFINITY" != "disabled" ]]; then
  cat << EOL
# Set custom RPS CPU affinity via Hotplug
mkdir -p /etc/hotplug.d/net
cat << 'EOF' > /etc/hotplug.d/net/30-rps-affinity
[ "\$ACTION" = "add" ] && {
  for d in /sys/class/net/*/queues/rx-*/rps_cpus; do
    [ -f "\$d" ] && echo $STEERING_AFFINITY > "\$d"
  done
}
EOF
chmod +x /etc/hotplug.d/net/30-rps-affinity

EOL
fi

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

uci set sqm.wan_sqm.qdisc="$SQM_QDISC"
uci set sqm.wan_sqm.script="$SQM_SCRIPT"

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

if [[ $ENABLE_IPV6 == "false" ]]; then
  cat << EOL
# Nuke IPv6 if it's not enabled
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

cp "$CONF_FILE" "image_files/99-autoconf-${HOSTNAME}"
info "Exporting UCI defaults for $HOSTNAME"
if [[ "$CONFIG_ONLY" == "true" ]]; then
  info "Config-only mode. Continuing..."
  exit 0
fi

### Actually build the image

info "Compiling image for $HOSTNAME ($PROFILE)..."
cd "${builder_dir}/"

rm -rf images/

if [[ "$REQUIRES_CLEAN" == "true" ]] || [[ "$is_first_run" == "true" ]]; then
  info "Running make clean for $HOSTNAME"
  make clean
else
  info "Skipping make clean for $HOSTNAME"
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
