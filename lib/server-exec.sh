#!/bin/bash

# Mikrus Toolbox - Server Execution Abstraction
# Transparentnie uruchamia komendy lokalnie lub przez SSH.
#
# Detekcja: /klucz_api istnieje TYLKO na serwerach Mikrusa.
# Na lokalnym kompie → ssh, scp (jak dotychczas).
# Na serwerze → bash -c, cp (bezpośrednio, bez SSH).
#
# Użycie:
#   source "$SCRIPT_DIR/../lib/server-exec.sh"
#   server_exec "cat /klucz_api"
#   server_exec_tty "bash install.sh"
#   server_copy "/tmp/file" "/opt/dest"

# Detekcja środowiska
if [ -f /klucz_api ]; then
    _MIKRUS_ON_SERVER=true
else
    _MIKRUS_ON_SERVER=false
fi

# Czy skrypt działa na serwerze Mikrusa?
is_on_server() { [ "$_MIKRUS_ON_SERVER" = true ]; }

# Uruchom komendę na serwerze
# Użycie: server_exec "polecenie"
server_exec() {
    if is_on_server; then
        bash -c "$1"
    else
        ssh "${SSH_ALIAS:-mikrus}" "$1"
    fi
}

# Uruchom komendę z alokacją TTY (dla interaktywnych poleceń)
# Użycie: server_exec_tty "polecenie"
server_exec_tty() {
    if is_on_server; then
        bash -c "$1"
    else
        ssh -t "${SSH_ALIAS:-mikrus}" "$1"
    fi
}

# Uruchom komendę z timeoutem połączenia
# Użycie: server_exec_timeout SEKUNDY "polecenie"
server_exec_timeout() {
    local timeout="$1"
    local cmd="$2"
    if is_on_server; then
        bash -c "$cmd"
    else
        ssh -o "ConnectTimeout=$timeout" "${SSH_ALIAS:-mikrus}" "$cmd" 2>/dev/null
    fi
}

# Skopiuj plik NA serwer
# Użycie: server_copy LOCAL_PATH REMOTE_PATH
server_copy() {
    local src="$1"
    local dst="$2"
    if is_on_server; then
        cp "$src" "$dst"
    else
        scp -q "$src" "${SSH_ALIAS:-mikrus}:$dst"
    fi
}

# Prześlij plik na serwer (odpowiednik: cat FILE | ssh "cat > DEST")
# Użycie: server_pipe_to LOCAL_FILE REMOTE_PATH
server_pipe_to() {
    local src="$1"
    local dst="$2"
    if is_on_server; then
        cp "$src" "$dst"
        chmod +x "$dst" 2>/dev/null || true
    else
        cat "$src" | ssh "${SSH_ALIAS:-mikrus}" "cat > '$dst' && chmod +x '$dst'"
    fi
}

# Pobierz hostname serwera
# Użycie: HOSTNAME=$(server_hostname)
server_hostname() {
    if is_on_server; then
        hostname
    else
        ssh -G "${SSH_ALIAS:-mikrus}" 2>/dev/null | grep "^hostname " | cut -d' ' -f2
    fi
}

# Pobierz username na serwerze
# Użycie: USER=$(server_user)
server_user() {
    if is_on_server; then
        whoami
    else
        ssh -G "${SSH_ALIAS:-mikrus}" 2>/dev/null | grep "^user " | cut -d' ' -f2
    fi
}

# Upewnij się że toolbox jest zainstalowany na serwerze
# Użycie: ensure_toolbox [ssh_alias]
ensure_toolbox() {
    local ALIAS="${1:-${SSH_ALIAS:-mikrus}}"

    # Na serwerze — toolbox już jest
    if is_on_server; then
        return 0
    fi

    # Sprawdź czy mikrus-expose istnieje (marker toolboxa)
    if server_exec "test -f /opt/mikrus-toolbox/local/deploy.sh" 2>/dev/null; then
        return 0
    fi

    echo "📦 Instaluję toolbox na serwerze..."

    # Użyj rsync jeśli mamy lokalne repo, inaczej git clone
    local SCRIPT_DIR_SE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local REPO_ROOT_SE="$(cd "$SCRIPT_DIR_SE/.." && pwd)"

    if [ -f "$REPO_ROOT_SE/local/deploy.sh" ] && command -v rsync &>/dev/null; then
        rsync -az --delete \
            --exclude '.git' \
            --exclude 'node_modules' \
            --exclude 'mcp-server' \
            --exclude '.claude' \
            --exclude '*.md' \
            "$REPO_ROOT_SE/" "$ALIAS:/opt/mikrus-toolbox/" 2>/dev/null
    else
        server_exec "command -v git >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq git >/dev/null 2>&1) && rm -rf /opt/mikrus-toolbox && git clone --depth 1 https://github.com/jurczykpawel/mikrus-toolbox.git /opt/mikrus-toolbox 2>&1"
    fi

    # Dodaj do PATH
    server_exec "grep -q 'mikrus-toolbox/local' ~/.bashrc 2>/dev/null || sed -i '1i\\# Mikrus Toolbox\nexport PATH=/opt/mikrus-toolbox/local:\$PATH\n' ~/.bashrc 2>/dev/null; grep -q 'mikrus-toolbox/local' ~/.zshenv 2>/dev/null || (echo '' >> ~/.zshenv && echo '# Mikrus Toolbox' >> ~/.zshenv && echo 'export PATH=/opt/mikrus-toolbox/local:\$PATH' >> ~/.zshenv) 2>/dev/null" || true

    # Weryfikacja
    if server_exec "test -f /opt/mikrus-toolbox/local/deploy.sh" 2>/dev/null; then
        echo -e "${GREEN:-}✅ Toolbox zainstalowany${NC:-}"
        return 0
    else
        echo -e "${RED:-}❌ Nie udało się zainstalować toolboxa${NC:-}"
        return 1
    fi
}

export _MIKRUS_ON_SERVER
export -f is_on_server server_exec server_exec_tty server_exec_timeout
export -f server_copy server_pipe_to server_hostname server_user ensure_toolbox
