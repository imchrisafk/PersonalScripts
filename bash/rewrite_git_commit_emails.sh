#!/bin/bash

# This script updates the author and committer email and name for all commits
# in a Git repository that match one or more specified old email addresses.
# It is designed to help users change their Git commit metadata, such as when
# updating to a new email address or correcting a misconfigured one.
#
# Usage: ./update_git_commits.sh <new_name> <new_email> <old_email1> [<old_email2> ...]
#
# Requirements:
#   - Run this script from the root of a Git repository.
#   - Ensure you have write permissions for the repository.
#   - The `git` command-line tool must be installed.
#   - Back up important repositories before running, as the script rewrites history.
#
# Notes:
#   - Creates a backup of the repository before making changes.
#   - Uses `git filter-branch` to rewrite commit history (Note: `git filter-repo` is recommended
#     for modern Git versions but this script uses `filter-branch` for broader compatibility).
#   - Force-pushing (`git push --force --all`) is required after running to update the remote repository.
#   - Coordinate with collaborators, as rewriting history can disrupt their clones.
#   - Ensure the new email is added to your GitHub account to maintain contribution tracking.

# Configuration
NEW_NAME="$1"
NEW_EMAIL="$2"
REPO_DIR="$(pwd)"
BACKUP_DIR="${REPO_DIR}-backup-$(date +%Y%m%d-%H%M%S)"

# Backup the repository
echo "Creating backup at $BACKUP_DIR..."
cp -r "$REPO_DIR" "$BACKUP_DIR"
if [ $? -ne 0 ]; then
    echo "Backup failed. Exiting."
    exit 1
fi

shift 2

for OLD_EMAIL in "$@"; do

    # Rewrite commit history
    echo "Rewriting commit history for email ${OLD_EMAIL}..."
    git filter-branch -f --env-filter '
    if [ "$GIT_COMMITTER_EMAIL" = "'"$OLD_EMAIL"'" ]; then
        export GIT_COMMITTER_EMAIL="'"$NEW_EMAIL"'"
        export GIT_COMMITTER_NAME="'"$NEW_NAME"'"
    fi
    if [ "$GIT_AUTHOR_EMAIL" = "'"$OLD_EMAIL"'" ]; then
        export GIT_AUTHOR_EMAIL="'"$NEW_EMAIL"'"
        export GIT_AUTHOR_NAME="'"$NEW_NAME"'"
    fi
    ' --tag-name-filter cat -- --branches --tags
    if [ $? -ne 0 ]; then
        echo "History rewrite failed. Restore from $BACKUP_DIR if needed."
        exit 1
    fi

done
     
# Clean up
echo "Cleaning up..."
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now
     
echo "Done! Commits updated to use name '$NEW_NAME' and email '$NEW_EMAIL'."
echo "Backup is at $BACKUP_DIR. Notify collaborators about the history rewrite."
