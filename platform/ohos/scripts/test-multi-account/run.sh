#!/bin/sh
# Repeatable multi-account test harness for the OpenHarmony host.
#
# Run this on the OpenHarmony device (the same machine as the app), from the
# repository root or from this directory:
#
#   platform/ohos/scripts/test-multi-account/run.sh --reset
#   platform/ohos/scripts/test-multi-account/run.sh --verify
#   platform/ohos/scripts/test-multi-account/run.sh --stop
#
# The script starts a plaintext local IMAP/SMTP server, builds a two-account
# backup from a real account backup, optionally clears the app data, and
# verifies that the app logged in to the local test account.
#
# Clearing data is destructive and only happens with --reset. The app's
# account backup does not include passwords or OAuth tokens; the real account
# needs its normal sign-in after a reset.
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUNDLE=${BUNDLE:-com.flectar.mail}
TARGET=${HDC_TARGET:-}
SOURCE=
OUT=${OUT:-$HOME/Desktop/flectar-multi-test.json}
MODE=setup
ASSUME_YES=0

usage() {
    cat <<EOF
usage: $0 [--reset] [--verify] [--stop] [--source <backup>] [--out <backup>]
          [--target <hdc-target>] [--yes]

  --reset    clear the app data, launch it, and print the import steps
  --verify   check the local server log for the app's test-account login
  --stop     stop the local test server
  --source   real Flectar Mail account backup to extend
  --out      output backup (default: \$HOME/Desktop/flectar-multi-test.json)
  --target   hdc target; defaults to \$HDC_TARGET or the first reported target
  --yes      do not ask before clearing the app data

Environment: BUNDLE (default com.flectar.mail), HDC_TARGET.
EOF
}

while [ $# -gt 0 ]; do
    case $1 in
        --reset) MODE=reset ;;
        --verify) MODE=verify ;;
        --stop) MODE=stop ;;
        --source) shift; SOURCE=${1:?--source needs a path} ;;
        --out) shift; OUT=${1:?--out needs a path} ;;
        --target) shift; TARGET=${1:?--target needs a value} ;;
        --yes) ASSUME_YES=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

LOG=$DIR/.server.log
PIDFILE=$DIR/.server.pid

port_open() {
    python3 - "$1" <<'PY'
import socket
import sys

sock = socket.socket()
sock.settimeout(0.5)
try:
    sock.connect(("127.0.0.1", int(sys.argv[1])))
except OSError:
    print("closed")
else:
    print("open")
finally:
    sock.close()
PY
}

start_server() {
    if [ "$(port_open 1143)" = open ] && [ "$(port_open 1025)" = open ]; then
        echo "local mail server already running"
        return
    fi
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "local mail server already running (pid $(cat "$PIDFILE"))"
        return
    fi
    : >"$LOG"
    nohup python3 "$DIR/local_mail_server.py" >>"$LOG" 2>&1 </dev/null &
    echo $! >"$PIDFILE"
    i=0
    while [ "$i" -lt 20 ]; do
        if [ "$(port_open 1143)" = open ] && [ "$(port_open 1025)" = open ]; then
            echo "local mail server started (pid $(cat "$PIDFILE"))"
            return
        fi
        i=$((i + 1))
        sleep 0.25
    done
    echo "local mail server did not start; log:" >&2
    tail -20 "$LOG" >&2 || true
    exit 1
}

stop_server() {
    if [ -f "$PIDFILE" ]; then
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            echo "stopped local mail server (pid $pid)"
        fi
        rm -f "$PIDFILE"
    else
        echo "no server started by this script"
    fi
}

pick_target() {
    if [ -n "$TARGET" ]; then
        return
    fi
    TARGET=$(hdc list targets 2>/dev/null | head -1 || true)
    if [ -z "$TARGET" ] || [ "$TARGET" = "[Empty]" ]; then
        echo "No hdc target. Set HDC_TARGET, pass --target, or connect the device." >&2
        echo "Example: hdc tconn 127.0.0.1:35175" >&2
        exit 1
    fi
}

verify() {
    echo "server log: $LOG"
    if grep -q "IMAP LOGIN test@flectar.test" "$LOG"; then
        echo "PASS: the app logged in to test@flectar.test"
        grep -q "IMAP SELECT" "$LOG" && echo "PASS: the app selected a mailbox"
        grep -q "SMTP message accepted" "$LOG" && echo "PASS: the app sent a message"
        exit 0
    fi
    echo "NOT YET: no app login to test@flectar.test in the server log."
    echo "Complete the sign-in in the app (password: test), then run --verify again."
    tail -10 "$LOG" || true
    exit 1
}

reset_app() {
    pick_target
    if [ "$ASSUME_YES" -ne 1 ]; then
        printf 'Clear all app data for %s on %s? [y/N] ' "$BUNDLE" "$TARGET"
        read -r answer || answer=
        case $answer in
            y|Y|yes|YES) ;;
            *) echo "cancelled"; exit 1 ;;
        esac
    fi
    hdc -t "$TARGET" shell "aa force-stop $BUNDLE" >/dev/null 2>&1 || true
    hdc -t "$TARGET" shell "bm clean -n $BUNDLE -d"
    hdc -t "$TARGET" shell "aa start -b $BUNDLE -a EntryAbility"
    echo "app data cleared and app launched"
}

if [ "$MODE" = stop ]; then
    stop_server
    exit 0
fi

start_server

if [ "$MODE" = verify ]; then
    verify
fi

python3 "$DIR/make_backup.py" --source "$SOURCE" --out "$OUT"

if [ "$MODE" = reset ]; then
    reset_app
fi

cat <<EOF

Test account:
  email    test@flectar.test
  password test
  IMAP     127.0.0.1:1143, security none
  SMTP     127.0.0.1:1025, security none
EOF

if [ "$MODE" = reset ]; then
    cat <<EOF

Steps on the device:
  1. Accept the consent screen.
  2. On the welcome screen choose "Import accounts and mail".
  3. Choose $OUT in the file picker (Desktop).
  4. When "Imported 2 accounts" appears, choose "Open accounts".
  5. Local Test -> pencil -> password "test" -> Save account.
  6. Run this script with --verify.
EOF
else
    cat <<EOF

If the app has no accounts, export a real backup and run this script with
--reset. If Local Test is already listed (from a previous import), open
Settings -> Accounts -> Local Test -> pencil -> password "test" -> Save
account. Otherwise use "Add mail account" with the test account values above.
Then run this script with --verify.
EOF
fi

cat <<EOF

Server control:
  $DIR/run.sh --verify   # check the app's login
  $DIR/run.sh --stop     # stop the local server
EOF
