#!/bin/bash
set -e

# =========================
# CONFIG
# =========================
SERVICE="traffic-checker"
CLEANER="traffic-cleaner"
INSTALL_DIR="/opt/traffic-checker"
LOGFILE="/var/log/traffic-checker.log"

echo "=== Installing Traffic Checker (SAFE) + Auto Log Cleaner ==="

# =========================
# ROOT CHECK
# =========================
if [[ "$EUID" -ne 0 ]]; then
    echo "Run with sudo!"
    exit 1
fi

# =========================
# DEPENDENCIES (SAFE)
# =========================
apt update -y >/dev/null 2>&1 || true
apt install -y python3 dnsutils iputils-ping >/dev/null 2>&1 || true

# =========================
# DIRECTORIES & LOG
# =========================
mkdir -p "$INSTALL_DIR"
touch "$LOGFILE"
chmod 666 "$LOGFILE"

# =========================
# PYTHON TRAFFIC CHECKER
# =========================
cat << 'EOF' > "$INSTALL_DIR/traffic_check.py"
#!/usr/bin/env python3
import subprocess
import time
from datetime import datetime

LOGFILE = "/var/log/traffic-checker.log"
INTERVAL = 300  # 5 minutes (SAFE)
START_TIME = time.time()

def ping_check():
    try:
        subprocess.run(
            ["ping", "-c", "1", "-W", "2", "1.1.1.1"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )
        return "PING OK"
    except subprocess.CalledProcessError:
        return "PING FAIL"

def dns_check():
    try:
        subprocess.run(
            ["dig", "google.com", "+short"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )
        return "DNS OK"
    except subprocess.CalledProcessError:
        return "DNS FAIL"

while True:
    uptime = int(time.time() - START_TIME)
    hours = uptime // 3600
    minutes = (uptime % 3600) // 60

    ping_status = ping_check()
    dns_status = dns_check()

    with open(LOGFILE, "a") as log:
        log.write(
            f"[{datetime.now()}] "
            f"{ping_status} | {dns_status} | "
            f"UPTIME: {hours}h {minutes}m\n"
        )

    time.sleep(INTERVAL)
EOF

chmod +x "$INSTALL_DIR/traffic_check.py"

# =========================
# SYSTEMD SERVICE
# =========================
cat << EOF > "/etc/systemd/system/${SERVICE}.service"
[Unit]
Description=Traffic Checker Service (Safe)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/python3 $INSTALL_DIR/traffic_check.py
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

# =========================
# LOG CLEANER SCRIPT
# =========================
cat << 'EOF' > "$INSTALL_DIR/clean_log.sh"
#!/bin/bash
: > /var/log/traffic-checker.log
EOF

chmod +x "$INSTALL_DIR/clean_log.sh"

# =========================
# CLEANER SERVICE
# =========================
cat << EOF > "/etc/systemd/system/${CLEANER}.service"
[Unit]
Description=Traffic Checker Log Cleaner

[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/clean_log.sh
EOF

# =========================
# CLEANER TIMER (EVERY 1 HOUR)
# =========================
cat << EOF > "/etc/systemd/system/${CLEANER}.timer"
[Unit]
Description=Clean Traffic Checker Log every 1 hour

[Timer]
OnBootSec=10min
OnUnitActiveSec=1h
Unit=$CLEANER.service

[Install]
WantedBy=timers.target
EOF

# =========================
# SYSTEMD RELOAD
# =========================
systemctl daemon-reexec
systemctl daemon-reload

# =========================
# ENABLE & START
# =========================
systemctl enable "$SERVICE"
systemctl restart "$SERVICE"

systemctl enable "${CLEANER}.timer"
systemctl start "${CLEANER}.timer"

echo
echo "=== INSTALL DONE ==="
echo "Traffic service : $SERVICE (SAFE)"
echo "Log cleaner     : every 1 hour"
echo "Log file        : $LOGFILE"
