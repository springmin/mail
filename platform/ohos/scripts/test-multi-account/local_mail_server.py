#!/usr/bin/env python3
"""Minimal local IMAP/SMTP server for the multi-account device test.

Plaintext test server on 127.0.0.1:1143 (IMAP) and 127.0.0.1:1025 (SMTP).
It serves one INBOX message and accepts outbound SMTP mail. It is not a
general-purpose mail server; use it only on a trusted test device.
"""

import socketserver
import threading
import time

HOST = "127.0.0.1"
IMAP_PORT = 1143
SMTP_PORT = 1025

MESSAGE = (
    "From: Test Sender <sender@flectar.test>\r\n"
    "To: Local Test <test@flectar.test>\r\n"
    "Subject: Local test message\r\n"
    "Date: Fri, 20 Nov 2026 14:00:00 +0000\r\n"
    "Message-ID: <local-1@flectar.test>\r\n"
    "MIME-Version: 1.0\r\n"
    "Content-Type: text/plain; charset=utf-8\r\n"
    "\r\n"
    "Hello from the local IMAP test server.\r\n"
).encode()

FOLDERS = ["INBOX", "Sent", "Drafts", "Trash", "Junk", "Archive"]
LOG_LOCK = threading.Lock()


def log(line):
    with LOG_LOCK:
        print(time.strftime("%H:%M:%S"), line, flush=True)


def unquote(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] == '"':
        return value[1:-1]
    return value


class ImapHandler(socketserver.StreamRequestHandler):
    def send(self, data):
        if isinstance(data, str):
            data = data.encode()
        self.wfile.write(data)
        self.wfile.flush()

    def handle(self):
        peer = "%s:%s" % self.client_address
        log("IMAP connect %s" % peer)
        self.send("* OK IMAP4rev1 local test server ready\r\n")
        mailbox = "INBOX"
        while True:
            line = self.rfile.readline()
            if not line:
                break
            text = line.decode("utf-8", "replace").rstrip("\r\n")
            if not text:
                continue
            parts = text.split(" ", 2)
            tag = parts[0]
            command = parts[1].upper() if len(parts) > 1 else ""
            rest = parts[2] if len(parts) > 2 else ""
            upper = rest.upper()
            if command == "CAPABILITY":
                self.send(
                    "* CAPABILITY IMAP4rev1 IDLE UIDPLUS MOVE\r\n"
                    f"{tag} OK CAPABILITY completed\r\n"
                )
            elif command == "LOGIN":
                fields = rest.split()
                user = unquote(fields[0]) if fields else ""
                log("IMAP LOGIN %s" % user)
                self.send(f"{tag} OK LOGIN completed\r\n")
            elif command in ("AUTHENTICATE",):
                log("IMAP AUTHENTICATE")
                self.send(f"{tag} OK AUTHENTICATE completed\r\n")
            elif command in ("LIST", "LSUB"):
                for folder in FOLDERS:
                    self.send(f'* {command} (\\HasNoChildren) "/" "{folder}"\r\n')
                self.send(f"{tag} OK {command} completed\r\n")
            elif command in ("SELECT", "EXAMINE"):
                mailbox = unquote(rest.split(" ")[0]) if rest else "INBOX"
                log("IMAP %s %s" % (command, mailbox))
                exists = 1 if mailbox.upper() == "INBOX" else 0
                self.send(
                    "* FLAGS (\\Seen \\Answered \\Flagged \\Deleted \\Draft)\r\n"
                    f"* {exists} EXISTS\r\n"
                    "* 0 RECENT\r\n"
                    "* OK [UIDVALIDITY 1] UIDs valid\r\n"
                    "* OK [UIDNEXT 2] Predicted next UID\r\n"
                    "* OK [PERMANENTFLAGS (\\Seen \\Answered \\Flagged \\Deleted \\Draft \\*)] Limited\r\n"
                    f"{tag} OK [READ-WRITE] {command} completed\r\n"
                )
            elif command == "STATUS":
                exists = 1 if "INBOX" in upper else 0
                self.send(
                    f'* STATUS "INBOX" (MESSAGES {exists} RECENT 0 UIDNEXT 2 UIDVALIDITY 1 UNSEEN 0)\r\n'
                    f"{tag} OK STATUS completed\r\n"
                )
            elif command == "UID":
                sub = upper.split(" ", 1)[0] if rest else ""
                if sub == "SEARCH":
                    self.send(f"* SEARCH 1\r\n{tag} OK SEARCH completed\r\n")
                elif sub in ("STORE", "COPY", "MOVE", "EXPUNGE"):
                    self.send(f"{tag} OK {sub} completed\r\n")
                elif sub == "FETCH":
                    log("IMAP UID FETCH")
                    self.send(
                        "* 1 FETCH (UID 1 FLAGS () INTERNALDATE \"20-Nov-2026 14:00:00 +0000\" "
                        f"RFC822.SIZE {len(MESSAGE)} BODY[] {{{len(MESSAGE)}}}\r\n"
                    )
                    self.wfile.write(MESSAGE)
                    self.wfile.write(b")\r\n")
                    self.wfile.flush()
                    self.send(f"{tag} OK FETCH completed\r\n")
                else:
                    self.send(f"{tag} OK {sub or 'UID'} completed\r\n")
            elif command == "FETCH":
                log("IMAP FETCH")
                self.send(
                    "* 1 FETCH (UID 1 FLAGS () INTERNALDATE \"20-Nov-2026 14:00:00 +0000\" "
                    f"RFC822.SIZE {len(MESSAGE)} BODY[] {{{len(MESSAGE)}}}\r\n"
                )
                self.wfile.write(MESSAGE)
                self.wfile.write(b")\r\n")
                self.wfile.flush()
                self.send(f"{tag} OK FETCH completed\r\n")
            elif command == "IDLE":
                self.send("+ idling\r\n")
                while True:
                    done = self.rfile.readline()
                    if not done or done.strip().upper() == b"DONE":
                        break
                self.send(f"{tag} OK IDLE terminated\r\n")
            elif command == "NOOP":
                self.send(f"{tag} OK NOOP completed\r\n")
            elif command == "LOGOUT":
                self.send(f"* BYE logging out\r\n{tag} OK LOGOUT completed\r\n")
                break
            elif command in (
                "CLOSE",
                "UNSELECT",
                "EXPUNGE",
                "ENABLE",
                "NAMESPACE",
                "ID",
                "CREATE",
                "DELETE",
                "RENAME",
                "SUBSCRIBE",
                "UNSUBSCRIBE",
                "APPEND",
                "CHECK",
            ):
                self.send(f"{tag} OK {command} completed\r\n")
            else:
                self.send(f"{tag} OK {command} completed\r\n")
        log("IMAP disconnect %s" % peer)


class SmtpHandler(socketserver.StreamRequestHandler):
    def send(self, data):
        if isinstance(data, str):
            data = data.encode()
        self.wfile.write(data)
        self.wfile.flush()

    def handle(self):
        peer = "%s:%s" % self.client_address
        log("SMTP connect %s" % peer)
        self.send("220 localhost ESMTP local test\r\n")
        in_data = False
        message = []
        while True:
            line = self.rfile.readline()
            if not line:
                break
            text = line.decode("utf-8", "replace").rstrip("\r\n")
            if in_data:
                if text == ".":
                    in_data = False
                    log("SMTP message accepted (%d lines)" % len(message))
                    message = []
                    self.send("250 2.0.0 Message accepted\r\n")
                else:
                    message.append(text)
                continue
            upper = text.upper()
            if upper.startswith("EHLO") or upper.startswith("HELO"):
                self.send(
                    "250-localhost\r\n"
                    "250-SIZE 10485760\r\n"
                    "250-AUTH PLAIN LOGIN\r\n"
                    "250-8BITMIME\r\n"
                    "250 OK\r\n"
                )
            elif upper.startswith("AUTH PLAIN"):
                log("SMTP AUTH PLAIN")
                self.send("235 2.7.0 Authentication successful\r\n")
            elif upper.startswith("AUTH LOGIN"):
                log("SMTP AUTH LOGIN")
                self.send("334 VXNlcm5hbWU6\r\n")
                self.rfile.readline()
                self.send("334 UGFzc3dvcmQ6\r\n")
                self.rfile.readline()
                self.send("235 2.7.0 Authentication successful\r\n")
            elif upper.startswith("MAIL FROM"):
                log("SMTP MAIL FROM")
                self.send("250 2.1.0 OK\r\n")
            elif upper.startswith("RCPT TO"):
                log("SMTP RCPT TO")
                self.send("250 2.1.0 OK\r\n")
            elif upper == "DATA":
                in_data = True
                self.send("354 End data with <CR><LF>.<CR><LF>\r\n")
            elif upper == "QUIT":
                self.send("221 2.0.0 Bye\r\n")
                break
            elif upper in ("RSET", "NOOP"):
                self.send("250 2.0.0 OK\r\n")
            else:
                self.send("250 2.0.0 OK\r\n")
        log("SMTP disconnect %s" % peer)


class ThreadingServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    imap = ThreadingServer((HOST, IMAP_PORT), ImapHandler)
    smtp = ThreadingServer((HOST, SMTP_PORT), SmtpHandler)
    threading.Thread(target=imap.serve_forever, daemon=True).start()
    threading.Thread(target=smtp.serve_forever, daemon=True).start()
    log("local mail server on %s:%d (IMAP) and %s:%d (SMTP)" % (HOST, IMAP_PORT, HOST, SMTP_PORT))
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
