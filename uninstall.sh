#!/bin/bash
set -e

SERVICE="traffic-checker"
CLEANER="traffic-cleaner"
INSTALL_DIR="/opt/traffic-checker"
LOGFILE="/var/log/traffic-checker.log"

echo "=== Uninstalling Traffic Checker ==="

# Root check
if [ "$EUID" -ne 0 ]; then
  echo "Please run with sudo!"
  exit 1
fi

# Stop services
systemctl stop $SERVICE 2>/dev/null || true
systemctl stop $CLEANER.timer 2>/dev/null || true

# Disable services
systemctl disable $SERVICE 2>/dev/null || true
systemctl disable $CLEANER.timer 2>/dev/null || true

# Remove systemd files
rm -f /etc/systemd/system/$SERVICE.service
rm -f /etc/systemd/system/$CLEANER.service
rm -f /etc/systemd/system/$CLEANER.timer

# Reload systemd
systemctl daemon-reexec
systemctl daemon-reload

# Remove files
rm -rf $INSTALL_DIR
rm -f $LOGFILE

echo
echo "=== UNINSTALL DONE ==="
echo "✔ Service removed"
echo "✔ Timer removed"
echo "✔ Logs deleted"
echo "✔ Files cleaned"
