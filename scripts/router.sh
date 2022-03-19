#!/bin/bash

# A script to build the image - for the router. Adjust the variables below:
PROFILE="totolink_x5000r"
PACKAGES="luci-ssl luci-app-sqm"
FILES="$PWD/router"
BIN_DIR="$PWD/images"
EXTRA_IMAGE_NAME="Router"

source common.sh

cd builder/
make clean
make image PROFILE="$PROFILE" PACKAGES="$PACKAGES" FILES="$FILES" BIN_DIR="$BIN_DIR" EXTRA_IMAGE_NAME="$EXTRA_IMAGE_NAME"
