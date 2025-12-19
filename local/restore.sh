#!/bin/bash

# Mikrus Toolbox - Emergency Restore
# Trigger a full system restore from the latest cloud backup.

MIKRUS_HOST="mikrus" # SSH alias

echo "🚨 EMERGENCY RESTORE PROTOCOL 🚨"
echo "This will connect to your Mikrus server ($MIKRUS_HOST) and restore data from the cloud."
echo "Any changes made since the last backup will be LOST."
echo ""
read -p "Press [Enter] to connect to server and start restore wizard..."

# 1. Deploy the restore core script (ensure it's up to date)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
cat "$REPO_ROOT/mikrus-toolbox/system/restore-core.sh" | ssh "$MIKRUS_HOST" "cat > ~/restore-core.sh && chmod +x ~/restore-core.sh"

# 2. Execute it interactively
# -t is crucial here to allow user input (typing 'YES') inside the SSH session
ssh -t "$MIKRUS_HOST" "./restore-core.sh"
