#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="/opt/aws-python-app"
SERVICE_NAME="aws-python-app"
APP_USER="appuser"

sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-pip

if ! id "$APP_USER" >/dev/null 2>&1; then
  sudo useradd --system --create-home --shell /usr/sbin/nologin "$APP_USER"
fi

sudo mkdir -p "$APP_DIR"
sudo cp -r app/. "$APP_DIR/"
sudo chown -R "$APP_USER:$APP_USER" "$APP_DIR"

sudo -u "$APP_USER" python3 -m venv "$APP_DIR/venv"
sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install --upgrade pip
sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"

sudo tee "/etc/systemd/system/$SERVICE_NAME.service" >/dev/null <<'UNIT'
[Unit]
Description=GitHub Actions deployed Python Flask application
After=network.target

[Service]
User=appuser
Group=appuser
WorkingDirectory=/opt/aws-python-app
Environment=DEPLOYMENT_METHOD=ec2
ExecStart=/opt/aws-python-app/venv/bin/gunicorn --workers 2 --bind 0.0.0.0:5000 app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"
sudo systemctl --no-pager --full status "$SERVICE_NAME"

echo "Deployment completed."
