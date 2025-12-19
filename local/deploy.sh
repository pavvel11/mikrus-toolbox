#!/bin/bash

# Mikrus Toolbox - Remote Deployer
# Usage: ./local/deploy.sh <script_path_relative_to_repo_root>
# Example: ./local/deploy.sh system/docker-setup.sh

TARGET="mikrus" # Assumes you have 'ssh mikrus' configured via setup_mikrus.sh
SCRIPT_PATH="$1"

# 1. Validate input
if [ -z "$SCRIPT_PATH" ]; then
  echo "❌ Error: No script specified."
  echo "Usage: $0 <path/to/script.sh>"
  exit 1
fi

if [ ! -f "$SCRIPT_PATH" ]; then
  # Try to find it relative to the repo root if run from a subdir
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
  if [ -f "$REPO_ROOT/$SCRIPT_PATH" ]; then
    SCRIPT_PATH="$REPO_ROOT/$SCRIPT_PATH"
  else
    echo "❌ Error: Script file '$SCRIPT_PATH' not found."
    exit 1
  fi
fi

# 2. Confirm action
echo "🚀 Deploying '$SCRIPT_PATH' to remote '$TARGET'..."
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# 3. Execute remotely via SSH pipe
# Using 'bash -s' allows passing arguments if we ever need them
cat "$SCRIPT_PATH" | ssh "$TARGET" "bash -s"

echo "✅ Deployment finished."
