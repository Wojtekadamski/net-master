# ==========================================
# NET-MASTER WINDOWS EDITION
# ==========================================
$CURRENT_VERSION = "1.0.0" # Startujemy od 1.0.0 dla wersji Windows
$GITHUB_USER = "Wojtekadamski"
$GITHUB_REPO = "net-master"
$BRANCH = "main"

# ==========================================
# FUNKCJE POMOCNICZE
# ==========================================
function Pause-Script {
    Write-Host "`nWciśnij [Enter], aby wrócić..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Check-Admin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ==========================================
# [1] DIAGNOSTYKA LOKALNA
# ==========================================
function Show-Interfaces {
    Clear-Host
    Write-Host "=== INTERFEJSY SIECIOWE I STAN POŁĄCZEŃ ===" -ForegroundColor Cyan
    Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object Name, InterfaceDescription, LinkSpeed | Format-Table -AutoSize
    Write-Host "`nAdresy IP:" -ForegroundColor Yellow
    Get-NetIPAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -notmatch "Loopback" | Select-Object InterfaceAlias, IPAddress | Format-Table -AutoSize
    Pause-Script
}

function Scan-Lan {
    Clear-Host
    Write-Host "=== SKANER SIECI LOKALNEJ (LAN) ===" -ForegroundColor Cyan
    Write-Host "Skanowanie pamięci podręcznej ARP (urządzenia w Twojej podsieci)...`n" -ForegroundColor Yellow
    
    $Neighbors = Get-NetNeighbor -AddressFamily IPv4 | Where-Object State -ne "Unreachable" | Where-Object LinkLayerAddress -ne "00-00-00-00-00-00"
    
    Write-Host "$('IP ADDRESS'.PadRight(15)) | $('MAC ADDRESS'.PadRight(17)) | HOSTNAME" -ForegroundColor Cyan
    Write-Host "-----------------------------------------------------------------"
    
    foreach ($Node in $Neighbors) {
        $IP = $Node.IPAddress
        $MAC = $Node.LinkLayerAddress.Replace("-", ":")
        try {
            $HostName = [System.Net.Dns]::GetHostEntry($IP).HostName
        } catch {
            $HostName = "[Brak nazwy]"
        }
        Write-Host "$($IP.PadRight(15)) " -ForegroundColor Green -NoNewline
        Write-Host "| $($MAC.PadRight(17)) | $HostName"
    }
    Pause-Script
}

function Scan-Wifi {
    Clear-Host
    Write-Host "=== SKANER WI-FI ===" -ForegroundColor Cyan
    Write-Host "Pobieranie listy sieci z okolicy...`n" -ForegroundColor Yellow
    
    # Wykorzystanie natywnego netsh
    netsh wlan show networks mode=bssid | Select-String "SSID|Sygnał|Kanał|BSSID"
    
    Write-Host "`nWskazówka: Aby zoptymalizować 2.4 GHz, wybieraj kanały 1, 6 lub 11." -ForegroundColor Yellow
    Pause-Script
}

# ==========================================
# [2] TESTY POŁĄCZENIA
# ==========================================
function Basic-Diag {
    Clear-Host
    Write-Host "=== PODSTAWOWA DIAGNOSTYKA ===" -ForegroundColor Cyan
    
    $Gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric | Select-Object -First 1).NextHop
    Write-Host "[+] Brama domyślna (Router): $Gateway" -ForegroundColor Green
    
    Write-Host "`n[+] Test połączenia z Internetem (Ping 8.8.8.8)..." -ForegroundColor Yellow
    $Ping = Test-Connection -ComputerName 8.8.8.8 -Count 4 -ErrorAction SilentlyContinue
    if ($Ping) {
        Write-Host "    Internet działa poprawnie." -ForegroundColor Green
    } else {
        Write-Host "    Brak dostępu do internetu!" -ForegroundColor Red
    }

    Write-Host "`n[+] Test rozwiązywania DNS (google.com)..." -ForegroundColor Yellow
    try {
        $dns = Resolve-DnsName google.com -ErrorAction Stop
        Write-Host "    DNS działa. Pomyślnie rozwiązano domenę." -ForegroundColor Green
    } catch {
        Write-Host "    Błąd serwera DNS." -ForegroundColor Red
    }
    Pause-Script
}

function Stability-Monitor {
    Clear-Host
    Write-Host "=== MONITOR STABILNOŚCI I JITTERA ===" -ForegroundColor Cyan
    Write-Host "Testowanie połączenia z 8.8.8.8 (20 pakietów)...`n" -ForegroundColor Yellow
    
    $Results = Test-Connection -ComputerName 8.8.8.8 -Count 20 -ErrorAction SilentlyContinue
    if ($Results) {
        $Times = $Results.ResponseTime
        $Min = ($Times | Measure-Object -Minimum).Minimum
        $Max = ($Times | Measure-Object -Maximum).Maximum
        $Avg = [math]::Round(($Times | Measure-Object -Average).Average, 2)
        
        Write-Host "Wysłano pakietów:      20" -ForegroundColor Cyan
        Write-Host "Odebrano:              $($Results.Count)" -ForegroundColor Green
        Write-Host "Minimalne opóźnienie:  $Min ms" -ForegroundColor Cyan
        Write-Host "Średnie opóźnienie:    $Avg ms" -ForegroundColor Cyan
        Write-Host "Maksymalne opóźnienie: $Max ms" -ForegroundColor Yellow
        Write-Host "Różnica (Jitter ok.):  $($Max - $Min) ms" -ForegroundColor Yellow
    } else {
        Write-Host "Brak połączenia z siecią." -ForegroundColor Red
    }
    
    $Renew = Read-Host "`nCzy chcesz wymusić odnowienie IP od routera (ipconfig /renew)? [t/N]"
    if ($Renew -match "^[TtYy]$") {
        ipconfig /renew | Out-Null
        Write-Host "Zresetowano kartę sieciową." -ForegroundColor Green
    }
    Pause-Script
}

function Speed-Test {
    Clear-Host
    Write-Host "=== POMIAR PRĘDKOŚCI ŁĄCZA ===" -ForegroundColor Cyan
    Write-Host "Instalowanie/Uruchamianie modułu Ookla Speedtest...`n" -ForegroundColor Yellow
    
    if (-not (Get-Command "speedtest.exe" -ErrorAction SilentlyContinue)) {
        Write-Host "Brak speedtest-cli. Zainstaluj go za pomocą: winget install Ookla.Speedtest.CLI" -ForegroundColor Red
    } else {
        speedtest.exe
    }
    Pause-Script
}

# ==========================================
# [3] ANALIZA ZEWNĘTRZNA
# ==========================================
function GeoIP-Scanner {
    Clear-Host
    Write-Host "=== PUBLICZNE IP I GEO-LOKALIZACJA ===" -ForegroundColor Cyan
    try {
        $Info = Invoke-RestMethod -Uri "http://ip-api.com/json/"
        Write-Host "`nTwoje Publiczne IP: " -NoNewline; Write-Host $Info.query -ForegroundColor Green
        Write-Host "Kraj:               $($Info.country)" -ForegroundColor Cyan
        Write-Host "Miasto:             $($Info.city)" -ForegroundColor Cyan
        Write-Host "Dostawca ISP:       $($Info.isp)" -ForegroundColor Green
        Write-Host "Organizacja (ASN):  $($Info.as)" -ForegroundColor Cyan
    } catch {
        Write-Host "Błąd pobierania danych." -ForegroundColor Red
    }
    Pause-Script
}

function Port-Scanner {
    Clear-Host
    Write-Host "=== SKANER PORTÓW TCP ===" -ForegroundColor Cyan
    $Target = Read-Host "Podaj adres IP / domenę (domyślnie localhost)"
    if ([string]::IsNullOrWhiteSpace($Target)) { $Target = "127.0.0.1" }
    
    $Ports = @(21, 22, 25, 53, 80, 110, 143, 443, 3306, 3389, 8080)
    Write-Host "`nSkanowanie hosta: $Target`n" -ForegroundColor Yellow
    
    foreach ($Port in $Ports) {
        $Test = Test-NetConnection -ComputerName $Target -Port $Port -WarningAction SilentlyContinue
        if ($Test.TcpTestSucceeded) {
            Write-Host "PORT $Port `t | [+] OTWARTY" -ForegroundColor Green
        } else {
            Write-Host "PORT $Port `t | [-] ZAMKNIĘTY" -ForegroundColor Red
        }
    }
    Pause-Script
}

function SSL-Verifier {
    Clear-Host
    Write-Host "=== WERYFIKATOR CERTYFIKATÓW SSL/TLS ===" -ForegroundColor Cyan
    $Domain = Read-Host "Podaj domenę (np. google.com)"
    if ([string]::IsNullOrWhiteSpace($Domain)) { return }
    $Domain = $Domain.Replace("https://", "").Replace("http://", "").Split('/')[0]

    try {
        $TcpClient = New-Object Net.Sockets.TcpClient($Domain, 443)
        $SslStream = New-Object Net.Security.SslStream($TcpClient.GetStream(), $false, { $true })
        $SslStream.AuthenticateAsClient($Domain)
        
        $Cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$SslStream.RemoteCertificate
        $ExpDate = [datetime]$Cert.GetExpirationDateString()
        $DaysLeft = ($ExpDate - (Get-Date)).Days

        Write-Host "`nWystawca certyfikatu: $($Cert.Issuer)" -ForegroundColor Cyan
        Write-Host "Data wygaśnięcia:     $ExpDate" -ForegroundColor Cyan
        
        if ($DaysLeft -lt 0) {
            Write-Host "Status:               WYGASŁ! ❌" -ForegroundColor Red
        } elseif ($DaysLeft -le 14) {
            Write-Host "Status:               Wygasa za $DaysLeft dni ⚠️" -ForegroundColor Yellow
        } else {
            Write-Host "Status:               Ważny przez $DaysLeft dni ✅" -ForegroundColor Green
        }
        $TcpClient.Close()
    } catch {
        Write-Host "Błąd pobierania certyfikatu. Sprawdź domenę." -ForegroundColor Red
    }
    Pause-Script
}

# ==========================================
# [4] DIAGNOSTYKA SYSTEMOWA (HOST)
# ==========================================
function Local-Sockets {
    Clear-Host
    Write-Host "=== AKTYWNE GNIAZDA I PROCESY (LISTEN) ===" -ForegroundColor Cyan
    if (-not (Check-Admin)) {
        Write-Host "OSTRZEŻENIE: Brak uprawnień administratora. Nazwy procesów mogą być ukryte." -ForegroundColor Yellow
    }
    Write-Host "LocalAddress:Port `t | PID `t | Nazwa Procesu" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------"
    
    $Connections = Get-NetTCPConnection -State Listen
    foreach ($Conn in $Connections) {
        $ProcessName = "Nieznany"
        try {
            if ($Conn.OwningProcess -ne 0) {
                $ProcessName = (Get-Process -Id $Conn.OwningProcess -ErrorAction SilentlyContinue).ProcessName
            }
        } catch {}
        Write-Host "$($Conn.LocalAddress):$($Conn.LocalPort) `t | $($Conn.OwningProcess) `t | $ProcessName" -ForegroundColor Green
    }
    Pause-Script
}

function Firewall-Diag {
    Clear-Host
    Write-Host "=== DIAGNOSTYKA ZAPORY SIECIOWEJ (FIREWALL) ===" -ForegroundColor Cyan
    Write-Host "Status profili Windows Defender Firewall:`n" -ForegroundColor Yellow
    Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction | Format-Table -AutoSize
    Pause-Script
}

# ==========================================
# AKTUALIZACJA (OTA)
# ==========================================
function Check-Update {
    Clear-Host
    Write-Host "=== AKTUALIZACJA PROGRAMU ===" -ForegroundColor Cyan
    Write-Host "Obecna wersja: $CURRENT_VERSION" -ForegroundColor Yellow
    
    $RawUrl = "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/net-master.ps1"
    
    try {
        $RemoteScript = Invoke-RestMethod -Uri $RawUrl -UseBasicParsing
        $RemoteVersionMatch = [regex]::Match($RemoteScript, '\$CURRENT_VERSION\s*=\s*"([^"]+)"')
        
        if ($RemoteVersionMatch.Success) {
            $RemoteVersion = $RemoteVersionMatch.Groups[1].Value
            if ($CURRENT_VERSION -ne $RemoteVersion) {
                Write-Host "`nZnaleziono nową wersję: $RemoteVersion!" -ForegroundColor Green
                $Choice = Read-Host "Czy chcesz zainstalować aktualizację teraz? [T/n]"
                if ($Choice -match "^[TtYy]$" -or [string]::IsNullOrWhiteSpace($Choice)) {
                    $ScriptPath = $MyInvocation.MyCommand.Path
                    $RemoteScript | Out-File -FilePath $ScriptPath -Encoding utf8
                    Write-Host "Zaktualizowano pomyślnie! Uruchom program ponownie." -ForegroundColor Green
                    Start-Sleep -Seconds 2
                    exit
                }
            } else {
                Write-Host "`nMasz najnowszą wersję." -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "Błąd połączenia z serwerem aktualizacji." -ForegroundColor Red
    }
    Pause-Script
}

# ==========================================
# PODMENU
# ==========================================
function Menu-Local {
    while ($true) {
        Clear-Host
        Write-Host "==============================================" -ForegroundColor Blue
        Write-Host "        [1] DIAGNOSTYKA LOKALNA I WI-FI       " -ForegroundColor Cyan
        Write-Host "==============================================" -ForegroundColor Blue
        Write-Host "1. Interfejsy i stan połączeń"
        Write-Host "2. Skaner sieci lokalnej (LAN)"
        Write-Host "3. Skaner Wi-Fi"
        Write-Host "0. Wróć"
        $sub = Read-Host "Wybierz opcję"
        switch ($sub) {
            '1' { Show-Interfaces }
            '2' { Scan-Lan }
            '3' { Scan-Wifi }
            '0' { return }
        }
    }
}

function Menu-Conn {
    while ($true) {
        Clear-Host
        Write-Host "==============================================" -ForegroundColor Blue
        Write-Host "       [2] TESTY POŁĄCZENIA I WYDAJNOŚCI      " -ForegroundColor Cyan
        Write-Host "==============================================" -ForegroundColor Blue
        Write-Host "1. Podstawowa diagnostyka"
        Write-Host "2. Monitor Stabilności (Ping)"
        Write-Host "3. Pomiar prędkości (Speedtest)"
        Write-Host "0. Wróć"
        $sub = Read-Host "Wybierz opcję"
        switch ($sub) {
            '1' { Basic-Diag }
            '2' { Stability-Monitor }
            '3' { Speed-Test }
            '0' { return }
        }
    }
}

function Menu-Web {
    while ($true) {
        Clear-Host
        Write-Host "==============================================" -ForegroundColor Blue
        Write-Host "        [3] ANALIZA ZEWNĘTRZNA I WEBOWA       " -ForegroundColor Cyan
        Write-Host "==============================================" -ForegroundColor Blue
        Write-Host "1. Moje publiczne IP i Geo-lokalizacja"
        Write-Host "2. Skaner Otwartych Portów TCP"
        Write-Host "3. Weryfikator certyfikatów SSL/TLS"
        Write-Host "0. Wróć"
        $sub = Read-Host "Wybierz opcję"
        switch ($sub) {
            '1' { GeoIP-Scanner }
            '2' { Port-Scanner }
            '3' { SSL-Verifier }
            '0' { return }
        }
    }
}

function Menu-Sys {
    while ($true) {
        Clear-Host
        Write-Host "==============================================" -ForegroundColor Blue
        Write-Host "        [4] DIAGNOSTYKA SYSTEMOWA (HOST)      " -ForegroundColor Cyan
        Write-Host "==============================================" -ForegroundColor Blue
        Write-Host "1. Aktywne gniazda i procesy (Local Sockets)"
        Write-Host "2. Diagnostyka Windows Firewall"
        Write-Host "0. Wróć"
        $sub = Read-Host "Wybierz opcję"
        switch ($sub) {
            '1' { Local-Sockets }
            '2' { Firewall-Diag }
            '0' { return }
        }
    }
}

# ==========================================
# START PROGRAMU
# ==========================================
# Automatyczna zmiana rozmiaru i koloru tła okna dla lepszej czytelności (opcjonalnie)
[console]::BackgroundColor = "Black"
[console]::ForegroundColor = "Gray"

while ($true) {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Blue
    Write-Host "  NET-MASTER (WINDOWS) - DIAGNOSTYKA v$CURRENT_VERSION" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Blue
    Write-Host "1. Diagnostyka Lokalna i Wi-Fi"
    Write-Host "2. Testy Połączenia i Wydajności"
    Write-Host "3. Analiza Zewnętrzna i Webowa"
    Write-Host "4. Diagnostyka Systemowa (Host)"
    Write-Host "8. Sprawdź aktualizacje programu"
    Write-Host "0. Zakończ program"
    Write-Host "==============================================" -ForegroundColor Blue
    
    $choice = Read-Host "Wybierz kategorię [0-4, 8]"
    
    switch ($choice) {
        '1' { Menu-Local }
        '2' { Menu-Conn }
        '3' { Menu-Web }
        '4' { Menu-Sys }
        '8' { Check-Update }
        '0' { Clear-Host; Write-Host "Zakończono. Miłego dnia!"; exit }
    }
}