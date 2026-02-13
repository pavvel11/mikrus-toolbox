# AGENTS.md

This repository contains Bash scripts for managing Mikrus servers and deploying applications.

## Build/Test Commands

Pure Bash project - no build, compile, or test runners.

**Run scripts directly:**
```bash
./local/deploy.sh APP_NAME --ssh=mikrus
./local/cytrus-domain.sh domain.com 3001
./local/setup-backup.sh
./local/deploy.sh APP_NAME --dry-run  # Test without executing
```

**Manual testing:** Run on test server, verify `docker ps | grep APP`, check `docker logs -f APP`, confirm port responds with `curl -I http://localhost:PORT`.

## Code Style Guidelines

### Header Format
```bash
#!/bin/bash

# Mikrus Toolbox - Script Purpose
# Brief description.
# Author: Paweł (Lazy Engineer)
#
# IMAGE_SIZE_MB=500  # Optional Docker size hint
#
# Required env vars:
#   VAR1 - Description
```

### Error Handling
- Always use `set -e` for fail-fast
- Pattern: `|| { echo "Error"; exit 1; }`
- Use `|| true` for optional commands

```bash
set -e
command_to_run || { echo "❌ Error"; exit 1; }
```

### Functions & Variables
```bash
# snake_case, no 'function' keyword
function_name() {
    local var1="$1"
    local var2="${2:-default}"
}

export SSH_ALIAS="${SSH_ALIAS:-mikrus}"
export DB_PORT="${DB_PORT:-5432}"
local app_name="$1"
```

### Colors & Messages
```bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${GREEN}✅ Success${NC}"
echo -e "${RED}❌ Error${NC}"
echo -e "${YELLOW}⚠️  Warning${NC}"
```

**User messages:** Always use Polish, include emojis (✅ ❌ ⚠️ 🌐), box format for sections.

### File Creation (Heredoc)
```bash
cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  app:
    image: myimage:latest
    ports:
      - "$PORT:8080"
EOF
```

### SSH & Docker Patterns
```bash
SSH_ALIAS="${SSH_ALIAS:-mikrus}"
ssh "$SSH_ALIAS" "command"
scp local_file "$SSH_ALIAS:/remote/path"
ssh -t "$SSH_ALIAS" "export VAR=value; bash /path/to/script.sh"

APP_NAME="myapp"; STACK_DIR="/opt/stacks/$APP_NAME"; PORT=${PORT:-3000}
sudo mkdir -p "$STACK_DIR"; cd "$STACK_DIR"

cat <<EOF | sudo tee docker-compose.yaml > /dev/null
services:
  myapp:
    image: myimage:latest
    restart: always
    ports:
      - "$PORT:8080"
    deploy:
      resources:
        limits:
          memory: 256M
EOF

sudo docker compose up -d
```

### Database Pattern
```bash
if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo "❌ Brak danych bazy danych!"
    exit 1
fi
DB_PORT="${DB_PORT:-5432}"; DB_NAME="${DB_NAME:-app_db}"; DB_SCHEMA="${DB_SCHEMA:-public}"
```

### Library Usage
```bash
source "$REPO_ROOT/lib/cli-parser.sh"    # CLI parsing
source "$REPO_ROOT/lib/db-setup.sh"      # Database helpers
source "$REPO_ROOT/lib/domain-setup.sh"   # Domain config
source "$REPO_ROOT/lib/health-check.sh"   # Health checks
```

### Conditionals & Arg Parsing
```bash
if [[ "$VAR" == "value" ]]; then echo "Match"; fi
if [ "$PORT" -lt 1024 ]; then echo "Privileged port"; fi
if [ -n "$VAR" ]; then echo "VAR is set"; fi
if [ -z "$VAR" ]; then echo "VAR is empty"; fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ssh=*) SSH_ALIAS="${1#*=}" ;;
        --yes) YES_MODE=true ;;
        *) POSITIONAL_ARGS+=("$1") ;;
    esac
    shift
done
```

### Common Pitfalls
- Don't use `function` keyword - use `name()`
- Always declare function-local vars with `local`
- Always use `set -e` and handle failures
- Don't hardcode paths - use `/opt/stacks/$APP_NAME`
- Always use `confirm()` before destructive actions
- Use Polish for user messages
- Always add `memory:` limits in docker-compose

### Naming Conventions
- Variables: `UPPER_CASE_WITH_UNDERSCORES`
- Functions: `snake_case()`
- Constants: `ALL_CAPS` (`APP_NAME`, `PORT`)
- Files: `kebab-case.sh`
- Dirs: `kebab-case` (except `apps/` uses app names)

### File Organization
- `local/` - User-facing scripts (deploy, backup, setup)
- `apps/<app>/install.sh` - Application installers
- `lib/` - Reusable helpers
- `system/` - System-level scripts
- `docs/` - Documentation

### Security
- Never log or expose secrets
- Use env vars for credentials
- Store sensitive configs in `~/.config/mikrus/`
- Validate user input before use
