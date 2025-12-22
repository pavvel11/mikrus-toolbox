# 🍪 Cookie Hub (Klaro!)

Centralny serwer zarządzania zgodami RODO/Cookies.

## 🚀 Instalacja

```bash
./local/deploy.sh cookie-hub
```

## 💡 Idea "Centralizacji"
Zamiast konfigurować wtyczki do cookies na każdej stronie (WordPress, Ghost, Landing Page) z osobna:
1. Stawiasz **jeden** Cookie Hub.
2. Definiujesz usługi (Google Analytics, Pixel FB) w **jednym pliku** `config.js` na serwerze.
3. Wklejasz krótki kod HTML na wszystkie swoje strony.

Gdy zmieni się prawo lub dodasz nowe narzędzie śledzące, aktualizujesz tylko plik na Hubie, a zmiany pojawiają się wszędzie.

## 🛠️ Integracja
Wklej to do sekcji `<head>` swoich stron:

```html
<link rel="stylesheet" href="https://TWOJA-DOMENA-COOKIES/klaro.css" />
<script defer type="text/javascript" src="https://TWOJA-DOMENA-COOKIES/config.js"></script>
<script defer type="text/javascript" src="https://TWOJA-DOMENA-COOKIES/klaro.js"></script>
```

Aby zablokować skrypt (np. Google Analytics) do czasu zgody, zmień jego typ:
```html
<script type="text/plain" data-type="application/javascript" data-name="googleAnalytics">
  // Twój kod GA tutaj
</script>
```
