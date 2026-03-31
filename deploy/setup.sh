#!/usr/bin/env bash
set -euo pipefail

# TY Trading Backend — Server Setup Script
# Run on the target server as root or with sudo

APP_DIR="/opt/ty-backend"
SERVICE_NAME="ty-backend"
NGINX_CONF="/etc/nginx/sites-enabled/pump-scanner"

echo "=== [1/9] Creating $APP_DIR ==="
sudo mkdir -p "$APP_DIR"
sudo chown ubuntu:ubuntu "$APP_DIR"

echo "=== [2/9] Creating Python venv ==="
python3 -m venv "$APP_DIR/.venv"

echo "=== [3/9] Copying code ==="
# Assumes this script is run from the project root
rsync -a --exclude='.venv' --exclude='__pycache__' --exclude='.git' \
    ./ "$APP_DIR/"

echo "=== [4/9] Installing dependencies ==="
"$APP_DIR/.venv/bin/pip" install --upgrade pip
"$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"

echo "=== [5/9] Creating .env from template ==="
if [ ! -f "$APP_DIR/.env" ]; then
    cp "$APP_DIR/deploy/.env.example" "$APP_DIR/.env"
    echo ">>> Created .env — please edit with real credentials"
else
    echo ">>> .env already exists, skipping"
fi

echo "=== [6/9] Running DB migration ==="
cd "$APP_DIR"
"$APP_DIR/.venv/bin/python" -c "
import subprocess, sys
# Run the schema SQL if alembic is not set up yet
print('Schema creation handled by deploy SQL scripts')
"

echo "=== [7/9] Installing systemd service ==="
sudo cp "$APP_DIR/deploy/ty-backend.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"

echo "=== [8/9] Adding nginx config ==="
# Check if ty location block already exists
if ! grep -q '/api/ty/' "$NGINX_CONF"; then
    # Insert the ty location block before the final 'location / {' block
    sudo sed -i '/^    location \/ {/i \
    location /api/ty/ {\
        proxy_pass http://127.0.0.1:8003/;\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto $scheme;\
        proxy_read_timeout 60s;\
    }\
' "$NGINX_CONF"
    echo ">>> Added /api/ty/ location block to nginx"
else
    echo ">>> /api/ty/ location block already exists in nginx"
fi

echo "=== [9/9] Reloading nginx ==="
sudo nginx -t && sudo systemctl reload nginx
echo ">>> nginx reloaded successfully"

echo ""
echo "=== Setup complete ==="
echo "Start the service: sudo systemctl start $SERVICE_NAME"
echo "Check status:      sudo systemctl status $SERVICE_NAME"
echo "View logs:         sudo journalctl -u $SERVICE_NAME -f"
