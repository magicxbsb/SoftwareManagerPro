<#
.SYNOPSIS
    Favorites module for Software Manager Pro.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

$Script:Favorites = $null

function Get-FavoritesPath {
    return Join-Path $Global:ConfigPath "Favorites.json"
}

function Load-Favorites {
    $Path = Get-FavoritesPath
    $Data = Read-JsonFile -Path $Path
    if ($null -eq $Data -or -not $Data.PSObject.Properties['Apps']) {
        $Script:Favorites = @()
    } else {
        $Script:Favorites = @($Data.Apps)
    }
    return $Script:Favorites
}

function Save-Favorites {
    $Path = Get-FavoritesPath
    Write-JsonFile -Path $Path -Data ([PSCustomObject]@{ Apps = $Script:Favorites }) | Out-Null
    Write-Log -Level "Information" -Message "Favorites saved ($($Script:Favorites.Count) apps)." -Module "Favorites"
}

function Add-Favorite {
    param([Parameter(Mandatory)][hashtable]$App)

    Load-Favorites | Out-Null
    $Exists = $Script:Favorites | Where-Object { $_.Id -eq $App.Id }
    if ($Exists) {
        Write-Host "  ⚠ Already in favorites." -ForegroundColor DarkYellow
        return
    }

    $Script:Favorites += [PSCustomObject]@{ Name = $App.Name ; Id = $App.Id ; Url = $App.Url }
    Save-Favorites
    Write-Host "  ✔ Added to favorites: $($App.Name)" -ForegroundColor Green
}

function Remove-Favorite {
    param([Parameter(Mandatory)][string]$Id)

    Load-Favorites | Out-Null
    $Before = $Script:Favorites.Count
    $Script:Favorites = @($Script:Favorites | Where-Object { $_.Id -ne $Id })
    if ($Script:Favorites.Count -lt $Before) {
        Save-Favorites
        Write-Host "  ✔ Removed from favorites." -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Not found in favorites." -ForegroundColor DarkYellow
    }
}

function Show-FavoritesMenu {
    while ($true) {
        $Favs = Load-Favorites
        $Installed = Get-InstalledApps

        Clear-Host
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║  FAVORIS                                 ║" -ForegroundColor Cyan
        Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""

        if ($Favs.Count -eq 0) {
            Write-Host "  Aucun favori enregistré." -ForegroundColor DarkGray
            Write-Host ""
            Read-Host "  Appuyez sur Entrée pour retourner"
            break
        }

        for ($i = 0; $i -lt $Favs.Count; $i++) {
            $F = $Favs[$i]
            Write-Host "  [" -NoNewline -ForegroundColor DarkGray
            Write-Host ($i+1) -NoNewline -ForegroundColor Yellow
            Write-Host "] " -NoNewline -ForegroundColor DarkGray
            Write-Host $F.Name.PadRight(35) -NoNewline -ForegroundColor Gray
            if ($F.Id -and $Installed.ContainsKey($F.Id)) {
                Write-Host " ✔ $($Installed[$F.Id])" -ForegroundColor Green
            } elseif ($F.Id) {
                Write-Host " [non installé]" -ForegroundColor DarkGray
            } else {
                Write-Host " [lien web]" -ForegroundColor DarkYellow
            }
        }

        Write-Host ""
        Write-Host "  [" -NoNewline -ForegroundColor DarkGray
        Write-Host "a" -NoNewline -ForegroundColor Yellow
        Write-Host "] Tout installer   [" -NoNewline -ForegroundColor DarkGray
        Write-Host "d" -NoNewline -ForegroundColor Yellow
        Write-Host "] Supprimer un favori   [" -NoNewline -ForegroundColor DarkGray
        Write-Host "0" -NoNewline -ForegroundColor Yellow
        Write-Host "] Retour" -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "  Votre choix"

        if ($Choice -eq '0') { break }

        if ($Choice -eq 'a') {
            Write-Host ""
            $AppList = $Favs | ForEach-Object { @{ Name = $_.Name ; Id = $_.Id ; Url = $_.Url } }
            $Summary = Install-AppsBatch -Apps $AppList
            Write-Host ""
            Write-Host "  ✔ $($Summary.Ok) succès" -NoNewline -ForegroundColor Green
            if ($Summary.Fail -gt 0) { Write-Host "   ✖ $($Summary.Fail) échec(s)" -NoNewline -ForegroundColor Red }
            Write-Host ""
            Read-Host "`n  Appuyez sur Entrée pour continuer"
            continue
        }

        if ($Choice -eq 'd') {
            $Del = Read-Host "  Numéro du favori à supprimer"
            if ($Del -match '^\d+$') {
                $N = [int]$Del
                if ($N -ge 1 -and $N -le $Favs.Count) {
                    Remove-Favorite -Id $Favs[$N-1].Id
                    Start-Sleep -Seconds 1
                }
            }
            continue
        }

        if ($Choice -match '^\d+$') {
            $N = [int]$Choice
            if ($N -ge 1 -and $N -le $Favs.Count) {
                $F = $Favs[$N-1]
                Install-App -App @{ Name = $F.Name ; Id = $F.Id ; Url = $F.Url }
                Read-Host "`n  Appuyez sur Entrée pour continuer"
            }
        }
    }
}

Export-ModuleMember *
