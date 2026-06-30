# Net-Master

Kompleksowe, działające w terminalu narzędzie do diagnostyki połączenia sieciowego, analizy LAN/Wi-Fi oraz profilowania usług webowych. Zostało stworzone z myślą o środowiskach opartych na systemie Debian (m.in. Linux Mint, Ubuntu, Debian). Net-Master oferuje przejrzyste, kaskadowe menu, automatycznie pobiera brakujące zależności i tworzy skrót w systemowym menu aplikacji.

## Główne funkcje

Narzędzie zostało podzielone na trzy główne moduły:

**1. Diagnostyka Lokalna i Wi-Fi**
* **Interfejsy i stan połączeń:** Szybki wgląd w dostępne karty sieciowe, ich status oraz przypisane adresy IP.
* **Skaner sieci lokalnej (LAN):** Wykrywanie wszystkich urządzeń podłączonych do obecnej podsieci wraz z ich adresami IP, MAC oraz nazwami hostów.
* **Skaner Wi-Fi i optymalizacja kanałów:** Analiza zagęszczenia sieci na pasmach 2.4 GHz oraz 5 GHz z rekomendacją najmniej zakłóconego kanału.

**2. Testy Połączenia i Wydajności**
* **Podstawowa diagnostyka:** Zautomatyzowany test bramy domyślnej, serwerów DNS, stabilności połączenia z internetem oraz śledzenie trasy pakietów.
* **Monitor stabilności i Jittera:** Wykonywanie pogłębionych testów opóźnień, wykrywanie skoków pingu (lagów) oraz utraty pakietów, z opcją wymuszenia odnowienia dzierżawy DHCP.
* **Pomiar prędkości:** Test prędkości pobierania i wysyłania danych.

**3. Analiza Zewnętrzna i Webowa**
* **Publiczne IP i Geo-lokalizacja:** Identyfikacja publicznego adresu IP, nazwy dostawcy (ISP) oraz lokalizacji geograficznej.
* **Benchmark serwerów DNS:** Porównanie czasów odpowiedzi najpopularniejszych publicznych serwerów DNS (Google, Cloudflare, Quad9, OpenDNS).
* **Skaner otwartych portów TCP:** Szybka weryfikacja dostępności kluczowych usług (SSH, HTTP, Bazy Danych) na wskazanym serwerze.
* **Profiler zapytań HTTP:** Analiza cyklu życia zapytania (czas rozwiązywania DNS, nawiązywania połączenia TCP, negocjacji TLS oraz TTFB).
* **Weryfikator certyfikatów SSL/TLS:** Sprawdzanie poprawności, wystawcy oraz dokładnej daty wygaśnięcia certyfikatu dla podanej domeny.

## Wymagania

Narzędzie wymaga do rozpoczęcia instalacji jedynie pakietu `curl`. 
Pozostałe zależności (takie jak `iproute2`, `dnsutils`, `network-manager`, `speedtest-cli`, `nmap`, `netcat-openbsd`, `openssl`) zostaną zainstalowane automatycznie podczas pierwszego uruchomienia programu. System poprosi o podanie hasła administratora (sudo) w celu doinstalowania brakujących pakietów.

## Instalacja

Instalacja sprowadza się do wykonania jednego polecenia w terminalu. Skrypt pobierze główny program, umieści go w odpowiednim katalogu użytkownika (`~/.local/bin`) i utworzy systemowy skrót aplikacji.

Uruchom poniższe polecenie w terminalu:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Wojtekadamski/net-master/main/install.sh)"
