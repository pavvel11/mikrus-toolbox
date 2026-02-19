#!/bin/bash

# Mikrus Toolbox - Server Status
# Pokazuje stan serwera: RAM, dysk, kontenery, porty, stacki.
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   ./local/server-status.sh [--ssh=ALIAS]
#
# Przykłady:
#   ./local/server-status.sh                # domyślny alias: mikrus
#   ./local/server-status.sh --ssh=hanna    # inny serwer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parsowanie argumentów
SSH_ALIAS="mikrus"
for arg in "$@"; do
    case "$arg" in
        --ssh=*) SSH_ALIAS="${arg#--ssh=}" ;;
        -h|--help)
            echo "Użycie: $0 [--ssh=ALIAS]"
            echo ""
            echo "Pokazuje stan serwera Mikrus:"
            echo "  - RAM i dysk"
            echo "  - Działające kontenery Docker"
            echo "  - Zajęte porty"
            echo "  - Zainstalowane stacki"
            echo ""
            echo "Opcje:"
            echo "  --ssh=ALIAS   Alias SSH (domyślnie: mikrus)"
            exit 0
            ;;
    esac
done

# Załaduj server-exec
source "$REPO_ROOT/lib/server-exec.sh"
export SSH_ALIAS

# =============================================================================
# POŁĄCZENIE
# =============================================================================

echo ""
echo -n "🔗 Łączenie z serwerem ($SSH_ALIAS)... "
if ! server_exec "true" 2>/dev/null; then
    echo -e "${RED}✗${NC}"
    echo -e "${RED}❌ Nie mogę połączyć się z serwerem: $SSH_ALIAS${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC}"

HOSTNAME=$(server_exec "hostname" 2>/dev/null)
echo "   Host: $HOSTNAME"

# =============================================================================
# ZASOBY
# =============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  📊 Zasoby serwera                                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

RESOURCES=$(server_exec "free -m | awk '/^Mem:/ {print \$7, \$2}'; df -m / | awk 'NR==2 {print \$4, \$2}'" 2>/dev/null)
RAM_AVAIL=$(echo "$RESOURCES" | sed -n '1p' | awk '{print $1}')
RAM_TOTAL=$(echo "$RESOURCES" | sed -n '1p' | awk '{print $2}')
DISK_AVAIL=$(echo "$RESOURCES" | sed -n '2p' | awk '{print $1}')
DISK_TOTAL=$(echo "$RESOURCES" | sed -n '2p' | awk '{print $2}')

if [ -n "$RAM_AVAIL" ] && [ -n "$RAM_TOTAL" ]; then
    RAM_USED_PCT=$(( (RAM_TOTAL - RAM_AVAIL) * 100 / RAM_TOTAL ))
    if [ "$RAM_USED_PCT" -gt 80 ]; then
        RAM_LABEL="${RED}KRYTYCZNIE${NC}"
    elif [ "$RAM_USED_PCT" -gt 60 ]; then
        RAM_LABEL="${YELLOW}CIASNO${NC}"
    else
        RAM_LABEL="${GREEN}OK${NC}"
    fi
    echo -e "   RAM:  ${RAM_AVAIL}MB / ${RAM_TOTAL}MB wolne (${RAM_USED_PCT}% zajęte) — $RAM_LABEL"
else
    echo -e "   RAM:  ${YELLOW}nie udało się odczytać${NC}"
fi

if [ -n "$DISK_AVAIL" ] && [ -n "$DISK_TOTAL" ]; then
    DISK_USED_PCT=$(( (DISK_TOTAL - DISK_AVAIL) * 100 / DISK_TOTAL ))
    DISK_AVAIL_GB=$(awk "BEGIN {printf \"%.1f\", $DISK_AVAIL / 1024}")
    DISK_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $DISK_TOTAL / 1024}")
    if [ "$DISK_USED_PCT" -gt 85 ]; then
        DISK_LABEL="${RED}KRYTYCZNIE${NC}"
    elif [ "$DISK_USED_PCT" -gt 60 ]; then
        DISK_LABEL="${YELLOW}CIASNO${NC}"
    else
        DISK_LABEL="${GREEN}OK${NC}"
    fi
    echo -e "   Dysk: ${DISK_AVAIL_GB}GB / ${DISK_TOTAL_GB}GB wolne (${DISK_USED_PCT}% zajęte) — $DISK_LABEL"
else
    echo -e "   Dysk: ${YELLOW}nie udało się odczytać${NC}"
fi

# =============================================================================
# KONTENERY DOCKER
# =============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  🐳 Kontenery Docker                                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

CONTAINERS=$(server_exec "docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null" 2>/dev/null)

if [ -z "$CONTAINERS" ]; then
    echo "   (brak działających kontenerów)"
else
    CONTAINER_COUNT=$(echo "$CONTAINERS" | wc -l | tr -d ' ')
    echo "   Działające: $CONTAINER_COUNT"
    echo ""
    echo "$CONTAINERS" | while IFS=$'\t' read -r NAME IMAGE STATUS PORTS; do
        # Skróć status
        SHORT_STATUS=$(echo "$STATUS" | sed 's/Up /↑ /; s/ (healthy)/ ✓/; s/ (unhealthy)/ ✗/; s/ (starting)/ .../; s/ seconds/s/; s/ minutes/m/; s/ hours/h/; s/ days/d/; s/ weeks/w/')
        # Skróć porty (usuń IPv6 duplikaty)
        SHORT_PORTS=$(echo "$PORTS" | sed 's/, \[::\]:[0-9]*->[0-9]*\/tcp//g; s/0\.0\.0\.0://g; s/\/tcp//g')

        # Koloruj status
        if echo "$STATUS" | grep -q "healthy"; then
            echo -e "   ${GREEN}●${NC} $NAME  $SHORT_STATUS  $SHORT_PORTS"
        elif echo "$STATUS" | grep -q "unhealthy"; then
            echo -e "   ${RED}●${NC} $NAME  $SHORT_STATUS  $SHORT_PORTS"
        else
            echo -e "   ${YELLOW}●${NC} $NAME  $SHORT_STATUS  $SHORT_PORTS"
        fi
    done
fi

# =============================================================================
# ZAJĘTE PORTY
# =============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  🔌 Zajęte porty                                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

PORTS=$(server_exec "ss -tlnp 2>/dev/null | awk 'NR>1 {split(\$4,a,\":\"); port=a[length(a)]; if(port+0>0) print port}' | sort -un | tr '\n' ' '" 2>/dev/null)
echo "   $PORTS"

# =============================================================================
# STACKI
# =============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  📦 Zainstalowane stacki                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

STACKS_STATUS=$(server_exec "for s in /opt/stacks/*/; do name=\$(basename \"\$s\"); if [ -f \"\$s/docker-compose.yaml\" ] || [ -f \"\$s/docker-compose.yml\" ]; then state=\$(cd \"\$s\" && docker compose ps --format '{{.State}}' 2>/dev/null | head -1); echo \"\$name|\$state\"; else echo \"\$name|static\"; fi; done" 2>/dev/null)
if [ -z "$STACKS_STATUS" ]; then
    echo "   (brak stacków w /opt/stacks/)"
else
    echo "$STACKS_STATUS" | while IFS='|' read -r stack state; do
        if [ "$state" = "static" ]; then
            echo -e "   ${BLUE}●${NC} $stack (pliki)"
        elif [ "$state" = "running" ]; then
            echo -e "   ${GREEN}●${NC} $stack"
        elif [ -n "$state" ]; then
            echo -e "   ${RED}●${NC} $stack ($state)"
        else
            echo -e "   ${RED}●${NC} $stack (zatrzymany)"
        fi
    done
fi

# =============================================================================
# PODSUMOWANIE
# =============================================================================

echo ""
if [ -n "$RAM_AVAIL" ] && [ -n "$DISK_AVAIL" ]; then
    HEALTH_LEVEL=0
    [ "${RAM_USED_PCT:-0}" -gt 60 ] && HEALTH_LEVEL=1
    [ "${RAM_USED_PCT:-0}" -gt 80 ] && HEALTH_LEVEL=2
    [ "${DISK_USED_PCT:-0}" -gt 60 ] && [ "$HEALTH_LEVEL" -lt 1 ] && HEALTH_LEVEL=1
    [ "${DISK_USED_PCT:-0}" -gt 85 ] && HEALTH_LEVEL=2

    if [ "$HEALTH_LEVEL" -eq 0 ]; then
        echo -e "${GREEN}✅ Serwer w dobrej kondycji.${NC}"
    elif [ "$HEALTH_LEVEL" -eq 1 ]; then
        echo -e "${YELLOW}⚠️  Robi się ciasno. Rozważ upgrade przed dodawaniem ciężkich usług.${NC}"
    else
        echo -e "${RED}❌ Serwer mocno obciążony! Rozważ upgrade lub usunięcie nieużywanych usług.${NC}"
    fi
fi
echo ""
