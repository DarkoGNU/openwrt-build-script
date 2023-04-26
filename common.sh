#!/bin/bash

### Image config

# Addresses
GATEWAY="192.168.1.1"

# SQM
ENABLE_SQM="true"
DOWNLOAD_SPEED="0"
UPLOAD_SPEED="16000"

# WiFi - common config
SSID="Fiber"
MOBILITY_DOMAIN="abba"
COUNTRY="PL"

# WiFi - 2GHz Main
ENABLE_2G="true"

# WiFi - 5GHz Main
ENABLE_5G="true"

# WiFi - 2GHz Alt
ENABLE_2G_ALT="false"
SSID_2G_ALT="${SSID}2G"
MOBILITY_DOMAIN_2G_ALT="abb2"

# WiFi - 5GHz Alt
ENABLE_5G_ALT="true"
SSID_5G_ALT="${SSID}5G"
MOBILITY_DOMAIN_5G_ALT="abb5"

# WiFi - legacy
LEGACY="true"
SSID_LEGACY="Legacy"
ENABLE_2G_LEGACY="true"
ENABLE_5G_LEGACY="false"

# Time zone
ZONENAME="Europe/Warsaw"
TIMEZONE="CET-1CEST,M3.5.0,M10.5.0/3"

# DNS
DNS_1="1.1.1.1"
DNS_2="1.0.0.1"
DNS6_1="2606:4700:4700::1111"
DNS6_2="2606:4700:4700::1001"

# Packages & theme
PACKAGES="luci-ssl luci-app-sqm wpad-mbedtls"
WPAD_REMOVED="-wpad -wpad-basic -wpad-basic-mbedtls -wpad-basic-openssl -wpad-basic-wolfssl -wpad-mesh-mbedtls -wpad-mesh-openssl -wpad-mesh-wolfssl -wpad-mini -wpad-openssl -wpad-wolfssl"
REMOVED_PACKAGES="$WPAD_REMOVED"
THEME="bootstrap-dark"

###
