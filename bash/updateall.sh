#!/usr/bin/env bash

# This script is intended to perform a complete update of all updatable things.
# Currently updating:
# - System packages (zypper)
# - System packages not covered by zypper (packagekit)
# - Flatpaks
# - pipx packages
# - ClamAV virus definitions
# - Tealdeer entries

source chrislib.sh

highlight "Attempting distribution upgrade..."
if is_installed pacman; then
    sudo pacman -Syyuu
elif is_installed zypper; then
    sudo env ZYPP_CURL2=1 zypper ref
    sudo env ZYPP_PCK_PRELOAD=1 zypper dup -l
fi

if is_installed pkcon; then
    highlight "Updating via PackageKit..."
    pkcon update
fi

if is_installed flatpak; then
    highlight "Updating flatpaks..."
    flatpak update

    highlight "Removing orphaned flatpaks..."
    flatpak uninstall --unused

    highlight "Removing orphaned flatpak data..."
    flatpak uninstall --delete-data
fi

if is_installed pipx; then
    highlight "Updating pipx packages..."
    pipx upgrade-all
fi

if is_installed freshclam; then
    highlight "Updating anti-virus definitions"
    sudo freshclam
fi

if is_installed tldr; then
    highlight "Updating tealdeer entry cache..."
    tldr --update
fi
