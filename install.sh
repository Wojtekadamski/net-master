#!/bin/bash

# ==========================================
# KONFIGURACJA INSTALATORA
# ==========================================
# ZMIEŃ NA SWÓJ LOGIN I NAZWĘ REPOZYTORIUM
GITHUB_USER="Wojtekadamski"
GITHUB_REPO="net-master"
BRANCH="main"

RAW_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/net-master.sh"

BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
BIN_PATH="$BIN_DIR/net-master"
DESKTOP_PATH="$APP_DIR/net-master.desktop"

echo -e "\033[1;36mRozpoczynam instalację Net-Master...\033[0m"

# 1. Przygotowanie katalogów
mkdir -p "$BIN_DIR"
mkdir -p "$APP_DIR"

# 2. Pobieranie głównego skryptu
echo "Pobieranie skryptu z GitHuba..."
if curl -fsSL "$RAW_URL" -o "$BIN_PATH"; then
    chmod +x "$BIN_PATH"
    echo -e "\033[1;32m[+] Skrypt pobrany i zainstalowany w $BIN_PATH\033[0m"
else
    echo -e "\033[1;31m[-] Błąd pobierania skryptu. Sprawdź URL lub połączenie sieciowe.\033[0m"
    exit 1
fi

# 3. Tworzenie skrótu w menu systemowym (.desktop)
echo "Tworzenie skrótu w menu aplikacji..."
cat << EOF > "$DESKTOP_PATH"
[Desktop Entry]
Version=1.0
Type=Application
Name=Net-Master Diagnostyka
Comment=Kompleksowe narzędzie do analizy sieci (CLI)
Exec=$BIN_PATH
Icon=network-transmit-receive
Terminal=true
Categories=Network;Utility;
EOF

chmod +x "$DESKTOP_PATH"
echo -e "\033[1;32m[+] Skrót utworzony w $DESKTOP_PATH\033[0m"

# 4. Sprawdzenie zmiennej PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "\033[1;33m[!] UWAGA: Katalog $BIN_DIR nie jest w Twojej zmiennej PATH.\033[0m"
    echo "Aby móc odpalać program wpisując po prostu 'net-master' w terminalu,"
    echo "dodaj: export PATH=\"\$HOME/.local/bin:\$PATH\" do swojego pliku .bashrc lub .zshrc."
fi

echo -e "\n\033[1;32mInstalacja zakończona sukcesem!\033[0m"
echo "Możesz teraz uruchomić program wpisując 'net-master' w terminalu lub znajdując go w menu aplikacji."
