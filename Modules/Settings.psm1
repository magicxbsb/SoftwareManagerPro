<#
.SYNOPSIS
    Settings loader for Software Manager Pro.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

$Script:Settings = $null

function Get-Settings {
    $Path = Join-Path $Global:ConfigPath "Settings.json"
    $Data = Read-JsonFile -Path $Path

    if ($null -eq $Data) {
        Write-Host "  ⚠ Settings not found, using defaults." -ForegroundColor DarkYellow
        $Data = Get-DefaultSettings
    }

    $Script:Settings = $Data
    Write-Log -Level "Information" -Message "Settings loaded." -Module "Settings"
    return $Data
}

function Get-Setting {
    param([string]$Key)
    # Key format: "Section.Property"  e.g. "Cache.Enabled"
    $Parts = $Key -split '\.'
    $Node  = $Script:Settings
    foreach ($Part in $Parts) {
        if ($null -eq $Node) { return $null }
        $Node = $Node.$Part
    }
    return $Node
}

function Set-Setting {
    param([string]$Key, $Value)

    $Parts  = $Key -split '\.'
    $Node   = $Script:Settings
    for ($i = 0; $i -lt $Parts.Count - 1; $i++) {
        $Node = $Node.($Parts[$i])
    }
    $Node.($Parts[-1]) = $Value

    $Path = Join-Path $Global:ConfigPath "Settings.json"
    Write-JsonFile -Path $Path -Data $Script:Settings | Out-Null
    Write-Log -Level "Information" -Message "Setting updated: $Key = $Value" -Module "Settings"
}

function Get-DefaultSettings {
    return [PSCustomObject]@{
        Application  = [PSCustomObject]@{ Name = "Software Manager Pro"; Version = "1.0.0"; Language = "fr-FR"; Theme = "Dark" }
        Sources      = [PSCustomObject]@{ PreferredSource = "Auto"; EnableWinget = $true; EnableMicrosoftStore = $true; EnableOfficialWebsite = $true }
        Installation = [PSCustomObject]@{ PreferredChannel = "Stable"; AskChannelEachTime = $false; RunAsAdministrator = $true; ParallelInstallations = $false; MaximumParallelJobs = 2 }
        Cache        = [PSCustomObject]@{ Enabled = $true; ExpirationHours = 24; InstalledAppsCache = "Cache/InstalledApps.json"; WingetCache = "Cache/Winget.json" }
        Logging      = [PSCustomObject]@{ Enabled = $true; Level = "Information"; RetentionDays = 30 }
        Security     = [PSCustomObject]@{ ConfirmUninstall = $true; ConfirmMassInstall = $true; ConfirmMassUpdate = $true }
        Interface    = [PSCustomObject]@{ ShowBanner = $true; ShowProgressBar = $true; AccentColor = "Cyan" }
        Developer    = [PSCustomObject]@{ DebugMode = $false; VerboseLogs = $false }
        Favorites    = [PSCustomObject]@{ File = "Config/Favorites.json" }
        Profiles     = [PSCustomObject]@{ Folder = "Config/Profiles" }
        Packs        = [PSCustomObject]@{ Folder = "Config/Packs" }
        Downloads    = [PSCustomObject]@{ Folder = "Downloads"; DeleteAfterInstall = $true }
    }
}

Export-ModuleMember *
