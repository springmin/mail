#!/bin/sh
# Build a HAP from a temporary worktree whose Cargo target, hvigor output and
# HAP staging all live under /tmp (hmfs userdata), not the user hmdfs tree.
#
# The user hmdfs tree is indexed and security-scanned; large Rust targets there
# caused severe I/O pressure and system reboots on this device. This wrapper
# keeps the build write path off hmdfs. The source worktree is disposable.
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
PLATFORM_DIR=$(dirname "$HERE")
REPO_ROOT=$(cd "$PLATFORM_DIR/../.." && pwd)
ROOT="${OHOS_ISOLATED_ROOT:-/tmp/flectar-build}"
WORKTREE="$ROOT/mail"
TARGET_DIR="$ROOT/target"
HAP_DIR="$ROOT/hap"
REVISION="${OHOS_ISOLATED_REVISION:-$(git -C "$REPO_ROOT" rev-parse HEAD)}"

log() { printf '[isolated-build] %s\n' "$*"; }
die() { printf '[isolated-build] ERROR: %s\n' "$*" >&2; exit 1; }

mkdir -p "$ROOT"
[ -w "$ROOT" ] || die "$ROOT is not writable"
# /tmp is backed by hmfs userdata on this device, not by the user hmdfs tree.
case "$ROOT" in
    /tmp/*) ;;
    *) log "warning: $ROOT is not under /tmp; verify it is not an indexed hmdfs path" ;;
esac

if [ -e "$WORKTREE/.git" ]; then
    log "recreating disposable worktree $WORKTREE"
    git -C "$REPO_ROOT" worktree remove --force "$WORKTREE"
elif [ -e "$WORKTREE" ]; then
    die "$WORKTREE exists but is not a git worktree; remove it manually"
fi
log "worktree $WORKTREE at $REVISION"
git -C "$REPO_ROOT" worktree add --detach "$WORKTREE" "$REVISION"

# Ignored build inputs are not part of the worktree. Copy only the staged
# native libraries and local hvigor modules; do not copy target/build output.
if [ -d "$REPO_ROOT/platform/ohos/prebuilt" ]; then
    rm -rf "$WORKTREE/platform/ohos/prebuilt"
    cp -a "$REPO_ROOT/platform/ohos/prebuilt" "$WORKTREE/platform/ohos/prebuilt"
fi
if [ -d "$REPO_ROOT/platform/ohos/shell/oh_modules" ]; then
    rm -rf "$WORKTREE/platform/ohos/shell/oh_modules"
    cp -a "$REPO_ROOT/platform/ohos/shell/oh_modules" "$WORKTREE/platform/ohos/shell/oh_modules"
fi

mkdir -p "$TARGET_DIR" "$HAP_DIR"
log "cargo target: $TARGET_DIR"
log "hap output:   $HAP_DIR"
log "building with CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS:-1}, incremental off"

cd "$WORKTREE/platform/ohos"
CARGO_TARGET_DIR="$TARGET_DIR" \
OHOS_BUILD_DIR="$HAP_DIR" \
CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}" \
CARGO_INCREMENTAL=0 \
CARGO_NET_OFFLINE="${CARGO_NET_OFFLINE:-true}" \
APP="${APP:-mail}" \
PROFILE="${PROFILE:-release}" \
SKIP_SIGN="${SKIP_SIGN:-1}" \
sh scripts/build-hap.sh

HAP="$HAP_DIR/flectar_mail_ohos-unsigned.hap"
[ -f "$HAP" ] || die "unsigned hap not found at $HAP"
log "unsigned hap: $HAP"
log "worktree and target remain under $ROOT; this tree is disposable"
