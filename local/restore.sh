#!/bin/bash

# Mikrus Toolbox - Emergency Restore
# Trigger a full system restore from the latest cloud backup.

MIKRUS_HOST="${1:-mikrus}" # First argument or default to 'mikrus'

# Get remote server info for confirmation
REMOTE_HOST=$(ssh -G "$MIKRUS_HOST" 2>/dev/null | grep "^hostname " | cut -d' ' -f2)
REMOTE_USER=$(ssh -G "$MIKRUS_HOST" 2>/dev/null | grep "^user " | cut -d' ' -f2)

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  🚨  EMERGENCY RESTORE PROTOCOL                                ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Serwer:  $REMOTE_USER@$REMOTE_HOST"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "UWAGA: To przywróci dane z chmury i NADPISZE obecne pliki!"
echo "Wszystkie zmiany od ostatniego backupu zostaną UTRACONE."
echo ""
read -p "Czy na pewno chcesz kontynuować? (t/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[TtYy]$ ]]; then
    echo "Anulowano."
    exit 1
fi

read -p "Naciśnij [Enter] aby połączyć się z serwerem..."

# 1. Deploy the restore core script (ensure it's up to date)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
cat "$REPO_ROOT/system/restore-core.sh" | ssh "$MIKRUS_HOST" "cat > ~/restore-core.sh && chmod +x ~/restore-core.sh"

# 2. Execute it interactively
# -t is crucial here to allow user input (typing 'YES') inside the SSH session
ssh -t "$MIKRUS_HOST" "./restore-core.sh"
