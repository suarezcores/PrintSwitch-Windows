param (
    [string]$ConfigPath = ".\config\printers.json",
    [string]$DiscoveryPath = ".\src\PrinterDiscovery.ps1"
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "PrintSwitch - ProfileAnalyzer v0.1" -ForegroundColor Cyan
Write-Host "Modo: COMPARACION NO INTRUSIVA" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# FUNCION AUXILIAR
# ============================================================

function Normalize-Value {
    param ($Value)

    if ($null -eq $Value) {
        return ""
    }

    return ([string]$Value).Trim()
}

# ============================================================
# 1. CONFIGURACION
# ============================================================

Write-Host "========================================"
Write-Host "1. CONFIGURACION"
Write-Host "========================================"

if (-not (Test-Path $ConfigPath)) {

    Write-Host "ERROR: archivo de configuracion no encontrado." `
        -ForegroundColor Red

    return [PSCustomObject]@{
        Component      = "ProfileAnalyzer"
        Version        = "0.1"
        Classification = "CONFIG_NOT_FOUND"
        IsMatch        = $false
        PrinterName    = $null
        ConfiguredIP   = $null
        DiscoveredIP   = $null
        Errors         = @("CONFIG_FILE_NOT_FOUND")
    }
}

try {
    $Config = Get-Content $ConfigPath -Raw |
        ConvertFrom-Json -ErrorAction Stop
}
catch {

    Write-Host "ERROR: JSON invalido." -ForegroundColor Red

    return [PSCustomObject]@{
        Component      = "ProfileAnalyzer"
        Version        = "0.1"
        Classification = "CONFIG_INVALID"
        IsMatch        = $false
        PrinterName    = $null
        ConfiguredIP   = $null
        DiscoveredIP   = $null
        Errors         = @("INVALID_JSON")
    }
}

$ConfiguredPrinters = @($Config.printers)

Write-Host "Perfiles configurados : $($ConfiguredPrinters.Count)"
Write-Host "Archivo               : $ConfigPath"

# ============================================================
# 2. PRINTER DISCOVERY
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. PRINTER DISCOVERY"
Write-Host "========================================"

if (-not (Test-Path $DiscoveryPath)) {

    Write-Host "ERROR: PrinterDiscovery no encontrado." `
        -ForegroundColor Red

    return
}

$DiscoveredPrinters = @(
    & $DiscoveryPath
)

Write-Host ""
Write-Host "Candidatos fisicos descubiertos: $($DiscoveredPrinters.Count)"

# ============================================================
# 3. COMPARACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. COMPARACION DE PERFILES"
Write-Host "========================================"

$Results = @()

foreach ($Profile in $ConfiguredPrinters) {

    $ConfiguredName = Normalize-Value $Profile.name
    $ConfiguredIP   = Normalize-Value $Profile.ip

    Write-Host ""
    Write-Host "----------------------------------------"
    Write-Host "Perfil configurado: $ConfiguredName"

    $Discovered = $DiscoveredPrinters |
        Where-Object {
            $_.Name -eq $ConfiguredName
        } |
        Select-Object -First 1

    # --------------------------------------------------------
    # IMPRESORA NO ENCONTRADA
    # --------------------------------------------------------

    if ($null -eq $Discovered) {

        Write-Host "Resultado : PRINTER_NOT_FOUND" `
            -ForegroundColor Yellow

        $Results += [PSCustomObject]@{
            Component       = "ProfileAnalyzer"
            Version         = "0.1"
            Classification  = "PRINTER_NOT_FOUND"
            IsMatch         = $false
            PrinterName     = $ConfiguredName
            ConfiguredIP    = $ConfiguredIP
            DiscoveredIP    = $null
            DiscoveryStatus = $null
            Resolver        = $null
            MacAddress      = $null
            RequiredSSID    = $Profile.requiredSSID
            Errors          = @("PRINTER_NOT_FOUND")
        }

        continue
    }

    $DiscoveredIP = Normalize-Value $Discovered.Destination

    # --------------------------------------------------------
    # DESTINO NO RESUELTO
    # --------------------------------------------------------

    if (
        $Discovered.DiscoveryStatus -ne "DESTINATION_RESOLVED" -or
        [string]::IsNullOrWhiteSpace($DiscoveredIP)
    ) {

        Write-Host "Resultado : DESTINATION_UNKNOWN" `
            -ForegroundColor Yellow

        $Results += [PSCustomObject]@{
            Component       = "ProfileAnalyzer"
            Version         = "0.1"
            Classification  = "DESTINATION_UNKNOWN"
            IsMatch         = $false
            PrinterName     = $ConfiguredName
            ConfiguredIP    = $ConfiguredIP
            DiscoveredIP    = $DiscoveredIP
            DiscoveryStatus = $Discovered.DiscoveryStatus
            Resolver        = $Discovered.Resolver
            MacAddress      = $Discovered.MacAddress
            RequiredSSID    = $Profile.requiredSSID
            Errors          = @("DESTINATION_UNKNOWN")
        }

        continue
    }

    # --------------------------------------------------------
    # COMPARAR DESTINO
    # --------------------------------------------------------

    if ($ConfiguredIP -eq $DiscoveredIP) {

        $Classification = "PROFILE_MATCH"
        $IsMatch = $true
        $Errors = @()

        Write-Host "Nombre configurado : $ConfiguredName"
        Write-Host "IP configurada      : $ConfiguredIP"
        Write-Host "IP descubierta      : $DiscoveredIP"
        Write-Host "Resolver             : $($Discovered.Resolver)"
        Write-Host "MAC                  : $($Discovered.MacAddress)"
        Write-Host "Resultado            : PROFILE_MATCH" `
            -ForegroundColor Green
    }
    else {

        $Classification = "PROFILE_MISMATCH"
        $IsMatch = $false
        $Errors = @(
            "DESTINATION_MISMATCH:$ConfiguredIP->$DiscoveredIP"
        )

        Write-Host "Nombre configurado : $ConfiguredName"
        Write-Host "IP configurada      : $ConfiguredIP"
        Write-Host "IP descubierta      : $DiscoveredIP"
        Write-Host "Resultado            : PROFILE_MISMATCH" `
            -ForegroundColor Yellow
    }

    $Results += [PSCustomObject]@{
        Component       = "ProfileAnalyzer"
        Version         = "0.1"
        Classification  = $Classification
        IsMatch         = $IsMatch
        PrinterName     = $ConfiguredName
        ConfiguredIP    = $ConfiguredIP
        DiscoveredIP    = $DiscoveredIP
        DiscoveryStatus = $Discovered.DiscoveryStatus
        Resolver        = $Discovered.Resolver
        MacAddress      = $Discovered.MacAddress
        RequiredSSID    = $Profile.requiredSSID
        Errors          = $Errors
    }
}

# ============================================================
# 4. RESULTADO
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "4. RESULTADO PROFILEANALYZER"
Write-Host "========================================"

foreach ($Result in $Results) {

    Write-Host ""
    Write-Host "PrinterName     : $($Result.PrinterName)"
    Write-Host "Classification  : $($Result.Classification)"
    Write-Host "IsMatch         : $($Result.IsMatch)"
    Write-Host "ConfiguredIP    : $($Result.ConfiguredIP)"
    Write-Host "DiscoveredIP    : $($Result.DiscoveredIP)"
    Write-Host "RequiredSSID    : $($Result.RequiredSSID)"
    Write-Host "Resolver        : $($Result.Resolver)"
    Write-Host "MAC             : $($Result.MacAddress)"
}

Write-Host ""
Write-Host "========================================"
Write-Host "FIN PROFILEANALYZER v0.1"
Write-Host "========================================"

$Results