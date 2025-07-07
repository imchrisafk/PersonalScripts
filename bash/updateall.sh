#!/usr/bin/env bash

# Performs a comprehensive update of various software components on the system.
# Updates:
# - System packages (via pacman or zypper)
# - PackageKit packages
# - Flatpak applications and removes orphaned data
# - pipx Python packages
# - Rust toolchains
# - ClamAV virus definitions
# - Tealdeer (tldr) command-line help cache

# Requires: chrislib.sh for utility functions like 'highlight' and 'is_installed'

source chrislib.sh

# Update system packages based on package manager
highlight "Updating system packages..."
if is_installed pacman; then
    sudo pacman -Syyuu # Synchronize and upgrade Arch-based system packages
elif is_installed zypper; then
    sudo env ZYPP_CURL2=1 zypper ref           # Refresh openSUSE repositories
    sudo env ZYPP_PCK_PRELOAD=1 zypper dup -ly # Perform distribution upgrade
fi

# Update PackageKit packages if available
if is_installed pkcon; then
    highlight "Updating PackageKit packages..."
    pkcon update
fi

# Update Flatpak applications and clean up unused data
if is_installed flatpak; then
    highlight "Updating Flatpak applications..."
    flatpak update

    highlight "Removing unused Flatpak applications..."
    flatpak uninstall --unused

    highlight "Cleaning up orphaned Flatpak data..."
    flatpak uninstall --delete-data
fi

# Upgrade all pipx-installed Python packages
if is_installed pipx; then
    highlight "Updating pipx Python packages..."
    pipx upgrade-all
fi

# Update Rust toolchains
if is_installed rustup; then
    highlight "Updating Rust toolchains..."
    rustup update
fi

# Update ClamAV virus definitions
if is_installed freshclam; then
    highlight "Updating ClamAV virus definitions..."
    sudo freshclam
fi

# Update Tealdeer (tldr) command-line help cache
if is_installed tldr; then
    highlight "Updating Tealdeer (tldr) cache..."
    tldr --update
fi
