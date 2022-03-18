#!/bin/bash

# A script to download and extract the image builder. Adjust the variables below:
BUILDER_LINK="https://downloads.openwrt.org/snapshots/targets/ramips/mt7621/openwrt-imagebuilder-ramips-mt7621.Linux-x86_64.tar.xz"

# Download the builder
wget -O builder.tar.xz $BUILDER_LINK

# Extract it
mkdir builder
tar xf builder.tar.xz --strip=1 -C ./builder

# Remove the archive
rm builder.tar.xz

