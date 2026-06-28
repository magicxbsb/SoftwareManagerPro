<#
.SYNOPSIS
    Update module for Software Manager Pro.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

function Get-PendingUpdates {
    <#
    .SYNOPSIS
        Returns a list of apps that have updates available via winget upgrade.
    #>

    Write-Host "  Checking for updates..." -ForegroundColor DarkGray
    Write-Log -Level "Information" -Message "Checking pending updates..." -Module "Update"

    $Updates = @()

    try {
        $Raw = winget upgrade --accept-source-agreements 2>$null
        $Started = $false

        foreach ($Line in $Raw) {
            # Skip header lines
            if ($Line -match '^[-]+$') { $Started = $true ; continue }
            if (-not $Started)         { continue }
            if ([string]::IsNullOrWhiteSpace($Line)) { continue }

            # Parse: Name   Id   Installed   Available   Source
            $Parts = ($Line -split '\s{2,}') | Where-Object { $_ -ne '' }
            if ($Parts.Count -ge 5) {
                $Updates += [PSCustomObject]@{
                    Name      = $Parts[0].Trim()
                    Id        = $Parts[1].Trim()
                    Installed = $Parts[2].Trim()
                    Available = $Parts[3].Trim()
                    Source    = $Parts[4].Trim()
                }
            }
        }
    }
    catch {
        Write-Log -Level "Error" -Message "winget upgrade failed: $_" -Module "Update"
    }

    Write-Log -Level "Information" -Message "$($Updates.Count) updates found." -Module "Update"
    return $Updates
}

function Update-SingleApp {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Source = "winget"
    )

    Write-Host "  ► Updating $Id..." -ForegroundColor Green
    Write-Log -Level "Information" -Message "Updating $Id via $Source" -Module "Update"

    winget upgrade --id $Id --exact --silent --source $Source `
        --accept-source-agreements --accept-package-agreements

    $Code = $LASTEXITCODE

    if ($Code -eq 0) {
        Write-Host "  ✔ Updated successfully." -ForegroundColor Green
        Write-Log -Level "Information" -Message "$Id updated OK." -Module "Update"
        return $true
    } elseif ($Code -eq -1978335189) {
        Write-Host "  ✔ Already up to date." -ForegroundColor DarkYellow
        return $true
    } else {
        Write-Host "  ✖ Update failed (code $Code)." -ForegroundColor Red
        Write-Log -Level "Error" -Message "$Id update failed. Code=$Code" -Module "Update"
        return $false
    }
}

function Update-AllApps {
    <#
    .SYNOPSIS
        Runs winget upgrade --all with confirmation.
    #>
    param([switch]$Force)

    if (-not $Force) {
        $Confirm = Read-Host "  Update ALL installed apps? (y/N)"
        if ($Confirm -notmatch '^[yY]$') {
            Write-Host "  Cancelled." -ForegroundColor DarkGray
            return
        }
    }

    Write-Host ""
    Write-Host "  ► Updating all apps via winget..." -ForegroundColor Green
    Write-Log -Level "Information" -Message "Running winget upgrade --all" -Module "Update"

    winget upgrade --all --silent --accept-source-agreements --accept-package-agreements

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✔ All apps updated." -ForegroundColor Green
        Write-Log -Level "Information" -Message "winget upgrade --all completed OK." -Module "Update"
    } else {
        Write-Host "  ⚠ Some updates may have failed (code $LASTEXITCODE)." -ForegroundColor DarkYellow
        Write-Log -Level "Warning" -Message "winget upgrade --all exited $LASTEXITCODE" -Module "Update"
    }

    Clear-Cache
}

function Show-UpdatesMenu {
    <#
    .SYNOPSIS
        Interactive screen listing all pending updates.
    #>

    while ($true) {
        $Updates = Get-PendingUpdates
        Clear-Host
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║  MISES À JOUR DISPONIBLES                ║" -ForegroundColor Cyan
        Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""

        if ($Updates.Count -eq 0) {
            Write-Host "  ✔ Tout est à jour." -ForegroundColor Green
            Write-Host ""
            Read-Host "  Appuyez sur Entrée pour retourner"
            break
        }

        Write-Host "  $($Updates.Count) mise(s) à jour disponible(s) :" -ForegroundColor DarkYellow
        Write-Host ""

        for ($i = 0; $i -lt $Updates.Count; $i++) {
            $U = $Updates[$i]
            Write-Host "  [" -NoNewline -ForegroundColor DarkGray
            Write-Host ($i+1) -NoNewline -ForegroundColor Yellow
            Write-Host "] " -NoNewline -ForegroundColor DarkGray
            Write-Host $U.Name.PadRight(30) -NoNewline -ForegroundColor Gray
            Write-Host $U.Installed.PadRight(14) -NoNewline -ForegroundColor DarkYellow
            Write-Host " → " -NoNewline -ForegroundColor DarkGray
            Write-Host $U.Available -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "  [" -NoNewline -ForegroundColor DarkGray
        Write-Host "a" -NoNewline -ForegroundColor Yellow
        Write-Host "] Tout mettre à jour   [" -NoNewline -ForegroundColor DarkGray
        Write-Host "0" -NoNewline -ForegroundColor Yellow
        Write-Host "] Retour" -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "  Votre choix"

        if ($Choice -eq '0') { break }

        if ($Choice -eq 'a') {
            Update-AllApps -Force
            Read-Host "`n  Appuyez sur Entrée pour continuer"
            continue
        }

        if ($Choice -match '^\d+$') {
            $N = [int]$Choice
            if ($N -ge 1 -and $N -le $Updates.Count) {
                Update-SingleApp -Id $Updates[$N-1].Id -Source $Updates[$N-1].Source
                Clear-Cache
                Read-Host "`n  Appuyez sur Entrée pour continuer"
            } else {
                Write-Host "  ✖ Numéro invalide." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

Export-ModuleMember *
