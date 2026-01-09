#!/bin/bash

# Mikrus Toolbox - Remote Deployer
# Usage: ./local/deploy.sh <script_or_app> [ssh_alias]
# Example: ./local/deploy.sh system/docker-setup.sh
# Example: ./local/deploy.sh n8n hanna          # deploy to 'hanna' server

SCRIPT_PATH="$1"
TARGET="${2:-mikrus}" # Second argument or default to 'mikrus'

# 1. Validate input
if [ -z "$SCRIPT_PATH" ]; then
  echo "❌ Error: No script or app name specified."
  echo ""
  echo "Usage: $0 <app_or_script> [serwer]"
  echo ""
  echo "Przykłady:"
  echo "  $0 n8n                    # instaluje n8n na 'mikrus' (domyślny)"
  echo "  $0 n8n hanna              # instaluje n8n na 'hanna'"
  echo "  $0 system/docker-setup.sh # uruchamia skrypt na 'mikrus'"
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# Check if it's a short app name (Smart Mode)
if [ -f "$REPO_ROOT/apps/$SCRIPT_PATH/install.sh" ]; then
    echo "💡 Detected App Name: '$SCRIPT_PATH'. Using installer."
    SCRIPT_PATH="$REPO_ROOT/apps/$SCRIPT_PATH/install.sh"
elif [ -f "$SCRIPT_PATH" ]; then
    # Direct file exists
    :
elif [ -f "$REPO_ROOT/$SCRIPT_PATH" ]; then
    # Relative to root exists
    SCRIPT_PATH="$REPO_ROOT/$SCRIPT_PATH"
else
    echo "❌ Error: Script or App '$SCRIPT_PATH' not found."
    echo "   Searched for:"
    echo "   - apps/$SCRIPT_PATH/install.sh"
    echo "   - $SCRIPT_PATH"
    exit 1
fi

# 2. Get remote server info for confirmation
REMOTE_HOST=$(ssh -G "$TARGET" 2>/dev/null | grep "^hostname " | cut -d' ' -f2)
REMOTE_USER=$(ssh -G "$TARGET" 2>/dev/null | grep "^user " | cut -d' ' -f2)

# 3. Big warning and confirmation
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ⚠️   UWAGA: INSTALACJA NA ZDALNYM SERWERZE!                   ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Serwer:  $REMOTE_USER@$REMOTE_HOST"
echo "║  Skrypt:  $(basename "$SCRIPT_PATH")"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
read -p "Czy na pewno chcesz uruchomić ten skrypt na ZDALNYM serwerze? (t/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[TtYy]$ ]]; then
    echo "Anulowano."
    exit 1
fi

# 4. Execute remotely via SSH pipe
# Using 'bash -s' allows passing arguments if we ever need them
if cat "$SCRIPT_PATH" | ssh "$TARGET" "bash -s"; then
    echo ""
    echo "✅ Deployment finished."
else
    echo ""
    echo "❌ Deployment FAILED! Sprawdź błędy powyżej."
    exit 1
fi
