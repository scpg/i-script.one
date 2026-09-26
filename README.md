# i-script.one

A growing collection of shell scripts for Linux and Windows administration tasks.

## Install

```bash
git clone https://github.com/scpg/i-script.one
cd i-script.one
bash install.sh
```

This symlinks all `is1-*` scripts into `~/.local/bin` so they are available as commands.

## Usage

```bash
is1 help                      # list all available commands
is1-doctor                    # verify the installation
is1-update                    # pull latest changes and re-link
is1-bash-syntax-check <file>  # check shell script syntax (uses shellcheck)
```

Run any command with `-h` for its own help:

```bash
is1-install -h
is1-remove -h
```

## Uninstall

```bash
is1-remove
```

## Requirements

- bash 4+
- git (for `is1-update`)
- shellcheck (optional, for `is1-bash-syntax-check` — falls back to `bash -n` without it)
