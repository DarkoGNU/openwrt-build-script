#!/bin/bash

### Image config

# Addresses
ADDRESS="192.168.1.2"
HOSTNAME="Hotspot 1"
IS_HOTSPOT="true"

# WiFi - 2GHz
CHANNEL_2G="6"
MODE_2G="HT20"
RADIO_2G="0"

# WiFi - 5GHz
CHANNEL_5G="149"
MODE_5G="VHT80"
RADIO_5G="1"

# Target device
RELEASE="snapshot"
TARGET="ramips/mt7621"
PROFILE="netgear_r6220"

###

### Build the image

source build.sh

###

