<#
.SYNOPSIS
    Cache module for Software Manager Pro.
    Caches installed apps and winget query results to avoid redundant calls.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

$Script:InstalledApps  = $null
$Script:CacheLoadedAt  = $null
$Script:CacheEnabled   = $true
$Script:ExpirationHours = 24

function Initialize-Cache {
    param(
        [bool]$Enabled        = $true,
        [int]$ExpirationHours = 24
    )

    $Script:CacheEnabled      = $Enabled
    $Script:ExpirationHours   = $ExpirationHours
    Write-Log -Level "Information" -Message "Cache initialized. Enabled=$Enabled TTL=$ExpirationHours h" -Module "Cache"
}

function Get-InstalledApps {
    <#
    .SYNOPSIS
        Returns a hashtable of installed apps { Id -> Version }.
        Uses in-memory cache first, then disk cache, then live winget list.
    #>

    # Already loaded this session
    if ($null -ne $Script:InstalledApps) { return $Script:InstalledApps }

    # Try disk cache
    if ($Script:CacheEnabled) {
        $CachePath = Join-Path $Global:CachePath "InstalledApps.json"
        if (Test-Path $CachePath) {
            $Age = (Get-Date) - (Get-Item $CachePath).LastWriteTime
            if ($Age.TotalHours -lt $Script:ExpirationHours) {
                $Cached = Read-JsonFile -Path $CachePath
                if ($Cached) {
                    $Map = @{}
                    foreach ($Prop in $Cached.PSObject.Properties) { $Map[$Prop.Name] = $Prop.Value }
                    $Script:InstalledApps = $Map
                    Write-Log -Level "Debug" -Message "InstalledApps loaded from disk cache." -Module "Cache"
                    return $Map
                }
            }
        }
    }

    # Live winget list
    return Refresh-InstalledApps
}

function Refresh-InstalledApps {
    <#
    .SYNOPSIS
        Forces a fresh winget list and updates cache.
    #>

    Write-Log -Level "Information" -Message "Refreshing installed apps from winget..." -Module "Cache"

    $Map = @{}
    try {
        $Raw = winget list --accept-source-agreements 2>$null
        foreach ($Line in $Raw) {
            if ($Line -match '^\s*(.+?)\s{2,}(\S+)\s{2,}(\S+)') {
                $Id  = $Matches[2].Trim()
                $Ver = $Matches[3].Trim()
                if ($Id -and $Ver) { $Map[$Id] = $Ver }
            }
        }
    }
    catch {
        Write-Log -Level "Warning" -Message "winget list failed: $_" -Module "Cache"
    }

    $Script:InstalledApps = $Map
    $Script:CacheLoadedAt = Get-Date

    if ($Script:CacheEnabled) {
        $CachePath = Join-Path $Global:CachePath "InstalledApps.json"
        Write-JsonFile -Path $CachePath -Data ([PSCustomObject]$Map) | Out-Null
    }

    Write-Log -Level "Information" -Message "InstalledApps refreshed: $($Map.Count) apps." -Module "Cache"
    return $Map
}

function Get-InstalledVersion {
    param([string]$Id)
    $Apps = Get-InstalledApps
    if ($Apps.ContainsKey($Id)) { return $Apps[$Id] }
    return $null
}

function Clear-Cache {
    $Script:InstalledApps = $null
    $Script:CacheLoadedAt = $null
    $CachePath = Join-Path $Global:CachePath "InstalledApps.json"
    if (Test-Path $CachePath) { Remove-Item $CachePath -Force }
    Write-Log -Level "Information" -Message "Cache cleared." -Module "Cache"
}

function Update-CachedVersion {
    param([string]$Id, [string]$Version)
    if ($null -ne $Script:InstalledApps) {
        $Script:InstalledApps[$Id] = $Version
    }
}

Export-ModuleMember *
