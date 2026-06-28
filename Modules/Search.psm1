<#
.SYNOPSIS
    Search module for Software Manager Pro.
    Searches both the local app catalog and winget.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

function Search-LocalCatalog {
    <#
    .SYNOPSIS
        Searches all loaded App JSON files for a keyword.
        Returns matching app objects.
    #>
    param([Parameter(Mandatory)][string]$Query)

    $Results  = @()
    $AppsPath = Join-Path $Global:AppRoot "Apps"

    if (-not (Test-Path $AppsPath)) { return $Results }

    $Files = Get-ChildItem -Path $AppsPath -Filter "*.json" -ErrorAction SilentlyContinue

    foreach ($File in $Files) {
        $Data = Read-JsonFile -Path $File.FullName
        if ($null -eq $Data) { continue }

        $Category = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)

        foreach ($Group in $Data) {
            $Apps = if ($Group.PSObject.Properties['Apps']) { $Group.Apps } else { @($Group) }
            foreach ($App in $Apps) {
                if (-not $App.Name -and -not $App.Id) { continue }
                $HitName = $App.Name -match [regex]::Escape($Query)
                $HitId   = $App.Id  -match [regex]::Escape($Query)
                if ($HitName -or $HitId) {
                    $Results += [PSCustomObject]@{
                        Name     = $App.Name
                        Id       = $App.Id
                        Category = $Category
                        Url      = $App.Url
                    }
                }
            }
        }
    }

    return $Results
}

function Search-Winget {
    <#
    .SYNOPSIS
        Runs winget search and returns structured results.
    #>
    param(
        [Parameter(Mandatory)][string]$Query,
        [int]$MaxResults = 15
    )

    $Results = @()

    try {
        $Raw     = winget search $Query --accept-source-agreements 2>$null
        $Started = $false

        foreach ($Line in $Raw) {
            if ($Line -match '^[-]+$') { $Started = $true ; continue }
            if (-not $Started) { continue }
            if ([string]::IsNullOrWhiteSpace($Line)) { continue }

            $Parts = ($Line -split '\s{2,}') | Where-Object { $_ -ne '' }
            if ($Parts.Count -ge 3) {
                $Results += [PSCustomObject]@{
                    Name    = $Parts[0].Trim()
                    Id      = $Parts[1].Trim()
                    Version = $Parts[2].Trim()
                    Source  = if ($Parts.Count -ge 4) { $Parts[-1].Trim() } else { "winget" }
                }
            }

            if ($Results.Count -ge $MaxResults) { break }
        }
    }
    catch {
        Write-Log -Level "Warning" -Message "winget search failed: $_" -Module "Search"
    }

    return $Results
}

function Show-SearchMenu {
    <#
    .SYNOPSIS
        Interactive search screen — searches local catalog + winget.
    #>

    while ($true) {
        Clear-Host
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║  RECHERCHE D'APPLICATION                 ║" -ForegroundColor Cyan
        Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [0] Retour" -ForegroundColor DarkGray
        Write-Host ""

        $Query = Read-Host "  Rechercher"

        if ($Query -eq '0' -or [string]::IsNullOrWhiteSpace($Query)) { break }

        Clear-Host
        Write-Host ""
        Write-Host "  Recherche de '$Query'..." -ForegroundColor DarkGray
        Write-Host ""

        # Local catalog
        $Local = Search-LocalCatalog -Query $Query
        if ($Local.Count -gt 0) {
            Write-Host "  ── Catalogue local ─────────────────────" -ForegroundColor DarkCyan
            foreach ($R in $Local) {
                Write-Host "  " -NoNewline
                Write-Host $R.Name.PadRight(30) -NoNewline -ForegroundColor Gray
                Write-Host $R.Id.PadRight(30) -NoNewline -ForegroundColor DarkGray
                Write-Host "[$($R.Category)]" -ForegroundColor DarkCyan
            }
            Write-Host ""
        }

        # Winget
        Write-Host "  ── Winget ──────────────────────────────" -ForegroundColor DarkCyan
        $WingetResults = Search-Winget -Query $Query
        if ($WingetResults.Count -eq 0) {
            Write-Host "  Aucun résultat winget." -ForegroundColor DarkGray
        } else {
            $Installed = Get-InstalledApps
            for ($i = 0; $i -lt $WingetResults.Count; $i++) {
                $R = $WingetResults[$i]
                Write-Host "  [" -NoNewline -ForegroundColor DarkGray
                Write-Host ($i+1) -NoNewline -ForegroundColor Yellow
                Write-Host "] " -NoNewline -ForegroundColor DarkGray
                Write-Host $R.Name.PadRight(30) -NoNewline -ForegroundColor Gray
                Write-Host $R.Id.PadRight(30) -NoNewline -ForegroundColor DarkGray
                Write-Host $R.Version.PadRight(10) -NoNewline -ForegroundColor DarkGray
                if ($Installed.ContainsKey($R.Id)) {
                    Write-Host " ✔" -ForegroundColor Green
                } else {
                    Write-Host ""
                }
            }
        }

        Write-Host ""
        Write-Host "  Entrez un numéro pour installer, [" -NoNewline -ForegroundColor DarkGray
        Write-Host "r" -NoNewline -ForegroundColor Yellow
        Write-Host "] pour rechercher à nouveau, [" -NoNewline -ForegroundColor DarkGray
        Write-Host "0" -NoNewline -ForegroundColor Yellow
        Write-Host "] pour retourner." -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "  Votre choix"

        if ($Choice -eq '0') { break }
        if ($Choice -eq 'r') { continue }

        if ($Choice -match '^\d+$') {
            $N = [int]$Choice
            if ($N -ge 1 -and $N -le $WingetResults.Count) {
                $Selected = $WingetResults[$N-1]
                $AppHash  = @{ Name = $Selected.Name ; Id = $Selected.Id }
                $Result   = Install-App -App $AppHash -Source $Selected.Source
                Read-Host "`n  Appuyez sur Entrée pour continuer"
            }
        }
    }
}

Export-ModuleMember *
