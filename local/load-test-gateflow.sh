#!/bin/bash
set -e

# Test obciążeniowy GateFlow
# Wymaga: curl, jq (opcjonalnie)
#
# Użycie: ./local/load-test-gateflow.sh <url> [liczba_requestów] [współbieżność]
#
# Przykłady:
#   ./local/load-test-gateflow.sh https://shop.example.com
#   ./local/load-test-gateflow.sh https://shop.byst.re 100 10
#   ./local/load-test-gateflow.sh https://shop.example.com 500 20

URL=${1}
TOTAL_REQUESTS=${2:-50}
CONCURRENT=${3:-5}

if [ -z "$URL" ]; then
  echo "❌ Użycie: $0 <url> [liczba_requestów] [współbieżność]"
  exit 1
fi

# Usuń trailing slash
URL=${URL%/}

echo "🚀 Test obciążeniowy GateFlow"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "URL:          $URL"
echo "Requesty:     $TOTAL_REQUESTS"
echo "Współbieżne:  $CONCURRENT"
echo ""
echo "📝 Scenariusz testu:"
echo "  1. Strona główna (20%)"
echo "  2. Lista produktów (30%)"
echo "  3. Szczegóły produktu (30%)"
echo "  4. Profil użytkownika (20%)"
echo ""

# Sprawdź czy serwer odpowiada
echo "🔍 Sprawdzam dostępność serwera..."
if ! curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" > /dev/null; then
  echo "❌ Serwer nie odpowiada. Sprawdź czy aplikacja działa."
  exit 1
fi
echo "✅ Serwer dostępny"
echo ""

# Przygotuj plik z URLami do testowania
TEST_FILE=$(mktemp)
DETAILS_LOG="/tmp/load-test-details-$(date +%s).log"
trap "rm -f $TEST_FILE; echo '💡 Szczegóły: $DETAILS_LOG'" EXIT

# Generuj requesty (proporcje scenariusza)
HOME_REQUESTS=$((TOTAL_REQUESTS * 20 / 100))
PRODUCTS_REQUESTS=$((TOTAL_REQUESTS * 30 / 100))
PRODUCT_DETAILS_REQUESTS=$((TOTAL_REQUESTS * 30 / 100))
PROFILE_REQUESTS=$((TOTAL_REQUESTS - HOME_REQUESTS - PRODUCTS_REQUESTS - PRODUCT_DETAILS_REQUESTS))

for i in $(seq 1 $HOME_REQUESTS); do echo "$URL"; done >> "$TEST_FILE"
for i in $(seq 1 $PRODUCTS_REQUESTS); do echo "$URL/products"; done >> "$TEST_FILE"
for i in $(seq 1 $PRODUCT_DETAILS_REQUESTS); do echo "$URL/products/demo-product-$((RANDOM % 5))"; done >> "$TEST_FILE"
for i in $(seq 1 $PROFILE_REQUESTS); do echo "$URL/profile"; done >> "$TEST_FILE"

# Pomieszaj requesty
sort -R "$TEST_FILE" -o "$TEST_FILE"

echo "🔥 Rozpoczynam test..."
echo ""

START_TIME=$(date +%s)
SUCCESS=0
FAILED=0
TOTAL_TIME=0
MIN_TIME=99999
MAX_TIME=0

# Funkcja do wysłania requestu
send_request() {
  local url=$1

  # Kompatybilność macOS i Linux - użyj python3 dla milisekund
  local start=$(python3 -c 'import time; print(int(time.time() * 1000))')
  local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "$url" 2>/dev/null || echo "000")
  local end=$(python3 -c 'import time; print(int(time.time() * 1000))')
  local duration=$((end - start))

  # Loguj szczegóły (URL, HTTP code, czas)
  echo "$url|$http_code|$duration" >> "$DETAILS_LOG"

  echo "$http_code $duration"
}

export -f send_request
export URL

# Wykonaj testy współbieżnie
cat "$TEST_FILE" | xargs -P "$CONCURRENT" -I {} bash -c 'send_request "{}"' | while read -r code duration; do
  if [ "$code" = "200" ] || [ "$code" = "304" ]; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAILED=$((FAILED + 1))
  fi

  TOTAL_TIME=$((TOTAL_TIME + duration))

  if [ "$duration" -lt "$MIN_TIME" ]; then MIN_TIME=$duration; fi
  if [ "$duration" -gt "$MAX_TIME" ]; then MAX_TIME=$duration; fi

  # Progress
  COMPLETED=$((SUCCESS + FAILED))
  PROGRESS=$((COMPLETED * 100 / TOTAL_REQUESTS))
  printf "\r⏳ [%-50s] %d%% | ✅ %d | ❌ %d" \
    "$(printf '#%.0s' $(seq 1 $((PROGRESS / 2))))" \
    "$PROGRESS" "$SUCCESS" "$FAILED"
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Wczytaj finalne statystyki (xargs może nadpisać zmienne)
RESULTS=$(cat "$TEST_FILE" | xargs -P "$CONCURRENT" -I {} bash -c 'send_request "{}"')
SUCCESS=$(echo "$RESULTS" | grep -c '^200\|^304' || echo 0)
FAILED=$((TOTAL_REQUESTS - SUCCESS))

# Oblicz średni czas
AVG_TIME=0
if [ "$SUCCESS" -gt 0 ]; then
  TIMES=$(echo "$RESULTS" | awk '{print $2}')
  TOTAL_TIME=$(echo "$TIMES" | awk '{sum+=$1} END {print sum}')
  AVG_TIME=$((TOTAL_TIME / SUCCESS))
  MIN_TIME=$(echo "$TIMES" | sort -n | head -1)
  MAX_TIME=$(echo "$TIMES" | sort -n | tail -1)
fi

echo ""
echo ""
echo "📈 Wyniki testu:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Czas trwania:     ${DURATION}s"
echo "Requesty:"
echo "  Sukces:         $SUCCESS"
echo "  Błędy:          $FAILED"
echo "  Success rate:   $((SUCCESS * 100 / TOTAL_REQUESTS))%"
echo ""
echo "Czasy odpowiedzi:"
echo "  Min:            ${MIN_TIME}ms"
echo "  Średnia:        ${AVG_TIME}ms"
echo "  Max:            ${MAX_TIME}ms"
echo ""

# Statystyki per endpoint
echo "🔍 Statystyki per endpoint:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "$DETAILS_LOG" ]; then
  # Home
  HOME_TOTAL=$(grep -c "^$URL|" "$DETAILS_LOG" || echo 0)
  HOME_SUCCESS=$(grep "^$URL|200\|^$URL|304" "$DETAILS_LOG" | wc -l | xargs)
  HOME_FAILED=$((HOME_TOTAL - HOME_SUCCESS))
  HOME_404=$(grep "^$URL|404" "$DETAILS_LOG" | wc -l | xargs)
  HOME_AVG=$(grep "^$URL|" "$DETAILS_LOG" | awk -F'|' '{sum+=$3} END {printf "%.0f", sum/NR}')

  # Products
  PRODUCTS_URL="$URL/products"
  PRODUCTS_TOTAL=$(grep -c "^$PRODUCTS_URL|" "$DETAILS_LOG" || echo 0)
  PRODUCTS_SUCCESS=$(grep "^$PRODUCTS_URL|200\|^$PRODUCTS_URL|304" "$DETAILS_LOG" | wc -l | xargs)
  PRODUCTS_FAILED=$((PRODUCTS_TOTAL - PRODUCTS_SUCCESS))
  PRODUCTS_AVG=$(grep "^$PRODUCTS_URL|" "$DETAILS_LOG" | awk -F'|' '{sum+=$3} END {printf "%.0f", sum/NR}')

  # Product Details (agreguj wszystkie demo-product-X)
  DETAILS_TOTAL=$(grep -c "^$URL/products/demo-product-" "$DETAILS_LOG" || echo 0)
  DETAILS_SUCCESS=$(grep "^$URL/products/demo-product-|200\|^$URL/products/demo-product-|304" "$DETAILS_LOG" | wc -l | xargs)
  DETAILS_FAILED=$((DETAILS_TOTAL - DETAILS_SUCCESS))
  DETAILS_404=$(grep "^$URL/products/demo-product-|404" "$DETAILS_LOG" | wc -l | xargs)
  DETAILS_AVG=$(grep "^$URL/products/demo-product-" "$DETAILS_LOG" | awk -F'|' '{sum+=$3} END {printf "%.0f", sum/NR}')

  # Profile
  PROFILE_URL="$URL/profile"
  PROFILE_TOTAL=$(grep -c "^$PROFILE_URL|" "$DETAILS_LOG" || echo 0)
  PROFILE_SUCCESS=$(grep "^$PROFILE_URL|200\|^$PROFILE_URL|304" "$DETAILS_LOG" | wc -l | xargs)
  PROFILE_FAILED=$((PROFILE_TOTAL - PROFILE_SUCCESS))
  PROFILE_AVG=$(grep "^$PROFILE_URL|" "$DETAILS_LOG" | awk -F'|' '{sum+=$3} END {printf "%.0f", sum/NR}')

  # Wyświetl tabelkę
  printf "%-20s %10s %10s %10s %10s\n" "Endpoint" "Total" "Success" "Failed" "Avg(ms)"
  printf "%-20s %10s %10s %10s %10s\n" "--------" "-----" "-------" "------" "-------"
  printf "%-20s %10d %10d %10d %10s\n" "Home" "$HOME_TOTAL" "$HOME_SUCCESS" "$HOME_FAILED" "${HOME_AVG:--}"
  printf "%-20s %10d %10d %10d %10s\n" "Products" "$PRODUCTS_TOTAL" "$PRODUCTS_SUCCESS" "$PRODUCTS_FAILED" "${PRODUCTS_AVG:--}"
  printf "%-20s %10d %10d %10d %10s\n" "Product Details" "$DETAILS_TOTAL" "$DETAILS_SUCCESS" "$DETAILS_FAILED" "${DETAILS_AVG:--}"
  printf "%-20s %10d %10d %10d %10s\n" "Profile" "$PROFILE_TOTAL" "$PROFILE_SUCCESS" "$PROFILE_FAILED" "${PROFILE_AVG:--}"

  # Szczegóły błędów
  if [ "$DETAILS_404" -gt 0 ] || [ "$HOME_404" -gt 0 ]; then
    echo ""
    echo "⚠️  Błędy 404:"
    if [ "$DETAILS_404" -gt 0 ]; then
      echo "  - Product Details: $DETAILS_404 requestów zwróciło 404 (demo-product-X nie istnieje)"
    fi
    if [ "$HOME_404" -gt 0 ]; then
      echo "  - Home: $HOME_404 requestów zwróciło 404"
    fi
  fi

  # Kody błędów
  echo ""
  echo "📋 Kod błędów:"
  grep "|000\|400\|401\|403\|404\|500\|502\|503\|504\|429\|" "$DETAILS_LOG" 2>/dev/null | \
    awk -F'|' '{codes[$2]++} END {for (c in codes) printf "  %s: %d\n", c, codes[c]}' | sort -k2 -rn || echo "  Brak błędów"

  # Przykłady błędnych requestów
  echo ""
  echo "❌ Przykłady błędnych requestów:"
  grep -v "|200\|304\|" "$DETAILS_LOG" | head -5 | while IFS='|' read url code duration; do
    printf "  %s -> %s (%sms)\n" "$url" "$code" "$duration"
  done

  echo ""
  echo "💡 Szczegóły zapisane w: $DETAILS_LOG"
else
  echo "  Brak szczegółów do analizy"
fi

echo ""

# Ocena wydajności
if [ "$AVG_TIME" -lt 500 ]; then
  echo "✅ Wydajność: Świetna! (< 500ms)"
elif [ "$AVG_TIME" -lt 1000 ]; then
  echo "⚠️  Wydajność: Dobra, ale można zoptymalizować (500-1000ms)"
elif [ "$AVG_TIME" -lt 2000 ]; then
  echo "🔶 Wydajność: Przeciętna, wymaga optymalizacji (1-2s)"
else
  echo "🔥 Wydajność: Słaba! Pilnie wymagana optymalizacja (> 2s)"
fi

echo ""
echo "💡 Wskazówki:"
echo "  - Uruchom ./local/monitor-gateflow.sh podczas testu aby zobaczyć zużycie zasobów"
echo "  - Zwiększ współbieżność (--concurrent) aby symulować więcej użytkowników"
echo "  - Sprawdź logi: ssh <alias> 'pm2 logs gateflow-admin --lines 100'"
