#!/usr/bin/env bash

# This script is intended to perform a complete update of all updatable things.
# Currently updating:
# - System packages (zypper)
# - System packages not covered by zypper (packagekit)
# - Flatpaks
# - pipx packages
# - Tealdeer entries

source chrislib.sh

highlight "Performing distribution upgrade..."
sudo env ZYPP_CURL2=1 zypper ref
sudo env ZYPP_PCK_PRELOAD=1 zypper dup -l

highlight "Updating flatpaks..."
flatpak update

highlight "Removing stale flatpak data..."
flatpak uninstall --unused
flatpak uninstall --delete-data

highlight "Updating PackageKit packages..."
pkcon update

highlight "Updating pipx packages..."
pipx upgrade-all

#highlight "Updating anti-virus definitions"
#sudo freshclam

highlight "Updating tealdeer entry cache..."
tldr --update
