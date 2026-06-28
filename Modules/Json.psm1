<#
.SYNOPSIS
    JSON read/write helpers for Software Manager Pro.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

function Read-JsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$Ordered
    )

    if (-not (Test-Path $Path)) { return $null }

    try {
        $Raw = Get-Content -Path $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
        return $Raw | ConvertFrom-Json -AsHashtable:$Ordered.IsPresent
    }
    catch {
        Write-Log -Level "Error" -Message "Failed to read JSON: $Path — $_" -Module "Json"
        return $null
    }
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Data,
        [int]$Depth = 10
    )

    try {
        $Dir = Split-Path $Path
        if ($Dir -and -not (Test-Path $Dir)) {
            New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        }
        $Data | ConvertTo-Json -Depth $Depth | Set-Content -Path $Path -Encoding UTF8
        return $true
    }
    catch {
        Write-Log -Level "Error" -Message "Failed to write JSON: $Path — $_" -Module "Json"
        return $false
    }
}

function Merge-JsonObjects {
    param($Base, $Override)

    if ($null -eq $Base)     { return $Override }
    if ($null -eq $Override) { return $Base }

    $Result = $Base.PSObject.Copy()
    foreach ($Key in $Override.PSObject.Properties.Name) {
        $Result.$Key = $Override.$Key
    }
    return $Result
}

Export-ModuleMember *
