#!/bin/bash

# Mikrus Toolbox - Social Media Generator
# Generuj spójne grafiki social media z szablonów HTML.
# Jeden tekst, wiele formatów (Instagram, Stories, YouTube).
# https://github.com/jurczykpawel/social-media-generator
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=1000  # Python 3.12 + Playwright/Chromium + FastAPI + deps
#
# ⚠️  UWAGA: Ta aplikacja wymaga minimum 2GB RAM (Mikrus 3.0+)!
#     Social Media Generator uruchamia headless Chromium do renderowania grafik.
#     Na Mikrus 2.1 (1GB RAM) może powodować zawieszenie serwera.
#
# Stack: FastAPI + Playwright (Chromium) + PostgreSQL 16
# UI: Panel webowy z logowaniem przez magic link
# API: REST API do generowania grafik programowo

set -e

APP_NAME="social-media-generator"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-8000}
REPO_URL="https://github.com/jurczykpawel/social-media-generator.git"

echo "--- 🎨 Social Media Generator Setup ---"
echo "Generuj grafiki social media z szablonów HTML."
echo ""

# Port binding: Cytrus wymaga 0.0.0.0, Cloudflare/local → 127.0.0.1
if [ "${DOMAIN_TYPE:-}" = "cytrus" ]; then
    BIND_ADDR=""
else
    BIND_ADDR="127.0.0.1:"
fi

# Sprawdź dostępny RAM - WYMAGANE minimum 2GB!
TOTAL_RAM=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "0")

if [ "$TOTAL_RAM" -gt 0 ] && [ "$TOTAL_RAM" -lt 1800 ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ❌ BŁĄD: Za mało RAM dla Social Media Generator!            ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  Twój serwer: ${TOTAL_RAM}MB RAM                             ║"
    echo "║  Wymagane:    2048MB RAM (Mikrus 3.0+)                       ║"
    echo "║                                                              ║"
    echo "║  Aplikacja uruchamia headless Chromium (~1GB RAM).           ║"
    echo "║  Na Mikrus 2.1 zawiesza serwer!                             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# Domain
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo "✅ Domena: $DOMAIN"
elif [ "$DOMAIN" = "-" ]; then
    echo "✅ Domena: automatyczna (Cytrus)"
else
    echo "⚠️  Brak domeny - użyj --domain=... lub dostęp przez SSH tunnel"
fi

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

# Klonuj lub aktualizuj repozytorium
if [ -d "$STACK_DIR/repo/.git" ]; then
    echo "📦 Aktualizuję repozytorium..."
    cd "$STACK_DIR/repo"
    sudo git pull --quiet
    cd "$STACK_DIR"
else
    echo "📦 Klonuję repozytorium..."
    sudo git clone --depth 1 "$REPO_URL" "$STACK_DIR/repo"
fi

# Generuj sekrety
SECRET_KEY=$(openssl rand -hex 32)
PG_PASS=$(openssl rand -hex 16)

# Generuj .env
BASE_URL=""
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    BASE_URL="https://$DOMAIN"
fi

cat <<EOF | sudo tee .env > /dev/null
SECRET_KEY=$SECRET_KEY
DATABASE_URL=postgresql://smg:${PG_PASS}@db:5432/smg
BASE_URL=${BASE_URL:-http://localhost:$PORT}
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
EMAIL_FROM=
CREDIT_PRODUCTS={"100-credits": 100, "500-credits": 500, "unlimited": 10000}
POSTGRES_DB=smg
POSTGRES_USER=smg
POSTGRES_PASSWORD=$PG_PASS
EOF

sudo chmod 600 .env
echo "✅ Konfiguracja wygenerowana"

# Generuj docker-compose.yaml
cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  app:
    build:
      context: ./repo
      dockerfile: Dockerfile
    restart: always
    ports:
      - "${BIND_ADDR}$PORT:8000"
    env_file: .env
    volumes:
      - app_data:/app/data
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    deploy:
      resources:
        limits:
          memory: 1024M

  db:
    image: postgres:16-alpine
    restart: always
    env_file: .env
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "smg"]
      interval: 2s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 256M

volumes:
  app_data:
  pg_data:
EOF

# Buduj i uruchamiaj
echo "🔨 Buduję obraz Docker (to może potrwać kilka minut)..."
sudo docker compose build --quiet 2>/dev/null || sudo docker compose build
sudo docker compose up -d

# Health check - Chromium potrzebuje czasu na start
echo "⏳ Czekam na uruchomienie (~60-90s, Chromium się ładuje)..."
source /opt/mikrus-toolbox/lib/health-check.sh 2>/dev/null || true
if type wait_for_healthy &>/dev/null; then
    wait_for_healthy "$APP_NAME" "$PORT" 90 || { echo "❌ Instalacja nie powiodła się!"; exit 1; }
else
    for i in $(seq 1 9); do
        sleep 10
        if curl -sf "http://localhost:$PORT/health" > /dev/null 2>&1; then
            echo "✅ Social Media Generator działa (po $((i*10))s)"
            break
        fi
        echo "   ... $((i*10))s"
        if [ "$i" -eq 9 ]; then
            echo "❌ Kontener nie wystartował w 90s!"
            sudo docker compose logs --tail 30
            exit 1
        fi
    done
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ Social Media Generator zainstalowany!"
echo "════════════════════════════════════════════════════════════════"
echo ""
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "-" ]; then
    echo "🔗 Panel: https://$DOMAIN"
    echo "🔗 API:   https://$DOMAIN/docs"
elif [ "$DOMAIN" = "-" ]; then
    echo "🔗 Domena zostanie skonfigurowana automatycznie po instalacji"
else
    echo "🔗 Dostęp przez SSH tunnel: ssh -L $PORT:localhost:$PORT <server>"
    echo "   Panel: http://localhost:$PORT"
    echo "   API:   http://localhost:$PORT/docs"
fi
echo ""
echo "🔑 SECRET_KEY zapisany w: $STACK_DIR/.env"
echo ""
echo "📋 Następne kroki:"
echo "   1. Skonfiguruj SMTP w .env (magic link auth wymaga maila)"
echo "   2. Otwórz panel i zarejestruj konto (pierwszy user = admin)"
echo "   3. Dodaj własne brandy w /opt/stacks/$APP_NAME/repo/brands/"
echo ""
echo "📋 Przykład użycia API:"
echo "   curl -X POST http://localhost:$PORT/api/generate \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"brand\": \"example\", \"template\": \"quote-card\", \"text\": \"Hello!\"}'"
