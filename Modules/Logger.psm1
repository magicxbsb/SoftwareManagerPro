<#
.SYNOPSIS
    Logger module for Software Manager Pro.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

$Script:LogFile = $null
$Script:LogLevel = "Information"
$Script:LogEnabled = $true

$Script:LevelOrder = @{ "Debug" = 0; "Information" = 1; "Warning" = 2; "Error" = 3 }

function Initialize-Logger {
    param(
        [string]$LogFolder = $Global:LogsPath,
        [string]$Level     = "Information",
        [bool]$Enabled     = $true
    )

    $Script:LogEnabled = $Enabled
    $Script:LogLevel   = $Level

    if (-not $Enabled) { return }

    if (-not (Test-Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
    }

    $Date = (Get-Date).ToString("yyyy-MM-dd")
    $Script:LogFile = Join-Path $LogFolder "SMP_$Date.log"

    Write-Log -Level "Information" -Message "Logger initialized. Level=$Level"
}

function Write-Log {
    param(
        [ValidateSet("Debug","Information","Warning","Error")]
        [string]$Level   = "Information",
        [string]$Message = "",
        [string]$Module  = ""
    )

    if (-not $Script:LogEnabled) { return }
    if ($Script:LevelOrder[$Level] -lt $Script:LevelOrder[$Script:LogLevel]) { return }

    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $Prefix    = if ($Module) { "[$Module]" } else { "" }
    $Line      = "$Timestamp [$Level] $Prefix $Message"

    try {
        Add-Content -Path $Script:LogFile -Value $Line -ErrorAction SilentlyContinue
    } catch {}
}

function Clear-OldLogs {
    param([int]$RetentionDays = 30)

    if (-not $Script:LogEnabled) { return }

    $Cutoff = (Get-Date).AddDays(-$RetentionDays)
    Get-ChildItem -Path $Global:LogsPath -Filter "SMP_*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $Cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Log -Level "Information" -Message "Old logs cleaned (>$RetentionDays days)."
}

Export-ModuleMember *
