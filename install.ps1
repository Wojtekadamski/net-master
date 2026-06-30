# ==========================================
# INSTALATOR NET-MASTER (WINDOWS)
# ==========================================
$GitHubUser = "Wojtekadamski"
$GitHubRepo = "net-master"
$Branch = "main"

$RawUrl = "https://raw.githubusercontent.com/$GitHubUser/$GitHubRepo/$Branch/net-master.ps1"
$InstallDir = "$env:LOCALAPPDATA\NetMaster"
$ScriptPath = "$InstallDir\net-master.ps1"

Write-Host "Rozpoczynam instalację Net-Master..." -ForegroundColor Cyan

# 1. Tworzenie katalogu
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }

# 2. Pobieranie skryptu
Write-Host "Pobieranie skryptu z GitHuba..."
try {
    Invoke-WebRequest -Uri $RawUrl -OutFile $ScriptPath -UseBasicParsing
    Write-Host "[+] Pobrano pomyślnie!" -ForegroundColor Green
} catch {
    Write-Host "[-] Błąd pobierania skryptu. Sprawdź połączenie." -ForegroundColor Red
    exit
}

# 3. Tworzenie skrótu w Menu Start
Write-Host "Tworzenie skrótu w Menu Start..."
$WshShell = New-Object -ComObject WScript.Shell
$ShortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Net-Master Diagnostyka.lnk"
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
# Odpalanie przez PowerShell z ominięciem lokalnych restrykcji
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -File `"$ScriptPath`""
$Shortcut.IconLocation = "shell32.dll,18" # Ikonka sieci
$Shortcut.Save()

Write-Host "[+] Skrót utworzony!" -ForegroundColor Green
Write-Host "`nInstalacja zakończona sukcesem. Możesz teraz wyszukać 'Net-Master' w Menu Start." -ForegroundColor Green
Start-Sleep -Seconds 3