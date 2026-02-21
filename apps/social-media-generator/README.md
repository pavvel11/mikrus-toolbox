# Social Media Generator - Grafiki social media z szablonów HTML

Generuj pixel-perfect grafiki na Instagram, Stories i YouTube z szablonów HTML/CSS. Jeden tekst → wiele formatów, spójny branding.

## Instalacja

```bash
./local/deploy.sh social-media-generator --ssh=mikrus --domain-type=cytrus --domain=auto
```

## Wymagania

- **RAM:** minimum 2GB (Mikrus 3.0+), ~512MB-1GB zużycia w runtime
- **Dysk:** ~1GB (obraz Docker z Chromium + Python + deps) + ~200MB PostgreSQL
- **Baza danych:** PostgreSQL 16 (bundled, instalowany automatycznie)

**Social Media Generator NIE zadziała na Mikrus 2.1 (1GB RAM)!** Headless Chromium potrzebuje ~1GB RAM. Install.sh blokuje instalację przy <1800MB RAM.

## Po instalacji

Panel webowy i API dostępne od razu:
- **Panel:** `https://domena` — logowanie przez magic link (email)
- **API docs:** `https://domena/docs` — Swagger/OpenAPI
- **Health:** `https://domena/health`

### Pierwsze kroki

1. Skonfiguruj SMTP w `/opt/stacks/social-media-generator/.env` (magic link wymaga maila)
2. Otwórz panel i zarejestruj konto — pierwszy użytkownik = admin
3. Dodaj własne brandy w `repo/brands/` (CSS custom properties)

## Formaty wyjściowe

| Format | Rozdzielczość | Użycie |
|--------|---------------|--------|
| **Post** | 1080×1080 | Instagram, Facebook, LinkedIn |
| **Story** | 1080×1920 | Instagram Stories, TikTok |
| **YouTube** | 1280×720 | Miniatury YouTube |

## Zmienne środowiskowe

| Zmienna | Domyślna | Opis |
|---------|----------|------|
| `SECRET_KEY` | (generowany) | Klucz sesji — install.sh generuje automatycznie |
| `DATABASE_URL` | (bundled) | PostgreSQL connection string |
| `BASE_URL` | `http://localhost:8000` | Publiczny URL (ustawiany przez install.sh) |
| `SMTP_HOST` | (puste) | Serwer SMTP dla magic link auth |
| `SMTP_PORT` | 587 | Port SMTP |
| `SMTP_USER` | (puste) | Użytkownik SMTP |
| `SMTP_PASS` | (puste) | Hasło SMTP |
| `EMAIL_FROM` | (puste) | Adres nadawcy |
| `CREDIT_PRODUCTS` | JSON | Mapowanie produktów na kredyty |

## Szablony

4 wbudowane szablony:
- **quote-card** — cytaty z tłem
- **tip-card** — porady/tipy
- **announcement** — ogłoszenia
- **ad-card** — reklamy

Własne szablony: dodaj HTML/CSS do `repo/templates/`.

## Brandy

Branding przez CSS custom properties (`--brand-accent`, `--brand-font`, itp.). Dodaj katalog z plikiem CSS w `repo/brands/`.

## Użycie

### CLI (na serwerze)

```bash
docker exec -it social-media-generator-app-1 \
  python generate.py --brand example --template quote-card --text "Twój tekst"
```

### API

```bash
curl -X POST https://twoja-domena/api/generate \
  -H "Content-Type: application/json" \
  -d '{"brand": "example", "template": "quote-card", "text": "Twój tekst"}'
```

### Z n8n

Social Media Generator integruje się z n8n do automatycznego generowania grafik:
1. HTTP Request node → POST do API
2. Odbierz wygenerowane obrazy (base64/URL)
3. Opublikuj przez Postiz lub wyślij mailem

## Stack

```
app (build: Dockerfile)  →  FastAPI + Playwright/Chromium + Jinja2
db  (postgres:16-alpine) →  Baza danych użytkowników i kredytów
```

## Backup

```bash
# Backup bazy danych
ssh mikrus 'cd /opt/stacks/social-media-generator && docker compose exec db pg_dump -U smg smg > backup.sql'

# Backup custom brandów i szablonów
ssh mikrus 'tar czf /tmp/smg-custom.tar.gz /opt/stacks/social-media-generator/repo/brands/ /opt/stacks/social-media-generator/repo/templates/'
```

## Ograniczenia

- **Wolny build** — pierwsze `docker compose build` trwa 3-5 minut (Playwright + Chromium)
- **RAM na Mikrus** — Na 2GB VPS limit kontenera to 1024MB, wystarczy na normalne użycie
- **Magic link wymaga SMTP** — Bez konfiguracji maila linki logowania wyświetlają się w konsoli (tryb dev)
