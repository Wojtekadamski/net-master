# ==========================================
# NET-MASTER WINDOWS EDITION
# ==========================================
$CURRENT_VERSION = "1.0.0"
$GITHUB_USER = "Wojtekadamski"
$GITHUB_REPO = "net-master"
$BRANCH = "main"

# ==========================================
# FUNKCJE POMOCNICZE
# ==========================================
function Pause-Script {
    Write-Host "`nWcisnij [Enter], aby wrocic..." -ForegroundColor DarkGray
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
    Write-Host "=== INTERFEJSY SIECIOWE I STAN POLACZEN ===" -ForegroundColor Cyan
    Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object Name, InterfaceDescription, LinkSpeed | Format-Table -AutoSize
    Write-Host "`nAdresy IP:" -ForegroundColor Yellow
    Get-NetIPAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -notmatch "Loopback" | Select-Object InterfaceAlias, IPAddress | Format-Table -AutoSize
    Pause-Script
}

function Scan-Lan {
    Clear-Host
    Write-Host "=== SKANER SIECI LOKALNEJ (LAN) ===" -ForegroundColor Cyan
    Write-Host "Skanowanie pamieci podrecznej ARP (urzadzenia w Twojej podsieci)...`n" -ForegroundColor Yellow
    
    $Neighbors = Get-NetNeighbor -AddressFamily IPv4 | Where-Object State -ne "Unreachable" | Where-Object LinkLayerAddress -ne "00-00-00-00-00-00"
    
    Write-Host ('{0,-15} | {1,-17} | HOSTNAME' -f 'IP ADDRESS', 'MAC ADDRESS') -ForegroundColor Cyan
    Write-Host "-----------------------------------------------------------------"
    
    foreach ($Node in $Neighbors) {
        $IP = $Node.IPAddress
        $MAC = $Node.LinkLayerAddress.Replace("-", ":")
        try {
            $HostName = [System.Net.Dns]::GetHostEntry($IP).HostName
        } catch {
            $HostName = "[Brak nazwy]"
        }
        Write-Host ('{0,-15} ' -f $IP) -ForegroundColor Green -NoNewline
        Write-Host ('| {0,-17} | {1}' -f $MAC, $HostName)
    }
    Pause-Script
}

function Scan-Wifi {
    Clear-Host
    Write-Host "=== SKANER WI-FI ===" -ForegroundColor Cyan
    Write-Host "Pobieranie listy sieci z okolicy...`n" -ForegroundColor Yellow
    
    netsh wlan show networks mode=bssid | Select-String "SSID|Sygnał|Kanał|BSSID"
    
    Write-Host "`nWskazowka: Aby zoptymalizowac 2.4 GHz, wybieraj kanaly 1, 6 lub 11." -ForegroundColor Yellow
    Pause-Script
}

# ==========================================
# [2] TESTY POŁĄCZENIA
# ==========================================
function Basic-Diag {
    Clear-Host
    Write-Host "=== PODSTAWOWA DIAGNOSTYKA ===" -ForegroundColor Cyan
    
    $Gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric | Select-Object -First 1).NextHop
    Write-Host ('[+] Brama domyslna (Router): {0}' -f $Gateway) -ForegroundColor Green
    
    Write-Host "`n[+] Test polaczenia z Internetem (Ping 8.8.8.8)..." -ForegroundColor Yellow
    $Ping = Test-Connection -ComputerName 8.8.8.8 -Count 4 -ErrorAction SilentlyContinue
    if ($Ping) {
        Write-Host "    Internet dziala poprawnie." -ForegroundColor Green
    } else {
        Write-Host "    Brak dostepu do internetu!" -ForegroundColor Red
    }

    Write-Host "`n[+] Test rozwiazywania DNS (google.com)..." -ForegroundColor Yellow
    try {
        $dns = Resolve-DnsName google.com -ErrorAction Stop
        Write-Host "    DNS dziala. Pomyslnie rozwiazano domene." -ForegroundColor Green
    } catch {
        Write-Host "    Blad serwera DNS." -ForegroundColor Red
    }
    Pause-Script
}

function Stability-Monitor {
    Clear-Host
    Write-Host "=== MONITOR STABILNOSCI I JITTERA ===" -ForegroundColor Cyan
    Write-Host "Testowanie polaczenia z 8.8.8.8 (20 pakietow)...`n" -ForegroundColor Yellow
    
    $Results = Test-Connection -ComputerName 8.8.8.8 -Count 20 -ErrorAction SilentlyContinue
    if ($Results) {
        $Times = $Results.ResponseTime
        $Min = ($Times | Measure-Object -Minimum).Minimum
        $Max = ($Times | Measure-Object -Maximum).Maximum
        $Avg = [math]::Round(($Times | Measure-Object -Average).Average, 2)
        
        Write-Host "Wyslano pakietow:      20" -ForegroundColor Cyan
        Write-Host ('Odebrano:              {0}' -f $Results.Count) -ForegroundColor Green
        Write-Host ('Minimalne opoznienie:  {0} ms' -f $Min) -ForegroundColor Cyan
        Write-Host ('Srednie opoznienie:    {0} ms' -f $Avg) -ForegroundColor Cyan
        Write-Host ('Maksymalne opoznienie: {0} ms' -f $Max) -ForegroundColor Yellow
        Write-Host ('Roznica (Jitter ok.):  {0} ms' -f ($Max - $Min)) -ForegroundColor Yellow
    } else {
        Write-Host "Brak polaczenia z siecia." -ForegroundColor Red
    }
    
    $Renew = Read-Host "`nCzy chcesz wymusic odnowienie IP od routera (ipconfig /renew)? [t/N]"
    if ($Renew -match "^[TtYy]$") {
        ipconfig /renew | Out-Null
        Write-Host "Zresetowano karte sieciowa." -ForegroundColor Green
    }
    Pause-Script
}

function Speed-Test {
    Clear-Host
    Write-Host "=== POMIAR PREDKOSCI LACZA ===" -ForegroundColor Cyan
    Write-Host "Instalowanie/Uruchamianie modulu Ookla Speedtest...`n" -ForegroundColor Yellow
    
    if (-not (Get-Command "speedtest.exe" -ErrorAction SilentlyContinue)) {
        Write-Host "Brak speedtest-cli. Zainstaluj go za pomoca: winget install Ookla.Speedtest.CLI" -ForegroundColor Red
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
        Write-Host ('Kraj:               {0}' -f $Info.country) -ForegroundColor Cyan
        Write-Host ('Miasto:             {0}' -f $Info.city) -ForegroundColor Cyan
        Write-Host ('Dostawca ISP:       {0}' -f $Info.isp) -ForegroundColor Green
        Write-Host ('Organizacja (ASN):  {0}' -f $Info.as) -ForegroundColor Cyan
    } catch {
        Write-Host "Blad pobierania danych." -ForegroundColor Red
    }
    Pause-Script
}

function Port-Scanner {
    Clear-Host
    Write-Host "=== SKANER PORTOW TCP ===" -ForegroundColor Cyan
    $Target = Read-Host "Podaj adres IP / domene (domyslnie localhost)"
    if ([string]::IsNullOrWhiteSpace($Target)) { $Target = "127.0.0.1" }
    
    $Ports = @(21, 22, 25, 53, 80, 110, 143, 443, 3306, 3389, 8080)
    Write-Host ("`nSkanowanie hosta: {0}`n" -f $Target) -ForegroundColor Yellow
    
    foreach ($Port in $Ports) {
        $Test = Test-NetConnection -ComputerName $Target -Port $Port -WarningAction SilentlyContinue
        if ($Test.TcpTestSucceeded) {
            Write-Host ('PORT {0,-5} | [+] OTWARTY' -f $Port) -ForegroundColor Green
        } else {
            Write-Host ('PORT {0,-5} | [-] ZAMKNIETY' -f $Port) -ForegroundColor Red
        }
    }
    Pause-Script
}

function SSL-Verifier {
    Clear-Host
    Write-Host "=== WERYFIKATOR CERTYFIKATOW SSL/TLS ===" -ForegroundColor Cyan
    $Domain = Read-Host "Podaj domene (np. google.com)"
    if ([string]::IsNullOrWhiteSpace($Domain)) { return }
    $Domain = $Domain.Replace("https://", "").Replace("http://", "").Split('/')[0]

    try {
        $TcpClient = New-Object Net.Sockets.TcpClient($Domain, 443)
        $SslStream = New-Object Net.Security.SslStream($TcpClient.GetStream(), $false, { $true })
        $SslStream.AuthenticateAsClient($Domain)
        
        $Cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$SslStream.RemoteCertificate
        $ExpDate = [datetime]$Cert.GetExpirationDateString()
        $DaysLeft = ($ExpDate - (Get-Date)).Days

        Write-Host ('`nWystawca certyfikatu: {0}' -f $Cert.Issuer) -ForegroundColor Cyan
        Write-Host ('Data wygasniecia:     {0}' -f $ExpDate) -ForegroundColor Cyan
        
        if ($DaysLeft -lt 0) {
            Write-Host "Status:               WYGASL! [X]" -ForegroundColor Red
        } elseif ($DaysLeft -le 14) {
            Write-Host ("Status:               Wygasa za {0} dni [!]" -f $DaysLeft) -ForegroundColor Yellow
        } else {
            Write-Host ("Status:               Wazny przez {0} dni [V]" -f $DaysLeft) -ForegroundColor Green
        }
        $TcpClient.Close()
    } catch {
        Write-Host "Blad pobierania certyfikatu. Sprawdz domene." -ForegroundColor Red
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
        Write-Host "OSTRZEZENIE: Brak uprawnien administratora. Nazwy procesow moga byc ukryte." -ForegroundColor Yellow
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
        Write-Host ('{0}:{1} `t | {2} `t | {3}' -f $Conn.LocalAddress, $Conn.LocalPort, $Conn.OwningProcess, $ProcessName) -ForegroundColor Green
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
    Write-Host ("Obecna wersja: {0}" -f $CURRENT_VERSION) -ForegroundColor Yellow
    
    $RawUrl = "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/net-master.ps1"
    
    try {
        $RemoteScript = Invoke-RestMethod -Uri $RawUrl -UseBasicParsing
        $RemoteVersionMatch = [regex]::Match($RemoteScript, '\$CURRENT_VERSION\s*=\s*"([^"]+)"')
        
        if ($RemoteVersionMatch.Success) {
            $RemoteVersion = $RemoteVersionMatch.Groups[1].Value
            if ($CURRENT_VERSION -ne $RemoteVersion) {
                Write-Host ("`nZnaleziono nowa wersje: {0}!" -f $RemoteVersion) -ForegroundColor Green
                
                # === POBIERANIE I WYSWIETLANIE CHANGELOGU ===
                $ChangelogUrl = "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/changelog-win.txt"
                try {
                    $Changelog = Invoke-RestMethod -Uri $ChangelogUrl -UseBasicParsing -ErrorAction SilentlyContinue
                    if (-not [string]::IsNullOrWhiteSpace($Changelog)) {
                        Write-Host "`n--- CO NOWEGO? ---" -ForegroundColor Cyan
                        Write-Host $Changelog
                        Write-Host "------------------`n" -ForegroundColor Cyan
                    }
                } catch { 
                    # Ignorujemy blad, jesli plik changelogu jeszcze nie istnieje
                }
                # ============================================

                $Choice = Read-Host "Czy chcesz zainstalowac aktualizacje teraz? [T/n]"
                if ($Choice -match "^[TtYy]$" -or [string]::IsNullOrWhiteSpace($Choice)) {
                    $ScriptPath = $MyInvocation.MyCommand.Path
                    $RemoteScript | Out-File -FilePath $ScriptPath -Encoding UTF8
                    Write-Host "Zaktualizowano pomyslnie! Uruchom program ponownie." -ForegroundColor Green
                    Start-Sleep -Seconds 2
                    exit
                }
            } else {
                Write-Host "`nMasz najnowsza wersje." -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "Blad polaczenia z serwerem aktualizacji." -ForegroundColor Red
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
        Write-Host "1. Interfejsy i stan polaczen"
        Write-Host "2. Skaner sieci lokalnej (LAN)"
        Write-Host "3. Skaner Wi-Fi"
        Write-Host "0. Wroc"
        $sub = Read-Host "Wybierz opcje"
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
        Write-Host "       [2] TESTY POLACZENIA I WYDAJNOSCI      " -ForegroundColor Cyan
        Write-Host "==============================================" -ForegroundColor Blue
        Write-Host "1. Podstawowa diagnostyka"
        Write-Host "2. Monitor Stabilnosci (Ping)"
        Write-Host "3. Pomiar predkosci (Speedtest)"
        Write-Host "0. Wroc"
        $sub = Read-Host "Wybierz opcje"
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
        Write-Host "        [3] ANALIZA ZEWNETRZNA I WEBOWA       " -ForegroundColor Cyan
        Write-Host "==============================================" -ForegroundColor Blue
        Write-Host "1. Moje publiczne IP i Geo-lokalizacja"
        Write-Host "2. Skaner Otwartych Portow TCP"
        Write-Host "3. Weryfikator certyfikatow SSL/TLS"
        Write-Host "0. Wroc"
        $sub = Read-Host "Wybierz opcje"
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
        Write-Host "0. Wroc"
        $sub = Read-Host "Wybierz opcje"
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
[console]::BackgroundColor = "Black"
[console]::ForegroundColor = "Gray"

while ($true) {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Blue
    Write-Host ("  NET-MASTER (WINDOWS) - DIAGNOSTYKA v{0}" -f $CURRENT_VERSION) -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Blue
    Write-Host "1. Diagnostyka Lokalna i Wi-Fi"
    Write-Host "2. Testy Polaczenia i Wydajnosci"
    Write-Host "3. Analiza Zewnetrzna i Webowa"
    Write-Host "4. Diagnostyka Systemowa (Host)"
    Write-Host "8. Sprawdz aktualizacje programu"
    Write-Host "0. Zakoncz program"
    Write-Host "==============================================" -ForegroundColor Blue
    
    $choice = Read-Host "Wybierz kategorie [0-4, 8]"
    
    switch ($choice) {
        '1' { Menu-Local }
        '2' { Menu-Conn }
        '3' { Menu-Web }
        '4' { Menu-Sys }
        '8' { Check-Update }
        '0' { Clear-Host; Write-Host "Zakonczono. Milego dnia!"; exit }
    }
}