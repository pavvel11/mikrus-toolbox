# Mikrus Toolbox - Analysis & Strategy

## Context
- **Goal:** Open Source repo for one-line Mikrus deployments.
- **Inspiration:** `https://github.com/unkn0w/noobs`
- **Prerequisite:** Local machine configured via `setup_mikrus.sh` (SSH alias available).

## Reference: `unkn0w/noobs`
- **Structure:** `scripts/` (services), `actions/` (system maintenance).
- **Style:** Bash scripts, mostly dealing with system packages (apt) and simple configurations.
- **Target:** Ubuntu 22.04 on Mikrus.

## Strategy: "The Lazy/Smart Layer"
Since we have `setup_mikrus.sh` configuring `ssh mikrus`, we can do better than just server-side scripts. We can have a local "Command Center".

### Component 1: Server Scripts (The Core)
Standard `curl | bash` scripts that run ON the server.
- Install Docker.
- Install specific apps (Docker Compose preferred for easy rollback/update).
- System hardening.

### Component 2: Local Wrapper (The Bridge)
A script on your Mac that:
1. Accepts an app name (e.g., `n8n`).
2. SSH's into Mikrus.
3. Triggers the installation command.

## Tech Stack
- **OS:** Mikrus (usually Ubuntu/Debian).
- **Containerization:** Docker is preferred for apps to keep the host clean, but strictly optimized for low RAM (Mikrus constraints).
- **Proxy:** Caddy or Traefik (optional, but Caddy is easier for automatic HTTPS).
