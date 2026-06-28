<#
.SYNOPSIS
    Version comparison and availability checks for Software Manager Pro.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

function Get-AvailableVersion {
    <#
    .SYNOPSIS
        Returns the available version of an app from a given source (winget or msstore).
    #>
    param(
        [Parameter(Mandatory)][string]$Id,
        [ValidateSet("winget","msstore")]
        [string]$Source = "winget"
    )

    try {
        $Raw = winget show --id $Id --exact --source $Source `
               --accept-source-agreements 2>$null
        $Line = $Raw | Select-String '^\s*Version\s*:\s*(.+)$'
        if ($Line) {
            return $Line.Matches[0].Groups[1].Value.Trim()
        }
    }
    catch {}

    return $null
}

function Compare-Versions {
    <#
    .SYNOPSIS
        Compares two version strings. Returns 1 if A > B, -1 if A < B, 0 if equal.
    #>
    param(
        [string]$VersionA,
        [string]$VersionB
    )

    if (-not $VersionA -and -not $VersionB) { return 0 }
    if (-not $VersionA) { return -1 }
    if (-not $VersionB) { return 1 }
    if ($VersionA -eq $VersionB) { return 0 }

    try {
        $CleanA = $VersionA -replace '[^\d.]',''
        $CleanB = $VersionB -replace '[^\d.]',''
        $vA = [System.Version]$CleanA
        $vB = [System.Version]$CleanB
        return $vA.CompareTo($vB)
    }
    catch {
        return [string]::Compare($VersionA, $VersionB)
    }
}

function Get-BestSource {
    <#
    .SYNOPSIS
        Returns which source (winget or msstore) has the most recent version.
        Returns "winget", "msstore", or "equal".
    #>
    param(
        [string]$VersionWinget,
        [string]$VersionMsstore
    )

    if (-not $VersionWinget -and -not $VersionMsstore) { return $null }
    if (-not $VersionWinget)  { return "msstore" }
    if (-not $VersionMsstore) { return "winget"  }

    $Cmp = Compare-Versions -VersionA $VersionWinget -VersionB $VersionMsstore
    if ($Cmp -gt 0) { return "winget"  }
    if ($Cmp -lt 0) { return "msstore" }
    return "equal"
}

function Test-UpdateAvailable {
    <#
    .SYNOPSIS
        Returns $true if the available version is newer than the installed version.
    #>
    param(
        [string]$InstalledVersion,
        [string]$AvailableVersion
    )

    if (-not $InstalledVersion -or -not $AvailableVersion) { return $false }
    return (Compare-Versions -VersionA $AvailableVersion -VersionB $InstalledVersion) -gt 0
}

Export-ModuleMember *
