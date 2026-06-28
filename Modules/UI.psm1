<#
.SYNOPSIS
    UI module for Software Manager Pro.
    All display helpers, banners, tables, badges, progress bars.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

# ── Color palette ──────────────────────────────────────────────────────────────
$Global:C = @{
    Title   = 'Magenta'
    Header  = 'Cyan'
    Sub     = 'DarkCyan'
    Num     = 'Yellow'
    OK      = 'Green'
    Warn    = 'DarkYellow'
    Err     = 'Red'
    Dim     = 'DarkGray'
    Default = 'Gray'
    New     = 'Green'
    Old     = 'DarkYellow'
    White   = 'White'
}

# ── Banner ──────────────────────────────────────────────────────────────────────
function Show-Banner {
    param([string]$Subtitle = "")

    $Ver = "v1.0.0"
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor $Global:C.Title
    Write-Host "  ║        SOFTWARE MANAGER PRO  $($Ver.PadRight(15))║" -ForegroundColor $Global:C.Title
    Write-Host "  ║        by Moustapha SOUMAH                   ║" -ForegroundColor $Global:C.Dim
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor $Global:C.Title
    if ($Subtitle) {
        Write-Host "  $Subtitle" -ForegroundColor $Global:C.Dim
    }
    Write-Host ""
}

# ── Section header ──────────────────────────────────────────────────────────────
function Show-Header {
    param([string]$Title)

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor $Global:C.Header
    Write-Host "  ║  $($Title.PadRight(42))║" -ForegroundColor $Global:C.Header
    Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor $Global:C.Header
    Write-Host ""
}

# ── Separator ───────────────────────────────────────────────────────────────────
function Show-Separator {
    param([string]$Label = "", [string]$Color = "DarkCyan")

    if ($Label) {
        $Dashes = "─" * [Math]::Max(2, 38 - $Label.Length)
        Write-Host "  ── $Label " -NoNewline -ForegroundColor $Color
        Write-Host $Dashes -ForegroundColor $Global:C.Dim
    } else {
        Write-Host "  " + ("─" * 44) -ForegroundColor $Global:C.Dim
    }
}

# ── Version badge ───────────────────────────────────────────────────────────────
function Show-VersionBadge {
    param([string]$Id, [hashtable]$Versions)

    if ($Id -and $Versions -and $Versions.ContainsKey($Id)) {
        Write-Host " [" -NoNewline -ForegroundColor $Global:C.Dim
        Write-Host $Versions[$Id] -NoNewline -ForegroundColor $Global:C.OK
        Write-Host "]" -NoNewline -ForegroundColor $Global:C.Dim
    } elseif ($Id) {
        Write-Host " [non installé]" -NoNewline -ForegroundColor $Global:C.Dim
    } else {
        Write-Host " [lien web]" -NoNewline -ForegroundColor $Global:C.Warn
    }
}

# ── Menu item ───────────────────────────────────────────────────────────────────
function Show-MenuItem {
    param(
        [string]$Key,
        [string]$Label,
        [string]$KeyColor  = "Yellow",
        [string]$LabelColor = "Gray"
    )

    Write-Host "  [" -NoNewline -ForegroundColor $Global:C.Dim
    Write-Host $Key -NoNewline -ForegroundColor $KeyColor
    Write-Host "] " -NoNewline -ForegroundColor $Global:C.Dim
    Write-Host $Label -ForegroundColor $LabelColor
}

# ── Source comparison table ──────────────────────────────────────────────────────
function Show-SourceTable {
    param(
        [string]$VerWinget,
        [string]$VerMsstore,
        [string]$VerInstalled,
        [string]$BestSource
    )

    Write-Host "  ┌─────────────┬──────────────────┬──────────────────────┐" -ForegroundColor $Global:C.Dim
    Write-Host "  │ " -NoNewline -ForegroundColor $Global:C.Dim
    Write-Host "Source      " -NoNewline -ForegroundColor $Global:C.Default
    Write-Host " │ " -NoNewline -ForegroundColor $Global:C.Dim
    Write-Host "Version dispo   " -NoNewline -ForegroundColor $Global:C.Default
    Write-Host " │ " -NoNewline -ForegroundColor $Global:C.Dim
    Write-Host "Statut              " -NoNewline -ForegroundColor $Global:C.Default
    Write-Host " │" -ForegroundColor $Global:C.Dim
    Write-Host "  ├─────────────┼──────────────────┼──────────────────────┤" -ForegroundColor $Global:C.Dim

    foreach ($Src in @("winget","msstore")) {
        $Ver  = if ($Src -eq "winget") { $VerWinget } else { $VerMsstore }
        $Num  = if ($Src -eq "winget") { "1" } else { "2" }
        $Key  = "[" + $Num + "] " + $Src.PadRight(8)

        Write-Host "  │ " -NoNewline -ForegroundColor $Global:C.Dim
        Write-Host $Key -NoNewline -ForegroundColor $Global:C.Num
        Write-Host " │ " -NoNewline -ForegroundColor $Global:C.Dim

        if ($Ver) {
            $Col = if ($BestSource -eq $Src) { $Global:C.New } else { $Global:C.Default }
            Write-Host $Ver.PadRight(16) -NoNewline -ForegroundColor $Col
        } else {
            Write-Host "non dispo       " -NoNewline -ForegroundColor $Global:C.Dim
        }

        Write-Host " │ " -NoNewline -ForegroundColor $Global:C.Dim

        $Status = Get-SourceStatus -Source $Src -Ver $Ver -BestSource $BestSource -VerInstalled $VerInstalled -VerWinget $VerWinget -VerMsstore $VerMsstore
        Write-Host $Status.Text.PadRight(21) -NoNewline -ForegroundColor $Status.Color
        Write-Host "│" -ForegroundColor $Global:C.Dim
    }

    Write-Host "  └─────────────┴──────────────────┴──────────────────────┘" -ForegroundColor $Global:C.Dim
}

function Get-SourceStatus {
    param($Source, $Ver, $BestSource, $VerInstalled, $VerWinget, $VerMsstore)

    if (-not $Ver)                        { return @{ Text = "indisponible";     Color = $Global:C.Dim  } }
    if ($BestSource -eq $Source)          { return @{ Text = "★ plus récent";    Color = $Global:C.New  } }
    if ($BestSource -and $BestSource -ne $Source -and $BestSource -ne "equal") {
                                            return @{ Text = "version ancienne"; Color = $Global:C.Old  } }
    if ($VerInstalled -and $VerInstalled -eq $Ver) {
                                            return @{ Text = "déjà installé";    Color = $Global:C.OK   } }
                                            return @{ Text = "identique";        Color = $Global:C.Default }
}

# ── Progress bar ────────────────────────────────────────────────────────────────
function Show-ProgressBar {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Label = ""
    )

    $Pct  = if ($Total -gt 0) { [Math]::Round($Current / $Total * 100) } else { 0 }
    $Bars = [Math]::Floor($Pct / 5)
    $Bar  = "█" * $Bars + "░" * (20 - $Bars)

    Write-Host "`r  [$Bar] $Pct% $Label   " -NoNewline -ForegroundColor $Global:C.Header
}

# ── Startup steps display ───────────────────────────────────────────────────────
function Show-StartupStep {
    param([int]$Step, [int]$Total, [string]$Label, [string]$Status = "...")

    $Cols = @{ "..." = $Global:C.Dim; "OK" = $Global:C.OK; "FAIL" = $Global:C.Err; "SKIP" = $Global:C.Warn }
    $Col  = if ($Cols.ContainsKey($Status)) { $Cols[$Status] } else { $Global:C.Default }

    Write-Host "  [$Step/$Total] $Label" -NoNewline -ForegroundColor $Global:C.Dim
    Write-Host " $Status" -ForegroundColor $Col
}

# ── Pause ────────────────────────────────────────────────────────────────────────
function Wait-UserInput {
    param([string]$Prompt = "  Appuyez sur Entrée pour continuer")
    Write-Host ""
    Read-Host $Prompt
}

Export-ModuleMember *
