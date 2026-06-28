<#
.SYNOPSIS
    Download module for Software Manager Pro.
    Handles direct file downloads with progress display.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

function Get-FileFromUrl {
    <#
    .SYNOPSIS
        Downloads a file from a URL with progress display.
        Returns the local path if successful, $null on failure.
    #>
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$DestinationFolder = "",
        [string]$FileName          = ""
    )

    if (-not $DestinationFolder) {
        $DestinationFolder = Join-Path $Global:AppRoot "Downloads"
    }

    if (-not (Test-Path $DestinationFolder)) {
        New-Item -ItemType Directory -Path $DestinationFolder -Force | Out-Null
    }

    if (-not $FileName) {
        $FileName = [System.IO.Path]::GetFileName(($Url -split '\?')[0])
        if (-not $FileName) { $FileName = "installer_$(Get-Date -Format 'yyyyMMddHHmmss').exe" }
    }

    $DestPath = Join-Path $DestinationFolder $FileName

    Write-Host ""
    Write-Host "  ► Downloading: $FileName" -ForegroundColor Green
    Write-Host "    From: $Url" -ForegroundColor DarkGray
    Write-Host ""

    Write-Log -Level "Information" -Message "Downloading $Url → $DestPath" -Module "Download"

    try {
        $WebClient = New-Object System.Net.WebClient
        $WebClient.Headers.Add("User-Agent", "SoftwareManagerPro/1.0")

        # Progress tracking
        $StartTime = [DateTime]::Now
        $WebClient.DownloadProgressChanged += {
            $Pct     = $_.ProgressPercentage
            $Bars    = [Math]::Floor($Pct / 5)
            $Bar     = ("[" + ("█" * $Bars) + (" " * (20 - $Bars)) + "]")
            $Elapsed = ([DateTime]::Now - $StartTime).TotalSeconds
            $Speed   = if ($Elapsed -gt 0 -and $_.BytesReceived -gt 0) {
                "$([Math]::Round($_.BytesReceived / 1KB / $Elapsed, 0)) KB/s"
            } else { "..." }

            Write-Host "`r  $Bar $Pct%  $Speed   " -NoNewline -ForegroundColor Cyan
        }

        $Task = $WebClient.DownloadFileTaskAsync($Url, $DestPath)
        $Task.Wait()
        $WebClient.Dispose()

        Write-Host ""
        Write-Host "  ✔ Download complete: $DestPath" -ForegroundColor Green
        Write-Log -Level "Information" -Message "Download complete: $DestPath" -Module "Download"

        return $DestPath
    }
    catch {
        Write-Host ""
        Write-Host "  ✖ Download failed: $_" -ForegroundColor Red
        Write-Log -Level "Error" -Message "Download failed: $Url — $_" -Module "Download"
        return $null
    }
}

function Clear-Downloads {
    $Folder = Join-Path $Global:AppRoot "Downloads"
    if (Test-Path $Folder) {
        $Files = Get-ChildItem -Path $Folder -ErrorAction SilentlyContinue
        $Files | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host "  ✔ $($Files.Count) file(s) deleted from Downloads." -ForegroundColor Green
        Write-Log -Level "Information" -Message "Downloads cleared." -Module "Download"
    }
}

Export-ModuleMember *
