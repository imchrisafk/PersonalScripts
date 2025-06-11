#!/usr/bin/env bash

source chrislib.sh

BASH_HISTORY=.bash_history
TEMP_HISTORY=.new_bash_history
MAX_NUM_ENTRIES=50

SYSTEM_CACHE=.cache/
CACHE_ITEMS=(chromium digikam dolphin falkon favicons jedi kdeconnect.daemon kdenlive kioexec librewolf mozilla Otter peek pip "Raspberry Pi" samba showfoto spectacle starship strawberry thunderbird transmission whisper yakuake yarn yt-dlp)
FLOORP_CACHE=.var/app/one.ablaze.floorp/cache/

store_cd
cd $HOME

# Empty Trash
highlight "Emptying trash..."
gio trash --empty

# Clear Old System Logs
highlight "Clearing old logs..."
sudo journalctl --rotate
sudo journalctl --vacuum-time=7d

# Remove System Cache
highlight "Deleting cache..."
for CACHE_ITEM in ${CACHE_ITEMS[@]}; do
    secure_dir_rm "$SYSTEM_CACHE$CACHE_ITEM"
done

# Remove Floorp Cache
highlight "Removing Floorp cache..."
secure_dir_rm $FLOORP_CACHE

# Delete Stale RPM Packages
highlight "Deleting stale RPM packages..."
sudo zypper clean

# Trim Old System Snapshots
highlight "Trimming old system snapshots..."
sudo snapper cleanup number

# Limit Bash History to MAX_NUM_ENTRIES
highlight "Truncating bash history..."
tail -n $MAX_NUM_ENTRIES $BASH_HISTORY >$TEMP_HISTORY
srm -P $BASH_HISTORY
mv $TEMP_HISTORY $BASH_HISTORY

# Restore previous directory since it is no longer required.
recover_cd

## Shutdown ##
highlight "Good night..."
sudo shutdown now
