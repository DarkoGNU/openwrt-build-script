#!/bin/bash

### Image config

# Addresses
ADDRESS="192.168.1.2"
HOSTNAME="Hotspot 1"
IS_HOTSPOT="true"

# WiFi - 2GHz
CHANNEL_2G="6"
MODE_2G="HE20"
RADIO_2G="0"

# WiFi - 5GHz
CHANNEL_5G="100"
MODE_5G="HE160"
RADIO_5G="1"

# Target device
RELEASE="snapshot"
TARGET="mediatek/filogic"
PROFILE="xiaomi_redmi-router-ax6000-stock"

###

### Build the image

source build.sh

###
