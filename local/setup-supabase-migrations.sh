#!/bin/bash

# Mikrus Toolbox - Supabase Migrations (via API)
# Przygotowuje bazę danych dla GateFlow
# Author: Paweł (Lazy Engineer)
#
# Używa Supabase Management API - nie wymaga DATABASE_URL ani psql
# Potrzebuje tylko SUPABASE_URL i Personal Access Token
#
# Użycie:
#   ./local/setup-supabase-migrations.sh
#
# Zmienne środowiskowe (opcjonalne - można podać interaktywnie):
#   SUPABASE_URL - URL projektu (https://xxx.supabase.co)
#   SUPABASE_ACCESS_TOKEN - Personal Access Token

set -e

GITHUB_REPO="pavvel11/gateflow"
MIGRATIONS_PATH="supabase/migrations"

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Konfiguracja
CONFIG_DIR="$HOME/.config/gateflow"
CONFIG_FILE="$CONFIG_DIR/supabase.env"

echo ""
echo -e "${BLUE}🗄️  Przygotowanie bazy danych${NC}"
echo ""

# =============================================================================
# 1. POBIERZ KONFIGURACJĘ
# =============================================================================

# Załaduj zapisaną konfigurację
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Sprawdź SUPABASE_URL
if [ -z "$SUPABASE_URL" ]; then
    echo -e "${RED}❌ Brak SUPABASE_URL${NC}"
    echo "   Najpierw uruchom instalację GateFlow lub setup-supabase-gateflow.sh"
    exit 1
fi

# Wyciągnij project ref z URL (np. https://abcdefgh.supabase.co -> abcdefgh)
PROJECT_REF=$(echo "$SUPABASE_URL" | sed -E 's|https://([^.]+)\.supabase\.co.*|\1|')

if [ -z "$PROJECT_REF" ] || [ "$PROJECT_REF" = "$SUPABASE_URL" ]; then
    echo -e "${RED}❌ Nie mogę wyciągnąć project ref z URL: $SUPABASE_URL${NC}"
    exit 1
fi

echo "   Projekt: $PROJECT_REF"

# Sprawdź Personal Access Token
if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
    # Sprawdź w głównym configu cloudflare (gdzie zapisujemy tokeny)
    SUPABASE_TOKEN_FILE="$HOME/.config/supabase/access_token"
    if [ -f "$SUPABASE_TOKEN_FILE" ]; then
        SUPABASE_ACCESS_TOKEN=$(cat "$SUPABASE_TOKEN_FILE")
    fi
fi

if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Brak Personal Access Token${NC}"
    echo ""
    echo "Potrzebuję tokena do wykonania zmian w bazie danych."
    echo ""
    echo "Gdzie go znaleźć:"
    echo "   1. Otwórz: https://supabase.com/dashboard/account/tokens"
    echo "   2. Kliknij 'Generate new token'"
    echo "   3. Skopiuj token"
    echo ""

    read -p "Naciśnij Enter aby otworzyć Supabase..." _
    if command -v open &>/dev/null; then
        open "https://supabase.com/dashboard/account/tokens"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "https://supabase.com/dashboard/account/tokens"
    fi

    echo ""
    read -p "Wklej Personal Access Token: " SUPABASE_ACCESS_TOKEN

    if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
        echo -e "${RED}❌ Token jest wymagany${NC}"
        exit 1
    fi

    # Zapisz token
    mkdir -p "$HOME/.config/supabase"
    echo "$SUPABASE_ACCESS_TOKEN" > "$SUPABASE_TOKEN_FILE"
    chmod 600 "$SUPABASE_TOKEN_FILE"
    echo "   ✅ Token zapisany"
fi

# =============================================================================
# 2. FUNKCJA DO WYKONYWANIA SQL
# =============================================================================

run_sql() {
    local SQL="$1"

    RESPONSE=$(curl -s -X POST "https://api.supabase.com/v1/projects/$PROJECT_REF/database/query" \
        -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"query\": $(echo "$SQL" | jq -Rs .)}")

    # Sprawdź błędy
    if echo "$RESPONSE" | grep -q '"error"'; then
        ERROR=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        echo -e "${RED}❌ Błąd SQL: $ERROR${NC}" >&2
        return 1
    fi

    echo "$RESPONSE"
}

# Test połączenia
echo ""
echo "🔍 Sprawdzam połączenie z bazą..."

TEST_RESULT=$(run_sql "SELECT 1 as test" 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Nie mogę połączyć się z bazą${NC}"
    echo "   Sprawdź czy token jest prawidłowy"
    exit 1
fi

echo -e "${GREEN}✅ Połączenie OK${NC}"

# =============================================================================
# 3. POBIERZ MIGRACJE
# =============================================================================

echo ""
echo "📥 Pobieram pliki migracji..."

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Pobierz listę migracji z GitHub
MIGRATIONS_LIST=$(curl -sL "https://api.github.com/repos/$GITHUB_REPO/contents/$MIGRATIONS_PATH" \
    -H "Authorization: token ${GITHUB_TOKEN:-}" 2>/dev/null | grep -o '"name": "[^"]*\.sql"' | cut -d'"' -f4 | sort)

if [ -z "$MIGRATIONS_LIST" ]; then
    echo -e "${YELLOW}⚠️  Nie udało się pobrać listy migracji z GitHub${NC}"
    echo "   Repo może być prywatne. Pomijam przygotowanie bazy."
    exit 0
fi

echo "   Znaleziono migracje:"
for migration in $MIGRATIONS_LIST; do
    echo "   - $migration"
done

# Pobierz każdy plik
for migration in $MIGRATIONS_LIST; do
    curl -sL "https://raw.githubusercontent.com/$GITHUB_REPO/main/$MIGRATIONS_PATH/$migration" \
        -H "Authorization: token ${GITHUB_TOKEN:-}" \
        -o "$TEMP_DIR/$migration"
done

echo -e "${GREEN}✅ Migracje pobrane${NC}"

# =============================================================================
# 4. SPRAWDŹ KTÓRE MIGRACJE SĄ POTRZEBNE
# =============================================================================

echo ""
echo "🔍 Sprawdzam status bazy..."

# Sprawdź czy tabela migracji istnieje
TABLE_CHECK=$(run_sql "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'schema_migrations');" 2>/dev/null)

if echo "$TABLE_CHECK" | grep -q "true"; then
    echo "   Tabela migracji istnieje"
    APPLIED_RESULT=$(run_sql "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null)
    APPLIED_MIGRATIONS=$(echo "$APPLIED_RESULT" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' ')
else
    echo "   Tabela migracji nie istnieje (świeża instalacja)"
    APPLIED_MIGRATIONS=""

    # Utwórz tabelę
    run_sql "CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ DEFAULT NOW());" > /dev/null
    echo "   ✅ Utworzono tabelę schema_migrations"
fi

# Określ które migracje trzeba wykonać
PENDING_MIGRATIONS=""
for migration in $MIGRATIONS_LIST; do
    VERSION=$(echo "$migration" | cut -d'_' -f1)
    if ! echo "$APPLIED_MIGRATIONS" | grep -q "$VERSION"; then
        PENDING_MIGRATIONS="$PENDING_MIGRATIONS $migration"
    fi
done

PENDING_MIGRATIONS=$(echo "$PENDING_MIGRATIONS" | xargs)

if [ -z "$PENDING_MIGRATIONS" ]; then
    echo ""
    echo -e "${GREEN}✅ Baza danych jest aktualna${NC}"
    exit 0
fi

echo ""
echo "📋 Do wykonania:"
for migration in $PENDING_MIGRATIONS; do
    echo -e "   ${YELLOW}→ $migration${NC}"
done

# =============================================================================
# 5. WYKONAJ MIGRACJE
# =============================================================================

echo ""
echo "🚀 Wykonuję..."

for migration in $PENDING_MIGRATIONS; do
    VERSION=$(echo "$migration" | cut -d'_' -f1)
    echo -n "   $migration... "

    SQL_CONTENT=$(cat "$TEMP_DIR/$migration")

    if run_sql "$SQL_CONTENT" > /dev/null 2>&1; then
        # Zapisz że migracja została wykonana
        run_sql "INSERT INTO schema_migrations (version) VALUES ('$VERSION');" > /dev/null 2>&1
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
        echo -e "${RED}   Błąd w migracji $migration${NC}"
        exit 1
    fi
done

echo ""
echo -e "${GREEN}🎉 Baza danych przygotowana!${NC}"
