#!/usr/bin/env bash

# Check if executable is in system path or not.
function is_installed() {
    local executable="$1"
    command -v "$executable" >/dev/null 2>&1
}

# Apply inverse video effect to the given text.
function highlight() {
    local text="$1"
    printf "\033[7m%s\033[0m\n" "$text"
}

# Empty Trash
if is_installed ktrash6; then
    highlight "Emptying trash..."
    ktrash6 --empty
fi

# Clear Old System Logs
if is_installed journalctl; then
    highlight "Clearing old logs..."
    sudo journalctl --rotate --vacuum-time=7d
fi

# Delete Stale RPM Packages
if is_installed zypper; then
    highlight "Deleting stale RPM packages..."
    sudo zypper clean
fi

# Trim Old System Snapshots
if is_installed snapper; then
    highlight "Trimming old system snapshots..."
    sudo snapper cleanup number
fi

# Use Bleachbit for everything else
if is_installed bleachbit; then
    highlight "Running BleachBit..."
    bleachbit -c --preset
elif flatpak info org.bleachbit.BleachBit >/dev/null 2>&1; then
    highlight "Running BleachBit..."
    flatpak run org.bleachbit.BleachBit -c --preset
fi

## Shutdown ##
highlight "Good night..."
sudo systemctl poweroff
