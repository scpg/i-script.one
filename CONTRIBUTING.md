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
