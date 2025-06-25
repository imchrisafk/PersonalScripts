#!/usr/bin/env bash
# A library of useful functions.

previous_directory=$(pwd)

# Securely remove a directory.
function secure_dir_rm() {
    srm -srv "${1}"
}

# Apply inverse video effect to the given text.
function highlight() {
    local text="$1"
    printf "\033[7m%s\033[0m\n" "$text"
}

# Store current directory.
function store_cd() {
    previous_directory=$(pwd)
}

# Change current directory to stored directory.
function recover_cd() {
    cd $previous_directory
}

# Send a system notification.
function notification() {
    notify-send -a "${1}" "${2}"
}
