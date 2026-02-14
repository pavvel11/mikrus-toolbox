# AGENTS.md

Instrukcje dla agentów AI (Claude Code, Cursor, Copilot, itp.) pracujących z tym repozytorium.

## Projekt i rola

Skrypty Bash do zarządzania serwerami [Mikrus](https://mikr.us) - tani polski VPS.
Toolbox automatyzuje instalację aplikacji Docker, konfigurację domen, backupy i diagnostykę.

Pomagasz użytkownikom zarządzać ich serwerami Mikrus. Możesz:
- Instalować aplikacje (`./local/deploy.sh`)
- Konfigurować backupy i domeny
- Diagnozować problemy (logi, porty, RAM)
- Tworzyć nowe instalatory (`apps/<app>/install.sh`)

**Zawsze komunikuj się po polsku.** Zrób za użytkownika co się da, resztę wytłumacz krok po kroku.

**WAŻNE:** Nigdy nie konstruuj ręcznie komend curl do API Mikrusa - zawsze używaj skryptów!

## Struktura repozytorium

```
local/           → Skrypty użytkownika (deploy, backup, setup)
apps/<app>/      → Instalatory aplikacji (install.sh + README.md)
lib/             → Biblioteki pomocnicze (cli-parser, db-setup, domain-setup, health-check, resource-check)
system/          → Skrypty systemowe (docker, caddy, backup-core)
docs/            → Dokumentacja (Cloudflare, CLI reference)
```

## Deploy aplikacji

```bash
./local/deploy.sh APP [opcje]

# Opcje:
#   --ssh=ALIAS           SSH alias (domyślnie: mikrus)
#   --domain-type=TYPE    cytrus | cloudflare | local
#   --domain=DOMAIN       Domena lub "auto" dla Cytrus
#   --db-source=SOURCE    shared | custom (bazy danych)
#   --yes, -y             Pomiń wszystkie potwierdzenia

# Przykłady:
./local/deploy.sh n8n --ssh=hanna --domain-type=cytrus --domain=auto
./local/deploy.sh uptime-kuma --ssh=hanna --domain-type=local --yes
./local/deploy.sh wordpress --ssh=hanna --domain-type=cytrus --domain=auto
```

**WordPress env vars** (przekazywane jako opcje lub env):
- `WP_DB_MODE=sqlite|mysql` - tryb bazy (domyślnie: mysql)
- `WP_REDIS=auto|external|bundled` - auto-detekcja Redisa na hoście

**Post-install WordPress** - po ukończeniu kreatora w przeglądarce:
```bash
ssh hanna 'cd /opt/stacks/wordpress && ./wp-init.sh'
```

## Aplikacje (24)

Wszystkie w `apps/<nazwa>/install.sh`. Uruchamiane przez `deploy.sh`, nie ręcznie.

n8n, ntfy, uptime-kuma, filebrowser, dockge, stirling-pdf, vaultwarden, linkstack, littlelink, nocodb, umami, listmonk, typebot, redis, wordpress, convertx, postiz, crawl4ai, cap, gateflow, minio, gotenberg, cookie-hub, mcp-docker

Szczegóły konkretnej aplikacji (porty, wymagania, DB) → `apps/<app>/README.md` lub `GUIDE.md`

## WordPress - architektura

Najbardziej złożona aplikacja. Własny Dockerfile, 3 kontenery, auto-tuning na RAM.

```
wordpress (build: .) → wordpress:php8.3-fpm-alpine + pecl redis + WP-CLI
nginx:alpine          → gzip, FastCGI cache, rate limiting, security headers
redis:alpine          → object cache (bundled lub external, auto-detekcja)
```

**Pliki na serwerze (`/opt/stacks/wordpress/`):**
- `Dockerfile` - extends wordpress:fpm-alpine + redis ext + WP-CLI
- `docker-compose.yaml` - dynamiczny (zależy od DB i Redis mode)
- `config/` - php-opcache.ini, php-performance.ini, www.conf, nginx.conf
- `wp-init.sh` - post-install: wp-config tuning + Redis Object Cache (WP-CLI)
- `flush-cache.sh` - czyści FastCGI cache
- `.redis-host` - `redis` (bundled) lub `host-gateway` (external)

**DB detection:** install.sh zawiera literały `DB_HOST` i `mysql`, więc deploy.sh automatycznie wykrywa potrzebę MySQL. W trybie `WP_DB_MODE=sqlite` zmienne DB są ignorowane.

**wp-init.sh automatycznie:** HTTPS fix, WP-Cron→system cron, rewizje limit, autosave 5min, DISALLOW_FILE_EDIT, Redis config + plugin install/activate via WP-CLI.

## Code style

### Konwencje

- `set -e` w każdym skrypcie
- Zmienne: `UPPER_CASE`, funkcje: `snake_case()` (bez `function`)
- Pliki: `kebab-case.sh`, katalogi: `kebab-case`
- Komunikaty po polsku z emoji (✅ ❌ ⚠️)
- Zawsze `memory:` limit w docker-compose
- Porty: `127.0.0.1:$PORT:CONTAINER_PORT` (bezpieczeństwo, Cytrus wymaga `$PORT:CONTAINER_PORT` bez 127.0.0.1 - deploy.sh przekazuje `DOMAIN_TYPE`)

### Wzorzec install.sh

```bash
#!/bin/bash

# Mikrus Toolbox - Nazwa Aplikacji
# Opis.
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=200  # Rozmiar obrazu Docker

set -e

APP_NAME="myapp"
STACK_DIR="/opt/stacks/$APP_NAME"
PORT=${PORT:-3000}

# Walidacja (jeśli DB)
if [ -z "$DB_HOST" ]; then echo "❌ Brak danych DB!"; exit 1; fi

sudo mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  myapp:
    image: myimage:latest
    restart: always
    ports:
      - "127.0.0.1:$PORT:8080"
    deploy:
      resources:
        limits:
          memory: 256M
EOF

sudo docker compose up -d
```

### Kluczowe zasady

- Nie pytaj o domenę w install.sh - robi to deploy.sh
- Pliki w `/opt/stacks/<app>/`
- `|| { echo "❌ Error"; exit 1; }` dla obsługi błędów
- `|| true` dla opcjonalnych komend
- Nigdy nie loguj sekretów
- Sekrety w env vars, konfiguracje w `~/.config/mikrus/`

## Więcej informacji

Szczegółowa dokumentacja → **`GUIDE.md`** (referencja operacyjna):
- SSH, klucz API, konfiguracja połączenia
- Pełna tabela aplikacji z portami
- Szczegółowy flow deploy.sh (krok po kroku)
- Backup i restore (konfiguracja, ręczne uruchomienie, weryfikacja)
- Diagnostyka i troubleshooting (logi, porty, typowe problemy)
- Architektura (domeny Cytrus/Cloudflare, bazy danych)
- Limity i ograniczenia (RAM, dysk, porty)

Inne źródła:
- `apps/<app>/README.md` - szczegóły per aplikacja
- `docs/CLI-REFERENCE.md` - pełna referencja parametrów CLI
