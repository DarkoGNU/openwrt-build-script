#!/bin/bash

# Exit on failure?
EXIT_ON_FAIL="true"

# Target device
RELEASE="snapshot"
TARGET="ramips/mt7621"
PROFILE="totolink_x5000r"

# Main address, how many hotspots?
ROUTER_ADDRESS="192.168.1.1"
HOTSPOT_COUNT=0

# Time zone
ZONENAME="Europe/Warsaw"
TIMEZONE="CET-1CEST,M3.5.0,M10.5.0/3"

# WiFi - common config
SSID="Fiber"
MOBILITY_DOMAIN="abba"
G2_CHANNEL="1"
G2_MODE="HE20"

# WiFi - 5GHz
G5_ENABLE="true"
G5_CHANNEL="36"
G5_MODE="HE80"

# SQM
SQM_ENABLE="true"
DOWNLOAD_SPEED="0"
UPLOAD_SPEED="16000"

# DNS
DNS_1="1.1.1.1"
DNS_2="1.0.0.1"
DNS6_1="2606:4700:4700::1111"
DNS6_2="2606:4700:4700::1001"

# Load common config
source scripts/common.sh
