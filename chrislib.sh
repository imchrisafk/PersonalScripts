#!/usr/bin/env bash
# This is a library of useful functions for use in other scripts.

## BEGIN Global Vars ##
previous_directory=$(pwd)
## END Global Vars ##

## BEGIN Function Definitions ##
function secure_dir_rm() {
    srm -srv "${1}"
}

function highlight() {
    echo -e '\e[0;30;47m'"${1}"'\e[m'
}

function store_cd() {
    previous_directory=$(pwd)
}

function recover_cd() {
    cd $previous_directory
}

function notification() {
    notify-send -a "${1}" "${2}"
}
## END Function Definitions ##
