#!/bin/bash

# Mikrus Toolbox - Port Utilities
# Wyszukiwanie wolnych portów na serwerze.
# Author: Paweł (Lazy Engineer)
#
# Użycie:
#   source lib/port-utils.sh
#   PORT=$(find_free_port 8000)           # lokalnie
#   PORT=$(find_free_port_remote mikrus 8000)  # zdalnie przez SSH

# Znajdź pierwszy wolny port >= BASE_PORT (lokalnie)
# Jedno wywołanie ss, potem szukanie w pamięci - brak limitu prób.
# Argumenty: BASE_PORT
# Zwraca: numer wolnego portu (stdout)
find_free_port() {
    local port="${1:-8000}"
    local used
    used=$(ss -tlnp 2>/dev/null | awk '{print $4}' | grep -oE '[0-9]+$' | sort -un)

    while echo "$used" | grep -qx "$port"; do
        port=$((port + 1))
    done
    echo "$port"
}

# Znajdź pierwszy wolny port >= BASE_PORT (zdalnie przez SSH)
# Jedno wywołanie SSH, potem szukanie lokalne.
# Argumenty: SSH_ALIAS BASE_PORT
# Zwraca: numer wolnego portu (stdout)
find_free_port_remote() {
    local ssh_alias="$1"
    local port="${2:-8000}"
    local used
    used=$(ssh -o ConnectTimeout=5 "$ssh_alias" "ss -tlnp 2>/dev/null" 2>/dev/null | awk '{print $4}' | grep -oE '[0-9]+$' | sort -un)

    while echo "$used" | grep -qx "$port"; do
        port=$((port + 1))
    done
    echo "$port"
}

# Eksportuj funkcje
export -f find_free_port
export -f find_free_port_remote
