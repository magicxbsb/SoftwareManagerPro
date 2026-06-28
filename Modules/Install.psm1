<#
.SYNOPSIS
    Installation engine for Software Manager Pro.
    Handles winget, msstore, and direct URL (browser) installs.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

# Exit codes returned by winget
$Script:WingetCodes = @{
    Success         =  0
    AlreadyInstalled = -1978335189
    NotFound         = -1978335212
    NetworkError     = -1978335193
    Cancelled        = -1978335210
    HashMismatch     = -1978335215
    Blocked          = -1978335191
}

function Install-App {
    <#
    .SYNOPSIS
        Installs an app via winget on a specified source.
        Returns a result object with Success, ExitCode, Message.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$App,
        [ValidateSet("winget","msstore")]
        [string]$Source = "winget",
        [switch]$Silent
    )

    # Web-only app
    if (-not $App.Id -and $App.Url) {
        return Open-DownloadPage -App $App
    }

    $Name = $App.Name -replace '\s*[\^↗]\s*$', ''

    if (-not $Silent) {
        Write-Host ""
        Write-Host "  ► Installing $Name via $Source..." -ForegroundColor Green
    }

    Write-Log -Level "Information" -Message "Installing $($App.Id) via $Source" -Module "Install"

    winget install --id $App.Id --exact --silent --source $Source `
        --accept-source-agreements --accept-package-agreements

    $Code = $LASTEXITCODE
    return Resolve-InstallResult -App $App -ExitCode $Code -Source $Source -Silent:$Silent
}

function Install-AppFromUrl {
    <#
    .SYNOPSIS
        Direct download + silent install from a URL (.exe / .msi).
    #>
    param(
        [Parameter(Mandatory)][hashtable]$App
    )

    $Name     = $App.Name -replace '\s*[\^↗]\s*$', ''
    $Url      = $App.Url
    $FileName = Split-Path $Url -Leaf
    $DlFolder = Join-Path $Global:AppRoot "Downloads"
    $DlPath   = Join-Path $DlFolder $FileName

    Write-Host ""
    Write-Host "  ► Downloading $Name..." -ForegroundColor Green
    Write-Log -Level "Information" -Message "Downloading $Url" -Module "Install"

    try {
        Invoke-WebRequest -Uri $Url -OutFile $DlPath -UseBasicParsing
    }
    catch {
        Write-Host "  ✖ Download failed: $_" -ForegroundColor Red
        Write-Log -Level "Error" -Message "Download failed: $_" -Module "Install"
        return @{ Success = $false; Message = "Download failed" }
    }

    Write-Host "  ► Running installer..." -ForegroundColor Green

    $Ext = [System.IO.Path]::GetExtension($FileName).ToLower()
    try {
        if ($Ext -eq ".msi") {
            Start-Process msiexec -ArgumentList "/i `"$DlPath`" /quiet /norestart" -Wait
        } else {
            Start-Process $DlPath -ArgumentList "/S /silent /quiet" -Wait
        }
    }
    catch {
        Write-Host "  ✖ Installer failed: $_" -ForegroundColor Red
        Write-Log -Level "Error" -Message "Installer failed: $_" -Module "Install"
        return @{ Success = $false; Message = "Install failed" }
    }

    # Cleanup
    if ((Get-Setting "Downloads.DeleteAfterInstall") -ne $false) {
        Remove-Item $DlPath -Force -ErrorAction SilentlyContinue
    }

    Write-Host "  ✔ $Name installed." -ForegroundColor Green
    Write-Log -Level "Information" -Message "$($App.Id) installed from URL." -Module "Install"
    return @{ Success = $true; Message = "Installed from URL" }
}

function Open-DownloadPage {
    param([hashtable]$App)

    $Name = $App.Name -replace '\s*[\^↗]\s*$', ''
    Write-Host ""
    Write-Host "  ► Opening download page for $Name..." -ForegroundColor DarkYellow
    Start-Process $App.Url
    Write-Host "  ↗ Browser opened." -ForegroundColor DarkYellow
    Write-Log -Level "Information" -Message "Browser opened for $Name : $($App.Url)" -Module "Install"
    return @{ Success = $true; Message = "Browser opened" }
}

function Install-AppsBatch {
    <#
    .SYNOPSIS
        Installs a list of apps silently and returns a summary.
    #>
    param(
        [Parameter(Mandatory)][array]$Apps,
        [string]$Source = "winget"
    )

    $Ok   = 0
    $Fail = 0
    $Skipped = 0

    foreach ($App in $Apps) {
        $Name = $App.Name -replace '\s*[\^↗]\s*$', ''
        Write-Host "  · $($Name.PadRight(35))" -NoNewline -ForegroundColor DarkGray

        if (-not $App.Id -and $App.Url) {
            Start-Process $App.Url
            Write-Host " ↗ web" -ForegroundColor DarkYellow
            $Skipped++
            continue
        }

        $Result = Install-App -App $App -Source $Source -Silent
        if ($Result.Success) {
            Write-Host " ✔" -ForegroundColor Green
            $Ok++
        } else {
            Write-Host " ✖ $($Result.Message)" -ForegroundColor Red
            $Fail++
        }
    }

    return @{ Ok = $Ok; Fail = $Fail; Skipped = $Skipped }
}

function Resolve-InstallResult {
    param($App, [int]$ExitCode, [string]$Source, [switch]$Silent)

    $Name = $App.Name -replace '\s*[\^↗]\s*$', ''

    switch ($ExitCode) {
        0 {
            if (-not $Silent) { Write-Host "  ✔ $Name installed successfully ($Source)." -ForegroundColor Green }
            Write-Log -Level "Information" -Message "$($App.Id) installed OK via $Source." -Module "Install"
            Update-CachedVersion -Id $App.Id -Version "installed"
            return @{ Success = $true; ExitCode = $ExitCode; Message = "Success" }
        }
        -1978335189 {
            if (-not $Silent) { Write-Host "  ✔ $Name is already up to date." -ForegroundColor DarkYellow }
            Write-Log -Level "Information" -Message "$($App.Id) already up to date." -Module "Install"
            return @{ Success = $true; ExitCode = $ExitCode; Message = "Already installed" }
        }
        -1978335212 {
            if (-not $Silent) {
                Write-Host "  ✖ '$($App.Id)' not found on $Source." -ForegroundColor Red
                $FallbackUrl = Get-FallbackUrl -Id $App.Id -AppUrl ($App.Url)
                if ($FallbackUrl) {
                    Write-Host "  ↗ Opening download page..." -ForegroundColor DarkYellow
                    Start-Process $FallbackUrl
                }
            }
            Write-Log -Level "Warning" -Message "$($App.Id) not found on $Source." -Module "Install"
            return @{ Success = $false; ExitCode = $ExitCode; Message = "Not found" }
        }
        -1978335193 {
            if (-not $Silent) { Write-Host "  ✖ Network error." -ForegroundColor Red }
            Write-Log -Level "Error" -Message "$($App.Id) network error." -Module "Install"
            return @{ Success = $false; ExitCode = $ExitCode; Message = "Network error" }
        }
        -1978335210 {
            if (-not $Silent) { Write-Host "  ✖ Cancelled by user." -ForegroundColor DarkYellow }
            Write-Log -Level "Warning" -Message "$($App.Id) install cancelled." -Module "Install"
            return @{ Success = $false; ExitCode = $ExitCode; Message = "Cancelled" }
        }
        -1978335215 {
            if (-not $Silent) { Write-Host "  ✖ Hash mismatch. Installer may be corrupted." -ForegroundColor Red }
            Write-Log -Level "Error" -Message "$($App.Id) hash mismatch." -Module "Install"
            return @{ Success = $false; ExitCode = $ExitCode; Message = "Hash mismatch" }
        }
        default {
            if (-not $Silent) { Write-Host "  ✖ Failed (code $ExitCode)." -ForegroundColor Red }
            Write-Log -Level "Error" -Message "$($App.Id) failed with code $ExitCode." -Module "Install"
            return @{ Success = $false; ExitCode = $ExitCode; Message = "Failed ($ExitCode)" }
        }
    }
}

function Get-FallbackUrl {
    param([string]$Id, [string]$AppUrl)
    if ($AppUrl) { return $AppUrl }
    $Publisher = $Id -split '\.' | Select-Object -First 1
    $Map = @{
        "Elgato"       = "https://www.elgato.com/fr/fr/s/downloads"
        "OBSProject"   = "https://obsproject.com/fr/download"
        "Streamlabs"   = "https://streamlabs.com"
        "NVIDIA"       = "https://www.nvidia.com/fr-fr/geforce/broadcasting/broadcast-app/"
        "PlayStation"  = "https://www.playstation.com/fr-fr/remote-play/"
    }
    if ($Map.ContainsKey($Publisher)) { return $Map[$Publisher] }
    return $null
}

Export-ModuleMember *
