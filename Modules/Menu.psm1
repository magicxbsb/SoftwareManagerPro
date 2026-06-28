<#
.SYNOPSIS
    Menu module for Software Manager Pro.
    Main navigation, category screens, source comparison.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

# ── Flatten a group into a flat app list ─────────────────────────────────────
function Get-FlatApps {
    param($GroupItems)
    $List = @()
    foreach ($Item in $GroupItems) {
        if ($Item -is [hashtable] -and $Item.ContainsKey('Sub')) { $List += $Item.Apps }
        elseif ($Item.PSObject.Properties['Sub'])                { $List += $Item.Apps }
        else                                                     { $List += $Item }
    }
    return $List
}

# ── Source comparison screen (called when user picks a specific app) ──────────
function Show-SourceComparison {
    param($App, [hashtable]$InstalledVersions)

    # Web-only app
    if (-not $App.Id) {
        Write-Host ""
        Write-Host "  ► Ouverture navigateur pour $($App.Name)..." -ForegroundColor $Global:C.Warn
        Start-Process $App.Url
        Write-Host "  ↗ Navigateur ouvert." -ForegroundColor $Global:C.Warn
        return
    }

    Write-Host ""
    Write-Host "  Recherche des versions disponibles..." -ForegroundColor $Global:C.Dim

    $VerWinget  = Get-AvailableVersion -Id $App.Id -Source "winget"
    $VerMsstore = Get-AvailableVersion -Id $App.Id -Source "msstore"
    $VerInstall = if ($InstalledVersions -and $InstalledVersions.ContainsKey($App.Id)) { $InstalledVersions[$App.Id] } else { $null }
    $Best       = Get-BestSource -VersionWinget $VerWinget -VersionMsstore $VerMsstore

    $CleanName = $App.Name -replace '\s*[\^↗]\s*$', ''

    Clear-Host
    Show-Header -Title $CleanName

    if ($VerInstall) {
        Write-Host "  Installée actuellement : " -NoNewline -ForegroundColor $Global:C.Dim
        Write-Host $VerInstall -ForegroundColor $Global:C.OK
        Write-Host ""
    }

    Show-SourceTable -VerWinget $VerWinget -VerMsstore $VerMsstore `
                     -VerInstalled $VerInstall -BestSource $Best

    Write-Host ""
    Write-Host "  [" -NoNewline -ForegroundColor $Global:C.Dim
    Write-Host "1" -NoNewline -ForegroundColor $Global:C.Num
    Write-Host "] winget   [" -NoNewline -ForegroundColor $Global:C.Dim
    Write-Host "2" -NoNewline -ForegroundColor $Global:C.Num
    Write-Host "] msstore   [" -NoNewline -ForegroundColor $Global:C.Dim
    Write-Host "f" -NoNewline -ForegroundColor $Global:C.Num
    Write-Host "] Ajouter aux favoris   [" -NoNewline -ForegroundColor $Global:C.Dim
    Write-Host "0" -NoNewline -ForegroundColor $Global:C.Num
    Write-Host "] Annuler" -ForegroundColor $Global:C.Dim
    Write-Host ""

    $SrcChoice = Read-Host "  Votre choix"

    if ($SrcChoice -eq 'f') {
        Add-Favorite -App @{ Name = $App.Name ; Id = $App.Id ; Url = $App.Url }
        return
    }

    $SourceMap = @{ "1" = "winget" ; "2" = "msstore" }
    if (-not $SourceMap.ContainsKey($SrcChoice)) {
        Write-Host "  Annulé." -ForegroundColor $Global:C.Dim
        return
    }

    $ChosenSource = $SourceMap[$SrcChoice]
    $ChosenVer    = if ($ChosenSource -eq "winget") { $VerWinget } else { $VerMsstore }

    if (-not $ChosenVer) {
        Write-Host "  ✖ Non disponible sur $ChosenSource." -ForegroundColor $Global:C.Err
        return
    }

    Install-App -App @{ Name = $App.Name ; Id = $App.Id ; Url = $App.Url } -Source $ChosenSource
}

# ── Category screen ────────────────────────────────────────────────────────────
function Show-Category {
    param([string]$CatName, $GroupItems)

    while ($true) {
        Write-Host ""
        Write-Host "  Chargement des versions..." -ForegroundColor $Global:C.Dim
        $Versions = Get-InstalledApps

        $FlatApps = @()
        Clear-Host
        Show-Header -Title $CatName

        $Idx = 1
        foreach ($Item in $GroupItems) {

            $HasSub = ($Item -is [hashtable] -and $Item.ContainsKey('Sub')) -or
                      ($Item.PSObject.Properties['Sub'] -and $Item.Sub)

            if ($HasSub) {
                Show-Separator -Label $Item.Sub
                foreach ($App in $Item.Apps) {
                    Write-Host "  [" -NoNewline -ForegroundColor $Global:C.Dim
                    Write-Host $Idx -NoNewline -ForegroundColor $Global:C.Num
                    Write-Host "] " -NoNewline -ForegroundColor $Global:C.Dim
                    Write-Host $App.Name -NoNewline -ForegroundColor $Global:C.Default
                    Show-VersionBadge -Id $App.Id -Versions $Versions
                    Write-Host ""
                    $FlatApps += $App
                    $Idx++
                }
                Write-Host ""
            } else {
                Write-Host "  [" -NoNewline -ForegroundColor $Global:C.Dim
                Write-Host $Idx -NoNewline -ForegroundColor $Global:C.Num
                Write-Host "] " -NoNewline -ForegroundColor $Global:C.Dim
                Write-Host $Item.Name -NoNewline -ForegroundColor $Global:C.Default
                Show-VersionBadge -Id $Item.Id -Versions $Versions
                Write-Host ""
                $FlatApps += $Item
                $Idx++
            }
        }

        $Total = $FlatApps.Count
        Write-Host ""
        Show-Separator -Label "Actions"
        Show-MenuItem -Key "1-$Total" -Label "Comparer les sources et installer"
        Show-MenuItem -Key "a"        -Label "Tout installer via winget (auto)"
        Show-MenuItem -Key "u"        -Label "Vérifier les mises à jour"
        Show-MenuItem -Key "0"        -Label "Retour au menu principal"
        Write-Host ""

        $Choice = Read-Host "  Votre choix"

        if ($Choice -eq '0') { break }

        if ($Choice -eq 'a') {
            Write-Host ""
            Write-Host "  ► Installation de $Total apps via winget..." -ForegroundColor $Global:C.OK
            $FlatList = $FlatApps | ForEach-Object {
                if ($_ -is [hashtable]) { $_ }
                else { @{ Name = $_.Name ; Id = $_.Id ; Url = $_.Url } }
            }
            $Summary = Install-AppsBatch -Apps $FlatList
            Write-Host ""
            Write-Host "  ✔ $($Summary.Ok) succès" -NoNewline -ForegroundColor $Global:C.OK
            if ($Summary.Fail -gt 0) { Write-Host "   ✖ $($Summary.Fail) échec(s)" -NoNewline -ForegroundColor $Global:C.Err }
            Write-Host ""
            Wait-UserInput
            continue
        }

        if ($Choice -eq 'u') {
            Show-UpdatesMenu
            continue
        }

        if ($Choice -match '^\d+$') {
            $N = [int]$Choice
            if ($N -ge 1 -and $N -le $Total) {
                $Selected = $FlatApps[$N-1]
                $AppHash  = if ($Selected -is [hashtable]) { $Selected }
                            else { @{ Name = $Selected.Name ; Id = $Selected.Id ; Url = $Selected.Url } }
                Show-SourceComparison -App $AppHash -InstalledVersions $Versions
                Wait-UserInput
            } else {
                Write-Host "  ✖ Numéro invalide (1–$Total)." -ForegroundColor $Global:C.Err
                Start-Sleep -Seconds 1.5
            }
            continue
        }

        Write-Host "  ✖ Commande inconnue : '$Choice'" -ForegroundColor $Global:C.Err
        Start-Sleep -Seconds 1.5
    }
}

# ── Main menu ──────────────────────────────────────────────────────────────────
function Show-MainMenu {
    param([System.Collections.Specialized.OrderedDictionary]$AppMenu)

    while ($true) {
        Show-Banner

        # Pending updates count
        $UpdateCount = 0
        try {
            $Raw = winget upgrade --accept-source-agreements 2>$null | Select-String "^\w"
            $UpdateCount = if ($Raw) { ($Raw | Measure-Object).Count - 1 } else { 0 }
            if ($UpdateCount -lt 0) { $UpdateCount = 0 }
        } catch {}

        if ($UpdateCount -gt 0) {
            Write-Host "  ⚡ $UpdateCount mise(s) à jour disponible(s)" -ForegroundColor $Global:C.Warn
            Write-Host ""
        }

        # Category entries
        $Keys = $AppMenu.Keys
        $i    = 1
        foreach ($Key in $Keys) {
            $Count = (Get-FlatApps -GroupItems $AppMenu[$Key]).Count
            Show-MenuItem -Key $i -Label "$Key ($Count apps)"
            $i++
        }

        Write-Host ""
        Show-Separator -Label "Outils"
        Show-MenuItem -Key "f" -Label "Favoris"
        Show-MenuItem -Key "k" -Label "Packs d'applications"
        Show-MenuItem -Key "p" -Label "Profils"
        Show-MenuItem -Key "u" -Label "Mises à jour"
        Show-MenuItem -Key "d" -Label "Désinstaller"
        Show-MenuItem -Key "s" -Label "Rechercher"
        Show-MenuItem -Key "q" -Label "Quitter"
        Write-Host ""

        $Rep = Read-Host "  Sélectionner"

        switch ($Rep) {
            'q' { Write-Host "`n  Au revoir !`n" -ForegroundColor $Global:C.OK ; return }
            'f' { Show-FavoritesMenu  ; continue }
            'k' { Show-PacksMenu      ; continue }
            'p' { Show-ProfilesMenu   ; continue }
            'u' { Show-UpdatesMenu    ; continue }
            'd' { Show-UninstallMenu  ; continue }
            's' { Show-SearchMenu     ; continue }
        }

        if ($Rep -match '^\d+$') {
            $N = [int]$Rep
            if ($N -ge 1 -and $N -le $Keys.Count) {
                $SelKey = @($Keys)[$N-1]
                Show-Category -CatName $SelKey -GroupItems $AppMenu[$SelKey]
            } else {
                Write-Host "  ✖ Numéro invalide." -ForegroundColor $Global:C.Err
                Start-Sleep -Seconds 1.5
            }
        } else {
            Write-Host "  ✖ Commande inconnue : '$Rep'" -ForegroundColor $Global:C.Err
            Start-Sleep -Seconds 1.5
        }
    }
}

Export-ModuleMember *
