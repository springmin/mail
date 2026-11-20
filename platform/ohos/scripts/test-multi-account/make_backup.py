#!/usr/bin/env python3
"""Add the local test account to a real Flectar Mail account backup.

The result is a version 2 account backup with the user's real account(s) plus
a password account pointing at local_mail_server.py. The app's import dialog
accepts it on the welcome screen. Passwords are never included in a backup, so
the local account is signed in once in the app with TEST_PASSWORD.
"""

import argparse
import copy
import datetime
import json
import os
import sys

FORMAT = "flectar-mail-account-backup"
VERSION = 2
LOCAL_EMAIL = "test@flectar.test"
LOCAL_PASSWORD = "test"  # entered in the app after import; not stored in the backup
LOCAL_HOST = "127.0.0.1"
IMAP_PORT = 1143
SMTP_PORT = 1025


def latest_backup():
    desktop = os.path.expanduser("~/Desktop")
    if not os.path.isdir(desktop):
        return None
    candidates = [
        os.path.join(desktop, name)
        for name in os.listdir(desktop)
        if name.startswith("flectar-mail-backup-") and name.endswith(".json")
    ]
    candidates = [path for path in candidates if os.path.isfile(path)]
    if not candidates:
        return None
    return max(candidates, key=os.path.getmtime)


def local_account(template):
    account = copy.deepcopy(template)
    account.update(
        {
            "authKind": "password",
            "displayName": "Local Test",
            "email": LOCAL_EMAIL,
            "incomingHost": LOCAL_HOST,
            "incomingPort": IMAP_PORT,
            "jmapUrl": "",
            "mailProtocol": "imap",
            "provider": "generic",
            "smtpHost": LOCAL_HOST,
            "smtpPort": SMTP_PORT,
            "username": LOCAL_EMAIL,
        }
    )
    settings = account.setdefault("settings", {})
    settings["connection"] = {
        "incomingSecurity": "none",
        "smtpSecurity": "none",
        "trustedCertificatePem": "",
    }
    settings["defaultSenderEmail"] = None
    return account


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        help="real account backup to extend (default: newest flectar-mail-backup-*.json on the Desktop)",
    )
    parser.add_argument(
        "--out",
        default=os.path.expanduser("~/Desktop/flectar-multi-test.json"),
        help="output backup path",
    )
    args = parser.parse_args()

    source = args.source or latest_backup()
    if not source:
        sys.exit(
            "No source backup found. Export one from Settings -> Storage -> "
            "Export Flectar Mail account backup, or pass --source."
        )
    try:
        with open(source, encoding="utf-8") as handle:
            backup = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        sys.exit("Could not read %s: %s" % (source, error))

    if backup.get("format") != FORMAT or backup.get("version") != VERSION:
        sys.exit(
            "%s is not a version %d %s file" % (source, VERSION, FORMAT)
        )
    if backup.get("includesCredentials"):
        sys.exit("The source backup includes credentials; the app refuses those.")

    accounts = backup.get("accounts")
    if not isinstance(accounts, list) or not accounts:
        sys.exit("The source backup has no accounts.")

    template = next(
        (account for account in accounts if account.get("provider") != "generic"),
        accounts[0],
    )
    test = local_account(template)
    accounts[:] = [
        account for account in accounts if account.get("email") != LOCAL_EMAIL
    ]
    accounts.append(test)
    backup["createdAt"] = datetime.datetime.now(
        datetime.timezone.utc
    ).isoformat()
    backup["includesCredentials"] = False

    out = os.path.expanduser(args.out)
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(backup, handle, indent=1)
        handle.write("\n")

    print("source : %s" % source)
    print("output : %s" % out)
    for account in accounts:
        print(
            "account: %s (%s/%s, %s:%s)"
            % (
                account.get("email"),
                account.get("provider"),
                account.get("authKind"),
                account.get("incomingHost"),
                account.get("incomingPort"),
            )
        )
    print()
    print("After importing, sign in to %s with password %r." % (LOCAL_EMAIL, LOCAL_PASSWORD))


if __name__ == "__main__":
    main()
