#!/bin/bash

### Configuration

# Exit on failure?
EXIT_ON_FAIL="true"

###

### Exit on failure & pretty printing

if [[ $EXIT_ON_FAIL == "true" ]]; then
    set -e
fi

info () { echo -e "\e[32m[INFO]\e[0m ${1}" ; }
error () { echo -e "\e[31m[INFO]\e[0m ${1}" ; }

###
