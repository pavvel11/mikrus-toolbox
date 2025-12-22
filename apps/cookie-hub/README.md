# 🍪 Cookie Hub (Klaro!) - Zarządzanie Zgodami

Centralny serwer zarządzania zgodami RODO/Cookies. Zapomnij o konfigurowaniu banerów na każdej stronie z osobna.

## 🚀 Instalacja

```bash
./local/deploy.sh cookie-hub
```

Podczas instalacji zostaniesz poproszony o podanie domeny (np. `assets.twojadomena.pl`), pod którą będą serwowane skrypty.

## 💡 Idea "Centralizacji" (Lazy Engineer Style)
Zamiast konfigurować wtyczki do cookies na każdej stronie (WordPress, GateFlow, Landing Page) z osobna:
1. Stawiasz **jeden** Cookie Hub.
2. Definiujesz usługi (Google Analytics, Pixel FB, Umami) w **jednym pliku** na serwerze.
3. Wklejasz ten sam kod HTML na wszystkie swoje strony.

Gdy zmieni się prawo lub dodasz nowe narzędzie śledzące, aktualizujesz tylko plik na Mikrusie, a zmiany pojawiają się wszędzie natychmiastowo.

## 🛠️ Integracja (Krok po kroku)

### 1. Dodaj skrypty do swojej strony
Wklej poniższy kod do sekcji `<head>` na każdej swojej stronie:

```html
<!-- Style i konfiguracja Klaro -->
<link rel="stylesheet" href="https://TWOJA-DOMENA-COOKIES/klaro.css" />
<script defer type="text/javascript" src="https://TWOJA-DOMENA-COOKIES/config.js"></script>
<!-- Główny skrypt Klaro -->
<script defer type="text/javascript" src="https://TWOJA-DOMENA-COOKIES/klaro.js"></script>
```

## 📋 Biblioteka Przykładów (Kopiuj-Wklej)

Aby Klaro działało, musisz zmienić sposób wklejania kodów śledzących.
Zasada: Zmieniasz `type="text/javascript"` na `type="text/plain"` i dodajesz `data-name="nazwaUslugi"`.

### Google Analytics 4 (GA4)
Wymaga zdefiniowania usługi `googleAnalytics` w `config.js`.

```html
<script async type="text/plain" data-type="application/javascript" data-name="googleAnalytics" src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXX"></script>
<script type="text/plain" data-type="application/javascript" data-name="googleAnalytics">
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXX');
</script>
```

### Meta Pixel (Facebook Ads)
Wymaga zdefiniowania usługi `metaPixel` w `config.js`.

```html
<script type="text/plain" data-type="application/javascript" data-name="metaPixel">
!function(f,b,e,v,n,t,s)
{if(f.fbq)return;n=f.fbq=function(){n.callMethod?
n.callMethod.apply(n,arguments):n.queue.push(arguments)};
if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
n.queue=[];t=b.createElement(e);t.async=!0;
t.src=v;s=b.getElementsByTagName(e)[0];
s.parentNode.insertBefore(t,s)}(window, document,'script',
'https://connect.facebook.net/en_US/fbevents.js');
fbq('init', 'TWOJ_PIXEL_ID');
fbq('track', 'PageView');
</script>
```

### Umami (Twoja własna analityka)
Umami jest prywatne z natury, ale jeśli chcesz dać użytkownikowi wybór.
Wymaga usługi `umami` w `config.js`.

```html
<script 
  type="text/plain" 
  data-type="application/javascript" 
  data-name="umami" 
  src="https://stats.twojadomena.pl/script.js" 
  data-website-id="twoje-id-umami">
</script>
```

### Microsoft Clarity (Heatmapy)
Wymaga usługi `clarity` w `config.js`.

```html
<script type="text/plain" data-type="application/javascript" data-name="clarity">
    (function(c,l,a,r,i,t,y){
        c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};
        t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;
        y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);
    })(window, document, "clarity", "script", "TWOJ_PROJEKT_ID");
</script>
```

### YouTube Embed (Blokowanie filmów)
Możesz blokować filmy na stronie, dopóki użytkownik nie zaakceptuje ciasteczek marketingowych. Zastąp `src` przez `data-src`.

```html
<!-- Film zablokowany -->
<iframe 
  width="560" height="315" 
  data-name="youtube" 
  data-src="https://www.youtube.com/embed/VIDEO_ID" 
  frameborder="0" 
  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
  allowfullscreen>
</iframe>
```

---

## ⚙️ Edycja konfiguracji

Konfiguracja znajduje się na Twoim Mikrusie w pliku:
`/var/www/cookie-hub/public/config.js`

Aby edytować plik lokalnie:
1. Pobierz go: `./local/sync.sh down /var/www/cookie-hub/public/config.js ./config.js`
2. Wyedytuj w VS Code (dodaj nowe usługi do tablicy `services`).
3. Wyślij z powrotem: `./local/sync.sh up ./config.js /var/www/cookie-hub/public/config.js`

## 🇵🇱 Język Polski
System jest w pełni skonfigurowany w języku polskim. Przyciski ("Zaakceptuj wszystko", "Odrzuć"), opisy celów i komunikaty są gotowe do użycia bez żadnych dodatkowych zmian.
