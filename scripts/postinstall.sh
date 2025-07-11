#!/bin/bash
# VileSQL Post-Installation Script

set -e

DATA_DIR="/var/lib/vilesql"
LOG_DIR="/var/log/vilesql"
LOG_FILE="$LOG_DIR/vilesql.log"
RUNTIME_LOG_FILE="/var/log/vilesql.log"
BIN_PATH="/usr/bin/vilesql"
SERVICE_PATH="/etc/systemd/system/vilesql.service"
ENV_FILE="$DATA_DIR/.env"
USER="vilesql"
GROUP="vilesql"

log() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "🚀 Starting VileSQL post-installation script"

# Ensure running as root
if [[ "$EUID" -ne 0 ]]; then
    echo "❌ This script must be run as root!"
    exit 1
fi

# Create VileSQL system user and group (if missing)
if ! id "$USER" &>/dev/null; then
    log "📌 Creating system user: $USER"
    useradd -r -s /bin/false -d "$DATA_DIR" "$USER" || {
        log "❌ Failed to create system user: $USER"
        exit 1
    }
fi

# Ensure correct ownership for binary
log "🔧 Fixing ownership for VileSQL binary"
chown "$USER:$GROUP" "$BIN_PATH"
chmod 755 "$BIN_PATH"

# Create necessary directories with correct ownership
for dir in "$DATA_DIR" "$LOG_DIR"; do
    if [[ ! -d "$dir" ]]; then
        log "📁 Creating directory: $dir"
        mkdir -p "$dir" || {
            log "❌ Failed to create $dir"
            exit 1
        }
    fi
    chown "$USER:$GROUP" "$dir"
done

# Ensure log file exists
if [[ ! -f "$LOG_FILE" ]]; then
    log "📝 Creating log file: $LOG_FILE"
    touch "$LOG_FILE"
    chown "$USER:$GROUP" "$LOG_FILE"
    chmod 644 "$LOG_FILE"
fi

# Ensure required environment file exists with proper permissions
if [[ ! -f "$ENV_FILE" ]]; then
    log "⚠️ Environment file missing! Creating default."
    cat <<EOF | sudo tee "$ENV_FILE" > /dev/null
PORT=5000
SESSION_KEY=default-session-key
COOKIE_STORE_KEY=default-session-key
HOST=0.0.0.0
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=example@gmail.com
SMTP_PASSWORD=your_password
SMTP_FROM=example@gmail.com
EOF
fi

# Fix permissions for environment file
log "🔧 Setting correct permissions for environment file"
chown "$USER:$GROUP" "$ENV_FILE"
chmod 755 "$ENV_FILE"

# Set secure permissions for other directories
chmod 755 "$DATA_DIR"
chmod 755 "$LOG_DIR"

# Install systemd service file (if missing)
if [[ ! -f "$SERVICE_PATH" ]]; then
    log "⚙️ Installing systemd service file"
    if [[ -f "scripts/vilesql.service" ]]; then
        cp scripts/vilesql.service "$SERVICE_PATH"
        chmod 644 "$SERVICE_PATH"
        systemctl daemon-reload
    else
        log "❌ Service file missing: scripts/vilesql.service"
        exit 1
    fi
fi

# Enable service
log "🔄 Enabling VileSQL service..."
systemctl enable vilesql.service || log "⚠️ Warning: Failed to enable service."

# Check for missing dependencies
log "🔍 Checking dependencies..."
if ldd "$BIN_PATH" | grep -q "not found"; then
    log "⚠️ Missing dependencies detected! Run: ldd $BIN_PATH"
    exit 1
fi

# Start the service
log "▶️ Starting VileSQL service as user: $USER"
systemctl start vilesql || {
    log "❌ Failed to start VileSQL service."
    exit 1
}

# Check if service stays running
sleep 2
if ! systemctl is-active --quiet vilesql; then
    log "❌ VileSQL stopped unexpectedly! Run: journalctl -u vilesql --no-pager | tail -n 20"
fi

log "✅ VileSQL installation completed successfully!"

echo ""
echo "📁 Data directory: $DATA_DIR"
echo "⚙️ Configuration file: $ENV_FILE"
echo "📄 Log file: $LOG_FILE"
echo "📄 Runtime log file: $RUNTIME_LOG_FILE"
echo ""
echo "🚀 Next steps:"
echo "   1️⃣ Edit config: sudo nano $ENV_FILE"
echo "   2️⃣ Check status: sudo systemctl status vilesql"
echo "   3️⃣ View logs: sudo tail -f $LOG_FILE"
echo "   4️⃣ View runtime logs: sudo tail -f $RUNTIME_LOG_FILE"
echo "   5️⃣ Run manually: sudo -u vilesql /usr/bin/vilesql --help"
echo ""
