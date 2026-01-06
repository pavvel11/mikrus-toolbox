# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mikrus Toolbox is a collection of deployment scripts for self-hosted applications on low-resource VPS servers (primarily Mikrus.pl). The toolbox enables "solopreneurs" to run enterprise-grade services (n8n, Listmonk, NocoDB, etc.) on cheap VPS hosting (~20 PLN/month).

**Language:** Polish (README, comments, user prompts in scripts)

## Repository Structure

```
mikrus-toolbox/
├── local/           # Scripts run from local Mac (command center)
│   ├── deploy.sh    # Main deployment script - pipes app scripts to remote server
│   ├── sync.sh      # rsync wrapper for file uploads/downloads
│   ├── setup-backup.sh   # Backup configuration wizard (uses rclone)
│   └── restore.sh   # Emergency restore script
├── system/          # Server-side system setup scripts
│   ├── docker-setup.sh   # Docker installation with log optimization
│   ├── caddy-install.sh  # Caddy reverse proxy + mikrus-expose helper
│   ├── backup-core.sh    # Backup execution script (runs on server)
│   └── power-tools.sh    # CLI tools (yt-dlp, ffmpeg, pup)
└── apps/            # Application installers (one folder per app)
    └── <app>/
        ├── install.sh    # Main installer (run via deploy.sh)
        ├── backup.sh     # Optional app-specific backup
        └── README.md     # App documentation
```

## Key Commands

### Deploy an application
```bash
# Smart mode (detects apps/<name>/install.sh)
./local/deploy.sh n8n

# Direct script path
./local/deploy.sh apps/n8n/install.sh
./local/deploy.sh system/docker-setup.sh
```

### File synchronization
```bash
./local/sync.sh up ./local-folder /remote/path    # Upload
./local/sync.sh down /remote/path ./local-folder  # Download
```

### Setup backup
```bash
./local/setup-backup.sh   # Interactive wizard for cloud backup
```

## Architecture Patterns

### Deployment Model
Scripts in `local/` run on Mac and execute server scripts via SSH (`ssh mikrus`). The deploy.sh script pipes script content to the remote server (`cat script.sh | ssh mikrus "bash -s"`).

**Prerequisite:** SSH alias `mikrus` must be configured (via external `setup_mikrus.sh`).

### App Installation Convention
Each app in `apps/` follows the pattern:
1. Prompt user for configuration (domain, DB credentials)
2. Create `/opt/stacks/<app>/` directory on server
3. Generate `docker-compose.yaml` with memory limits
4. Start container with `docker compose up -d`
5. Configure HTTPS via `mikrus-expose <domain> <port>`

### Resource Constraints
All docker-compose files include memory limits (e.g., `600M` for n8n). Apps are optimized to use external PostgreSQL rather than local DB containers to save RAM.

### HTTPS/SSL
Caddy provides automatic HTTPS. The `mikrus-expose` CLI tool (installed by `caddy-install.sh`) adds domains to Caddyfile:
```bash
mikrus-expose app.domain.com 5000
```

## Writing New App Installers

When creating `apps/<newapp>/install.sh`:
- Use `set -e` for fail-fast behavior
- Prompt for all user inputs (domain, credentials) interactively with `read`
- Place files in `/opt/stacks/<app>/`
- Include memory limits in docker-compose deploy section
- Call `mikrus-expose` at the end for HTTPS setup
- Use Polish for user-facing messages
