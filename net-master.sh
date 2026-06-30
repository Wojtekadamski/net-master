#!/bin/bash

# ==========================================
# KONFIGURACJA WERSJI I REPOZYTORIUM
# ==========================================
CURRENT_VERSION="1.0.1"

# ZMIEŃ PONIŻSZE DANE NA SWOJE
GITHUB_USER="Wojtekadamski"
GITHUB_REPO="net-master"
BRANCH="main"

# ==========================================
# KOLORY
# ==========================================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

# ==========================================
# AUTO-INSTALACJA ZALEŻNOŚCI
# ==========================================
check_dependencies() {
    local deps=("ip" "ping" "traceroute" "dig" "curl" "speedtest-cli" "nmcli" "awk")
    local packages_to_install=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            case $dep in
                "ip") packages_to_install+=("iproute2") ;;
                "ping") packages_to_install+=("iputils-ping") ;;
                "dig") packages_to_install+=("dnsutils") ;;
                "nmcli") packages_to_install+=("network-manager") ;;
                *) packages_to_install+=("$dep") ;;
            esac
        fi
    done

    if [ ${#packages_to_install[@]} -ne 0 ]; then
        echo -e "${YELLOW}Brakuje następujących pakietów: ${packages_to_install[*]}${NC}"
        echo -e "Wymagane uprawnienia administratora do instalacji (sudo apt-get install)..."
        sudo apt-get update
        sudo apt-get install -y "${packages_to_install[@]}"
        echo -e "${GREEN}Zależności zainstalowane pomyślnie!${NC}\n"
        sleep 2
    fi
}

# ==========================================
# MODUŁY DIAGNOSTYCZNE
# ==========================================

show_interfaces() {
    clear
    echo -e "${CYAN}=== INTERFEJSY SIECIOWE I STAN POŁĄCZEŃ ===${NC}"
    echo -e "${YELLOW}1. Wykryte urządzenia (NetworkManager):${NC}"
    nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev | awk -F':' '{
        printf "Urządzenie: %-10s | Typ: %-10s | Stan: ", $1, $2
        if ($3 == "connected") printf "\033[1;32mPOŁĄCZONO\033[0m z %s\n", $4
        else printf "\033[1;31mROZŁĄCZONO\033[0m\n"
    }'
    
    echo -e "\n${YELLOW}2. Adresy IP interfejsów:${NC}"
    ip -brief address show | awk '{printf "%-15s %-15s %s\n", $1, $2, $3}'
    
    echo -e "\nWciśnij [Enter], aby wrócić..."
    read -r
}

basic_diag() {
    clear
    echo -e "${CYAN}=== PODSTAWOWA DIAGNOSTYKA POŁĄCZENIA ===${NC}"
    
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
    if [ -n "$GATEWAY" ]; then
        echo -e "[+] Brama domyślna (Router): ${GREEN}$GATEWAY${NC}"
        echo -n "    Testowanie routera (Ping)... "
        if ping -c 3 -W 2 "$GATEWAY" > /dev/null 2>&1; then
            echo -e "${GREEN}Sukces${NC}"
        else
            echo -e "${RED}Brak odpowiedzi${NC}"
        fi
    else
        echo -e "[-] ${RED}Brak bramy domyślnej! Problem z DHCP lub konfiguracją interfejsu.${NC}"
    fi

    echo -e "\n[+] Testowanie serwerów DNS (rozwiązywanie nazwy google.com)..."
    DNS_TIME=$(dig google.com | grep "Query time" | awk '{print $4" "$5}')
    if [ -n "$DNS_TIME" ]; then
        echo -e "    ${GREEN}DNS działa poprawnie${NC} (Czas odpowiedzi: $DNS_TIME)"
    else
        echo -e "    ${RED}Błąd DNS! Nie można przetłumaczyć nazwy na adres IP.${NC}"
    fi

    echo -e "\n[+] Test dostępu do Internetu (Ping do 8.8.8.8)..."
    PING_OUT=$(ping -c 4 -W 2 8.8.8.8 2>&1)
    LOSS=$(echo "$PING_OUT" | grep -oP '\d+(?=% packet loss)')
    if [ "$LOSS" == "0" ]; then
        echo -e "    ${GREEN}0% utraty pakietów. Internet działa.${NC}"
    elif [ -z "$LOSS" ]; then
        echo -e "    ${RED}Brak dostępu do internetu (Host nieosiągalny).${NC}"
    else
        echo -e "    ${YELLOW}Wykryto $LOSS% utraty pakietów! Łącze jest niestabilne.${NC}"
    fi

    echo -e "\n[+] Szybkie śledzenie trasy do 8.8.8.8 (pierwsze 5 skoków):"
    traceroute -4 -m 5 8.8.8.8 2>/dev/null | awk 'NR>1 {print "    Skok " $1 ": " $2 " " $3 " " $4 " " $5}'

    echo -e "\nWciśnij [Enter], aby wrócić..."
    read -r
}

wifi_diag() {
    clear
    echo -e "${CYAN}=== SKANER WI-FI I OPTYMALIZACJA KANAŁÓW ===${NC}"
    echo "Wymuszanie skanowania eteru (może zająć kilka sekund)..."
    nmcli dev wifi rescan >/dev/null 2>&1
    sleep 3
    
    TEMP_SCAN="/tmp/wifi_scan_cli.txt"
    
    # POPRAWKA 1: Nowa kolejność (FREQ, CHAN, SIGNAL, SSID). Brak adresu BSSID psującego kolumny.
    nmcli -t -f FREQ,CHAN,SIGNAL,SSID dev wifi list > "$TEMP_SCAN"

    if [ ! -s "$TEMP_SCAN" ]; then
        echo -e "${RED}Błąd: Nie wykryto sieci Wi-Fi. Upewnij się, że masz włączoną kartę bezprzewodową.${NC}"
        rm -f "$TEMP_SCAN"
        echo -en "\nWciśnij [Enter], aby wrócić..."
        read -r
        return
    fi

    echo -e "\n${YELLOW}--- SIECI 2.4 GHz ---${NC}"
    # POPRAWKA 2: Nowe indeksowanie w AWK, uwzględniające SSIDs z dwukropkami
    awk -F':' '$1 < 3000 {
        ssid=$4; for(i=5;i<=NF;i++) ssid=ssid":"$i; 
        printf "Kanał: %-3s | Moc: %-3s%% | Sieć: %s\n", $2, $3, ssid
    }' "$TEMP_SCAN" | sort -k2 -nr | head -n 10
    
    echo -e "\n${YELLOW}--- SIECI 5 GHz ---${NC}"
    awk -F':' '$1 > 5000 {
        ssid=$4; for(i=5;i<=NF;i++) ssid=ssid":"$i; 
        printf "Kanał: %-4s | Moc: %-3s%% | Sieć: %s\n", $2, $3, ssid
    }' "$TEMP_SCAN" | sort -k2 -nr | head -n 10

    echo -e "\n${CYAN}--- REKOMENDACJE ---${NC}"
    
    C1=$(awk -F':' '$1 < 3000 && ($2>=1 && $2<=3) {count++} END {print count+0}' "$TEMP_SCAN")
    C6=$(awk -F':' '$1 < 3000 && ($2>=4 && $2<=8) {count++} END {print count+0}' "$TEMP_SCAN")
    C11=$(awk -F':' '$1 < 3000 && ($2>=9 && $2<=14) {count++} END {print count+0}' "$TEMP_SCAN")

    MIN_C="1"
    MIN_VAL=$C1
    if [ "$C6" -lt "$MIN_VAL" ]; then MIN_VAL=$C6; MIN_C="6"; fi
    if [ "$C11" -lt "$MIN_VAL" ]; then MIN_C="11"; fi

    echo -e "Rekomendowany kanał dla ${YELLOW}2.4 GHz${NC}: ${GREEN}Kanał $MIN_C${NC} (najmniejsze zagęszczenie w tej strefie)."
    
    # POPRAWKA 3: Zmiana 'echo -n' na 'echo -ne', aby kolory (ANSI escapes) renderowały się poprawnie
    echo -ne "Zajęte kanały ${YELLOW}5 GHz${NC} w okolicy: "
    awk -F':' '$1 > 5000 {print $2}' "$TEMP_SCAN" | sort -nu | xargs | sed 's/ /, /g' | awk '{print "\033[1;31m" $0 "\033[0m"}'
    echo -e "Rekomendacja dla 5 GHz: Wybierz w routerze dowolny kanał, którego ${RED}NIE MA${NC} na liście powyżej (np. z zakresu DFS 52-140)."

    rm -f "$TEMP_SCAN"
    echo -en "\nWciśnij [Enter], aby wrócić..."
    read -r
}

speed_test() {
    clear
    echo -e "${CYAN}=== POMIAR PRĘDKOŚCI ŁĄCZA ===${NC}"
    echo "Trwa łączenie z serwerami (to potrwa kilkadziesiąt sekund)..."
    speedtest-cli --simple
    echo -e "\nWciśnij [Enter], aby wrócić..."
    read -r
}

check_update() {
    clear
    echo -e "${CYAN}=== AKTUALIZACJA PROGRAMU ===${NC}"
    echo -e "Obecna wersja programu: ${YELLOW}$CURRENT_VERSION${NC}"
    echo "Sprawdzanie najnowszej wersji w repozytorium GitHub..."
    
    # -m 3 oznacza timeout 3 sekundy. Nie zawieszamy programu, jeśli nie ma neta!
    RAW_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/net-master.sh"
    REMOTE_SCRIPT=$(curl -fsSL -m 3 "$RAW_URL" 2>/dev/null)
    
    if [ -z "$REMOTE_SCRIPT" ]; then
        echo -e "${RED}Błąd: Nie można połączyć się z serwerem aktualizacji. Sprawdź połączenie.${NC}"
        echo -e "\nWciśnij [Enter], aby wrócić..."
        read -r
        return
    fi

    # Ekstrakcja wersji z pobranego kodu
    REMOTE_VERSION=$(echo "$REMOTE_SCRIPT" | grep -oP '^CURRENT_VERSION="\K[^"]+')

    if [ -z "$REMOTE_VERSION" ]; then
         echo -e "${RED}Błąd: Nie udało się zweryfikować wersji na serwerze.${NC}"
         sleep 2
         return
    fi

    if [ "$CURRENT_VERSION" != "$REMOTE_VERSION" ]; then
        echo -e "${GREEN}Znaleziono nową wersję!${NC}"
        echo -e "Nowa wersja do pobrania: ${GREEN}$REMOTE_VERSION${NC}\n"

        CHANGELOG_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/changelog.txt"
        CHANGELOG=$(curl -fsSL -m 3 "$CHANGELOG_URL" 2>/dev/null)
        
        if [ -n "$CHANGELOG" ]; then
            echo -e "${CYAN}--- CO NOWEGO? (CHANGELOG) ---${NC}"
            echo -e "$CHANGELOG"
            echo -e "${CYAN}------------------------------${NC}\n"
        fi

        read -r -p "Czy chcesz zainstalować aktualizację teraz? [T/n]: " update_choice
        if [[ "$update_choice" =~ ^[TtYy]$ ]] || [[ -z "$update_choice" ]]; then
            echo "Instalowanie..."
            
            # Bezpieczne nadpisanie aktualnie uruchomionego pliku
            tmp_file=$(mktemp)
            echo "$REMOTE_SCRIPT" > "$tmp_file"
            cat "$tmp_file" > "$0"
            rm -f "$tmp_file"
            chmod +x "$0"
            
            echo -e "${GREEN}Zaktualizowano pomyślnie! Uruchamiam ponownie...${NC}"
            sleep 2
            exec "$0" "$@" # Gorący restart skryptu
        else
            echo "Anulowano aktualizację."
            sleep 1
        fi
    else
        echo -e "${GREEN}Posiadasz najnowszą dostępną wersję programu.${NC}"
        echo -e "\nWciśnij [Enter], aby wrócić..."
        read -r
    fi
}

# ==========================================
# GŁÓWNA PĘTLA PROGRAMU (MENU)
# ==========================================

check_dependencies

while true; do
    clear
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${CYAN}     NET-MASTER - DIAGNOSTYKA SIECI (v$CURRENT_VERSION)    ${NC}"
    echo -e "${BLUE}==============================================${NC}"
    echo "1. Pokaż interfejsy sieciowe i stan połączenia"
    echo "2. Pełna diagnostyka (DHCP, Brama, DNS, Traceroute)"
    echo "3. Skaner Wi-Fi i optymalizacja kanałów"
    echo "4. Pomiar prędkości łącza (Speedtest)"
    echo "5. Sprawdź aktualizacje (Update)"
    echo "0. Zakończ program"
    echo -e "${BLUE}==============================================${NC}"
    
    read -r -p "Wybierz opcję [0-5]: " choice
    
    case $choice in
        1) show_interfaces ;;
        2) basic_diag ;;
        3) wifi_diag ;;
        4) speed_test ;;
        5) check_update ;;
        0) echo "Zakończono."; exit 0 ;;
        *) echo -e "${RED}Nieprawidłowy wybór!${NC}"; sleep 1 ;;
    esac
done
