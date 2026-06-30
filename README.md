# Net-Master

Kompleksowe, działające w terminalu narzędzie do diagnostyki połączenia sieciowego i analizy Wi-Fi. Zostało stworzone z myślą o środowiskach opartych na systemie Debian (m.in. Linux Mint, Ubuntu, Debian). Net-Master oferuje przejrzyste menu, automatycznie pobiera brakujące zależności i tworzy skrót w systemowym menu aplikacji.

## Główne funkcje

* **Interfejsy i stan połączeń:** Szybki wgląd w dostępne karty sieciowe, ich status oraz przypisane adresy IP.
* **Podstawowa diagnostyka:** Zautomatyzowany test bramy domyślnej (routera), serwerów DNS, stabilności połączenia z internetem (ping) oraz śledzenie trasy (traceroute).
* **Skaner Wi-Fi i optymalizacja kanałów:** Analiza zagęszczenia sieci na pasmach 2.4 GHz oraz 5 GHz. Skrypt oblicza nakładanie się fal i rekomenduje najmniej zakłócony kanał do ustawienia w konfiguracji routera.
* **Pomiar prędkości:** Wbudowany test prędkości pobierania i wysyłania danych.
* **Aktualizacje OTA:** Mechanizm sprawdzania i pobierania nowszych wersji programu bezpośrednio z repozytorium GitHub za pomocą jednej opcji w menu.

## Wymagania

Narzędzie wymaga do rozpoczęcia instalacji jedynie pakietu `curl`. 
Pozostałe zależności (takie jak `iproute2`, `dnsutils`, `network-manager`, `speedtest-cli`) zostaną zainstalowane automatycznie podczas pierwszego uruchomienia programu. System może poprosić o podanie hasła (sudo) w celu instalacji pakietów.

## Instalacja

Instalacja sprowadza się do wykonania jednego polecenia w terminalu. Skrypt pobierze główny program, umieści go w odpowiednim katalogu użytkownika (`~/.local/bin`) i utworzy systemowy skrót aplikacji.

Uruchom poniższe polecenie w terminalu:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Wojtekadamski/net-master/main/install.sh)"
