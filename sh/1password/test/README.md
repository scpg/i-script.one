# Test harness for `install-1password.sh`

> ⚠️ **Safety rule:** the 1Password installer modifies system state (apt repos,
> GPG keyrings, files under `/etc`, package installs). It is **only ever tested
> inside disposable Docker containers — never on the host machine.**

## What this does

`run-test.sh` builds a throwaway Ubuntu container with a non-root `tester` user
(who has sudo), then runs `install-1password.sh` inside it. The container is
removed after every run (`--rm`), so each test starts from a clean machine and
nothing leaks onto your laptop.

## Requirements

- Docker installed and running.

## Usage

From this `test/` directory:

```bash
./run-test.sh                       # build + auto-run the installer (verbose) on Ubuntu
./run-test.sh ubuntu shell          # interactive shell inside the container
./run-test.sh ubuntu auto -- --help # pass --help straight to the installer
```

Arguments:

| Position | Value | Meaning |
|----------|-------|---------|
| 1 | `ubuntu` (default) | Linux flavour — matches a subfolder with a `Dockerfile` |
| 2 | `auto` (default) / `shell` | Run the installer unattended, or drop into a shell |
| after `--` | any args | Passed verbatim to `install-1password.sh` |

In the container the `tester` user has **passwordless sudo** (so the harness runs
unattended) and also the password **`test`** (so you can exercise the interactive
sudo prompt by hand in `shell` mode).

## Testing idempotency / re-runs

`--rm` gives a *fresh* container each time. To test what happens on a **second
run** (re-adding the repo, overwriting keyrings), run the installer twice inside
one `shell` session:

```bash
./run-test.sh ubuntu shell
# then, inside the container:
./install-1password.sh --verbose
./install-1password.sh --verbose   # second run
```

## Notes & known limitations

- The **1Password desktop app** (`1password` package) needs a GUI + systemd and
  will not launch in a container. The CLI (`op`) installs and works fully. The
  desktop check in the script is non-fatal, so CLI-focused testing is reliable
  here.
- Other Linux flavours (Debian, Fedora, Arch, …) will be added later as sibling
  folders next to `ubuntu/`, each with its own `Dockerfile`. `run-test.sh`
  already picks the flavour by folder name.

## Layout

```
test/
├── README.md          # this file
├── run-test.sh        # builds the image and runs the installer in a container
└── ubuntu/
    └── Dockerfile     # Ubuntu 24.04 test environment
```
