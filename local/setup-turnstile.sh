#!/bin/bash

# Mikrus Toolbox - Turnstile Setup
# Automatycznie konfiguruje Cloudflare Turnstile (CAPTCHA) dla aplikacji.
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   ./local/setup-turnstile.sh <domena> [ssh_alias]
#
# Przykłady:
#   ./local/setup-turnstile.sh gf.automagicznie.pl hanna
#   ./local/setup-turnstile.sh myapp.example.com

set -e

DOMAIN="$1"
SSH_ALIAS="${2:-mikrus}"

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Konfiguracja
CONFIG_DIR="$HOME/.config/cloudflare"
CONFIG_FILE="$CONFIG_DIR/config"
TURNSTILE_TOKEN_FILE="$CONFIG_DIR/turnstile_token"
TURNSTILE_ACCOUNT_FILE="$CONFIG_DIR/turnstile_account_id"

if [ -z "$DOMAIN" ]; then
    echo "Użycie: $0 <domena> [ssh_alias]"
    echo ""
    echo "Przykłady:"
    echo "  $0 gf.automagicznie.pl hanna"
    echo "  $0 myapp.example.com"
    exit 1
fi

echo ""
echo -e "${BLUE}🔒 Turnstile Setup${NC}"
echo "   Domena: $DOMAIN"
echo ""

# =============================================================================
# 1. SPRAWDŹ ISTNIEJĄCY TOKEN
# =============================================================================

get_account_id() {
    local TOKEN="$1"

    # Pobierz account ID z dowolnej strefy
    if [ -f "$CONFIG_FILE" ]; then
        local ZONE_ID=$(grep "\.pl=\|\.com=\|\.dev=\|\.org=" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d= -f2)
        if [ -n "$ZONE_ID" ]; then
            curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Content-Type: application/json" | \
                grep -o '"account":{[^}]*}' | grep -o '"id":"[^"]*"' | cut -d'"' -f4
        fi
    fi
}

check_turnstile_access() {
    local TOKEN="$1"
    local ACCOUNT_ID="$2"

    RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/challenges/widgets" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json")

    if echo "$RESPONSE" | grep -q '"success":true'; then
        return 0
    else
        return 1
    fi
}

# Sprawdź czy mamy token z uprawnieniami Turnstile
TURNSTILE_TOKEN=""
ACCOUNT_ID=""

# Spróbuj załadować zapisane dane
if [ -f "$TURNSTILE_TOKEN_FILE" ]; then
    TURNSTILE_TOKEN=$(cat "$TURNSTILE_TOKEN_FILE")
fi
if [ -f "$TURNSTILE_ACCOUNT_FILE" ]; then
    ACCOUNT_ID=$(cat "$TURNSTILE_ACCOUNT_FILE")
fi

# Zweryfikuj zapisany token
if [ -n "$TURNSTILE_TOKEN" ] && [ -n "$ACCOUNT_ID" ]; then
    echo "🔑 Znaleziono zapisany token Turnstile..."
    if check_turnstile_access "$TURNSTILE_TOKEN" "$ACCOUNT_ID"; then
        echo -e "${GREEN}   ✅ Token jest aktualny${NC}"
    else
        echo "   ⚠️  Token wygasł lub jest nieprawidłowy"
        TURNSTILE_TOKEN=""
        ACCOUNT_ID=""
        rm -f "$TURNSTILE_TOKEN_FILE" "$TURNSTILE_ACCOUNT_FILE"
    fi
fi

# Jeśli nie ma dedykowanego tokena, spróbuj głównego
if [ -z "$TURNSTILE_TOKEN" ] && [ -f "$CONFIG_FILE" ]; then
    MAIN_TOKEN=$(grep "^API_TOKEN=" "$CONFIG_FILE" | cut -d= -f2)
    if [ -n "$MAIN_TOKEN" ]; then
        ACCOUNT_ID=$(get_account_id "$MAIN_TOKEN")
        if [ -n "$ACCOUNT_ID" ] && check_turnstile_access "$MAIN_TOKEN" "$ACCOUNT_ID"; then
            TURNSTILE_TOKEN="$MAIN_TOKEN"
            echo -e "${GREEN}✅ Główny token ma uprawnienia Turnstile${NC}"
            # Zapisz Account ID dla przyszłych użyć
            mkdir -p "$CONFIG_DIR"
            echo "$ACCOUNT_ID" > "$TURNSTILE_ACCOUNT_FILE"
            chmod 600 "$TURNSTILE_ACCOUNT_FILE"
        fi
    fi
fi

# =============================================================================
# 2. JEŚLI BRAK TOKENA - POPROŚ O NOWY
# =============================================================================

if [ -z "$TURNSTILE_TOKEN" ] || [ -z "$ACCOUNT_ID" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Brak tokena z uprawnieniami Turnstile${NC}"
    echo ""
    echo "Potrzebuję token API z uprawnieniem: Account → Turnstile → Edit"
    echo ""
    echo "Krok po kroku:"
    echo "   1. Otwórz: https://dash.cloudflare.com/profile/api-tokens"
    echo "   2. Kliknij 'Create Token'"
    echo "   3. Wybierz 'Create Custom Token'"
    echo "   4. Nazwa: 'Turnstile API'"
    echo "   5. Permissions:"
    echo "      • Account → Turnstile → Edit"
    echo "   6. Account Resources: Include → All accounts (lub wybierz konkretne)"
    echo "   7. Kliknij 'Continue to summary' → 'Create Token'"
    echo "   8. Skopiuj token"
    echo ""

    read -p "Naciśnij Enter aby otworzyć Cloudflare..." _

    # Otwórz przeglądarkę
    if command -v open &>/dev/null; then
        open "https://dash.cloudflare.com/profile/api-tokens"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "https://dash.cloudflare.com/profile/api-tokens"
    fi

    echo ""
    read -p "Wklej token Turnstile: " TURNSTILE_TOKEN

    if [ -z "$TURNSTILE_TOKEN" ]; then
        echo -e "${RED}❌ Token nie może być pusty${NC}"
        exit 1
    fi

    # Pobierz account ID
    echo ""
    echo "🔍 Weryfikuję token..."

    # Najpierw spróbuj pobrać Account ID z głównego tokena CF (ma uprawnienia Zone)
    if [ -z "$ACCOUNT_ID" ] && [ -f "$CONFIG_FILE" ]; then
        MAIN_TOKEN=$(grep "^API_TOKEN=" "$CONFIG_FILE" | cut -d= -f2)
        if [ -n "$MAIN_TOKEN" ]; then
            ACCOUNT_ID=$(get_account_id "$MAIN_TOKEN")
        fi
    fi

    # Jeśli nadal brak - spróbuj z nowego tokena (wymaga Account:Read)
    if [ -z "$ACCOUNT_ID" ]; then
        ACCOUNTS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
            -H "Authorization: Bearer $TURNSTILE_TOKEN" \
            -H "Content-Type: application/json")

        if echo "$ACCOUNTS_RESPONSE" | grep -q '"success":true'; then
            ACCOUNT_ID=$(echo "$ACCOUNTS_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        fi
    fi

    # Ostatnia deska ratunku - zapytaj użytkownika
    if [ -z "$ACCOUNT_ID" ]; then
        echo ""
        echo -e "${YELLOW}Nie mogę automatycznie pobrać Account ID.${NC}"
        echo "Znajdziesz go na: https://dash.cloudflare.com → dowolna domena → Overview → Account ID (prawa strona)"
        echo ""
        read -p "Wklej Account ID: " ACCOUNT_ID

        if [ -z "$ACCOUNT_ID" ]; then
            echo -e "${RED}❌ Account ID jest wymagane${NC}"
            exit 1
        fi
    fi

    # Sprawdź uprawnienia Turnstile
    if ! check_turnstile_access "$TURNSTILE_TOKEN" "$ACCOUNT_ID"; then
        echo -e "${RED}❌ Token nie ma uprawnień do Turnstile${NC}"
        echo "   Upewnij się że dodałeś: Account → Turnstile → Edit"
        exit 1
    fi

    echo -e "${GREEN}✅ Token zweryfikowany!${NC}"

    # Zapisz token i Account ID
    mkdir -p "$CONFIG_DIR"
    echo "$TURNSTILE_TOKEN" > "$TURNSTILE_TOKEN_FILE"
    echo "$ACCOUNT_ID" > "$TURNSTILE_ACCOUNT_FILE"
    chmod 600 "$TURNSTILE_TOKEN_FILE" "$TURNSTILE_ACCOUNT_FILE"
    echo "   Token i Account ID zapisane"
fi

# =============================================================================
# 3. SPRAWDŹ CZY WIDGET JUŻ ISTNIEJE
# =============================================================================

echo ""
echo "🔍 Sprawdzam istniejące widgety Turnstile..."

WIDGETS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/challenges/widgets" \
    -H "Authorization: Bearer $TURNSTILE_TOKEN" \
    -H "Content-Type: application/json")

# Szukaj widgetu dla tej domeny
EXISTING_WIDGET=$(echo "$WIDGETS_RESPONSE" | grep -o '"sitekey":"[^"]*"[^}]*"domains":\[[^]]*"'"$DOMAIN"'"' | head -1)

if [ -n "$EXISTING_WIDGET" ]; then
    SITE_KEY=$(echo "$WIDGETS_RESPONSE" | grep -B5 "\"$DOMAIN\"" | grep -o '"sitekey":"[^"]*"' | head -1 | cut -d'"' -f4)

    # Sprawdź czy mamy zapisane klucze
    KEYS_FILE="$CONFIG_DIR/turnstile_keys_$DOMAIN"
    if [ -f "$KEYS_FILE" ]; then
        echo -e "${GREEN}✅ Widget istnieje i mamy zapisane klucze${NC}"
        source "$KEYS_FILE"
        echo "   Site Key: $CLOUDFLARE_TURNSTILE_SITE_KEY"
        echo ""
        echo -e "${GREEN}🎉 Turnstile skonfigurowany!${NC}"
        exit 0
    fi

    echo -e "${YELLOW}⚠️  Widget już istnieje dla $DOMAIN${NC}"
    echo "   Site Key: $SITE_KEY"
    echo ""
    echo "Secret Key jest widoczny tylko przy tworzeniu widgeta."
    echo "Nie mamy go zapisanego lokalnie."
    echo ""
    echo "Opcje:"
    echo "   [t] Usuń widget i utwórz nowy (wygeneruje nowe klucze)"
    echo "   [n] Anuluj (możesz wpisać Secret Key ręcznie w .env.local)"
    echo ""
    echo -e "${YELLOW}⚠️  Jeśli usuniesz widget, stare klucze przestaną działać!${NC}"
    echo "   Dotyczy to wszystkich instancji używających tego widgeta."
    echo ""
    read -p "Usunąć widget i utworzyć nowy? [t/N]: " DELETE_WIDGET

    if [[ "$DELETE_WIDGET" =~ ^[TtYy]$ ]]; then
        # Pobierz sitekey żeby usunąć widget
        echo "🗑️  Usuwam istniejący widget..."
        DELETE_RESPONSE=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/challenges/widgets/$SITE_KEY" \
            -H "Authorization: Bearer $TURNSTILE_TOKEN" \
            -H "Content-Type: application/json")

        if echo "$DELETE_RESPONSE" | grep -q '"success":true'; then
            echo -e "${GREEN}✅ Widget usunięty${NC}"
        else
            echo -e "${RED}❌ Nie udało się usunąć widgeta${NC}"
            exit 1
        fi
    else
        echo ""
        echo "Możesz ręcznie usunąć widget w panelu Cloudflare:"
        echo "   https://dash.cloudflare.com → Turnstile → $DOMAIN → Delete"
        exit 0
    fi
fi

# =============================================================================
# 4. UTWÓRZ NOWY WIDGET
# =============================================================================

echo ""
echo "🔧 Tworzę widget Turnstile dla $DOMAIN..."

CREATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/challenges/widgets" \
    -H "Authorization: Bearer $TURNSTILE_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{
        \"name\": \"$DOMAIN\",
        \"domains\": [\"$DOMAIN\"],
        \"mode\": \"managed\",
        \"bot_fight_mode\": false,
        \"clearance_level\": \"no_clearance\"
    }")

if echo "$CREATE_RESPONSE" | grep -q '"success":true'; then
    SITE_KEY=$(echo "$CREATE_RESPONSE" | grep -o '"sitekey":"[^"]*"' | cut -d'"' -f4)
    SECRET_KEY=$(echo "$CREATE_RESPONSE" | grep -o '"secret":"[^"]*"' | cut -d'"' -f4)

    echo -e "${GREEN}✅ Widget utworzony!${NC}"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "   CLOUDFLARE_TURNSTILE_SITE_KEY=$SITE_KEY"
    echo "   CLOUDFLARE_TURNSTILE_SECRET_KEY=$SECRET_KEY"
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    # Zapisz klucze do pliku (dla deploy.sh)
    KEYS_FILE="$CONFIG_DIR/turnstile_keys_$DOMAIN"
    echo "CLOUDFLARE_TURNSTILE_SITE_KEY=$SITE_KEY" > "$KEYS_FILE"
    echo "CLOUDFLARE_TURNSTILE_SECRET_KEY=$SECRET_KEY" >> "$KEYS_FILE"
    chmod 600 "$KEYS_FILE"

    # Dodaj do .env.local na serwerze (jeśli podano SSH_ALIAS)
    if [ -n "$SSH_ALIAS" ]; then
        echo ""
        echo "📤 Dodaję klucze do serwera $SSH_ALIAS..."

        # Wyznacz ścieżki na podstawie domeny (multi-instance support)
        # Nowa lokalizacja: /opt/stacks/gateflow*
        INSTANCE_NAME="${DOMAIN%%.*}"
        GATEFLOW_DIR="/opt/stacks/gateflow-${INSTANCE_NAME}"
        PM2_NAME="gateflow-${INSTANCE_NAME}"

        # Sprawdź czy istnieje katalog instancji, jeśli nie - szukaj dalej
        if ! ssh "$SSH_ALIAS" "test -d $GATEFLOW_DIR" 2>/dev/null; then
            GATEFLOW_DIR="/opt/stacks/gateflow"
            PM2_NAME="gateflow"
        fi
        # Fallback do starej lokalizacji
        if ! ssh "$SSH_ALIAS" "test -d $GATEFLOW_DIR" 2>/dev/null; then
            GATEFLOW_DIR="/root/gateflow-${INSTANCE_NAME}"
            PM2_NAME="gateflow-${INSTANCE_NAME}"
        fi
        if ! ssh "$SSH_ALIAS" "test -d $GATEFLOW_DIR" 2>/dev/null; then
            GATEFLOW_DIR="/root/gateflow"
            PM2_NAME="gateflow"
        fi

        ENV_FILE="$GATEFLOW_DIR/admin-panel/.env.local"
        STANDALONE_ENV="$GATEFLOW_DIR/admin-panel/.next/standalone/admin-panel/.env.local"

        # Sprawdź czy istnieje
        if ssh "$SSH_ALIAS" "test -f $ENV_FILE" 2>/dev/null; then
            # Dodaj do głównego .env.local (z aliasem TURNSTILE_SECRET_KEY dla Supabase)
            ssh "$SSH_ALIAS" "echo '' >> $ENV_FILE && echo '# Cloudflare Turnstile' >> $ENV_FILE && echo 'CLOUDFLARE_TURNSTILE_SITE_KEY=$SITE_KEY' >> $ENV_FILE && echo 'CLOUDFLARE_TURNSTILE_SECRET_KEY=$SECRET_KEY' >> $ENV_FILE && echo 'TURNSTILE_SECRET_KEY=$SECRET_KEY' >> $ENV_FILE"

            # Skopiuj do standalone
            ssh "$SSH_ALIAS" "cp $ENV_FILE $STANDALONE_ENV 2>/dev/null || true"

            echo -e "${GREEN}   ✅ Klucze dodane${NC}"

            # Restart PM2 z przeładowaniem zmiennych środowiskowych
            echo "🔄 Restartuję GateFlow..."

            STANDALONE_DIR="$GATEFLOW_DIR/admin-panel/.next/standalone/admin-panel"
            # WAŻNE: użyj --interpreter node, NIE 'node server.js' w cudzysłowach (bash nie dziedziczy env)
            RESTART_CMD="export PATH=\"\$HOME/.bun/bin:\$PATH\" && pm2 delete $PM2_NAME 2>/dev/null; cd $STANDALONE_DIR && set -a && source .env.local && set +a && export PORT=\${PORT:-3333} && export HOSTNAME=\${HOSTNAME:-::} && pm2 start server.js --name $PM2_NAME --interpreter node && pm2 save"

            if ssh "$SSH_ALIAS" "$RESTART_CMD" 2>/dev/null; then
                echo -e "${GREEN}   ✅ Aplikacja zrestartowana${NC}"
            else
                echo -e "${YELLOW}   ⚠️  Restart nieudany - zrób ręcznie: pm2 restart $PM2_NAME${NC}"
            fi
        else
            echo -e "${YELLOW}   ⚠️  Nie znaleziono .env.local - GateFlow nie zainstalowany?${NC}"
        fi
    fi

    # =============================================================================
    # 5. KONFIGURACJA CAPTCHA W SUPABASE AUTH
    # =============================================================================

    # Sprawdź czy mamy konfigurację Supabase
    SUPABASE_TOKEN_FILE="$HOME/.config/supabase/access_token"
    GATEFLOW_CONFIG="$HOME/.config/gateflow/supabase.env"

    if [ -f "$SUPABASE_TOKEN_FILE" ] && [ -f "$GATEFLOW_CONFIG" ]; then
        echo ""
        echo "🔧 Konfiguruję CAPTCHA w Supabase Auth..."

        SUPABASE_TOKEN=$(cat "$SUPABASE_TOKEN_FILE")
        source "$GATEFLOW_CONFIG"  # Ładuje PROJECT_REF

        if [ -n "$SUPABASE_TOKEN" ] && [ -n "$PROJECT_REF" ]; then
            CAPTCHA_CONFIG=$(cat <<EOF
{
    "security_captcha_enabled": true,
    "security_captcha_provider": "turnstile",
    "security_captcha_secret": "$SECRET_KEY"
}
EOF
)
            RESPONSE=$(curl -s -X PATCH "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
                -H "Authorization: Bearer $SUPABASE_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$CAPTCHA_CONFIG")

            if echo "$RESPONSE" | grep -q '"error"'; then
                echo -e "${YELLOW}   ⚠️  Nie udało się skonfigurować CAPTCHA w Supabase${NC}"
            else
                echo -e "${GREEN}   ✅ CAPTCHA włączony w Supabase Auth${NC}"
            fi
        fi
    else
        echo ""
        echo -e "${YELLOW}ℹ️  Aby włączyć CAPTCHA w Supabase, uruchom ponownie deploy.sh${NC}"
        echo "   lub skonfiguruj ręcznie w Supabase Dashboard → Authentication → Captcha"
    fi

    echo ""
    echo -e "${GREEN}🎉 Turnstile skonfigurowany!${NC}"
else
    ERROR=$(echo "$CREATE_RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    echo -e "${RED}❌ Błąd: $ERROR${NC}"
    echo ""
    echo "Pełna odpowiedź:"
    echo "$CREATE_RESPONSE" | head -c 500
    exit 1
fi
