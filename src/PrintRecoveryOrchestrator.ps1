param (
    [string]$PrinterName,

    [string]$TargetIP,

    [string]$TargetSSID,

    [string]$ConfigPath = (
        Join-Path `
            $PSScriptRoot `
            "..\config\printers.json"
    ),

    [string]$PolicyPath = (
        Join-Path `
            $PSScriptRoot `
            "..\config\policy.json"
    ),

    [switch]$Execute
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - PrintRecoveryOrchestrator v0.1
# Orquestador operativo de recuperacion de conectividad
#
# Integra:
# - RouteAnalyzer
# - ConnectivityPolicy
# - WiFiCandidateEvaluator
# - SwitchDecision
# - NetworkManager
# - ConnectivityAnalyzer
#
# Por defecto: DRY-RUN
# Con Modo EJECUCION OPERATIVA: permite cambio real de Wi-Fi.
#
# Ethernet nunca es modificado.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - PrintRecoveryOrchestrator v0.1" `
    -ForegroundColor Cyan

if ($Execute) {

    Write-Host "Modo: EJECUCION OPERATIVA" `
        -ForegroundColor Yellow
}
else {

    Write-Host "Modo: DRY-RUN OPERATIVO" `
        -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# RUTAS DE COMPONENTES
# ============================================================
$InterfacePathAnalyzerPath = Join-Path `
    $PSScriptRoot `
    "InterfacePathAnalyzer.ps1"
    
$RouteAnalyzerPath = Join-Path `
    $PSScriptRoot `
    "RouteAnalyzer.ps1"

$ConnectivityPolicyPath = Join-Path `
    $PSScriptRoot `
    "ConnectivityPolicy.ps1"

$WiFiCandidatePath = Join-Path `
    $PSScriptRoot `
    "WiFiCandidateEvaluator.ps1"

$SwitchDecisionPath = Join-Path `
    $PSScriptRoot `
    "SwitchDecision.ps1"

$NetworkManagerPath = Join-Path `
    $PSScriptRoot `
    "NetworkManager.ps1"

$RecoveryValidatorPath = Join-Path `
    $PSScriptRoot `
    "RecoveryValidator.ps1"


$ConnectivityAnalyzerPath = Join-Path `
    $PSScriptRoot `
    "ConnectivityAnalyzer.ps1"
$PrinterEndpointResolverPath = Join-Path `
    $PSScriptRoot `
    "PrinterEndpointResolver.ps1"

$PrinterEndpointReachabilityPath = Join-Path `
    $PSScriptRoot `
    "PrinterEndpointReachability.ps1"

# ============================================================
# 1. CARGAR CONFIGURACION
# ============================================================

Write-Host "========================================"
Write-Host "1. CONFIGURACION"
Write-Host "========================================"

# ============================================================
# POLICY OPCIONAL
# ============================================================

$Policy = $null
$QueuePolicy = $null
$PolicyFound = $false
$WifiRecoveryEnabled = $false

if (Test-Path -LiteralPath $PolicyPath) {

    try {

        $Policy =
            Get-Content `
                -LiteralPath $PolicyPath `
                -Raw `
                -Encoding UTF8 `
                -ErrorAction Stop |
            ConvertFrom-Json `
                -ErrorAction Stop
    }
    catch {

        Write-Host `
            "ERROR leyendo policy.json." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message

        return
    }
}
else {

    Write-Host `
        "Policy PrintSwitch no encontrada." `
        -ForegroundColor Yellow

    Write-Host `
        "Se continuara sin autorizacion especial de recovery."
}

# ============================================================
# DETERMINAR COLA
# ============================================================

if ([string]::IsNullOrWhiteSpace($PrinterName)) {

    try {

        $DefaultPrinter =
            Get-CimInstance `
                -ClassName Win32_Printer `
                -ErrorAction Stop |
            Where-Object {
                $_.Default -eq $true
            } |
            Select-Object -First 1

        if ($null -ne $DefaultPrinter) {

            $PrinterName =
                [string]$DefaultPrinter.Name
        }
    }
    catch {

        Write-Host `
            "No se pudo determinar la impresora predeterminada." `
            -ForegroundColor Yellow
    }
}

if ([string]::IsNullOrWhiteSpace($PrinterName)) {

    Write-Host `
        "ERROR: no se pudo determinar PrinterName." `
        -ForegroundColor Red

    return
}

# ============================================================
# RESOLVER POLICY DE LA COLA
# ============================================================

if (
    $null -ne $Policy -and
    $null -ne $Policy.queues
) {

    $QueuePolicyProperty =
        $Policy.queues.PSObject.Properties[$PrinterName]

    if ($null -ne $QueuePolicyProperty) {

        $QueuePolicy =
            $QueuePolicyProperty.Value

        $PolicyFound = $true
    }
}

if (
    $PolicyFound -and
    $null -ne $QueuePolicy.wifiRecovery
) {

    $WifiRecoveryEnabled =
        ($QueuePolicy.wifiRecovery.enabled -eq $true)

    if (
        [string]::IsNullOrWhiteSpace($TargetSSID) -and
        -not [string]::IsNullOrWhiteSpace(
            [string]$QueuePolicy.wifiRecovery.requiredSSID
        )
    ) {

        $TargetSSID =
            [string]$QueuePolicy.wifiRecovery.requiredSSID
    }
}

Write-Host "PrinterName         : $PrinterName"
Write-Host "PolicyFound         : $PolicyFound"
Write-Host "WifiRecoveryEnabled : $WifiRecoveryEnabled"
Write-Host "TargetIP override   : $TargetIP"
Write-Host "TargetSSID          : $TargetSSID"

# ============================================================
# 1.1 RESOLVER ENDPOINT OPERATIVO
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "1.1 ENDPOINT OPERATIVO"
Write-Host "========================================"

try {

    . $PrinterEndpointResolverPath
    . $PrinterEndpointReachabilityPath

    $Endpoint =
        Resolve-PrintSwitchEndpoint `
            -PrinterName $PrinterName

    if ($null -eq $Endpoint) {
        throw "PrinterEndpointResolver no devolvio resultado."
    }

    $EndpointReachability =
        Test-PrintSwitchEndpointReachability `
            -Endpoint $Endpoint

    if ($null -eq $EndpointReachability) {
        throw "PrinterEndpointReachability no devolvio resultado."
    }
}
catch {

    Write-Host `
        "ERROR resolviendo endpoint operativo." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message

    return
}

Write-Host "TransportType         : $($Endpoint.TransportType)"
Write-Host "Protocol              : $($Endpoint.Protocol)"
Write-Host "ReachabilityStrategy  : $($Endpoint.ReachabilityStrategy)"
Write-Host "ConfiguredDestination : $($Endpoint.ConfiguredDestination)"
Write-Host "TcpPort               : $($Endpoint.TcpPort)"
Write-Host "ReachabilityState     : $($EndpointReachability.ReachabilityState)"
Write-Host "ProbeResult           : $($EndpointReachability.ProbeResult)"

$OperationalTargetIP = $null
$OperationalTcpPort = $null

if ($Endpoint.TransportType -eq "NETWORK") {

    if (
        $EndpointReachability.ReachabilityState -eq "UNKNOWN" -and
        [string]::IsNullOrWhiteSpace(
            [string]$EndpointReachability.ResolvedDestination
        )
    ) {

        Write-Host ""
        Write-Host `
            "No fue posible resolver el destino de red del endpoint." `
            -ForegroundColor Yellow

        Write-Host `
            "PrintSwitch no autorizara cambios de red sin evidencia suficiente." `
            -ForegroundColor Yellow

        $FinalResult = [PSCustomObject]@{

            Component =
                "PrintRecoveryOrchestrator"

            Version =
                "0.2"

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

            EndpointReachabilityState =
                $EndpointReachability.ReachabilityState

            EndpointProbeResult =
                $EndpointReachability.ProbeResult

            TargetSSID =
                $TargetSSID

            ExecutionMode =
                $(if ($Execute) {
                    "EXECUTE"
                }
                else {
                    "DRY_RUN"
                })

            SwitchDecision =
                "NO_ACTION_INSUFFICIENT_ENDPOINT_EVIDENCE"

            SwitchAuthorized =
                $false

            SwitchExecuted =
                $false

            FinalClassification =
                "NETWORK_DESTINATION_UNRESOLVED"
        }

        return $FinalResult
    }

    $OperationalTargetIP =
        [string]$EndpointReachability.ResolvedDestination

    $OperationalTcpPort =
        [int]$Endpoint.TcpPort

    Write-Host ""
    Write-Host "OperationalTargetIP   : $OperationalTargetIP"
    Write-Host "OperationalTcpPort    : $OperationalTcpPort"
}
elseif ($Endpoint.TransportType -eq "USB") {

    Write-Host ""
    Write-Host "Endpoint USB detectado."
    Write-Host "La rama USB no requiere analisis IP ni recuperacion Wi-Fi."

    $UsbReachable =
        (
            $EndpointReachability.ReachabilityState -eq "REACHABLE"
        )

    $FinalResult = [PSCustomObject]@{

        Component =
            "PrintRecoveryOrchestrator"

        Version =
            "0.2"

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

        EndpointReachabilityState =
            $EndpointReachability.ReachabilityState

        EndpointProbeResult =
            $EndpointReachability.ProbeResult

        TargetSSID =
            $TargetSSID

        ExecutionMode =
            $(if ($Execute) {
                "EXECUTE"
            }
            else {
                "DRY_RUN"
            })

        SwitchDecision =
            "NO_WIFI_ACTION"

        SwitchAuthorized =
            $false

        SwitchExecuted =
            $false

        FinalClassification =
            $(if ($UsbReachable) {
                "USB_ENDPOINT_REACHABLE"
            }
            elseif (
                $EndpointReachability.ReachabilityState -eq
                    "UNREACHABLE"
            ) {
                "USB_ENDPOINT_UNREACHABLE"
            }
            else {
                "USB_ENDPOINT_UNKNOWN"
            })
    }

    return $FinalResult
}
else {

    Write-Host ""
    Write-Host `
        "Transporte no soportado por el Orchestrator actual: $($Endpoint.TransportType)" `
        -ForegroundColor Yellow

    return
}
# ============================================================
# 2. VALIDAR COMPONENTES
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. COMPONENTES"
Write-Host "========================================"

$RequiredComponents = @(
    $InterfacePathAnalyzerPath,
    $RouteAnalyzerPath,
    $ConnectivityPolicyPath,
    $WiFiCandidatePath,
    $SwitchDecisionPath,
    $NetworkManagerPath,
    $RecoveryValidatorPath,
    $ConnectivityAnalyzerPath
    $PrinterEndpointResolverPath,
    $PrinterEndpointReachabilityPath
)

foreach ($ComponentPath in $RequiredComponents) {

    if (-not (Test-Path $ComponentPath)) {

        Write-Host `
            "ERROR: componente no encontrado:" `
            -ForegroundColor Red

        Write-Host $ComponentPath

        return
    }
}

Write-Host "Componentes disponibles : True"


# ============================================================
# 3. INTERFACE PATH ANALYZER
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. INTERFACE PATH ANALYZER"
Write-Host "========================================"

$PathResult = & $InterfacePathAnalyzerPath `
    -TargetIP $OperationalTargetIP `
    -TcpPort $OperationalTcpPort

if ($null -eq $PathResult) {

    Write-Host `
        "ERROR: InterfacePathAnalyzer no devolvio resultado." `
        -ForegroundColor Red

    return
}

Write-Host ""
Write-Host "PathClassification : $($PathResult.Classification)"
Write-Host "ReachablePathCount : $($PathResult.ReachablePathCount)"
Write-Host "ReachableInterface : $($PathResult.SelectedReachableInterface)"

# ============================================================
# 3.1 HAPPY PATH - CAMINO YA COMPROBADO
# ============================================================

if (
    $PathResult.ReachablePathCount -gt 0
) {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "CAMINO FUNCIONAL YA DISPONIBLE"
    Write-Host "========================================"

   Write-Host `
    "Caminos alcanzables : $($PathResult.ReachablePathCount)"

if (
    $PathResult.Classification -eq "UNIQUE_REACHABLE_PATH"
) {

    Write-Host `
        "Interfaz : $($PathResult.SelectedReachableInterface)"

    Write-Host `
        "Tipo     : $($PathResult.SelectedReachableInterfaceType)"
}
else {

    Write-Host `
        "Varias interfaces alcanzan actualmente la impresora."
}

    Write-Host ""
    Write-Host `
        "PrintSwitch no modificara ninguna red." `
        -ForegroundColor Green

    $FinalResult = [PSCustomObject]@{

        Component =
            "PrintRecoveryOrchestrator"

        Version =
            "0.1"

        PrinterName =
            $PrinterName

        TargetIP =
            $OperationalTargetIP

        OperationalTargetIP =
            $OperationalTargetIP

        OperationalTcpPort =
            $OperationalTcpPort

        
        ExecutionMode =
            $(if ($Execute) {
                "EXECUTE"
            }
            else {
                "DRY_RUN"
            })

        PathClassification =
            $PathResult.Classification

        ReachablePathCount =
            $PathResult.ReachablePathCount

        ReachableInterface =
            $PathResult.SelectedReachableInterface

        ReachableInterfaceType =
            $PathResult.SelectedReachableInterfaceType

        SwitchDecision =
            "NO_ACTION"

        SwitchAuthorized =
            $false

        SwitchExecuted =
            $false

        PreserveEthernet =
    (
        @(
            $PathResult.ReachablePaths |
                Where-Object {
                    $_.InterfaceType -eq "Ethernet"
                }
        ).Count -gt 0
    )

        TargetSSID =
            $TargetSSID

        FinalClassification =
            "EXISTING_REACHABLE_PATH"
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "FIN PRINTRECOVERYORCHESTRATOR v0.1"
    Write-Host "========================================"

    return $FinalResult
}
# ============================================================
# 3.2 CAMINO EXISTENTE PERO IMPRESORA INALCANZABLE
# ============================================================

if (
    $PathResult.Classification -eq "CANDIDATE_PATHS_UNREACHABLE" -and
    $PathResult.DirectCandidateCount -gt 0
) {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "CAMINO EXISTENTE - IMPRESORA INALCANZABLE"
    Write-Host "========================================"

    Write-Host `
        "Existe al menos un camino local hacia la red del destino."

    Write-Host `
        "La impresora no responde actualmente."

    Write-Host ""
    Write-Host `
        "PrintSwitch NO autorizara un cambio de Wi-Fi." `
        -ForegroundColor Yellow

    Write-Host `
        "La causa puede pertenecer a la propia impresora."

    $FinalResult = [PSCustomObject]@{

        Component =
            "PrintRecoveryOrchestrator"

        Version =
            "0.1"

        PrinterName =
            $PrinterName

        TargetIP =
            $TargetIP

        TargetSSID =
            $TargetSSID


        ExecutionMode =
            $(if ($Execute) {
                "EXECUTE"
            }
            else {
                "DRY_RUN"
            })

        PathClassification =
            $PathResult.Classification

        DirectCandidateCount =
            $PathResult.DirectCandidateCount

        ReachablePathCount =
            $PathResult.ReachablePathCount

        PreferredInterface =
            $PathResult.PreferredInterface

        SwitchDecision =
            "NO_SWITCH_PRINTER_UNREACHABLE"

        SwitchAuthorized =
            $false

        SwitchExecuted =
            $false

        PreserveEthernet =
            $true

        

        FinalClassification =
            "EXISTING_PATH_PRINTER_UNREACHABLE"
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "FIN PRINTRECOVERYORCHESTRATOR v0.1"
    Write-Host "========================================"

    return $FinalResult
}

# ============================================================
# 3.3 AUTORIZACION DE RECUPERACION WIFI
# ============================================================

if (
    -not $PolicyFound -or
    -not $WifiRecoveryEnabled -or
    [string]::IsNullOrWhiteSpace($TargetSSID)
) {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "RECUPERACION WIFI NO AUTORIZADA"
    Write-Host "========================================"

    $RecoveryPolicyReason =
        if (-not $PolicyFound) {

            "POLICY_NOT_FOUND"
        }
        elseif (-not $WifiRecoveryEnabled) {

            "WIFI_RECOVERY_DISABLED"
        }
        elseif (
            [string]::IsNullOrWhiteSpace($TargetSSID)
        ) {

            "TARGET_SSID_NOT_DEFINED"
        }
        else {

            "RECOVERY_NOT_AUTHORIZED"
        }

    Write-Host "PolicyFound         : $PolicyFound"
    Write-Host "WifiRecoveryEnabled : $WifiRecoveryEnabled"
    Write-Host "TargetSSID          : $TargetSSID"
    Write-Host "Reason              : $RecoveryPolicyReason"

    Write-Host ""
    Write-Host `
        "PrintSwitch no modificara ninguna red." `
        -ForegroundColor Yellow

    $FinalResult = [PSCustomObject]@{

        Component =
            "PrintRecoveryOrchestrator"

        Version =
            "0.2"

        PrinterName =
            $PrinterName

        TargetIP =
            $OperationalTargetIP

        OperationalTargetIP =
            $OperationalTargetIP

        OperationalTcpPort =
            $OperationalTcpPort

        TargetSSID =
            $TargetSSID

        PolicyFound =
            $PolicyFound

        WifiRecoveryEnabled =
            $WifiRecoveryEnabled

        RecoveryPolicyReason =
            $RecoveryPolicyReason

        ExecutionMode =
            $(if ($Execute) {
                "EXECUTE"
            }
            else {
                "DRY_RUN"
            })

        PathClassification =
            $PathResult.Classification

        DirectCandidateCount =
            $PathResult.DirectCandidateCount

        ReachablePathCount =
            $PathResult.ReachablePathCount

        SwitchDecision =
            "NO_WIFI_ACTION"

        SwitchAuthorized =
            $false

        SwitchExecuted =
            $false

        PreserveEthernet =
            $true

        FinalClassification =
            "WIFI_RECOVERY_NOT_AUTHORIZED"
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "FIN PRINTRECOVERYORCHESTRATOR v0.2"
    Write-Host "========================================"

    return $FinalResult
}


# ============================================================
# 4. ROUTE ANALYZER
# ============================================================


Write-Host ""
Write-Host "========================================"
Write-Host "4. ROUTE ANALYZER"
Write-Host "========================================"

$RouteResult = & $RouteAnalyzerPath `
    -TargetIP $OperationalTargetIP `
    -TcpPort $OperationalTcpPort

if ($null -eq $RouteResult) {

    Write-Host `
        "ERROR: RouteAnalyzer no devolvio resultado." `
        -ForegroundColor Red

    return
}

# ============================================================
# 4. CONNECTIVITY POLICY
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "4. CONNECTIVITY POLICY"
Write-Host "========================================"

$PolicyResult = & $ConnectivityPolicyPath `
    -RouteResult $RouteResult `
    -TargetSSID $TargetSSID

if ($null -eq $PolicyResult) {

    Write-Host `
        "ERROR: ConnectivityPolicy no devolvio resultado." `
        -ForegroundColor Red

    return
}

# ============================================================
# 5. WIFI CANDIDATE
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "5. WIFI CANDIDATE"
Write-Host "========================================"

$WiFiCandidateResult = & $WiFiCandidatePath `
    -TargetSSID $TargetSSID

if ($null -eq $WiFiCandidateResult) {

    Write-Host `
        "ERROR: WiFiCandidateEvaluator no devolvio resultado." `
        -ForegroundColor Red

    return
}

# ============================================================
# 6. SWITCH DECISION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "6. SWITCH DECISION"
Write-Host "========================================"

$SwitchResult = & $SwitchDecisionPath `
    -PolicyResult $PolicyResult `
    -WiFiCandidateResult $WiFiCandidateResult

if ($null -eq $SwitchResult) {

    Write-Host `
        "ERROR: SwitchDecision no devolvio resultado." `
        -ForegroundColor Red

    return
}

# ============================================================
# 7. DECISION DEL ORQUESTADOR
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "7. DECISION CONTEXTUAL"
Write-Host "========================================"

Write-Host "Decision            : $($SwitchResult.Decision)"
Write-Host "ShouldExecuteSwitch : $($SwitchResult.ShouldExecuteSwitch)"
Write-Host "PreserveEthernet    : $($SwitchResult.PreserveEthernet)"
Write-Host "CurrentSSID         : $($SwitchResult.CurrentSSID)"
Write-Host "TargetSSID          : $($SwitchResult.TargetSSID)"

# ------------------------------------------------------------
# NO ACTION
# ------------------------------------------------------------

if (-not $SwitchResult.ShouldExecuteSwitch) {

    Write-Host ""
    Write-Host `
        "NO NETWORK CHANGE" `
        -ForegroundColor Green

    Write-Host `
        "La politica contextual no autoriza ningun cambio."

    $FinalResult = [PSCustomObject]@{

        Component =
            "PrintRecoveryOrchestrator"

        Version =
            "0.1"

        PrinterName =
            $PrinterName

        TargetIP =
            $OperationalTargetIP

        OperationalTargetIP =
            $OperationalTargetIP

        OperationalTcpPort =
            $OperationalTcpPort

        TargetSSID =
            $TargetSSID


        ExecutionMode =
            $(if ($Execute) {
                "EXECUTE"
            }
            else {
                "DRY_RUN"
            })

        InitialRouteClassification =
            $RouteResult.Classification

        PolicyDecision =
            $PolicyResult.Decision

        SwitchDecision =
            $SwitchResult.Decision

        SwitchAuthorized =
            $false

        SwitchExecuted =
            $false

        PreserveEthernet =
            $SwitchResult.PreserveEthernet

        
        FinalClassification =
            $RouteResult.Classification
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "FIN PRINTRECOVERYORCHESTRATOR v0.1"
    Write-Host "========================================"

    return $FinalResult
}

# ============================================================
# 8. SWITCH AUTORIZADO PERO DRY-RUN
# ============================================================

if (-not $Execute) {

    Write-Host ""
    Write-Host `
        "SWITCH AUTORIZADO CONCEPTUALMENTE" `
        -ForegroundColor Yellow

    Write-Host `
        "DRY-RUN: NetworkManager NO sera ejecutado."

    if ($SwitchResult.PreserveEthernet) {

    Write-Host `
        "Ethernet debe permanecer intacto."
}
else {

    Write-Host `
        "No existe Ethernet protector activo."

    Write-Host `
        "El cambio de Wi-Fi puede interrumpir temporalmente la conectividad general."
}

    $FinalResult = [PSCustomObject]@{

        Component =
            "PrintRecoveryOrchestrator"

        Version =
            "0.1"

        PrinterName =
            $PrinterName

        TargetIP =
            $OperationalTargetIP

        OperationalTargetIP =
            $OperationalTargetIP

        OperationalTcpPort =
            $OperationalTcpPort

        TargetSSID =
            $TargetSSID

        ExecutionMode =
            "DRY_RUN"

        InitialRouteClassification =
            $RouteResult.Classification

        PolicyDecision =
            $PolicyResult.Decision

        SwitchDecision =
            $SwitchResult.Decision

        SwitchAuthorized =
            $true

        SwitchExecuted =
            $false

        PreserveEthernet =
            $SwitchResult.PreserveEthernet

        
        FinalClassification =
            "SWITCH_NOT_EXECUTED_DRY_RUN"
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "FIN PRINTRECOVERYORCHESTRATOR v0.1"
    Write-Host "========================================"

    return $FinalResult
}

# ============================================================
# 9. CAPTURAR ESTADO ETHERNET PREVIO
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "8. ESTADO ETHERNET PREVIO"
Write-Host "========================================"

$EthernetBefore = @(
    Get-NetAdapter `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Status -eq "Up" -and
            $_.InterfaceDescription -match
                "Ethernet|PCIe|GbE|Gigabit"
        }
)
$EthernetPresentBefore =
    ($EthernetBefore.Count -gt 0)
foreach ($EthernetAdapter in $EthernetBefore) {

    Write-Host `
        "$($EthernetAdapter.Name) : $($EthernetAdapter.Status)"
}

# ============================================================
# 10. NETWORK MANAGER
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "9. NETWORK MANAGER"
Write-Host "========================================"

Write-Host `
    "Ejecutando cambio SOLO sobre Wi-Fi..." `
    -ForegroundColor Yellow

$NetworkResult = & $NetworkManagerPath `
    -TargetSSID $TargetSSID `
    -AutoExecute

if ($null -eq $NetworkResult) {

    Write-Host `
        "ERROR: NetworkManager no devolvio resultado." `
        -ForegroundColor Red

    return
}

# ============================================================
# 11. VERIFICAR ETHERNET DESPUES
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "10. VERIFICACION ETHERNET"
Write-Host "========================================"

$EthernetAfter = @(
    Get-NetAdapter `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Status -eq "Up" -and
            $_.InterfaceDescription -match
                "Ethernet|PCIe|GbE|Gigabit"
        }
)

$EthernetPresentAfter =
    ($EthernetAfter.Count -gt 0)

$EthernetPreserved =
    (
        $EthernetPresentBefore -eq $true -and
        $EthernetPresentAfter -eq $true
    )

foreach ($PreviousAdapter in $EthernetBefore) {

    $CurrentAdapter = Get-NetAdapter `
        -Name $PreviousAdapter.Name `
        -ErrorAction SilentlyContinue

    if (
        $null -eq $CurrentAdapter -or
        $CurrentAdapter.Status -ne "Up"
    ) {

        $EthernetPreserved = $false
    }

    if ($null -ne $CurrentAdapter) {

        Write-Host `
            "$($PreviousAdapter.Name) : $($CurrentAdapter.Status)"
    }
    else {

        Write-Host `
            "$($PreviousAdapter.Name) : NO DISPONIBLE"
    }
}


Write-Host `
    "EthernetPresentBefore : $EthernetPresentBefore"

Write-Host `
    "EthernetPresentAfter  : $EthernetPresentAfter"

Write-Host `
    "EthernetPreserved : $EthernetPreserved"

# ============================================================
# 12. REVALIDAR CONNECTIVITY ANALYZER
# ============================================================

# ============================================================
# 11. RECOVERY VALIDATOR
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "11. RECOVERY VALIDATOR"
Write-Host "========================================"

$RecoveryValidation = & $RecoveryValidatorPath `
    -TargetIP $OperationalTargetIP `
    -TcpPort $OperationalTcpPort

if ($null -eq $RecoveryValidation) {

    Write-Host `
        "ERROR: RecoveryValidator no devolvio resultado." `
        -ForegroundColor Red

    return
}

Write-Host ""
Write-Host "RecoveryClassification : $($RecoveryValidation.Classification)"
Write-Host "RecoveryConfirmed      : $($RecoveryValidation.RecoveryConfirmed)"
Write-Host "CompletedWindow        : $($RecoveryValidation.CompletedWindow)"
Write-Host "TotalElapsedMs         : $($RecoveryValidation.TotalElapsedMs)"


Write-Host ""
Write-Host "========================================"
Write-Host "12. REVALIDACION DE IMPRESORA"
Write-Host "========================================"

$ConnectivityAfter = & $ConnectivityAnalyzerPath `
    -PrinterName $PrinterName `
    -ConfigPath $ConfigPath

# ============================================================
# 13. REVALIDAR ROUTE ANALYZER
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "13. REVALIDACION DE RUTA"
Write-Host "========================================"

$RouteAfter = & $RouteAnalyzerPath `
    -TargetIP $OperationalTargetIP `
    -TcpPort $OperationalTcpPort

# ============================================================
# 14. RESULTADO FINAL
# ============================================================

$RecoverySucceeded =
    (
        $NetworkResult.SwitchVerified -eq $true -and
        $RecoveryValidation.RecoveryConfirmed -eq $true -and
        $RouteAfter.TargetReachable -eq $true
    )

if ($RecoverySucceeded) {

    $FinalClassification =
        "CONTEXTUAL_RECOVERY_SUCCESS"
}
else {

    $FinalClassification =
        "CONTEXTUAL_RECOVERY_INCOMPLETE"
}

$FinalResult = [PSCustomObject]@{

    Component =
        "PrintRecoveryOrchestrator"

    Version =
        "0.1"

    PrinterName =
        $PrinterName

    TargetIP =
        $OperationalTargetIP

    OperationalTargetIP =
        $OperationalTargetIP

    OperationalTcpPort =
        $OperationalTcpPort

    TargetSSID =
        $TargetSSID

    

    ExecutionMode =
        "EXECUTE"

    

    InitialRouteClassification =
        $RouteResult.Classification

    PolicyDecision =
        $PolicyResult.Decision

    SwitchDecision =
        $SwitchResult.Decision

    SwitchAuthorized =
        $true

    SwitchExecuted =
        $true

    RecoveryValidationClassification =
        $RecoveryValidation.Classification

    RecoveryValidationConfirmed =
        $RecoveryValidation.RecoveryConfirmed

    RecoveryValidationWindow =
        $RecoveryValidation.CompletedWindow

    RecoveryValidationElapsedMs =
        $RecoveryValidation.TotalElapsedMs

    NetworkSwitchVerified =
        $NetworkResult.SwitchVerified

    PreserveEthernet =
        $SwitchResult.PreserveEthernet

    EthernetPresentBefore =
        $EthernetPresentBefore

    EthernetPresentAfter =
        $EthernetPresentAfter

    EthernetPreserved =
        $EthernetPreserved

    ConnectivityAfter =
        $ConnectivityAfter.Classification

    RouteAfter =
        $RouteAfter.Classification

    RecoverySucceeded =
        $RecoverySucceeded

    FinalClassification =
        $FinalClassification
}

Write-Host ""
Write-Host "========================================"
Write-Host "14. RESULTADO FINAL"
Write-Host "========================================"

Write-Host `
    "SwitchDecision        : $($FinalResult.SwitchDecision)"

Write-Host `
    "NetworkSwitchVerified : $($FinalResult.NetworkSwitchVerified)"

Write-Host `
    "EthernetPresentBefore : $($FinalResult.EthernetPresentBefore)"

Write-Host `
    "EthernetPresentAfter  : $($FinalResult.EthernetPresentAfter)"

Write-Host `
    "EthernetPreserved     : $($FinalResult.EthernetPreserved)"

Write-Host `
    "ConnectivityAfter     : $($FinalResult.ConnectivityAfter)"

Write-Host `
    "RouteAfter            : $($FinalResult.RouteAfter)"

Write-Host `
    "RecoverySucceeded     : $($FinalResult.RecoverySucceeded)"

Write-Host `
    "FinalClassification   : $($FinalResult.FinalClassification)"

Write-Host `
    "RecoveryValidation    : $($FinalResult.RecoveryValidationClassification)"

Write-Host `
    "RecoveryConfirmed     : $($FinalResult.RecoveryValidationConfirmed)"

Write-Host `
    "RecoveryWindow        : $($FinalResult.RecoveryValidationWindow)"

Write-Host `
    "RecoveryElapsedMs     : $($FinalResult.RecoveryValidationElapsedMs)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN PRINTRECOVERYORCHESTRATOR v0.1"
Write-Host "========================================"

$FinalResult