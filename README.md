# PersonalScripts

A collection of bash and Python scripts for automating tasks and simplifying workflows on Linux.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

## Contents

- [Scripts](#scripts)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Environment](#environment)
- [License](#license)

---

## Scripts

### Bash

| Script | Description |
|---|---|
| `bash/go2sleep.sh` | Cleans up the system (trash, logs, RPM cache, snapshots, BleachBit) then shuts down |
| `bash/rewrite_git_commit_emails.sh` | Rewrites author/committer name and email across all commits in a repo's history |
| `bash/squarizevideo.sh` | Converts a video to 1:1 aspect ratio by adding a blurred background via ffmpeg |
| `bash/updateall.sh` | Updates system packages, Flatpak, pipx, Rust, ClamAV definitions, and tldr cache |

### Python

| Script | Description |
|---|---|
| `python/webp_to_apng.py` | Converts an animated WebP file to APNG, preserving frame durations |

## Prerequisites

- `bash` — for all `.sh` scripts
- `python3` + `Pillow` — for `webp_to_apng.py` (`pip install Pillow`)
- `ffmpeg` — for `squarizevideo.sh`
- `git` — for `rewrite_git_commit_emails.sh`
- Other per-script dependencies (e.g. `flatpak`, `rustup`, `snapper`) are optional (scripts check for them before running)

## Usage

Clone the repository:

```bash
git clone https://codeberg.org/chrisafk/PersonalScripts.git
cd PersonalScripts
```

Run a bash script:

```bash
bash bash/script-name.sh
```

Run the Python script:

```bash
pip install Pillow
python3 python/webp_to_apng.py input.webp output.png
```

For `rewrite_git_commit_emails.sh`, run from the root of the target repository:

```bash
bash /path/to/rewrite_git_commit_emails.sh <new_name> <new_email> <old_email> [<old_email2> ...]
```

> [!WARNING]
> `rewrite_git_commit_emails.sh` rewrites Git history. A backup is created automatically, but force-pushing afterwards will disrupt collaborators' clones.

## Environment

Developed and tested on **openSUSE Tumbleweed**. Most scripts should work on other systemd-based Linux distributions, though package manager commands (`zypper`, `snapper`, etc.) are openSUSE-specific.

## License

Licensed under the [GNU General Public License v3.0](LICENSE).
