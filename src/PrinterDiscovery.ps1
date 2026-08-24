param (
    [switch]$IncludeVirtual
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - PrinterDiscovery v0.2
#
# Descubre impresoras instaladas y trata de resolver
# el destino de red a partir del puerto configurado.
#
# Estrategias actuales:
# - Standard TCP/IP Port
# - EpsonNet Print Port
#
# No modifica configuración, red ni impresoras.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - PrinterDiscovery v0.2" `
    -ForegroundColor Cyan

Write-Host "Modo: DESCUBRIMIENTO NO INTRUSIVO" `
    -ForegroundColor Yellow

Write-Host ""

# ============================================================
# FUNCION: NORMALIZAR MAC
# ============================================================

function Format-MacAddress {

    param (
        [string]$MacAddress
    )

    if ([string]::IsNullOrWhiteSpace($MacAddress)) {
        return $null
    }

    $Clean = (
        $MacAddress -replace '[^0-9A-Fa-f]', ''
    ).ToUpper()

    if ($Clean.Length -ne 12) {
        return $MacAddress
    }

    return (
        ($Clean -split '(.{2})' |
            Where-Object { $_ }) -join ':'
    )
}

# ============================================================
# FUNCION: RESOLVER STANDARD TCP/IP
# ============================================================

function Resolve-StandardTcpIpPort {

    param (
        $PrinterPort
    )

    if ($null -eq $PrinterPort) {
        return $null
    }

    if (
        $PrinterPort.CimClass.CimClassName `
            -ne "MSFT_TcpIpPrinterPort"
    ) {
        return $null
    }

    return [PSCustomObject]@{

        Resolver =
            "StandardTcpIp"

        Destination =
            [string]$PrinterPort.PrinterHostAddress

        Protocol =
            [string]$PrinterPort.Protocol

        PortNumber =
            $PrinterPort.PortNumber

        MacAddress =
            $null

        SnmpEnabled =
            $PrinterPort.SNMPEnabled
    }
}

# ============================================================
# FUNCION: RESOLVER EPSONNET
# ============================================================

function Resolve-EpsonNetPort {

    param (
        [string]$PortName
    )

    if ([string]::IsNullOrWhiteSpace($PortName)) {
        return $null
    }

    $RegistryPath = Join-Path `
        "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\EpsonNet Print Port\Ports" `
        $PortName

    if (-not (Test-Path $RegistryPath)) {
        return $null
    }

    try {

        $EpsonConfig = Get-ItemProperty `
            $RegistryPath `
            -ErrorAction Stop
    }
    catch {

        return $null
    }

    return [PSCustomObject]@{

        Resolver =
            "EpsonNetRegistry"

        Destination =
            [string]$EpsonConfig.IpAddress

        Protocol =
            [string]$EpsonConfig.ProtocolID

        PortNumber =
            $null

        MacAddress =
            Format-MacAddress `
                -MacAddress ([string]$EpsonConfig.MacAddress)

        SnmpEnabled =
            $null
    }
}

# ============================================================
# FUNCION: CLASIFICAR PUERTO
# ============================================================

function Resolve-PrinterDestination {

    param (
        [string]$PortName,
        $PrinterPort
    )

    $PortMonitor = $null
    $PortDescription = $null

    if ($null -ne $PrinterPort) {

        $PortMonitor =
            [string]$PrinterPort.PortMonitor

        $PortDescription =
            [string]$PrinterPort.Description
    }

    # --------------------------------------------------------
    # Standard TCP/IP
    # --------------------------------------------------------

    $StandardResult = Resolve-StandardTcpIpPort `
        -PrinterPort $PrinterPort

    if ($null -ne $StandardResult) {

        return [PSCustomObject]@{

            PortType =
                "StandardTcpIp"

            PortMonitor =
                $PortMonitor

            PortDescription =
                $PortDescription

            Resolver =
                $StandardResult.Resolver

            Destination =
                $StandardResult.Destination

            Protocol =
                $StandardResult.Protocol

            PortNumber =
                $StandardResult.PortNumber

            MacAddress =
                $StandardResult.MacAddress

            SnmpEnabled =
                $StandardResult.SnmpEnabled
        }
    }

    # --------------------------------------------------------
    # EpsonNet
    # --------------------------------------------------------

    if ($PortMonitor -eq "EpsonNet Print Port") {

        $EpsonResult = Resolve-EpsonNetPort `
            -PortName $PortName

        if ($null -ne $EpsonResult) {

            return [PSCustomObject]@{

                PortType =
                    "VendorSpecific"

                PortMonitor =
                    $PortMonitor

                PortDescription =
                    $PortDescription

                Resolver =
                    $EpsonResult.Resolver

                Destination =
                    $EpsonResult.Destination

                Protocol =
                    $EpsonResult.Protocol

                PortNumber =
                    $EpsonResult.PortNumber

                MacAddress =
                    $EpsonResult.MacAddress

                SnmpEnabled =
                    $EpsonResult.SnmpEnabled
            }
        }
    }

    # --------------------------------------------------------
    # No resuelto
    # --------------------------------------------------------

    return [PSCustomObject]@{

        PortType =
            "Unknown"

        PortMonitor =
            $PortMonitor

        PortDescription =
            $PortDescription

        Resolver =
            "None"

        Destination =
            $null

        Protocol =
            $null

        PortNumber =
            $null

        MacAddress =
            $null

        SnmpEnabled =
            $null
    }
}

# ============================================================
# 1. IMPRESORAS
# ============================================================

Write-Host "========================================"
Write-Host "1. IMPRESORAS"
Write-Host "========================================"

try {

    $PrinterList = @(
        Get-Printer `
            -ErrorAction Stop
    )
}
catch {

    Write-Host `
        "ERROR: no se pudo consultar Get-Printer." `
        -ForegroundColor Red

    return
}

Write-Host "Cantidad detectada: $($PrinterList.Count)"

# ============================================================
# 2. WIN32_PRINTER
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. WIN32_PRINTER"
Write-Host "========================================"

try {

    $CimPrinterList = @(
        Get-CimInstance `
            Win32_Printer `
            -ErrorAction Stop
    )
}
catch {

    Write-Host `
        "ERROR: no se pudo consultar Win32_Printer." `
        -ForegroundColor Red

    return
}

# ============================================================
# 3. PUERTOS
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. PUERTOS"
Write-Host "========================================"

try {

    $PrinterPorts = @(
        Get-PrinterPort `
            -ErrorAction Stop
    )
}
catch {

    Write-Host `
        "ERROR: no se pudo consultar Get-PrinterPort." `
        -ForegroundColor Red

    return
}

Write-Host "Puertos detectados: $($PrinterPorts.Count)"

# ============================================================
# 4. CORRELACION Y RESOLUCION
# ============================================================

$DiscoveryResults = @()

$VirtualNamePatterns = @(
    "Microsoft Print to PDF",
    "Microsoft XPS Document Writer",
    "Fax",
    "OneNote"
)

foreach ($Printer in $PrinterList) {

    $CimMatch = $CimPrinterList |
        Where-Object {
            $_.Name -eq $Printer.Name
        } |
        Select-Object -First 1

    $PortMatch = $PrinterPorts |
        Where-Object {
            $_.Name -eq $Printer.PortName
        } |
        Select-Object -First 1

    $IsProbablyVirtual = $false

    foreach ($Pattern in $VirtualNamePatterns) {

        if ($Printer.Name -like "*$Pattern*") {

            $IsProbablyVirtual = $true
            break
        }
    }

    if (
        -not $IncludeVirtual -and
        $IsProbablyVirtual
    ) {
        continue
    }

    $DestinationInfo = Resolve-PrinterDestination `
        -PortName $Printer.PortName `
        -PrinterPort $PortMatch

    $IsDefault = $false
    $WorkOffline = $null

    if ($null -ne $CimMatch) {

        $IsDefault =
            [bool]$CimMatch.Default

        $WorkOffline =
            $CimMatch.WorkOffline
    }

    $DiscoveryResults += [PSCustomObject]@{

        Component =
            "PrinterDiscovery"

        Version =
            "0.2"

        Name =
            $Printer.Name

        DriverName =
            $Printer.DriverName

        PortName =
            $Printer.PortName

        PortType =
            $DestinationInfo.PortType

        PortMonitor =
            $DestinationInfo.PortMonitor

        PortDescription =
            $DestinationInfo.PortDescription

        Destination =
            $DestinationInfo.Destination

        Protocol =
            $DestinationInfo.Protocol

        PortNumber =
            $DestinationInfo.PortNumber

        MacAddress =
            $DestinationInfo.MacAddress

        Resolver =
            $DestinationInfo.Resolver

        SnmpEnabled =
            $DestinationInfo.SnmpEnabled

        Default =
            $IsDefault

        WorkOffline =
            $WorkOffline

        PrinterStatus =
            $Printer.PrinterStatus

        JobCount =
            $Printer.JobCount

        IsProbablyVirtual =
            $IsProbablyVirtual
    }
}

# ============================================================
# 5. RESULTADOS
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "5. IMPRESORAS DESCUBIERTAS"
Write-Host "========================================"

foreach ($Item in $DiscoveryResults) {

    Write-Host ""
    Write-Host "----------------------------------------"

    Write-Host "Nombre        : $($Item.Name)"
    Write-Host "Driver        : $($Item.DriverName)"
    Write-Host "Puerto        : $($Item.PortName)"
    Write-Host "Tipo puerto   : $($Item.PortType)"
    Write-Host "Monitor       : $($Item.PortMonitor)"
    Write-Host "Destino       : $($Item.Destination)"
    Write-Host "Protocolo     : $($Item.Protocol)"
    Write-Host "Puerto TCP    : $($Item.PortNumber)"
    Write-Host "MAC           : $($Item.MacAddress)"
    Write-Host "Resolver      : $($Item.Resolver)"
    Write-Host "Predeterminada: $($Item.Default)"
    Write-Host "Virtual       : $($Item.IsProbablyVirtual)"
}

# ============================================================
# 6. RESUMEN
# ============================================================

$DefaultPrinter = $DiscoveryResults |
    Where-Object {
        $_.Default -eq $true
    } |
    Select-Object -First 1

Write-Host ""
Write-Host "========================================"
Write-Host "6. RESUMEN"
Write-Host "========================================"

Write-Host `
    "Impresoras mostradas : $($DiscoveryResults.Count)"

if ($null -ne $DefaultPrinter) {

    Write-Host `
        "Predeterminada       : $($DefaultPrinter.Name)"
}
else {

    Write-Host `
        "Predeterminada       : no detectada"
}

Write-Host ""
Write-Host "========================================"
Write-Host "FIN PRINTERDISCOVERY v0.2"
Write-Host "========================================"

$DiscoveryResults