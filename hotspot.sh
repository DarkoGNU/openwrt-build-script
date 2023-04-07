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
CHANNEL_5G="149"
MODE_5G="HE80"
RADIO_5G="1"

# Target device
RELEASE="snapshot"
TARGET="ramips/mt7621"
PROFILE="totolink_x5000r"

###

### Build the image

source build.sh

###
