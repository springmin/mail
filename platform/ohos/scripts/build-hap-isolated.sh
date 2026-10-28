#!/bin/sh
# Build a HAP while keeping the large write path off the user hmdfs tree.
#
# Cargo's advisory file lock is unsupported on the /tmp hmfs mount. The source,
# Cargo.lock and Cargo target therefore stay on hmdfs, but the target uses the
# hidden ~/.cache/flectar-target path so the user-file indexer does not scan
# it. The shell project copy, hvigor output and HAP staging live under /tmp.
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
PLATFORM_DIR=$(dirname "$HERE")
REPO_ROOT=$(cd "$PLATFORM_DIR/../.." && pwd)
ROOT="${OHOS_ISOLATED_ROOT:-/tmp/flectar-build}"
TARGET_DIR="${OHOS_TARGET_DIR:-$HOME/.cache/flectar-target}"
HAP_DIR="$ROOT/hap"
SHELL_DIR="$ROOT/shell"

log() { printf '[isolated-build] %s\n' "$*"; }
die() { printf '[isolated-build] ERROR: %s\n' "$*" >&2; exit 1; }

mkdir -p "$ROOT" "$TARGET_DIR"
[ -w "$ROOT" ] || die "$ROOT is not writable"
# The source, Cargo.lock and target stay on hmdfs for Cargo's file lock; the
# shell/staging outputs use hmfs under /tmp.
if [ -e "$ROOT/mail" ]; then
    if git -C "$REPO_ROOT" worktree list 2>/dev/null | grep -q "$ROOT/mail"; then
        git -C "$REPO_ROOT" worktree remove --force "$ROOT/mail"
    else
        rm -rf "$ROOT/mail"
    fi
fi

rm -rf "$SHELL_DIR"
mkdir -p "$SHELL_DIR"
cp -a "$PLATFORM_DIR/shell/." "$SHELL_DIR/"
mkdir -p "$HAP_DIR"

log "source:       $REPO_ROOT"
log "shell copy:   $SHELL_DIR"
log "cargo target: $TARGET_DIR"
log "hap output:   $HAP_DIR"
log "building with CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS:-1}, incremental off"

cd "$PLATFORM_DIR"
CARGO_TARGET_DIR="$TARGET_DIR" \
OHOS_BUILD_DIR="$HAP_DIR" \
OHOS_SHELL_DIR="$SHELL_DIR" \
CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}" \
CARGO_INCREMENTAL=0 \
CARGO_NET_OFFLINE="${CARGO_NET_OFFLINE:-true}" \
APP="${APP:-mail}" \
PROFILE="${PROFILE:-release}" \
SKIP_CARGO="${SKIP_CARGO:-0}" \
SKIP_SIGN="${SKIP_SIGN:-1}" \
sh scripts/build-hap.sh

HAP="$HAP_DIR/flectar_mail_ohos-unsigned.hap"
[ -f "$HAP" ] || die "unsigned hap not found at $HAP"
log "unsigned hap: $HAP"
