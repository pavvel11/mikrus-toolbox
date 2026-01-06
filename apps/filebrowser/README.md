# 📂 FileBrowser - Twój prywatny dysk i hosting

Lekki menadżer plików przez przeglądarkę. Zarządzaj plikami na serwerze jak w Google Drive.

## 🚀 Instalacja

```bash
./local/deploy.sh filebrowser
```

## 💡 Funkcje "Tiiny.host Killer"
Podczas instalacji możesz podać **dwie domeny**:
1. **Admin Domain (`files.twojadomena.pl`):** Tu się logujesz, zarządzasz plikami, tworzysz foldery. To jest bezpieczne i wymaga hasła.
2. **Public Domain (`static.twojadomena.pl`):** Wszystko, co wrzucisz do głównego folderu w FileBrowserze, będzie publicznie dostępne pod tym adresem.

## 🔗 Jak błyskawicznie pobrać link do pliku? (Workflow)
1. Zaloguj się do panelu admina (`files.twojadomena.pl`) i wrzuć plik, np. `oferta.pdf`.
2. Otwórz w nowej karcie swoją domenę publiczną (`static.twojadomena.pl`).
3. Zobaczysz tam listę swoich plików. Kliknij prawym przyciskiem na plik i wybierz **"Kopiuj adres linku"**.
4. To wszystko! Masz link, który możesz wysłać klientowi.

## 🛠️ Edycja kodu
FileBrowser ma wbudowany edytor tekstowy. Możesz poprawić plik `index.html` lub `config.js` (dla Cookie Hub) prosto z przeglądarki, nawet z telefonu.

## ⚠️ Uwaga o prywatności
Domyślnie na domenie publicznej włączona jest "lista plików" (każdy może zobaczyć nazwy Twoich plików). Jeśli chcesz to wyłączyć (żeby plik był dostępny tylko dla kogoś, kto zna dokładny link), wyedytuj Caddyfile i usuń słowo `browse`.