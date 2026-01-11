#!/bin/bash

# Mikrus Toolbox - Database Backup Setup
# Konfiguruje automatyczny backup bazy danych PostgreSQL/MySQL
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   Na serwerze: ./setup-db-backup.sh
#   Lub przez deploy.sh: ./local/deploy.sh backup-db --ssh=ALIAS

set -e

BACKUP_DIR="/opt/backups/db"
BACKUP_SCRIPT="/opt/mikrus-toolbox/scripts/db-backup.sh"
CRON_FILE="/etc/cron.d/mikrus-db-backup"

echo "--- 🗄️ Konfiguracja backupu bazy danych ---"
echo ""

# Sprawdź czy mamy dostęp do API (żeby pobrać dane bazy)
API_KEY=$(cat /klucz_api 2>/dev/null || true)
HOSTNAME=$(hostname 2>/dev/null || true)

if [ -z "$API_KEY" ]; then
    echo "❌ Brak klucza API (/klucz_api)"
    echo "   Włącz API w panelu: https://mikr.us/panel/?a=api"
    exit 1
fi

echo "🔑 Pobieram dane bazy z API Mikrusa..."

RESPONSE=$(curl -s -d "srv=$HOSTNAME&key=$API_KEY" https://api.mikr.us/db.bash 2>/dev/null)

if [ -z "$RESPONSE" ]; then
    echo "❌ Brak odpowiedzi z API"
    exit 1
fi

# Wykryj dostępne bazy
HAS_POSTGRES=false
HAS_MYSQL=false

if echo "$RESPONSE" | grep -q "^psql="; then
    PSQL_HOST=$(echo "$RESPONSE" | grep -A4 "^psql=" | grep 'Server:' | head -1 | sed 's/.*Server: *//' | tr -d '"')
    PSQL_USER=$(echo "$RESPONSE" | grep -A4 "^psql=" | grep 'login:' | head -1 | sed 's/.*login: *//')
    PSQL_PASS=$(echo "$RESPONSE" | grep -A4 "^psql=" | grep 'Haslo:' | head -1 | sed 's/.*Haslo: *//')
    PSQL_NAME=$(echo "$RESPONSE" | grep -A4 "^psql=" | grep 'Baza:' | head -1 | sed 's/.*Baza: *//' | tr -d '"')

    if [ -n "$PSQL_HOST" ] && [ -n "$PSQL_USER" ]; then
        HAS_POSTGRES=true
        echo "✅ PostgreSQL: $PSQL_HOST / $PSQL_NAME"
    fi
fi

if echo "$RESPONSE" | grep -q "^mysql="; then
    MYSQL_HOST=$(echo "$RESPONSE" | grep -A4 "^mysql=" | grep 'Server:' | head -1 | sed 's/.*Server: *//' | tr -d '"')
    MYSQL_USER=$(echo "$RESPONSE" | grep -A4 "^mysql=" | grep 'login:' | head -1 | sed 's/.*login: *//')
    MYSQL_PASS=$(echo "$RESPONSE" | grep -A4 "^mysql=" | grep 'Haslo:' | head -1 | sed 's/.*Haslo: *//')
    MYSQL_NAME=$(echo "$RESPONSE" | grep -A4 "^mysql=" | grep 'Baza:' | head -1 | sed 's/.*Baza: *//' | tr -d '"')

    if [ -n "$MYSQL_HOST" ] && [ -n "$MYSQL_USER" ]; then
        HAS_MYSQL=true
        echo "✅ MySQL: $MYSQL_HOST / $MYSQL_NAME"
    fi
fi

if [ "$HAS_POSTGRES" = false ] && [ "$HAS_MYSQL" = false ]; then
    echo ""
    echo "❌ Nie znaleziono aktywnych baz danych!"
    echo "   Włącz bazę w panelu:"
    echo "   - PostgreSQL: https://mikr.us/panel/?a=postgres"
    echo "   - MySQL: https://mikr.us/panel/?a=mysql"
    exit 1
fi

# Utwórz katalog backupów
echo ""
echo "📁 Tworzę katalog backupów: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Utwórz skrypt backupu
echo "📝 Tworzę skrypt backupu..."

mkdir -p "$(dirname "$BACKUP_SCRIPT")"

cat > "$BACKUP_SCRIPT" << 'BACKUP_EOF'
#!/bin/bash
# Automatyczny backup baz danych Mikrus
# Wygenerowane przez setup-db-backup.sh

BACKUP_DIR="/opt/backups/db"
DATE=$(date +%Y%m%d_%H%M%S)
KEEP_DAYS=7

# Usuń stare backupy
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$KEEP_DAYS -delete 2>/dev/null

BACKUP_EOF

# Dodaj backup PostgreSQL
if [ "$HAS_POSTGRES" = true ]; then
    cat >> "$BACKUP_SCRIPT" << EOF

# PostgreSQL backup
export PGPASSWORD='$PSQL_PASS'
pg_dump -h '$PSQL_HOST' -U '$PSQL_USER' '$PSQL_NAME' 2>/dev/null | gzip > "\$BACKUP_DIR/postgres_\$DATE.sql.gz"
if [ \$? -eq 0 ]; then
    echo "\$(date): PostgreSQL backup OK - postgres_\$DATE.sql.gz"
else
    echo "\$(date): PostgreSQL backup FAILED"
fi
unset PGPASSWORD
EOF
fi

# Dodaj backup MySQL
if [ "$HAS_MYSQL" = true ]; then
    cat >> "$BACKUP_SCRIPT" << EOF

# MySQL backup
mysqldump -h '$MYSQL_HOST' -u '$MYSQL_USER' -p'$MYSQL_PASS' '$MYSQL_NAME' 2>/dev/null | gzip > "\$BACKUP_DIR/mysql_\$DATE.sql.gz"
if [ \$? -eq 0 ]; then
    echo "\$(date): MySQL backup OK - mysql_\$DATE.sql.gz"
else
    echo "\$(date): MySQL backup FAILED"
fi
EOF
fi

chmod +x "$BACKUP_SCRIPT"

# Utwórz cron job
echo "⏰ Konfiguruję automatyczny backup (codziennie o 3:00)..."

cat > "$CRON_FILE" << EOF
# Mikrus Toolbox - Automatyczny backup bazy danych
# Codziennie o 3:00
0 3 * * * root $BACKUP_SCRIPT >> /var/log/db-backup.log 2>&1
EOF

chmod 644 "$CRON_FILE"

# Testowy backup
echo ""
echo "🧪 Wykonuję testowy backup..."
if $BACKUP_SCRIPT; then
    echo ""
    echo "✅ Backup działa!"
    echo ""
    echo "📋 Konfiguracja:"
    echo "   Katalog backupów: $BACKUP_DIR"
    echo "   Skrypt:           $BACKUP_SCRIPT"
    echo "   Cron:             $CRON_FILE (codziennie o 3:00)"
    echo "   Retencja:         7 dni"
    echo ""
    echo "📦 Utworzone backupy:"
    ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null || echo "   (brak plików)"
    echo ""
    echo "💡 Ręczny backup: $BACKUP_SCRIPT"
    echo "💡 Przywracanie PostgreSQL:"
    echo "   gunzip -c backup.sql.gz | psql -h HOST -U USER DATABASE"
    echo "💡 Przywracanie MySQL:"
    echo "   gunzip -c backup.sql.gz | mysql -h HOST -u USER -p DATABASE"
else
    echo ""
    echo "❌ Testowy backup nie powiódł się!"
    echo "   Sprawdź logi: /var/log/db-backup.log"
fi

echo ""
echo "⚠️  UWAGA: Backupy są przechowywane lokalnie na serwerze."
echo "   Dla pełnego bezpieczeństwa, rozważ kopiowanie na zewnętrzny storage:"
echo "   - Strych Mikrusa (200MB limit): setup-backup-mikrus.sh"
echo "   - Google Drive/Dropbox: rclone"
echo ""
