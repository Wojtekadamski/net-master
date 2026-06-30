#!/bin/bash

# ==========================================
# KONFIGURACJA WERSJI I REPOZYTORIUM
# ==========================================
CURRENT_VERSION="1.1.0"

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
    # Dodano 'nc' (netcat) do sprawdzania portów
    local deps=("ip" "ping" "traceroute" "dig" "curl" "speedtest-cli" "nmcli" "awk" "nmap" "nc")
    local packages_to_install=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            case $dep in
                "ip") packages_to_install+=("iproute2") ;;
                "ping") packages_to_install+=("iputils-ping") ;;
                "dig") packages_to_install+=("dnsutils") ;;
                "nmcli") packages_to_install+=("network-manager") ;;
                "nc") packages_to_install+=("netcat-openbsd") ;;
                *) packages_to_install+=("$dep") ;;
            esac
        fi
    done

    if [ ${#packages_to_install[@]} -ne 0 ]; then
        echo -e "${YELLOW}Brakuje pakietów: ${packages_to_install[*]}${NC}"
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
    
    echo -en "\nWciśnij [Enter], aby wrócić..."
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

    echo -en "\nWciśnij [Enter], aby wrócić..."
    read -r
}

wifi_diag() {
    clear
    echo -e "${CYAN}=== SKANER WI-FI I OPTYMALIZACJA KANAŁÓW ===${NC}"
    echo "Wymuszanie skanowania eteru (może zająć kilka sekund)..."
    nmcli dev wifi rescan >/dev/null 2>&1
    sleep 3
    
    TEMP_SCAN="/tmp/wifi_scan_cli.txt"
    nmcli -t -f FREQ,CHAN,SIGNAL,SSID dev wifi list > "$TEMP_SCAN"

    if [ ! -s "$TEMP_SCAN" ]; then
        echo -e "${RED}Błąd: Nie wykryto sieci Wi-Fi. Upewnij się, że masz włączoną kartę bezprzewodową.${NC}"
        rm -f "$TEMP_SCAN"
        echo -en "\nWciśnij [Enter], aby wrócić..."
        read -r
        return
    fi

    echo -e "\n${YELLOW}--- SIECI 2.4 GHz ---${NC}"
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
    
    echo -ne "Zajęte kanały ${YELLOW}5 GHz${NC} w okolicy: "
    awk -F':' '$1 > 5000 {print $2}' "$TEMP_SCAN" | sort -nu | xargs | sed 's/ /, /g' | awk '{print "\033[1;31m" $0 "\033[0m"}'
    echo -e "Rekomendacja dla 5 GHz: Wybierz w routerze dowolny kanał, którego ${RED}NIE MA${NC} na liście powyżej."

    rm -f "$TEMP_SCAN"
    echo -en "\nWciśnij [Enter], aby wrócić..."
    read -r
}

lan_scan() {
    clear
    echo -e "${CYAN}=== SKANER SIECI LOKALNEJ (LAN) ===${NC}"
    SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n 1)
    
    if [ -z "$SUBNET" ]; then
        echo -e "${RED}Błąd: Nie wykryto aktywnego połączenia sieciowego z adresem IPv4.${NC}"
    else
        echo -e "Wykryta podsieć: ${YELLOW}$SUBNET${NC}"
        echo "Skanowanie urządzeń podłączonych do Twojego routera (to potrwa kilka sekund)..."
        
        nmap -T4 -sn "$SUBNET" > /dev/null 2>&1
        
        echo -e "\n${CYAN}IP ADDRESS${NC}      | ${CYAN}MAC ADDRESS${NC}       | ${CYAN}HOSTNAME (Nazwa urządzenia)${NC}"
        echo "------------------------------------------------------------------------"
        
        ip neigh show | grep "lladdr" | awk '{print $1, $5}' | sort -t . -k 4,4n | while read -r IP MAC; do
            HOSTNAME=$(dig +short -x "$IP" 2>/dev/null | sed 's/\.$//')
            if [ -z "$HOSTNAME" ]; then HOSTNAME="[Nieznany / Brak nazwy]"; fi
            printf "\033[1;32m%-15s\033[0m | %-17s | %s\n" "$IP" "$MAC" "$HOSTNAME"
        done
        
        MY_IP=$(ip -o -4 addr list | awk '/scope global/ {print $4}' | cut -d/ -f1 | head -n 1)
        MY_MAC=$(ip link show | grep ether | awk '{print $2}' | head -n 1)
        printf "\033[1;34m%-15s\033[0m | %-17s | [Twój Komputer]\n" "$MY_IP" "${MY_MAC:-N/A}"
    fi
    echo -en "\nWciśnij [Enter], aby wrócić..."
    read -r
}

http_profiler() {
    clear
    echo -e "${CYAN}=== PROFILER ZAPYTAŃ HTTP (TTFB) ===${NC}"
    read -r -p "Podaj adres URL lub domenę (np. google.com): " TARGET_URL
    
    if [ -z "$TARGET_URL" ]; then TARGET_URL="https://google.com"; fi
    if [[ ! "$TARGET_URL" =~ ^https?:// ]]; then TARGET_URL="https://$TARGET_URL"; fi
    
    echo -e "\nNawiązywanie połączenia z: ${YELLOW}$TARGET_URL${NC}...\n"
    
    FORMAT="%{time_namelookup}\n%{time_connect}\n%{time_appconnect}\n%{time_pretransfer}\n%{time_starttransfer}\n%{time_total}\n%{http_code}"
    RESULT=$(curl -o /dev/null -s -w "$FORMAT" "$TARGET_URL")
    
    if [ -z "$RESULT" ]; then
        echo -e "${RED}Błąd połączenia. Upewnij się, że adres jest poprawny.${NC}"
    else
        mapfile -t METRICS <<< "$RESULT"
        DNS=$(echo "${METRICS[0]}" | awk '{printf "%.0f", $1 * 1000}')
        TCP=$(echo "${METRICS[0]} ${METRICS[1]}" | awk '{printf "%.0f", ($2 - $1) * 1000}')
        TLS=$(echo "${METRICS[1]} ${METRICS[2]}" | awk '{printf "%.0f", ($2 - $1) * 1000}')
        TTFB=$(echo "${METRICS[3]} ${METRICS[4]}" | awk '{printf "%.0f", ($2 - $1) * 1000}')
        TOTAL=$(echo "${METRICS[5]}" | awk '{printf "%.0f", $1 * 1000}')
        CODE=${METRICS[6]}
        
        if [ "$CODE" == "000" ]; then
             echo -e "${RED}[-] Host nieosiągalny, zablokowany lub odrzucił połączenie.${NC}"
        else
            echo -e "Kod odpowiedzi HTTP: \033[1;32m$CODE\033[0m\n"
            echo -e "Czas rozwiązywania DNS (DNS Lookup):   ${CYAN}${DNS} ms${NC}"
            echo -e "Handshake TCP (Połączenie bazowe):     ${CYAN}${TCP} ms${NC}"
            if [[ "$TARGET_URL" == https* ]] && [ "$TLS" -gt 0 ]; then
                echo -e "Negocjacja TLS (Certyfikat SSL):       ${CYAN}${TLS} ms${NC}"
            fi
            echo -e "Czas do pierwszego bajtu (TTFB):       ${YELLOW}${TTFB} ms${NC}"
            echo -e "================================================="
            echo -e "Całkowity czas odpowiedzi:             ${GREEN}${TOTAL} ms${NC}"
        fi
    fi
    echo -en "\nWciśnij [Enter], aby wrócić..."
    read -r
}

port_scanner() {
    clear
    echo -e "${CYAN}=== SKANER PORTÓW TCP ===${NC}"
    read -r -p "Podaj adres IP lub domenę serwera do skanowania (domyślnie localhost): " TARGET
    TARGET=${TARGET:-127.0.0.1}
    
    echo -e "\nSkanowanie najpopularniejszych portów na hoście: ${YELLOW}$TARGET${NC}...\n"
    
    # Lista popularnych portów (FTP, SSH, SMTP, DNS, HTTP, POP3, IMAP, HTTPS, MySQL, RDP, HTTP-ALT)
    PORTS=(21 22 25 53 80 110 143 443 3306 3389 8080)
    
    printf "${CYAN}%-6s | %-15s | %s${NC}\n" "PORT" "USŁUGA (Typ)" "STATUS"
    echo "----------------------------------------------------"
    
    for PORT in "${PORTS[@]}"; do
        # Opcja -z to tryb skanowania, -w 1 to timeout 1 sekunda
        if nc -z -w 1 "$TARGET" "$PORT" 2>/dev/null; then
            # Próba odczytania nazwy usługi z /etc/services
            SERVICE=$(awk -v p="$PORT/tcp" '$2 == p {print $1; exit}' /etc/services)
            SERVICE=${SERVICE:-Nieznana}
            printf "\033[1;32m%-6s\033[0m | %-15s | \033[1;32m[+] OTWARTY\033[0m\n" "$PORT" "$SERVICE"
        else
            SERVICE=$(awk -v p="$PORT/tcp" '$2 == p {print $1; exit}' /etc/services)
            SERVICE=${SERVICE:-Nieznana}
            printf "\033[1;31m%-6s\033[0m | %-15s | \033[1;31m[-] ZAMKNIĘTY\033[0m\n" "$PORT" "$SERVICE"
        fi
    done
    
    echo -en "\nWciśnij [Enter], aby wrócić..."
    read -r
}

stability_monitor() {
    clear
    echo -e "${CYAN}=== MONITOR STABILNOŚCI I JITTERA ===${NC}"
    echo "Narzędzie wysyła 20 pakietów kontrolnych, aby sprawdzić "
    echo "mikro-przerwy i wahania pingów (Jitter) psujące jakość połączenia."
    echo ""
    
    TARGET="8.8.8.8"
    echo -e "Testowanie połączenia z ${YELLOW}$TARGET${NC}...\n"
    
    # Wysyłamy 20 pakietów w odstępach 0.5s dla szybszego wyniku
    PING_OUT=$(ping -c 20 -i 0.5 -q "$TARGET" 2>&1)
    
    LOSS=$(echo "$PING_OUT" | grep -oP '\d+(?=% packet loss)')
    STATS=$(echo "$PING_OUT" | grep -oP 'rtt min/avg/max/mdev = \K.*' | tr '/' ' ')
    
    if [ -n "$STATS" ]; then
        read -r MIN AVG MAX MDEV <<< "$STATS"
        echo -e "Wysłano pakietów:       ${CYAN}20${NC}"
        
        if [ "$LOSS" -eq 0 ]; then
            echo -e "Utrata pakietów:        ${GREEN}0%${NC}"
        else
            echo -e "Utrata pakietów:        ${RED}${LOSS}%${NC}"
        fi
        
        echo -e "Minimalne opóźnienie:   ${CYAN}${MIN} ms${NC}"
        echo -e "Średnie opóźnienie:     ${CYAN}${AVG} ms${NC}"
        echo -e "Maksymalne opóźnienie:  ${YELLOW}${MAX} ms${NC}"
        echo -e "Jitter (Odchylenie):    ${YELLOW}${MDEV} ms${NC}\n"
        
        echo -e "${CYAN}--- WERDYKT ---${NC}"
        
        # Logika werdyktu - sprawdzamy Jitter > 10ms
        IS_HIGH_JITTER=$(awk -v m="$MDEV" 'BEGIN{if(m>10.0) print 1; else print 0}')
        
        if [ "$LOSS" -gt 0 ]; then
            echo -e "${RED}[!] Wykryto utratę pakietów.${NC} Łącze gubi dane. Możliwy problem z sygnałem Wi-Fi lub po stronie operatora."
        elif [ "$IS_HIGH_JITTER" -eq 1 ]; then
            echo -e "${YELLOW}[!] Wysoki Jitter ($MDEV ms).${NC} Opóźnienia 'skaczą'. Będziesz odczuwać lagi w grach i ścinanie obrazu na spotkaniach."
        else
            echo -e "${GREEN}[+] Połączenie jest wzorowe.${NC} Brak utraty pakietów, niski jitter. Sieć działa stabilnie."
        fi
    else
        echo -e "${RED}Błąd: Nie można ukończyć testu. Brak połączenia z internetem.${NC}"
    fi
    
    echo -e "\n${YELLOW}--- OPCJE NAPRAWCZE ---${NC}"
    read -r -p "Czy chcesz zresetować interfejs sieciowy i wymusić nowe IP (DHCP Renew)? [t/N]: " RESTART_CHOICE
    if [[ "$RESTART_CHOICE" =~ ^[TtYy]$ ]]; then
        echo -e "\n${CYAN}Wymagane uprawnienia administratora do restartu usługi NetworkManager...${NC}"
        if sudo systemctl restart NetworkManager; then
            echo -e "${GREEN}Zresetowano kartę sieciową.${NC} Poczekaj kilka sekund na ponowne nawiązanie połączenia."
        else
            echo -e "${RED}Nie udało się zresetować sieci.${NC}"
        fi
    fi
    
    echo -en "\nWciśnij [Enter], aby wrócić..."
    read -r
}

speed_test() {
    clear
    echo -e "${CYAN}=== POMIAR PRĘDKOŚCI ŁĄCZA ===${NC}"
    echo "Trwa łączenie z serwerami (to potrwa kilkadziesiąt sekund)..."
    speedtest-cli --simple
    echo -en "\nWciśnij [Enter], aby wrócić..."
    read -r
}

check_update() {
    clear
    echo -e "${CYAN}=== AKTUALIZACJA PROGRAMU ===${NC}"
    echo -e "Obecna wersja programu: ${YELLOW}$CURRENT_VERSION${NC}"
    echo "Sprawdzanie najnowszej wersji w repozytorium GitHub..."
    
    RAW_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/net-master.sh"
    REMOTE_SCRIPT=$(curl -fsSL -m 3 "$RAW_URL" 2>/dev/null)
    
    if [ -z "$REMOTE_SCRIPT" ]; then
        echo -e "${RED}Błąd: Nie można połączyć się z serwerem aktualizacji. Sprawdź połączenie.${NC}"
        echo -en "\nWciśnij [Enter], aby wrócić..."
        read -r
        return
    fi

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
            
            tmp_file=$(mktemp)
            echo "$REMOTE_SCRIPT" > "$tmp_file"
            cat "$tmp_file" > "$0"
            rm -f "$tmp_file"
            chmod +x "$0"
            
            echo -e "${GREEN}Zaktualizowano pomyślnie! Uruchamiam ponownie...${NC}"
            sleep 2
            exec "$0" "$@"
        else
            echo "Anulowano aktualizację."
            sleep 1
        fi
    else
        echo -e "${GREEN}Posiadasz najnowszą dostępną wersję programu.${NC}"
        echo -en "\nWciśnij [Enter], aby wrócić..."
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
    echo "2. Pełna diagnostyka (Brama, DNS, Traceroute)"
    echo "3. Skaner Wi-Fi i optymalizacja kanałów"
    echo "4. Skaner LAN (Kto jest w mojej sieci?)"
    echo "5. Profiler zapytań HTTP (Czas ładowania)"
    echo "6. Skaner Otwartych Portów TCP"
    echo "7. Monitor Stabilności i Jittera (+ Reset DHCP)"
    echo "8. Pomiar prędkości łącza (Speedtest)"
    echo "9. Sprawdź aktualizacje (Update)"
    echo "0. Zakończ program"
    echo -e "${BLUE}==============================================${NC}"
    
    read -r -p "Wybierz opcję [0-9]: " choice
    
    case $choice in
        1) show_interfaces ;;
        2) basic_diag ;;
        3) wifi_diag ;;
        4) lan_scan ;;
        5) http_profiler ;;
        6) port_scanner ;;
        7) stability_monitor ;;
        8) speed_test ;;
        9) check_update ;;
        0) echo "Zakończono."; exit 0 ;;
        *) echo -e "${RED}Nieprawidłowy wybór!${NC}"; sleep 1 ;;
    esac
done