<#
.SYNOPSIS
    Software Manager Pro

.DESCRIPTION
    Main entry point of the application.

.AUTHOR
    Moustapha SOUMAH

.VERSION
    0.1.0-alpha
#>

#Requires -Version 7.0

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Global variables
# ------------------------------------------------------------

$Global:AppRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Global:ModulesPath = Join-Path $AppRoot "Modules"
$Global:ConfigPath = Join-Path $AppRoot "Config"
$Global:LogsPath = Join-Path $AppRoot "Logs"
$Global:CachePath = Join-Path $AppRoot "Cache"

# ------------------------------------------------------------
# Banner
# ------------------------------------------------------------

function Show-Banner {

    Clear-Host

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                 SOFTWARE MANAGER PRO" -ForegroundColor White
    Write-Host "                     v0.1.0-alpha" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "      Powered by WinGet, Microsoft Store & Vendors" -ForegroundColor DarkGray
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ------------------------------------------------------------
# Import Modules
# ------------------------------------------------------------

function Import-ProjectModules {

    $Modules = @(
        "Utils.psm1",
        "Logger.psm1",
        "Settings.psm1"
    )

    foreach ($Module in $Modules) {

        $ModulePath = Join-Path $ModulesPath $Module

        if (!(Test-Path $ModulePath)) {

            Write-Host "[ERROR] Missing module: $Module" -ForegroundColor Red
            exit

        }

        Import-Module $ModulePath -Force

    }

}

# ------------------------------------------------------------
# Startup
# ------------------------------------------------------------

try {

    Show-Banner

    Write-Host "[1/5] Loading modules..." -ForegroundColor Cyan
    Import-ProjectModules

    Write-Host "[2/5] Checking folders..." -ForegroundColor Cyan
    Initialize-Folders

    Write-Host "[3/5] Loading settings..." -ForegroundColor Cyan
    $Settings = Get-Settings

    Write-Host "[4/5] Initializing logger..." -ForegroundColor Cyan
    Initialize-Logger

    Write-Host "[5/5] Checking WinGet..." -ForegroundColor Cyan
    Test-WinGet

    Write-Host ""
    Write-Host "Software Manager Pro started successfully." -ForegroundColor Green
    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "Fatal Error" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""

}