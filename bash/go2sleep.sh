#!/usr/bin/env bash

# Check if executable is in system path or not.
function is_installed() {
    local executable="$1"
    command -v "$executable" >/dev/null 2>&1 && return 0 || return 1
}

# Apply inverse video effect to the given text.
function highlight() {
    local text="$1"
    printf "\033[7m%s\033[0m\n" "$text"
}

# Empty Trash
highlight "Emptying trash..."
ktrash6 --empty

# Clear Old System Logs
highlight "Clearing old logs..."
sudo journalctl --rotate
sudo journalctl --vacuum-time=7d

# Delete Stale RPM Packages
highlight "Deleting stale RPM packages..."
sudo zypper clean

# Trim Old System Snapshots
highlight "Trimming old system snapshots..."
sudo snapper cleanup number

# Use Bleachbit for everything else
highlight "Running BleachBit..."
if is_installed bleachbit; then
    bleachbit -c --preset
elif flatpak info org.bleachbit.BleachBit >/dev/null 2>&1; then
    flatpak run org.bleachbit.BleachBit -c --preset
fi

## Shutdown ##
highlight "Good night..."
sudo shutdown now
