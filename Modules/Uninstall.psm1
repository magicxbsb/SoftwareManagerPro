<#
.SYNOPSIS
    Uninstall module for Software Manager Pro.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

function Uninstall-App {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Name  = $Id,
        [switch]$Force
    )

    if (-not $Force) {
        Write-Host ""
        Write-Host "  ⚠ Désinstaller $Name ?" -ForegroundColor DarkYellow
        $Confirm = Read-Host "  Confirmer (y/N)"
        if ($Confirm -notmatch '^[yY]$') {
            Write-Host "  Annulé." -ForegroundColor DarkGray
            return $false
        }
    }

    Write-Host ""
    Write-Host "  ► Désinstallation de $Name..." -ForegroundColor Green
    Write-Log -Level "Information" -Message "Uninstalling $Id" -Module "Uninstall"

    winget uninstall --id $Id --exact --silent --accept-source-agreements

    $Code = $LASTEXITCODE

    if ($Code -eq 0) {
        Write-Host "  ✔ $Name désinstallé." -ForegroundColor Green
        Write-Log -Level "Information" -Message "$Id uninstalled OK." -Module "Uninstall"
        Clear-Cache
        return $true
    } else {
        Write-Host "  ✖ Échec désinstallation (code $Code)." -ForegroundColor Red
        Write-Log -Level "Error" -Message "$Id uninstall failed. Code=$Code" -Module "Uninstall"
        return $false
    }
}

function Show-UninstallMenu {
    <#
    .SYNOPSIS
        Lists installed apps and lets user uninstall any of them.
    #>

    while ($true) {
        Write-Host ""
        Write-Host "  Chargement des apps installées..." -ForegroundColor DarkGray
        $Installed = Get-InstalledApps

        $AppList = $Installed.GetEnumerator() | Sort-Object Name | ForEach-Object {
            [PSCustomObject]@{ Id = $_.Key; Version = $_.Value }
        }

        Clear-Host
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║  DÉSINSTALLER UNE APPLICATION            ║" -ForegroundColor Cyan
        Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""

        if ($AppList.Count -eq 0) {
            Write-Host "  Aucune application trouvée." -ForegroundColor DarkGray
            Read-Host "  Appuyez sur Entrée pour retourner"
            break
        }

        Write-Host "  $($AppList.Count) application(s) installée(s)" -ForegroundColor DarkGray
        Write-Host ""

        # Paginate by 20
        $PageSize  = 20
        $Page      = 0
        $TotalPages = [Math]::Ceiling($AppList.Count / $PageSize)

        $Start = $Page * $PageSize
        $End   = [Math]::Min($Start + $PageSize, $AppList.Count) - 1

        for ($i = $Start; $i -le $End; $i++) {
            Write-Host "  [" -NoNewline -ForegroundColor DarkGray
            Write-Host ($i+1) -NoNewline -ForegroundColor Yellow
            Write-Host "] " -NoNewline -ForegroundColor DarkGray
            Write-Host $AppList[$i].Id.PadRight(45) -NoNewline -ForegroundColor Gray
            Write-Host $AppList[$i].Version -ForegroundColor DarkGray
        }

        Write-Host ""
        Write-Host "  Entrez un numéro pour désinstaller, ou [" -NoNewline -ForegroundColor DarkGray
        Write-Host "0" -NoNewline -ForegroundColor Yellow
        Write-Host "] pour retourner." -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "  Votre choix"

        if ($Choice -eq '0') { break }

        if ($Choice -match '^\d+$') {
            $N = [int]$Choice
            if ($N -ge 1 -and $N -le $AppList.Count) {
                Uninstall-App -Id $AppList[$N-1].Id -Name $AppList[$N-1].Id
                Read-Host "`n  Appuyez sur Entrée pour continuer"
            } else {
                Write-Host "  ✖ Numéro invalide." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

Export-ModuleMember *
