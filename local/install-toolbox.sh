#!/bin/bash

# Mikrus Toolbox - Install Toolbox on Server
# Kopiuje toolbox na serwer Mikrus, żeby skrypty działały bezpośrednio.
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   ./local/install-toolbox.sh [ssh_alias]
#
# Po instalacji na serwerze:
#   ssh mikrus
#   deploy.sh uptime-kuma
#   cytrus-domain.sh - 3001

set -e

SSH_ALIAS="${1:-mikrus}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Ten skrypt działa tylko z komputera lokalnego
if [ -f /klucz_api ]; then
    echo "Ten skrypt działa tylko na komputerze lokalnym."
    echo "Toolbox jest już zainstalowany na tym serwerze."
    exit 1
fi

echo ""
echo "📦 Instalacja Mikrus Toolbox na serwerze"
echo ""
echo "   Serwer: $SSH_ALIAS"
echo "   Źródło: $REPO_ROOT"
echo "   Cel:    /opt/mikrus-toolbox/"
echo ""

# Sprawdź rsync
if ! command -v rsync &>/dev/null; then
    echo "❌ rsync nie jest zainstalowany"
    echo "   Mac:   brew install rsync"
    echo "   Linux: sudo apt install rsync"
    exit 1
fi

# Kopiuj toolbox na serwer
echo "🚀 Kopiuję pliki..."
rsync -az --delete \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude 'mcp-server' \
    --exclude '.claude' \
    --exclude '*.md' \
    "$REPO_ROOT/" "$SSH_ALIAS:/opt/mikrus-toolbox/"

# Dodaj do PATH (jeśli jeszcze nie dodane)
echo "🔧 Konfiguruję PATH..."
ssh "$SSH_ALIAS" "
    if ! grep -q 'mikrus-toolbox/local' ~/.bashrc 2>/dev/null; then
        echo '' >> ~/.bashrc
        echo '# Mikrus Toolbox' >> ~/.bashrc
        echo 'export PATH=/opt/mikrus-toolbox/local:\$PATH' >> ~/.bashrc
    fi
"

echo ""
echo "✅ Toolbox zainstalowany!"
echo ""
echo "Teraz możesz:"
echo "   ssh $SSH_ALIAS"
echo "   deploy.sh uptime-kuma"
echo "   cytrus-domain.sh - 3001"
echo ""
echo "Aktualizacja: uruchom ten skrypt ponownie"
echo ""
