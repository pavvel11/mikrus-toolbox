# PicoClaw - Ultra-lekki Asystent AI

Osobisty asystent AI, ktory automatyzuje zadania przez Telegram, Discord lub Slack. Alternatywa dla OpenClaw.

**RAM:** ~64MB | **Obraz:** ~10MB | **Plan:** Mikrus 2.1+ (1GB RAM)

---

## Dlaczego PicoClaw?

- **Ultra-lekki** — binarny plik ~8MB, zuzycie RAM <64MB
- **17k+ gwiazdek** na GitHubie
- **Wiele kanalow** — Telegram, Discord, Slack
- **Wiele dostawcow LLM** — OpenRouter, Anthropic, OpenAI i inne
- **Gateway mode** — bot dziala jako dlugo-zywy proces, bez potrzeby wystawiania portow

---

## Instalacja

```bash
./local/deploy.sh picoclaw --ssh=mikrus --domain-type=local
```

Skrypt przeprowadzi Cie przez:
1. Wybor dostawcy LLM (OpenRouter, Anthropic, OpenAI)
2. Podanie klucza API
3. Wybor kanalu czatu (Telegram, Discord, Slack)
4. Podanie tokenow bota

> **Uwaga:** PicoClaw nie wymaga domeny — bot komunikuje sie wylacznie polaczeniami wychodzacymi. Uzyj `--domain-type=local`.

### Tryb automatyczny

```bash
# 1. Utworz config.json recznie (patrz sekcja Konfiguracja ponizej)
# 2. Skopiuj na serwer
scp config.json mikrus:/opt/stacks/picoclaw/config/config.json

# 3. Zainstaluj automatycznie
./local/deploy.sh picoclaw --ssh=mikrus --domain-type=local --yes
```

---

## Wymagania

| Usluga | Koszt | Do czego | Obowiazkowe |
|--------|-------|----------|-------------|
| **Mikrus 2.1+** | 75 zl/rok | Hosting kontenera | Tak |
| **Klucz API LLM** | Od darmowego | Modele AI | Tak |
| **Bot token** | Darmowe | Kanal komunikacji | Tak |

### Przed instalacja:

1. **Klucz API LLM** — jeden z:
   - [OpenRouter](https://openrouter.ai/keys) (zalecany — dostep do wielu modeli, darmowe modele dostepne)
   - [Anthropic](https://console.anthropic.com/settings/keys)
   - [OpenAI](https://platform.openai.com/api-keys)

2. **Token bota** — jeden z:
   - **Telegram** (zalecany): [@BotFather](https://t.me/BotFather) → `/newbot`
   - **Discord**: [Developer Portal](https://discord.com/developers/applications) → Bot → Token
   - **Slack**: [API Apps](https://api.slack.com/apps) → Bot Token + App Token

---

## Konfiguracja

Plik konfiguracyjny: `/opt/stacks/picoclaw/config/config.json`

### Telegram (zalecany)

```json
{
  "llm": {
    "provider": "openrouter",
    "api_key": "sk-or-v1-...",
    "model": "anthropic/claude-3.5-sonnet"
  },
  "channel": {
    "type": "telegram",
    "bot_token": "123456789:AAH...",
    "allowed_user_ids": [123456789]
  }
}
```

**Jak zdobyc Telegram User ID:** Napisz do [@userinfobot](https://t.me/userinfobot) — odpowie Twoim numerycznym ID.

### Discord

```json
{
  "llm": {
    "provider": "anthropic",
    "api_key": "sk-ant-...",
    "model": "claude-3-5-sonnet-20241022"
  },
  "channel": {
    "type": "discord",
    "bot_token": "MTIz..."
  }
}
```

### Slack

```json
{
  "llm": {
    "provider": "openai",
    "api_key": "sk-...",
    "model": "gpt-4o"
  },
  "channel": {
    "type": "slack",
    "bot_token": "xoxb-...",
    "app_token": "xapp-..."
  }
}
```

---

## Bezpieczenstwo

PicoClaw to agent AI wykonujacy komendy — dlatego instalator stosuje **najostrzejsza izolacje Docker** w calym toolboxie:

| Zabezpieczenie | Co robi |
|---|---|
| **Read-only filesystem** | Kontener nie moze modyfikowac wlasnego systemu plikow |
| **cap_drop: ALL** | Usuniete WSZYSTKIE uprawnienia Linux capabilities |
| **no-new-privileges** | Blokada eskalacji uprawnien |
| **Profil seccomp** | Niestandardowa lista dozwolonych syscalli (tylko to co potrzebne) |
| **Non-root user** | Proces dziala jako UID 1000 |
| **Limity zasobow** | Max 128MB RAM, 1 CPU, 64 procesy |
| **Brak Docker socket** | Kontener NIE ma dostepu do hosta Docker |
| **Izolowana siec** | Oddzielna siec bridge, brak dostepu do innych kontenerow |
| **tmpfs noexec** | Katalog tymczasowy bez prawa wykonywania plikow |
| **allowed_user_ids** | Tylko wskazani uzytkownicy moga wydawac polecenia (Telegram) |

### Dlaczego to wazne?

PicoClaw wykonuje komendy na podstawie instrukcji z czatu. Gdyby ktos zdolal wstrzyknac prompt (prompt injection), zle zabezpieczony kontener moglby:
- Odczytac pliki hosta
- Uruchomic inne kontenery
- Wysylac dane na zewnatrz

Dzieki powyzszym zabezpieczeniom nawet udany atak prompt injection jest ograniczony do izolowanego kontenera bez uprawnien.

---

## Zarzadzanie

```bash
# Status
ssh mikrus 'docker ps | grep picoclaw'

# Logi
ssh mikrus 'docker logs picoclaw --tail 50'

# Logi na zywo
ssh mikrus 'docker logs -f picoclaw'

# Restart
ssh mikrus 'docker restart picoclaw'

# Edycja konfiguracji
ssh mikrus 'nano /opt/stacks/picoclaw/config/config.json'
ssh mikrus 'docker restart picoclaw'  # po edycji

# Zuzycie zasobow
ssh mikrus 'docker stats picoclaw --no-stream'
```

---

## Troubleshooting

### Bot nie odpowiada

1. Sprawdz logi:
   ```bash
   ssh mikrus 'docker logs picoclaw --tail 30'
   ```

2. Sprawdz czy kontener dziala:
   ```bash
   ssh mikrus 'docker ps | grep picoclaw'
   ```

3. Sprawdz config.json — czy token bota i klucz API sa poprawne:
   ```bash
   ssh mikrus 'cat /opt/stacks/picoclaw/config/config.json'
   ```

### Kontener restartuje sie w petli

Najczesciej: bledny klucz API lub token bota.

```bash
ssh mikrus 'docker logs picoclaw --tail 50'
```

Szukaj bledow typu `401 Unauthorized` lub `invalid token`.

### Health check failing

PicoClaw uzywa wewnetrznego health checka na porcie 18790. Jesli kontener jest "unhealthy":

```bash
# Sprawdz status health checka
ssh mikrus 'docker inspect --format="{{.State.Health.Status}}" picoclaw'

# Szczegoly ostatnich checkow
ssh mikrus 'docker inspect --format="{{json .State.Health}}" picoclaw | python3 -m json.tool'
```

### Za malo RAM

PicoClaw potrzebuje minimum 64MB RAM. Limit kontenera to 128MB. Sprawdz zuzycie:

```bash
ssh mikrus 'docker stats picoclaw --no-stream --format "{{.MemUsage}}"'
```

---

## Backup

PicoClaw przechowuje dane w wolumenie `picoclaw-workspace`. Konfiguracja w `/opt/stacks/picoclaw/config/config.json`.

```bash
# Backup konfiguracji
ssh mikrus 'cp /opt/stacks/picoclaw/config/config.json ~/picoclaw-config-backup.json'

# Backup danych workspace
ssh mikrus 'docker run --rm -v picoclaw_picoclaw-workspace:/data -v /tmp:/backup alpine tar czf /backup/picoclaw-workspace.tar.gz -C /data .'
scp mikrus:/tmp/picoclaw-workspace.tar.gz ./
```

---

## Integracja z n8n

PicoClaw mozesz zintegrowac z n8n jako dodatkowy kanal powiadomien:

1. **n8n wysyla zadanie do PicoClaw** — przez Telegram API (wyslij wiadomosc do bota)
2. **PicoClaw wykonuje i raportuje** — bot odpowiada wynikiem na czacie

---

> PicoClaw: https://github.com/sipeed/picoclaw
