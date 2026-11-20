# Multi-account test harness

Repeatable setup and verification for the OpenHarmony multi-account path. It
starts a plaintext IMAP/SMTP server on localhost, extends a real Flectar Mail
account backup with a `test@flectar.test` account, optionally clears the app
data, and checks that the app signs in to the test account.

## Prerequisites

- The app is installed on the device.
- `hdc` can reach the device (`HDC_TARGET` or `hdc tconn`).
- Python 3 is available on the device.
- A real Flectar Mail account backup (Settings → Storage → *Export Flectar
  Mail account backup*). The newest `~/Desktop/flectar-mail-backup-*.json` is
  used by default.

## Run

```sh
cd <repository>
platform/ohos/scripts/test-multi-account/run.sh --reset
```

`--reset` is destructive: it runs `bm clean -n com.flectar.mail -d`, which
removes the app's database, preferences and OAuth tokens. The real account's
configuration is restored by the import; its OAuth sign-in is still required.
Use `--yes` to skip the confirmation prompt.

Then follow the printed steps:

1. Accept the consent screen.
2. Welcome → **Import accounts and mail**.
3. Choose `~/Desktop/flectar-multi-test.json`.
4. **Open accounts**.
5. **Local Test** → pencil → password `test` → **Save account**.

Verify:

```sh
platform/ohos/scripts/test-multi-account/run.sh --verify
```

The script prints `PASS: the app logged in to test@flectar.test` after the
app's IMAP client reaches the local server. It also reports mailbox selection
and accepted SMTP mail when present.

## Without clearing data

If the app already has accounts, use **Settings → Accounts → Add mail
account** with the values below. If a previous run already imported **Local
Test**, open its pencil instead and set the password there.

| Field | Value |
| --- | --- |
| Email / username | `test@flectar.test` |
| Password | `test` |
| IMAP server / port | `127.0.0.1` / `1143` |
| SMTP server / port | `127.0.0.1` / `1025` |
| Connection security | `None` |

Then run `--verify`.

## What is tested

- The account backup parser accepts a two-account backup with a `None`
  security password account.
- The onboarding import restores both account configurations.
- The Accounts page lists both accounts and their settings.
- The password account logs in to the local IMAP server, selects INBOX, and
  can send through the local SMTP server.

The import UI steps are manual: the system picker and soft keyboard focus are
environment-dependent on the 2-in-1, so the harness does not drive them.

## Cleanup

```sh
platform/ohos/scripts/test-multi-account/run.sh --stop
```

The test server only listens on `127.0.0.1`; do not expose it. The test account
can be removed from the app after the run. The real account is restored by the
import and needs its normal OAuth sign-in.
