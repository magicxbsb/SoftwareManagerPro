<#
.SYNOPSIS
    SteelSeries connector for Software Manager Pro.
    Loads SteelSeries-specific apps from Apps JSON and registers fallback URL.
.VERSION
    1.0.0
#>

Set-StrictMode -Version Latest

function Register-SteelSeriesConnector {
    # Register fallback URL for this publisher
    $FallbackMap = Get-Variable -Name 'FallbackUrls' -Scope Global -ErrorAction SilentlyContinue
    if ($FallbackMap) {
        switch ("SteelSeries") {
            "Elgato"      { $Global:FallbackUrls["Elgato"]      = "https://www.elgato.com/fr/fr/s/downloads" }
            "NVIDIA"      { $Global:FallbackUrls["NVIDIA"]      = "https://www.nvidia.com/fr-fr/geforce/broadcasting/broadcast-app/" }
            "MSI"         { $Global:FallbackUrls["MSI"]         = "https://fr.msi.com/Landing/mystic-light/download" }
            "Gigabyte"    { $Global:FallbackUrls["Gigabyte"]    = "https://www.gigabyte.com/Support/Utility" }
            "LianLi"      { $Global:FallbackUrls["LianLi"]      = "https://www.lian-li.com/l-connect3/" }
            "SteelSeries" { $Global:FallbackUrls["SteelSeries"] = "https://steelseries.com/gg" }
            "SignalRGB"   { $Global:FallbackUrls["SignalRGB"]   = "https://www.signalrgb.com/download/" }
            "OCCT"        { $Global:FallbackUrls["OCCT"]        = "https://www.ocbase.com/" }
        }
    }
    Write-Log -Level "Debug" -Message "SteelSeries connector registered." -Module "Connectors"
}

Export-ModuleMember *
