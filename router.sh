#!/bin/bash
### Image config

# Addresses
ADDRESS="192.168.1.1"
HOSTNAME="Router"
IS_AP="false"

# WAN Config
WAN_VLAN="35" # Set to "false" to disable VLAN tagging

# WiFi - 2GHz
CHANNEL_2G="1"
MODE_2G="HE20"
RADIO_2G="0"

# WiFi - 5GHz
CHANNEL_5G="36"
MODE_5G="HE160"
RADIO_5G="1"

# WiFi - legacy
LEGACY="true"
SSID_LEGACY="Legacy-1"
ENABLE_2G_LEGACY="true"
ENABLE_5G_LEGACY="false"

# Hardware Ports
WAN_PORT="eth1" # Physical WAN port name for this specific device

# Target device
RELEASE="25.12.2"
TARGET="mediatek/filogic"
PROFILE="xiaomi_redmi-router-ax6000-stock"
