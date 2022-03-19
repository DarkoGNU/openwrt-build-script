#!/bin/bash

# A script to build the image - for the router. Adjust the variables below:
PACKAGES="luci-ssl luci-app-sqm"
FILES="$PWD/router"
BIN_DIR="$PWD/images"
EXTRA_IMAGE_NAME="Router"

cd builder/
make clean
make image PROFILE="$PROFILE" PACKAGES="$PACKAGES" FILES="$FILES" BIN_DIR="$BIN_DIR" EXTRA_IMAGE_NAME="$EXTRA_IMAGE_NAME"
