#!/usr/bin/env bash
# A library of useful functions.

previous_directory=$(pwd)

# Check if executable is in system path or not.
function is_installed() {
    local executable="$1"
    command -v "$executable" >/dev/null 2>&1 && return 0 || return 1
}

# Securely remove a directory.
function secure_dir_rm() {
    local directory="$1"
    srm -srv "$directory"
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
    local title="$1"
    local text="$2"
    notify-send -a "$title" "$text"
}
