<#
.SYNOPSIS
    Packs module for Software Manager Pro.
    A Pack is a curated bundle of apps (e.g. "Essential Gaming", "Content Creator").
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

function Get-PacksPath {
    return Join-Path $Global:ConfigPath "Packs"
}

function Get-AllPacks {
    $Path = Get-PacksPath
    if (-not (Test-Path $Path)) {
        # Create default packs on first run
        Initialize-DefaultPacks
    }

    return Get-ChildItem -Path $Path -Filter "*.json" -ErrorAction SilentlyContinue |
        ForEach-Object { Read-JsonFile -Path $_.FullName } |
        Where-Object { $_ -ne $null }
}

function Initialize-DefaultPacks {
    $Path = Get-PacksPath
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }

    $Defaults = @(
        [PSCustomObject]@{
            Name        = "Streaming Complet"
            Description = "Tout pour streamer : OBS, Stream Deck, Wave Link"
            Icon        = "📡"
            Apps        = @(
                [PSCustomObject]@{ Name = "OBS Studio"    ; Id = "OBSProject.OBSStudio"   },
                [PSCustomObject]@{ Name = "Stream Deck"   ; Id = "Elgato.StreamDeck"       },
                [PSCustomObject]@{ Name = "Wave Link"     ; Id = "Elgato.WaveLink"         },
                [PSCustomObject]@{ Name = "Streamlabs"    ; Id = "Streamlabs.Streamlabs"   }
            )
        },
        [PSCustomObject]@{
            Name        = "Développement"
            Description = "Environnement dev complet"
            Icon        = "💻"
            Apps        = @(
                [PSCustomObject]@{ Name = "VS Code"          ; Id = "Microsoft.VisualStudioCode" },
                [PSCustomObject]@{ Name = "Git"              ; Id = "Git.Git"                    },
                [PSCustomObject]@{ Name = "Windows Terminal" ; Id = "Microsoft.WindowsTerminal"  },
                [PSCustomObject]@{ Name = "Notepad++"        ; Id = "Notepad++.Notepad++"        }
            )
        },
        [PSCustomObject]@{
            Name        = "Outils Essentiels"
            Description = "Apps indispensables après une install Windows"
            Icon        = "🔧"
            Apps        = @(
                [PSCustomObject]@{ Name = "VLC"           ; Id = "VideoLAN.VLC"                },
                [PSCustomObject]@{ Name = "Notepad++"     ; Id = "Notepad++.Notepad++"         },
                [PSCustomObject]@{ Name = "CPU-Z"         ; Id = "CPUID.CPU-Z"                 },
                [PSCustomObject]@{ Name = "TreeSize Free" ; Id = "JAMSoftware.TreeSize.Free"   },
                [PSCustomObject]@{ Name = "Process Lasso" ; Id = "Bitsum.ProcessLasso"         }
            )
        }
    )

    foreach ($Pack in $Defaults) {
        $File = Join-Path $Path "$($Pack.Name -replace '[^\w]','_').json"
        if (-not (Test-Path $File)) {
            Write-JsonFile -Path $File -Data $Pack | Out-Null
        }
    }

    Write-Log -Level "Information" -Message "Default packs initialized." -Module "Packs"
}

function Show-PacksMenu {
    while ($true) {
        $Packs     = @(Get-AllPacks)
        $Installed = Get-InstalledApps

        Clear-Host
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║  PACKS D'APPLICATIONS                    ║" -ForegroundColor Cyan
        Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""

        if ($Packs.Count -eq 0) {
            Write-Host "  Aucun pack disponible." -ForegroundColor DarkGray
            Read-Host "  Appuyez sur Entrée pour retourner"
            break
        }

        for ($i = 0; $i -lt $Packs.Count; $i++) {
            $P = $Packs[$i]
            $InstalledCount = ($P.Apps | Where-Object { $_.Id -and $Installed.ContainsKey($_.Id) }).Count
            $Icon = if ($P.Icon) { "$($P.Icon) " } else { "" }

            Write-Host "  [" -NoNewline -ForegroundColor DarkGray
            Write-Host ($i+1) -NoNewline -ForegroundColor Yellow
            Write-Host "] $Icon" -NoNewline -ForegroundColor DarkGray
            Write-Host $P.Name.PadRight(28) -NoNewline -ForegroundColor Gray
            Write-Host "$InstalledCount/$($P.Apps.Count) installés" -NoNewline -ForegroundColor DarkGray
            if ($P.Description) { Write-Host " — $($P.Description)" -ForegroundColor DarkGray } else { Write-Host "" }
        }

        Write-Host ""
        Write-Host "  [" -NoNewline -ForegroundColor DarkGray
        Write-Host "0" -NoNewline -ForegroundColor Yellow
        Write-Host "] Retour" -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "  Votre choix"

        if ($Choice -eq '0') { break }

        if ($Choice -match '^\d+$') {
            $N = [int]$Choice
            if ($N -ge 1 -and $N -le $Packs.Count) {
                Show-PackDetail -Pack $Packs[$N-1] -Installed $Installed
            }
        }
    }
}

function Show-PackDetail {
    param($Pack, $Installed)

    while ($true) {
        Clear-Host
        Write-Host ""
        $Icon = if ($Pack.Icon) { "$($Pack.Icon) " } else { "" }
        Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║  $($Icon)$($Pack.Name.PadRight(40))║" -ForegroundColor Cyan
        Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
        if ($Pack.Description) {
            Write-Host "  $($Pack.Description)" -ForegroundColor DarkGray
        }
        Write-Host ""

        for ($i = 0; $i -lt $Pack.Apps.Count; $i++) {
            $A = $Pack.Apps[$i]
            Write-Host "  [" -NoNewline -ForegroundColor DarkGray
            Write-Host ($i+1) -NoNewline -ForegroundColor Yellow
            Write-Host "] " -NoNewline -ForegroundColor DarkGray
            Write-Host $A.Name.PadRight(30) -NoNewline -ForegroundColor Gray
            if ($A.Id -and $Installed.ContainsKey($A.Id)) {
                Write-Host " ✔ $($Installed[$A.Id])" -ForegroundColor Green
            } else {
                Write-Host " [non installé]" -ForegroundColor DarkGray
            }
        }

        Write-Host ""
        Write-Host "  [" -NoNewline -ForegroundColor DarkGray
        Write-Host "a" -NoNewline -ForegroundColor Yellow
        Write-Host "] Tout installer   [" -NoNewline -ForegroundColor DarkGray
        Write-Host "0" -NoNewline -ForegroundColor Yellow
        Write-Host "] Retour" -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "  Votre choix"

        if ($Choice -eq '0') { break }

        if ($Choice -eq 'a') {
            $AppList = $Pack.Apps | ForEach-Object { @{ Name = $_.Name ; Id = $_.Id ; Url = $_.Url } }
            $Summary = Install-AppsBatch -Apps $AppList
            Write-Host ""
            Write-Host "  ✔ $($Summary.Ok) succès" -NoNewline -ForegroundColor Green
            if ($Summary.Fail -gt 0) { Write-Host "   ✖ $($Summary.Fail) échec(s)" -NoNewline -ForegroundColor Red }
            Write-Host ""
            Read-Host "`n  Appuyez sur Entrée pour continuer"
            $Installed = Get-InstalledApps
            continue
        }

        if ($Choice -match '^\d+$') {
            $N = [int]$Choice
            if ($N -ge 1 -and $N -le $Pack.Apps.Count) {
                $A = $Pack.Apps[$N-1]
                Install-App -App @{ Name = $A.Name ; Id = $A.Id ; Url = $A.Url }
                Read-Host "`n  Appuyez sur Entrée pour continuer"
                $Installed = Get-InstalledApps
            }
        }
    }
}

Export-ModuleMember *
