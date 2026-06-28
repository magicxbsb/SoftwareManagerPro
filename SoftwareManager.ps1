<#
.SYNOPSIS
    Software Manager Pro — Entry point.
    Loads all modules, initializes globals, then launches the main menu.
.VERSION
    1.0.0
.AUTHOR
    Moustapha SOUMAH
#>

#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  GLOBAL PATHS
# ══════════════════════════════════════════════════════════════════════════════
$Global:AppRoot     = $PSScriptRoot
$Global:ModulesPath = Join-Path $PSScriptRoot "Modules"
$Global:ConfigPath  = Join-Path $PSScriptRoot "Config"
$Global:CachePath   = Join-Path $PSScriptRoot "Cache"
$Global:LogsPath    = Join-Path $PSScriptRoot "Logs"
$Global:AppsPath    = Join-Path $PSScriptRoot "Apps"
$Global:FallbackUrls = @{
    "Elgato"      = "https://www.elgato.com/fr/fr/s/downloads"
    "OBSProject"  = "https://obsproject.com/fr/download"
    "Streamlabs"  = "https://streamlabs.com"
    "NVIDIA"      = "https://www.nvidia.com/fr-fr/geforce/broadcasting/broadcast-app/"
    "PlayStation" = "https://www.playstation.com/fr-fr/remote-play/"
    "MSI"         = "https://fr.msi.com/Landing/mystic-light/download"
    "Gigabyte"    = "https://www.gigabyte.com/Support/Utility"
    "SteelSeries" = "https://steelseries.com/gg"
    "SignalRGB"   = "https://www.signalrgb.com/download/"
}

# ══════════════════════════════════════════════════════════════════════════════
#  STARTUP DISPLAY
# ══════════════════════════════════════════════════════════════════════════════
Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║        SOFTWARE MANAGER PRO  v1.0.0         ║" -ForegroundColor Magenta
Write-Host "  ║        by Moustapha SOUMAH                   ║" -ForegroundColor DarkGray
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Initialisation..." -ForegroundColor DarkGray
Write-Host ""

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 1 — Load core modules (order matters)
# ══════════════════════════════════════════════════════════════════════════════
$CoreModules = @(
    "Logger","Json","Settings","Utils","Cache",
    "Version","Download","Install",
    "Update","Uninstall","Search",
    "Favorites","Profiles","Packs",
    "UI","Menu"
)

Write-Host "  [1/5] Chargement des modules..." -ForegroundColor DarkGray

foreach ($Mod in $CoreModules) {
    $Path = Join-Path $Global:ModulesPath "$Mod.psm1"
    try {
        Import-Module $Path -Force -Global -DisableNameChecking -ErrorAction Stop
    } catch {
        Write-Host "  ✖ Impossible de charger le module $Mod : $_" -ForegroundColor Red
        Read-Host "  Appuyez sur Entrée pour quitter"
        exit 1
    }
}

Write-Host "  [1/5] ✔ Modules chargés" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 2 — Initialize logger and settings
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "  [2/5] Chargement de la configuration..." -ForegroundColor DarkGray

try {
    $Settings = Get-Settings
    Initialize-Logger `
        -LogFolder $Global:LogsPath `
        -Level     ($Settings.Logging.Level ?? "Information") `
        -Enabled   ($Settings.Logging.Enabled ?? $true)

    Initialize-Cache `
        -Enabled        ($Settings.Cache.Enabled ?? $true) `
        -ExpirationHours ($Settings.Cache.ExpirationHours ?? 24)

    Write-Host "  [2/5] ✔ Configuration chargée" -ForegroundColor Green
} catch {
    Write-Host "  [2/5] ⚠ Config par défaut utilisée" -ForegroundColor DarkYellow
    Initialize-Logger -LogFolder $Global:LogsPath
    Initialize-Cache
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 3 — Check winget
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "  [3/5] Vérification de WinGet..." -ForegroundColor DarkGray

if (-not (Test-WinGet)) {
    Write-Host ""
    Write-Host "  ✖ WinGet est requis. Installez-le via le Microsoft Store (App Installer)." -ForegroundColor Red
    Read-Host "  Appuyez sur Entrée pour quitter"
    exit 1
}

Write-Host "  [3/5] ✔ WinGet détecté" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 4 — Load connectors
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "  [4/5] Chargement des connecteurs..." -ForegroundColor DarkGray

$ConnectorPath = Join-Path $PSScriptRoot "Connectors"
if (Test-Path $ConnectorPath) {
    Get-ChildItem -Path $ConnectorPath -Filter "*.psm1" | ForEach-Object {
        try {
            Import-Module $_.FullName -Force -Global -DisableNameChecking -ErrorAction SilentlyContinue
            $FnName = "Register-$([System.IO.Path]::GetFileNameWithoutExtension($_.Name))Connector"
            if (Get-Command $FnName -ErrorAction SilentlyContinue) { & $FnName }
        } catch {}
    }
}

Write-Host "  [4/5] ✔ Connecteurs chargés" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 5 — Build app menu from JSON files
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "  [5/5] Chargement du catalogue d'applications..." -ForegroundColor DarkGray

$AppMenu = [ordered]@{}

# Predefined category display order
$CategoryOrder = @(
    "Constructeurs","Streaming","Jeux","Audio",
    "Monitoring","RGB","IA","Internet",
    "Communication","Developpement","Essentiels",
    "Drivers","Virtualisation"
)

foreach ($Cat in $CategoryOrder) {
    $File = Join-Path $Global:AppsPath "$Cat.json"
    if (Test-Path $File) {
        $Data = Read-JsonFile -Path $File
        if ($Data) {
            $Label = switch ($Cat) {
                "Constructeurs"  { "CONSTRUCTEURS" }
                "Streaming"      { "STREAM" }
                "Jeux"           { "JEUX & GAMING" }
                "Audio"          { "AUDIO / VIDÉO" }
                "Monitoring"     { "MONITORING" }
                "RGB"            { "RGB & LIGHTING" }
                "IA"             { "INTELLIGENCE ARTIFICIELLE" }
                "Internet"       { "INTERNET & NAVIGATEURS" }
                "Communication"  { "COMMUNICATION" }
                "Developpement"  { "DÉVELOPPEMENT" }
                "Essentiels"     { "OUTILS ESSENTIELS" }
                "Drivers"        { "DRIVERS & PÉRIPHÉRIQUES" }
                "Virtualisation" { "VIRTUALISATION" }
                default          { $Cat.ToUpper() }
            }
            $AppMenu[$Label] = $Data
            Write-Log -Level "Debug" -Message "Loaded catalog: $Cat" -Module "Startup"
        }
    }
}

# Fallback: add any remaining JSON files not in the predefined order
Get-ChildItem -Path $Global:AppsPath -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    $Name = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    if ($CategoryOrder -notcontains $Name) {
        $Data = Read-JsonFile -Path $_.FullName
        if ($Data) { $AppMenu[$Name.ToUpper()] = $Data }
    }
}

$TotalApps = ($AppMenu.Values | ForEach-Object { $_ } | Measure-Object).Count
Write-Host "  [5/5] ✔ $($AppMenu.Count) catégories chargées" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════════════════
#  LAUNCH
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  Prêt." -ForegroundColor Green
Start-Sleep -Milliseconds 800

Write-Log -Level "Information" -Message "Software Manager Pro started. Categories=$($AppMenu.Count)" -Module "Startup"

Show-MainMenu -AppMenu $AppMenu
