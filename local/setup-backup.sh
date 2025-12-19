#!/bin/bash

# Mikrus Toolbox - Backup Setup Wizard
# Configures cloud backup on Mikrus using local Rclone for auth.
# Author: Paweł (Lazy Engineer)

set -e

# Configuration
MIKRUS_HOST="mikrus" # SSH alias
REMOTE_NAME="backup_remote"
TEMP_CONF="/tmp/rclone_mikrus_setup.conf"

echo "=== 🛡️  Mikrus Backup Setup Wizard ==="
echo "This tool will configure automatic backups from your Mikrus server to a cloud provider."

# 1. Check Local Prerequisites
if ! command -v rclone &> /dev/null; then
    echo "❌ Rclone is not installed on your Mac."
    echo "   Please install it: brew install rclone"
    echo "   Or download from: https://rclone.org/downloads/"
    exit 1
fi

# 2. Select Provider
echo ""
echo "Choose your backup provider:"
echo "1) Google Drive (Recommended)"
echo "2) Dropbox"
echo "3) Microsoft OneDrive"
echo "4) Mega"
echo "5) S3 Compatible (AWS, Wasabi, MinIO, etc.)"
read -p "Select [1-5]: " CHOICE

case $CHOICE in
    1) TYPE="drive"; CONF_ARGS="scope=drive.file" ;;
    2) TYPE="dropbox"; CONF_ARGS="" ;;
    3) TYPE="onedrive"; CONF_ARGS="" ;;
    4) TYPE="mega"; CONF_ARGS="" ;;
    5) TYPE="s3"; CONF_ARGS="provider=AWS env_auth=false" ;;
    *) echo "Invalid choice."; exit 1 ;;
esac

echo ""
echo "--- 🔐 Authenticating with $TYPE ---"
echo "We will now generate a configuration token."
if [[ "$TYPE" == "mega" || "$TYPE" == "s3" ]]; then
    echo "You will be asked for credentials in the terminal."
else
    echo "A browser window will open for you to log in."
fi
echo ""

# 3. Generate Config Locally
# We create a temporary config file just for this session
rm -f "$TEMP_CONF"
touch "$TEMP_CONF"

# Logic for Encryption abstraction
# If Encrypt = NO:  backup_remote -> Provider
# If Encrypt = YES: raw_cloud -> Provider, backup_remote (crypt) -> raw_cloud

echo ""
read -p "🔒 Do you want to ENCRYPT your backups? (Recommended) [y/N]: " ENCRYPT_CHOICE

if [[ "$ENCRYPT_CHOICE" =~ ^[Yy]$ ]]; then
    echo "--- Setting up Encryption ---"
    echo "Please enter a strong password. You will need this to restore files!"
    read -s -p "Password: " PASS1
    echo ""
    read -s -p "Confirm Password: " PASS2
    echo ""
    
    if [ "$PASS1" != "$PASS2" ]; then
        echo "❌ Passwords do not match. Aborting."
        exit 1
    fi
    
    # Create the raw backend first
    echo "Authenticating with provider..."
    rclone config create "raw_cloud" "$TYPE" $CONF_ARGS --config "$TEMP_CONF" >/dev/null
    
    # Create the crypt wrapper named 'backup_remote'
    # remote needs to point to the raw remote + bucket/folder path if needed
    # usually: raw_cloud:/
    echo "Configuring encryption layer..."
    rclone config create "$REMOTE_NAME" crypt remote="raw_cloud:/" password="$PASS1" --config "$TEMP_CONF" >/dev/null
    
    echo "✅ Encryption configured."
else
    # Direct setup
    echo "Authenticating with provider..."
    rclone config create "$REMOTE_NAME" "$TYPE" $CONF_ARGS --config "$TEMP_CONF"
fi

echo ""
echo "✅ Authentication successful! Config generated."

# 4. Deploy to Mikrus
echo ""
echo "--- 🚀 Deploying to Mikrus ---"

# 4a. Install Rclone on Mikrus if missing
echo "Checking Rclone on server..."
ssh "$MIKRUS_HOST" "command -v rclone >/dev/null || (curl https://rclone.org/install.sh | sudo bash)"

# 4b. Upload Config
echo "Uploading configuration..."
# We read the config content and write it to the server securely
CONF_CONTENT=$(cat "$TEMP_CONF")
ssh "$MIKRUS_HOST" "mkdir -p ~/.config/rclone && echo '$CONF_CONTENT' > ~/.config/rclone/rclone.conf"

# 4c. Upload Backup Script
echo "Installing backup script..."
# Using our deploy mechanism logic inline
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
cat "$REPO_ROOT/mikrus-toolbox/system/backup-core.sh" | ssh "$MIKRUS_HOST" "cat > ~/backup-core.sh && chmod +x ~/backup-core.sh"

# 4d. Setup Cron
echo "Setting up Cron job (Daily at 3:00 AM)..."
CRON_CMD="0 3 * * * /root/backup-core.sh >> /var/log/mikrus-backup.log 2>&1"
# Check if job exists, if not append
ssh "$MIKRUS_HOST" "crontab -l | grep -v 'backup-core.sh' | { cat; echo '$CRON_CMD'; } | crontab -"

# Cleanup
rm -f "$TEMP_CONF"

echo ""
echo "✅ Setup Complete!"
echo "Your Mikrus server will now backup /opt/stacks daily to your $TYPE."
echo "First backup scheduled for 3:00 AM. Run manually with: ssh $MIKRUS_HOST ~/backup-core.sh"
