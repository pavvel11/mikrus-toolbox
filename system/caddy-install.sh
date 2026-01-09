#!/bin/bash

# Mikrus Toolbox - Caddy Server & Helper Tool
# Installs Caddy (Modern Reverse Proxy) and a CLI helper for instant HTTPS.
# Author: Paweł (Lazy Engineer)

set -e

echo "--- 1. Installing Caddy (Official Repo) ---"

# Prerequisites
sudo apt install -y -q debian-keyring debian-archive-keyring apt-transport-https curl

# Add Key & Repo
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null

# Install
sudo apt update
sudo apt install caddy -y

echo "--- 2. Installing 'mikrus-expose' Helper Tool ---"

# Creating a lazy wrapper script to add domains easily
cat <<'EOF' | sudo tee /usr/local/bin/mikrus-expose > /dev/null
#!/bin/bash
# Usage: mikrus-expose <domain> <internal_port>
# Example: mikrus-expose n8n.kamil.pl 5678

DOMAIN=$1
PORT=$2
CADDYFILE="/etc/caddy/Caddyfile"

if [ -z "$DOMAIN" ] || [ -z "$PORT" ]; then
    echo "Usage: mikrus-expose <domain> <internal_port>"
    exit 1
fi

# Check if domain already exists to avoid duplicates
if grep -q "$DOMAIN" "$CADDYFILE"; then
    echo "⚠️  Domain $DOMAIN already exists in Caddyfile. Please edit manually."
    exit 1
fi

echo "🚀 Exposing $DOMAIN -> localhost:$PORT"

# Append config block
# reverse_proxy is the simplest directive
cat <<CONFIG | sudo tee -a "$CADDYFILE"

$DOMAIN {
    reverse_proxy localhost:$PORT
}
CONFIG

# Reload Caddy to apply changes (zero downtime)
sudo systemctl reload caddy

echo "✅ Done! Your site should be live at https://$DOMAIN"
EOF

# Make it executable
sudo chmod +x /usr/local/bin/mikrus-expose

echo "--- Setup Complete ---"
echo "✅ Caddy is running."
echo "✅ 'mikrus-expose' tool installed."
echo "   Usage: mikrus-expose app.domain.com 5000"
