# Contributing

## Branch workflow

Work on a feature branch, never directly on `main`.

```
main        ← protected, merged via PR only
dev         ← integration branch
feature/*   ← one branch per script family
```

Open a PR from your feature branch into `dev`. CI must be green before merging.

## Testing scripts safely

Scripts in this repo modify system state (apt repos, GPG keyrings, packages, `/etc`).
**Never run them directly on your machine.**

Use the Docker-based test harnesses provided alongside each script family:

```bash
# 1Password installer
cd sh/1password/test
./run-test.sh              # auto-run inside a disposable Ubuntu container
./run-test.sh ubuntu shell # interactive shell for manual testing
```

Each run starts from a clean container (`--rm`) and leaves your host untouched.

## Shared library (`sh/lib/is1-lib.sh`)

All `is1-*` scripts source the shared library at startup:

```bash
_LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/is1-lib.sh"
source "$_LIB"
```

The library provides: output helpers (`info`, `warn`, `error`, `die`, `step`), input
validation (`require_arg`, `require_file`, `require_dir`), command execution (`run` with
dry-run support via `IS1_DRY_RUN`), privilege escalation (`require_sudo`), and OS
detection (`detect_os`, `detect_os_version`).

**Rule:** If a pattern appears in more than one script, it belongs in `is1-lib.sh`, not
in the individual scripts.

## Meta-tools (`is1-*` naming convention)

Every script that is installed as a command is named `is1-<verb>-<subject>.sh`. When
installed, the `.sh` extension is dropped: `is1-install-docker-ubuntu.sh` becomes the
command `is1-install-docker-ubuntu`.

Each script must include a description comment on line 2:
```bash
# is1-description: <one-line description shown in is1 help>
```

The `is1` dispatcher reads this to build the help listing.

New scripts are discovered automatically by `is1-install` — no registration step needed.

## Testing meta-tools

The `is1` meta-tools (`is1-install`, `is1-remove`, `is1-doctor`, `is1-update`) are
tested with `bats-core` inside Docker:

```bash
cd sh/is1/test
./run-test.sh          # run the full bats suite in Docker
./run-test.sh shell    # interactive shell for manual debugging
```

## Local scratch directories (`*.local/`)

Any directory named `*.local` (e.g. `tmp.local/`, `notes.local/`) is reserved for
**local-only, throwaway content** — scratch scripts, temporary exports, work-in-progress
files that should never be committed.

Convention:
- The directory itself **is** tracked in git (via a `.gitkeep` or `.keep` anchor file)
  so it exists on a fresh clone without any manual setup.
- Its **contents** are gitignored — anything you put inside stays on your machine only.
- The pattern covers any depth: `docs/drafts.local/`, `sh/debug.local/`, etc.

```
tmp.local/        ← exists in the repo (tracked via .gitkeep)
tmp.local/my-experiment.sh   ← gitignored, never committed
```

This is a deliberate project convention, not a community standard. The `.local` suffix
is the signal: if a directory ends in `.local`, its contents stay local.
