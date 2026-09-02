param (
    [switch]$IncludeVirtual,

    [string]$OutputPath
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - PrinterDiscovery v0.4
#
# Responsabilidad:
# - Enumerar colas instaladas en Windows.
# - Obtener contexto general de cada cola.
# - Filtrar impresoras virtuales opcionalmente.
# - Delegar la resolucion del endpoint a
#   PrinterEndpointResolver.
# - Construir QueueContext normalizado.
# - Opcionalmente persistir el discovery como JSON.
#
# NO:
# - modifica impresoras
# - modifica puertos
# - modifica red
# - decide politicas de recovery
# - intenta cambiar Wi-Fi
#
# El JSON generado es discovery/cache.
# NO constituye policy de PrintSwitch.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - PrinterDiscovery v0.4" `
    -ForegroundColor Cyan

Write-Host "Modo: DISCOVERY NO INTRUSIVO" `
    -ForegroundColor Yellow

Write-Host ""

# ============================================================
# RUTAS
# ============================================================

$PrinterEndpointResolverPath = Join-Path `
    $PSScriptRoot `
    "PrinterEndpointResolver.ps1"

if (-not (Test-Path -LiteralPath $PrinterEndpointResolverPath)) {

    Write-Host `
        "ERROR: PrinterEndpointResolver no encontrado." `
        -ForegroundColor Red

    Write-Host $PrinterEndpointResolverPath

    return
}

try {

    . $PrinterEndpointResolverPath
}
catch {

    Write-Host `
        "ERROR cargando PrinterEndpointResolver." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message

    return
}

# ============================================================
# FUNCION: OBTENER PROPIEDAD DE FORMA SEGURA
# ============================================================

function Get-PrintSwitchPropertyValue {

    param (
        [Parameter(Mandatory)]
        $Object,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    if ($null -eq $Object) {
        return $null
    }

    $Property =
        $Object.PSObject.Properties[$PropertyName]

    if ($null -eq $Property) {
        return $null
    }

    return $Property.Value
}

# ============================================================
# FUNCION: DETECTAR IMPRESORA VIRTUAL
# ============================================================

function Test-ProbablyVirtualPrinter {

    param (
        [string]$PrinterName,
        [string]$DriverName,
        [string]$PortName
    )

    $VirtualNamePatterns = @(
        "Microsoft Print to PDF",
        "Microsoft XPS Document Writer",
        "Fax",
        "OneNote"
    )

    foreach ($Pattern in $VirtualNamePatterns) {

        if ($PrinterName -like "*$Pattern*") {
            return $true
        }
    }

    $VirtualPorts = @(
        "PORTPROMPT:",
        "SHRFAX:",
        "nul:"
    )

    if ($PortName -in $VirtualPorts) {
        return $true
    }

    if ($DriverName -like "*Software Printer*") {
        return $true
    }

    return $false
}

# ============================================================
# 1. ENUMERAR COLAS WINDOWS
# ============================================================

Write-Host "========================================"
Write-Host "1. COLAS WINDOWS"
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

    Write-Host $_.Exception.Message

    return
}

Write-Host "Colas detectadas : $($PrinterList.Count)"

# ============================================================
# 2. CONTEXTO WIN32_PRINTER
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. CONTEXTO WINDOWS"
Write-Host "========================================"

try {

    $CimPrinterList = @(
        Get-CimInstance `
            -ClassName Win32_Printer `
            -ErrorAction Stop
    )

    Write-Host "Win32_Printer disponible : True"
}
catch {

    $CimPrinterList = @()

    Write-Host `
        "Win32_Printer disponible : False" `
        -ForegroundColor Yellow

    Write-Host `
        "Discovery continuara con Get-Printer."
}

# ============================================================
# 3. CONSTRUIR QUEUE CONTEXT
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. RESOLUCION DE ENDPOINTS"
Write-Host "========================================"

$DiscoveryResults = @()

foreach ($Printer in $PrinterList) {

    $QueueName =
        [string]$Printer.Name

    $DriverName =
        [string]$Printer.DriverName

    $PortName =
        [string]$Printer.PortName

    $IsProbablyVirtual =
        Test-ProbablyVirtualPrinter `
            -PrinterName $QueueName `
            -DriverName $DriverName `
            -PortName $PortName

    if (
        $IsProbablyVirtual -and
        -not $IncludeVirtual
    ) {

        continue
    }

    $CimMatch =
        $CimPrinterList |
            Where-Object {
                $_.Name -eq $QueueName
            } |
            Select-Object -First 1

    $IsDefault = $false
    $WorkOffline = $null

    if ($null -ne $CimMatch) {

        $IsDefault =
            [bool]$CimMatch.Default

        $WorkOffline =
            $CimMatch.WorkOffline
    }

    $Endpoint = $null
    $EndpointResolutionError = $null

    if (-not $IsProbablyVirtual) {

        try {

            $Endpoint =
                Resolve-PrintSwitchEndpoint `
                    -PrinterName $QueueName
        }
        catch {

            $EndpointResolutionError =
                $_.Exception.Message
        }
    }

    if ($IsProbablyVirtual) {

        $DiscoveryStatus =
            "VIRTUAL_PRINTER"
    }
    elseif ($null -eq $Endpoint) {

        $DiscoveryStatus =
            "ENDPOINT_UNKNOWN"
    }
    elseif (
        (
            Get-PrintSwitchPropertyValue `
                -Object $Endpoint `
                -PropertyName "OperationalMinimumSatisfied"
        ) -eq $true
    ) {

        $DiscoveryStatus =
            "ENDPOINT_RESOLVED"
    }
    else {

        $DiscoveryStatus =
            "ENDPOINT_PARTIAL"
    }

    $Candidate = [PSCustomObject]@{

        Component =
            "QueueContext"

        Version =
            "0.4"

        DiscoveryStatus =
            $DiscoveryStatus

        QueueName =
            $QueueName

        DriverName =
            $DriverName

        PortName =
            $PortName

        Default =
            $IsDefault

        PrinterStatus =
            $Printer.PrinterStatus

        WorkOffline =
            $WorkOffline

        JobCount =
            $Printer.JobCount

        IsProbablyVirtual =
            $IsProbablyVirtual

        TransportType =
            $(if ($null -ne $Endpoint) {
                Get-PrintSwitchPropertyValue `
                    -Object $Endpoint `
                    -PropertyName "TransportType"
            })

        Protocol =
            $(if ($null -ne $Endpoint) {
                Get-PrintSwitchPropertyValue `
                    -Object $Endpoint `
                    -PropertyName "Protocol"
            })

        ConfiguredDestination =
            $(if ($null -ne $Endpoint) {
                Get-PrintSwitchPropertyValue `
                    -Object $Endpoint `
                    -PropertyName "ConfiguredDestination"
            })

        AddressType =
            $(if ($null -ne $Endpoint) {
                Get-PrintSwitchPropertyValue `
                    -Object $Endpoint `
                    -PropertyName "AddressType"
            })

        TcpPort =
            $(if ($null -ne $Endpoint) {
                Get-PrintSwitchPropertyValue `
                    -Object $Endpoint `
                    -PropertyName "TcpPort"
            })

        ServiceQueue =
            $(if ($null -ne $Endpoint) {
                Get-PrintSwitchPropertyValue `
                    -Object $Endpoint `
                    -PropertyName "ServiceQueue"
            })

        ReachabilityStrategy =
            $(if ($null -ne $Endpoint) {
                Get-PrintSwitchPropertyValue `
                    -Object $Endpoint `
                    -PropertyName "ReachabilityStrategy"
            })

        DiscoverySource =
            $(if ($null -ne $Endpoint) {
                Get-PrintSwitchPropertyValue `
                    -Object $Endpoint `
                    -PropertyName "DiscoverySource"
            })

        Confidence =
            $(if ($null -ne $Endpoint) {
                Get-PrintSwitchPropertyValue `
                    -Object $Endpoint `
                    -PropertyName "Confidence"
            })

        OperationalMinimumSatisfied =
            $(if ($null -ne $Endpoint) {
                Get-PrintSwitchPropertyValue `
                    -Object $Endpoint `
                    -PropertyName "OperationalMinimumSatisfied"
            })

        MissingRequirements =
            $(if ($null -ne $Endpoint) {
                Get-PrintSwitchPropertyValue `
                    -Object $Endpoint `
                    -PropertyName "MissingRequirements"
            })

        EndpointEvidence =
            $(if ($null -ne $Endpoint) {
                Get-PrintSwitchPropertyValue `
                    -Object $Endpoint `
                    -PropertyName "Evidence"
            })

        EndpointResolutionError =
            $EndpointResolutionError
    }

    $DiscoveryResults +=
        $Candidate
}

# ============================================================
# 4. RESULTADOS
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "4. QUEUE CONTEXTS"
Write-Host "========================================"

foreach ($Item in $DiscoveryResults) {

    Write-Host ""
    Write-Host "----------------------------------------"

    Write-Host "QueueName             : $($Item.QueueName)"
    Write-Host "DiscoveryStatus       : $($Item.DiscoveryStatus)"
    Write-Host "DriverName            : $($Item.DriverName)"
    Write-Host "PortName              : $($Item.PortName)"
    Write-Host "TransportType         : $($Item.TransportType)"
    Write-Host "Protocol              : $($Item.Protocol)"
    Write-Host "ConfiguredDestination : $($Item.ConfiguredDestination)"
    Write-Host "AddressType           : $($Item.AddressType)"
    Write-Host "TcpPort               : $($Item.TcpPort)"
    Write-Host "ServiceQueue          : $($Item.ServiceQueue)"
    Write-Host "ReachabilityStrategy  : $($Item.ReachabilityStrategy)"
    Write-Host "DiscoverySource       : $($Item.DiscoverySource)"
    Write-Host "Confidence            : $($Item.Confidence)"
    Write-Host "Default               : $($Item.Default)"
    Write-Host "Virtual               : $($Item.IsProbablyVirtual)"

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$Item.EndpointResolutionError
        )
    ) {

        Write-Host `
            "ResolutionError        : $($Item.EndpointResolutionError)" `
            -ForegroundColor Yellow
    }
}

# ============================================================
# 5. RESUMEN
# ============================================================

$ResolvedCount =
    @(
        $DiscoveryResults |
            Where-Object {
                $_.DiscoveryStatus -eq "ENDPOINT_RESOLVED"
            }
    ).Count

$PartialCount =
    @(
        $DiscoveryResults |
            Where-Object {
                $_.DiscoveryStatus -eq "ENDPOINT_PARTIAL"
            }
    ).Count

$UnknownCount =
    @(
        $DiscoveryResults |
            Where-Object {
                $_.DiscoveryStatus -eq "ENDPOINT_UNKNOWN"
            }
    ).Count

$VirtualCount =
    @(
        $DiscoveryResults |
            Where-Object {
                $_.DiscoveryStatus -eq "VIRTUAL_PRINTER"
            }
    ).Count

Write-Host ""
Write-Host "========================================"
Write-Host "5. RESUMEN"
Write-Host "========================================"

Write-Host "QueueContexts       : $($DiscoveryResults.Count)"
Write-Host "EndpointResolved    : $ResolvedCount"
Write-Host "EndpointPartial     : $PartialCount"
Write-Host "EndpointUnknown     : $UnknownCount"
Write-Host "VirtualPrinters     : $VirtualCount"

# ============================================================
# 6. JSON OPCIONAL
# ============================================================

if (
    -not [string]::IsNullOrWhiteSpace($OutputPath)
) {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "6. DISCOVERY JSON"
    Write-Host "========================================"

    try {

        $ResolvedOutputPath =
            [System.IO.Path]::GetFullPath($OutputPath)

        $OutputDirectory =
            Split-Path `
                -Path $ResolvedOutputPath `
                -Parent

        if (
            -not [string]::IsNullOrWhiteSpace($OutputDirectory) -and
            -not (Test-Path -LiteralPath $OutputDirectory)
        ) {

            New-Item `
                -ItemType Directory `
                -Path $OutputDirectory `
                -Force `
                -ErrorAction Stop |
                Out-Null
        }

        $Snapshot = [PSCustomObject]@{

            Component =
                "PrinterDiscoverySnapshot"

            Version =
                "0.4"

            GeneratedAt =
                (Get-Date).ToString("o")

            ComputerName =
                $env:COMPUTERNAME

            QueueCount =
                $DiscoveryResults.Count

            Queues =
                @($DiscoveryResults)
        }

        $Json =
            $Snapshot |
                ConvertTo-Json `
                    -Depth 10

        [System.IO.File]::WriteAllText(
            $ResolvedOutputPath,
            $Json + [Environment]::NewLine,
            [System.Text.UTF8Encoding]::new($false)
        )

        Write-Host "JSON generado:"
        Write-Host $ResolvedOutputPath
    }
    catch {

        Write-Host `
            "ERROR generando discovery JSON." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message
    }
}

# ============================================================
# 7. SALIDA ESTRUCTURADA
# ============================================================

$DiscoveryResults