#!/bin/bash

# Adjust the variables below:
RELEASE="snapshot"
TARGET="ramips/mt7621"

source common.sh

# Determine the image's address
if [ $RELEASE == "snapshot" ]; then
    image_link="https://downloads.openwrt.org/snapshots/targets/${TARGET}/openwrt-imagebuilder-${TARGET////-}.Linux-x86_64.tar.xz"
else
    image_link="https://downloads.openwrt.org/releases/${RELEASE}/targets/${TARGET}/openwrt-imagebuilder-${RELEASE}-${TARGET////-}.Linux-x86_64.tar.xz"
fi

info "Downloading the image builder"
wget -O builder.tar.xz ${image_link}

info "Extracting the image builder"
mkdir builder
tar xf builder.tar.xz --strip=1 -C ./builder

info "Deleting the archive"
rm builder.tar.xz
