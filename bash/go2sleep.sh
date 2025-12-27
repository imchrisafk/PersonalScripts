#!/usr/bin/env bash

source chrislib.sh

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

## Shutdown ##
highlight "Good night..."
sudo shutdown now
