#!/usr/bin/env bats
# Tests for is1-install, is1-remove, is1-doctor, and is1 dispatcher
# Run via run-test.sh (inside Docker) — never on the host

BIN="$HOME/.local/bin"

setup() {
    # Ensure bin dir exists and is empty of is1 links for each test
    mkdir -p "$BIN"
}

teardown() {
    # Remove any is1 links left by a test
    find "$BIN" -maxdepth 1 -name 'is1*' -type l -delete 2>/dev/null || true
}

@test "install.sh creates is1 symlinks in ~/.local/bin" {
    run bash /repo/install.sh -q
    [ "$status" -eq 0 ]
    [ -L "$BIN/is1" ]
    [ -L "$BIN/is1-install" ]
    [ -L "$BIN/is1-doctor" ]
    [ -L "$BIN/is1-remove" ]
    [ -L "$BIN/is1-update" ]
    [ -L "$BIN/is1-bash-syntax-check" ]
}

@test "install.sh is idempotent" {
    bash /repo/install.sh -q
    run bash /repo/install.sh -q
    [ "$status" -eq 0 ]
}

@test "install.sh dry-run makes no changes" {
    run bash /repo/install.sh -n
    [ "$status" -eq 0 ]
    [ ! -L "$BIN/is1" ]
}

@test "is1 help lists available commands" {
    bash /repo/install.sh -q
    run is1 help
    [ "$status" -eq 0 ]
    [[ "$output" == *"is1-bash-syntax-check"* ]]
}

@test "is1 dispatches to subcommand" {
    bash /repo/install.sh -q
    run is1 bash-syntax-check /repo/sh/lib/is1-lib.sh
    [ "$status" -eq 0 ]
}

@test "is1-doctor passes after install" {
    bash /repo/install.sh -q
    run is1-doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

@test "is1-bash-syntax-check passes on all is1 scripts" {
    bash /repo/install.sh -q
    run is1-bash-syntax-check \
        /repo/sh/lib/is1-lib.sh \
        /repo/sh/is1/is1.sh \
        /repo/sh/is1/is1-install.sh \
        /repo/sh/is1/is1-update.sh \
        /repo/sh/is1/is1-remove.sh \
        /repo/sh/is1/is1-doctor.sh
    [ "$status" -eq 0 ]
}

@test "is1-remove removes all is1 symlinks" {
    bash /repo/install.sh -q
    run is1-remove --force
    [ "$status" -eq 0 ]
    [ ! -L "$BIN/is1" ]
    [ ! -L "$BIN/is1-bash-syntax-check" ]
}

@test "is1-remove dry-run leaves symlinks intact" {
    bash /repo/install.sh -q
    run is1-remove -n
    [ "$status" -eq 0 ]
    [ -L "$BIN/is1" ]
}

@test "is1-doctor reports missing symlinks after remove" {
    bash /repo/install.sh -q
    is1-remove --force
    # Call by repo path since the symlink itself was just removed
    run bash /repo/sh/is1/is1-doctor.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}
