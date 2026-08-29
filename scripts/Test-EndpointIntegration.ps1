param (

    [Parameter(Mandatory = $true)]
    [string]$PrinterName
)

Set-StrictMode -Version Latest

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================"
Write-Host "PrintSwitch - Endpoint Integration Test"
Write-Host "========================================"
Write-Host ""
Write-Host "Modo: READ-ONLY"
Write-Host "PrinterName : $PrinterName"
Write-Host ""

# ============================================================
# 1. RUTAS
# ============================================================

$ProjectRoot =
    Split-Path $PSScriptRoot -Parent

$ResolverPath =
    Join-Path `
        $ProjectRoot `
        "src\PrinterEndpointResolver.ps1"

$ReachabilityPath =
    Join-Path `
        $ProjectRoot `
        "src\PrinterEndpointReachability.ps1"

$InterfacePathAnalyzerPath =
    Join-Path `
        $ProjectRoot `
        "src\InterfacePathAnalyzer.ps1"

$RouteAnalyzerPath =
    Join-Path `
        $ProjectRoot `
        "src\RouteAnalyzer.ps1"

$RequiredFiles = @(
    $ResolverPath,
    $ReachabilityPath,
    $InterfacePathAnalyzerPath,
    $RouteAnalyzerPath
)

foreach ($File in $RequiredFiles) {

    if (-not (Test-Path -LiteralPath $File)) {

        throw "Componente requerido no encontrado: $File"
    }
}

# ============================================================
# 2. CARGAR COMPONENTES
# ============================================================

. $ResolverPath
. $ReachabilityPath

# ============================================================
# 3. RESOLVER ENDPOINT
# ============================================================

Write-Host "========================================"
Write-Host "1. ENDPOINT RESOLUTION"
Write-Host "========================================"

$Endpoint =
    Resolve-PrintSwitchEndpoint `
        -PrinterName $PrinterName

if ($null -eq $Endpoint) {

    throw "PrinterEndpointResolver no devolvio resultado."
}

$Endpoint | Format-List *

# ============================================================
# 4. REACHABILITY DEL ENDPOINT
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. ENDPOINT REACHABILITY"
Write-Host "========================================"

$Reachability =
    Test-PrintSwitchEndpointReachability `
        -Endpoint $Endpoint

if ($null -eq $Reachability) {

    throw "PrinterEndpointReachability no devolvio resultado."
}

$Reachability | Format-List *

# ============================================================
# 5. RAMA USB
# ============================================================

if ($Endpoint.ReachabilityStrategy -eq "USB_PRESENCE") {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "3. USB PATH"
    Write-Host "========================================"

    Write-Host "Endpoint USB detectado."
    Write-Host "No se ejecutan analizadores IP."
    Write-Host ""

    $FinalResult = [PSCustomObject]@{

        Component =
            "EndpointIntegrationTest"

        Version =
            "0.1"

        PrinterName =
            $PrinterName

        TransportType =
            $Endpoint.TransportType

        ReachabilityStrategy =
            $Endpoint.ReachabilityStrategy

        ConfiguredDestination =
            $Endpoint.ConfiguredDestination

        OperationalTargetIP =
            $null

        OperationalTcpPort =
            $null

        EndpointReachable =
            $Reachability.Reachable

        ReachabilityState =
            $Reachability.ReachabilityState

        ProbeResult =
            $Reachability.ProbeResult

        PathAnalysisExecuted =
            $false

        RouteAnalysisExecuted =
            $false

        IntegrationClassification =
            if ($Reachability.ReachabilityState -eq "REACHABLE") {
                "USB_ENDPOINT_REACHABLE"
            }
            elseif ($Reachability.ReachabilityState -eq "UNREACHABLE") {
                "USB_ENDPOINT_UNREACHABLE"
            }
            else {
                "USB_ENDPOINT_UNKNOWN"
            }
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "RESULTADO INTEGRADO"
    Write-Host "========================================"

    $FinalResult | Format-List *

    return $FinalResult
}

# ============================================================
# 6. VALIDAR ENDPOINT DE RED
# ============================================================

if ($Endpoint.TransportType -ne "NETWORK") {

    throw "TransportType no soportado por este test: $($Endpoint.TransportType)"
}

if (
    $Reachability.ReachabilityState -eq "UNKNOWN" -and
    [string]::IsNullOrWhiteSpace(
        [string]$Reachability.ResolvedDestination
    )
) {

    Write-Host ""
    Write-Host "No existe una IPv4 operacional resuelta."
    Write-Host "No se ejecutaran analizadores de ruta."

    $FinalResult = [PSCustomObject]@{

        Component =
            "EndpointIntegrationTest"

        Version =
            "0.1"

        PrinterName =
            $PrinterName

        TransportType =
            $Endpoint.TransportType

        ReachabilityStrategy =
            $Endpoint.ReachabilityStrategy

        ConfiguredDestination =
            $Endpoint.ConfiguredDestination

        OperationalTargetIP =
            $null

        OperationalTcpPort =
            $Endpoint.TcpPort

        EndpointReachable =
            $Reachability.Reachable

        ReachabilityState =
            $Reachability.ReachabilityState

        ProbeResult =
            $Reachability.ProbeResult

        PathAnalysisExecuted =
            $false

        RouteAnalysisExecuted =
            $false

        IntegrationClassification =
            "NETWORK_DESTINATION_UNRESOLVED"
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "RESULTADO INTEGRADO"
    Write-Host "========================================"

    $FinalResult | Format-List *

    return $FinalResult
}

$OperationalTargetIP =
    [string]$Reachability.ResolvedDestination

$OperationalTcpPort =
    [int]$Endpoint.TcpPort

Write-Host ""
Write-Host "OperationalTargetIP  : $OperationalTargetIP"
Write-Host "OperationalTcpPort   : $OperationalTcpPort"

# ============================================================
# 7. INTERFACE PATH ANALYZER
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. INTERFACE PATH ANALYZER"
Write-Host "========================================"

$PathOutput =
    & $InterfacePathAnalyzerPath `
        -TargetIP $OperationalTargetIP `
        -TcpPort $OperationalTcpPort

$PathResult =
    @($PathOutput) |
    Where-Object {
        $_ -and
        $_.PSObject.Properties.Name -contains "Component" -and
        $_.Component -eq "InterfacePathAnalyzer"
    } |
    Select-Object -Last 1

if ($null -eq $PathResult) {

    throw "InterfacePathAnalyzer no devolvio un resultado estructurado valido."
}

# ============================================================
# 8. ROUTE ANALYZER
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "4. ROUTE ANALYZER"
Write-Host "========================================"

$RouteOutput =
    & $RouteAnalyzerPath `
        -TargetIP $OperationalTargetIP `
        -TcpPort $OperationalTcpPort

$RouteResult =
    @($RouteOutput) |
    Where-Object {
        $_ -and
        $_.PSObject.Properties.Name -contains "Component" -and
        $_.Component -eq "RouteAnalyzer"
    } |
    Select-Object -Last 1

if ($null -eq $RouteResult) {

    throw "RouteAnalyzer no devolvio un resultado estructurado valido."
}

# ============================================================
# 9. RESULTADO INTEGRADO
# ============================================================

$FinalResult = [PSCustomObject]@{

    Component =
        "EndpointIntegrationTest"

    Version =
        "0.1"

    PrinterName =
        $PrinterName

    TransportType =
        $Endpoint.TransportType

    ReachabilityStrategy =
        $Endpoint.ReachabilityStrategy

    ConfiguredDestination =
        $Endpoint.ConfiguredDestination

    OperationalTargetIP =
        $OperationalTargetIP

    OperationalTcpPort =
        $OperationalTcpPort

    EndpointReachable =
        $Reachability.Reachable

    ReachabilityState =
        $Reachability.ReachabilityState

    ProbeResult =
        $Reachability.ProbeResult

    PathAnalysisExecuted =
        $true

    PathClassification =
        $PathResult.Classification

    ReachablePathCount =
        $PathResult.ReachablePathCount

    SelectedReachableInterface =
        $PathResult.SelectedReachableInterface

    RouteAnalysisExecuted =
        $true

    RouteClassification =
        $RouteResult.Classification

    RouteTargetReachable =
        $RouteResult.TargetReachable

    IntegrationClassification =
        if (
            $Reachability.ReachabilityState -eq "REACHABLE" -and
            $PathResult.ReachablePathCount -gt 0
        ) {
            "NETWORK_ENDPOINT_REACHABLE"
        }
        elseif (
            $Reachability.ReachabilityState -eq "UNREACHABLE"
        ) {
            "NETWORK_ENDPOINT_UNREACHABLE"
        }
        else {
            "NETWORK_ENDPOINT_NEEDS_EVIDENCE"
        }
}

Write-Host ""
Write-Host "========================================"
Write-Host "RESULTADO INTEGRADO"
Write-Host "========================================"

$FinalResult | Format-List *

return $FinalResult
