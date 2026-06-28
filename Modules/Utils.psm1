<#
.SYNOPSIS
    Utility functions for Software Manager Pro.

.VERSION
    0.1.0-alpha
#>

Set-StrictMode -Version Latest

function Test-WinGet {

    <#
    .SYNOPSIS
        Checks whether WinGet is installed.
    #>

    try {

        $null = Get-Command winget -ErrorAction Stop
        Write-Host "  ✔ WinGet detected." -ForegroundColor Green
        return $true

    }
    catch {

        Write-Host "  ✖ WinGet is not installed." -ForegroundColor Red
        return $false

    }

}

function Initialize-Folders {

    <#
    .SYNOPSIS
        Creates missing project folders.
    #>

    $Folders = @(
        $Global:LogsPath,
        $Global:CachePath,
        (Join-Path $Global:AppRoot "Downloads"),
        (Join-Path $Global:AppRoot "Apps"),
        (Join-Path $Global:AppRoot "Assets"),
        (Join-Path $Global:AppRoot "Config"),
        (Join-Path $Global:AppRoot "Modules"),
        (Join-Path $Global:AppRoot "Connectors")
    )

    foreach ($Folder in $Folders) {

        if (!(Test-Path $Folder)) {

            New-Item -ItemType Directory -Path $Folder -Force | Out-Null

            Write-Host "  ✔ Created: $Folder" -ForegroundColor DarkGreen

        }

    }

}

function Test-Administrator {

    <#
    .SYNOPSIS
        Returns True if PowerShell is running as Administrator.
    #>

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

}

function Get-TimeStamp {

    return (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

}

function Write-Section {

    param(

        [string]$Title

    )

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""

}

function Pause-Application {

    Write-Host ""
    Read-Host "Press ENTER to continue"

}

Export-ModuleMember *