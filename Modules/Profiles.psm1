<#
.SYNOPSIS
    Profiles module for Software Manager Pro.
    A profile is a named collection of apps (e.g. "Gaming PC", "Streaming PC").
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

function Get-ProfilesPath {
    return Join-Path $Global:ConfigPath "Profiles"
}

function Get-AllProfiles {
    $Path = Get-ProfilesPath
    if (-not (Test-Path $Path)) { return @() }

    return Get-ChildItem -Path $Path -Filter "*.json" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $Data = Read-JsonFile -Path $_.FullName
            if ($Data) { $Data }
        }
}

function New-Profile {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Description = ""
    )

    $Path    = Get-ProfilesPath
    $File    = Join-Path $Path "$($Name -replace '[^\w]','_').json"

    if (Test-Path $File) {
        Write-Host "  ⚠ Profile '$Name' already exists." -ForegroundColor DarkYellow
        return $null
    }

    $Profile = [PSCustomObject]@{
        Name        = $Name
        Description = $Description
        CreatedAt   = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        Apps        = @()
    }

    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }

    Write-JsonFile -Path $File -Data $Profile | Out-Null
    Write-Host "  ✔ Profile '$Name' created." -ForegroundColor Green
    Write-Log -Level "Information" -Message "Profile created: $Name" -Module "Profiles"
    return $Profile
}

function Add-AppToProfile {
    param(
        [Parameter(Mandatory)][string]$ProfileName,
        [Parameter(Mandatory)][hashtable]$App
    )

    $Path = Get-ProfilesPath
    $File = Join-Path $Path "$($ProfileName -replace '[^\w]','_').json"

    if (-not (Test-Path $File)) {
        Write-Host "  ✖ Profile '$ProfileName' not found." -ForegroundColor Red
        return
    }

    $Profile = Read-JsonFile -Path $File
    $Exists  = $Profile.Apps | Where-Object { $_.Id -eq $App.Id }

    if ($Exists) {
        Write-Host "  ⚠ App already in profile." -ForegroundColor DarkYellow
        return
    }

    $Profile.Apps += [PSCustomObject]@{ Name = $App.Name ; Id = $App.Id ; Url = $App.Url }
    Write-JsonFile -Path $File -Data $Profile | Out-Null
    Write-Host "  ✔ Added '$($App.Name)' to profile '$ProfileName'." -ForegroundColor Green
}

function Install-Profile {
    param([Parameter(Mandatory)]$Profile)

    Write-Host ""
    Write-Host "  ► Installing profile: $($Profile.Name) ($($Profile.Apps.Count) apps)" -ForegroundColor Green
    Write-Log -Level "Information" -Message "Installing profile: $($Profile.Name)" -Module "Profiles"

    $AppList = $Profile.Apps | ForEach-Object { @{ Name = $_.Name ; Id = $_.Id ; Url = $_.Url } }
    $Summary = Install-AppsBatch -Apps $AppList

    Write-Host ""
    Write-Host "  ✔ $($Summary.Ok) succès" -NoNewline -ForegroundColor Green
    if ($Summary.Fail -gt 0) { Write-Host "   ✖ $($Summary.Fail) échec(s)" -NoNewline -ForegroundColor Red }
    Write-Host ""
}

function Show-ProfilesMenu {
    while ($true) {
        $Profiles = Get-AllProfiles

        Clear-Host
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║  PROFILS D'INSTALLATION                  ║" -ForegroundColor Cyan
        Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""

        if ($Profiles.Count -eq 0) {
            Write-Host "  Aucun profil. Créez-en un avec [n]." -ForegroundColor DarkGray
        } else {
            for ($i = 0; $i -lt $Profiles.Count; $i++) {
                $P = $Profiles[$i]
                Write-Host "  [" -NoNewline -ForegroundColor DarkGray
                Write-Host ($i+1) -NoNewline -ForegroundColor Yellow
                Write-Host "] " -NoNewline -ForegroundColor DarkGray
                Write-Host $P.Name.PadRight(25) -NoNewline -ForegroundColor Gray
                Write-Host "$($P.Apps.Count) apps" -NoNewline -ForegroundColor DarkGray
                if ($P.Description) { Write-Host " — $($P.Description)" -ForegroundColor DarkGray } else { Write-Host "" }
            }
        }

        Write-Host ""
        Write-Host "  [" -NoNewline -ForegroundColor DarkGray
        Write-Host "n" -NoNewline -ForegroundColor Yellow
        Write-Host "] Nouveau profil   [" -NoNewline -ForegroundColor DarkGray
        Write-Host "0" -NoNewline -ForegroundColor Yellow
        Write-Host "] Retour" -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "  Votre choix"

        if ($Choice -eq '0') { break }

        if ($Choice -eq 'n') {
            $PName = Read-Host "  Nom du profil"
            $PDesc = Read-Host "  Description (optionnel)"
            New-Profile -Name $PName -Description $PDesc | Out-Null
            Start-Sleep -Seconds 1
            continue
        }

        if ($Choice -match '^\d+$') {
            $N = [int]$Choice
            if ($N -ge 1 -and $N -le $Profiles.Count) {
                $Selected = $Profiles[$N-1]
                Write-Host ""
                Write-Host "  Profil : $($Selected.Name)" -ForegroundColor Cyan
                Write-Host "  Apps   : $($Selected.Apps.Count)" -ForegroundColor DarkGray
                Write-Host ""
                Write-Host "  [i] Installer   [0] Retour"
                $Sub = Read-Host "  Choix"
                if ($Sub -eq 'i') {
                    Install-Profile -Profile $Selected
                    Read-Host "`n  Appuyez sur Entrée pour continuer"
                }
            }
        }
    }
}

Export-ModuleMember *
