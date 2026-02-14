#!/bin/bash

# Mikrus Toolbox - Redis Detection
# Wspólna logika detekcji Redis (external vs bundled).
# Używane przez: apps/wordpress/install.sh, apps/postiz/install.sh
#
# Użycie:
#   source /opt/mikrus-toolbox/lib/redis-detect.sh
#   detect_redis "$MODE"  # MODE: auto|external|bundled
#
# Po wywołaniu ustawia zmienne:
#   REDIS_HOST  - "host-gateway" (external) lub nazwa serwisu (bundled)
#   REDIS_PASS  - hasło (puste jeśli bez hasła lub bundled)
#
# Parametry:
#   $1 - tryb: auto|external|bundled
#   $2 - nazwa serwisu bundled Redis (domyślnie: "redis")

detect_redis() {
    local MODE="${1:-auto}"
    local BUNDLED_NAME="${2:-redis}"

    REDIS_HOST=""
    REDIS_PASS=""

    # Sprawdź czy external Redis odpowiada (z obsługą hasła)
    _redis_ping() {
        # Najpierw sprawdź standalone Redis z hasłem (apps/redis)
        if [ -f /opt/stacks/redis/.redis_password ]; then
            local pass
            pass=$(cat /opt/stacks/redis/.redis_password 2>/dev/null)
            if [ -n "$pass" ] && redis-cli -a "$pass" ping 2>/dev/null | grep -q PONG; then
                REDIS_PASS="$pass"
                return 0
            fi
        fi
        # Fallback: Redis bez hasła
        if redis-cli ping 2>/dev/null | grep -q PONG; then
            return 0
        fi
        return 1
    }

    if [ "$MODE" = "external" ]; then
        if _redis_ping; then
            REDIS_HOST="host-gateway"
            echo "✅ Redis: zewnętrzny (host, wymuszony)"
        else
            echo "⚠️  Redis external nie odpowiada na localhost:6379"
            echo "   Używam bundled Redis zamiast tego."
            REDIS_HOST="$BUNDLED_NAME"
        fi
    elif [ "$MODE" = "bundled" ]; then
        REDIS_HOST="$BUNDLED_NAME"
        echo "✅ Redis: bundled (wymuszony)"
    elif _redis_ping; then
        REDIS_HOST="host-gateway"
        echo "✅ Redis: zewnętrzny (wykryty na localhost:6379)"
    else
        REDIS_HOST="$BUNDLED_NAME"
        echo "✅ Redis: bundled (brak istniejącego)"
    fi
}
