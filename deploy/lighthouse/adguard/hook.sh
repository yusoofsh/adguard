#!/bin/sh
# lego deploy hook: reload AdGuard Home TLS config after a certificate renewal.
if [ "$(cat /proc/1/comm 2>/dev/null)" = "AdGuardHome" ]; then
  echo "hook: sending SIGHUP to AdGuardHome (pid 1)" >&2
  kill -HUP 1
else
  echo "hook: /proc/1/comm is not AdGuardHome; skipping SIGHUP" >&2
fi
exit 0
