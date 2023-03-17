#!/bin/bash

### Image config

# Addresses
GATEWAY="192.168.1.1"
ADDRESS="192.168.1.2"
HOSTNAME="Hotspot 1"
IS_HOTSPOT="true"

# SQM
ENABLE_SQM="true"
DOWNLOAD_SPEED="0"
UPLOAD_SPEED="16000"

# WiFi - common config
SSID="Fiber"
MOBILITY_DOMAIN="abba"

LEGACY="true"
LEGACY_SSID="Printer"

# WiFi - 2GHz
ENABLE_2G="true"
CHANNEL_2G="6"
COUNTRY_2G="US"
MODE_2G="HT20"
RADIO_2G="0"

# WiFi - 5GHz
ENABLE_5G="true"
CHANNEL_5G="149"
COUNTRY_5G="US"
MODE_5G="VHT80"
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
RELEASE="22.03.3"
TARGET="ramips/mt7621"
PROFILE="netgear_r6220"

# Packages & theme
PACKAGES="luci-ssl luci-app-sqm"
THEME="bootstrap-dark"

###

### Build the image

source build.sh

###
