#!/bin/bash

# Adjust the variables below:
EXIT_ON_FAIL="true"

if [ ${EXIT_ON_FAIL} == "true" ]; then
    set -e
fi

# Pretty printing
info () { echo -e "\e[32m[INFO]\e[0m ${1}" ; }
error () { echo -e "\e[31m[INFO]\e[0m ${1}" ; }
