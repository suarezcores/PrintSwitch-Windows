param (
    [string]$PrinterName,

    [string]$ConfigPath = (
        Join-Path `
            (Split-Path $PSScriptRoot -Parent) `
            "config\printers.json"
    ),

    [switch]$Execute
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - ContextualRecoveryTest v0.1
#
# Orquestador experimental.
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
# Con -Execute: permite cambio real de Wi-Fi.
#
# Ethernet nunca es modificado.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - ContextualRecoveryTest v0.1" `
    -ForegroundColor Cyan

if ($Execute) {

    Write-Host "Modo: EJECUCION CONTEXTUAL" `
        -ForegroundColor Yellow
}
else {

    Write-Host "Modo: DRY-RUN CONTEXTUAL" `
        -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# RUTAS DE COMPONENTES
# ============================================================

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

$ConnectivityAnalyzerPath = Join-Path `
    $PSScriptRoot `
    "ConnectivityAnalyzer.ps1"

# ============================================================
# 1. CARGAR CONFIGURACION
# ============================================================

Write-Host "========================================"
Write-Host "1. CONFIGURACION"
Write-Host "========================================"

if (-not (Test-Path $ConfigPath)) {

    Write-Host `
        "ERROR: no existe la configuracion." `
        -ForegroundColor Red

    return
}

try {

    $Config = Get-Content `
        $ConfigPath `
        -Raw `
        -ErrorAction Stop |
        ConvertFrom-Json `
            -ErrorAction Stop
}
catch {

    Write-Host `
        "ERROR leyendo configuracion." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message

    return
}

$PrinterProfile = $null

if ($PrinterName) {

    $PrinterProfile = @(
        $Config.printers |
            Where-Object {
                $_.name -eq $PrinterName
            }
    ) |
        Select-Object -First 1
}
else {

    $PrinterProfile = @($Config.printers)[0]
}

if ($null -eq $PrinterProfile) {

    Write-Host `
        "ERROR: perfil de impresora no encontrado." `
        -ForegroundColor Red

    return
}

$PrinterName =
    [string]$PrinterProfile.name

$TargetIP =
    [string]$PrinterProfile.ip

$TargetSSID =
    [string]$PrinterProfile.requiredSSID

Write-Host "PrinterName : $PrinterName"
Write-Host "TargetIP    : $TargetIP"
Write-Host "TargetSSID  : $TargetSSID"

# ============================================================
# 2. VALIDAR COMPONENTES
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. COMPONENTES"
Write-Host "========================================"

$RequiredComponents = @(
    $RouteAnalyzerPath,
    $ConnectivityPolicyPath,
    $WiFiCandidatePath,
    $SwitchDecisionPath,
    $NetworkManagerPath,
    $ConnectivityAnalyzerPath
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
# 3. ROUTE ANALYZER
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. ROUTE ANALYZER"
Write-Host "========================================"

$RouteResult = & $RouteAnalyzerPath `
    -TargetIP $TargetIP

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
            "ContextualRecoveryTest"

        Version =
            "0.1"

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

        TargetSSID =
            $TargetSSID

        FinalClassification =
            $RouteResult.Classification
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "FIN CONTEXTUALRECOVERYTEST v0.1"
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

    Write-Host `
        "Ethernet debe permanecer intacto."

    $FinalResult = [PSCustomObject]@{

        Component =
            "ContextualRecoveryTest"

        Version =
            "0.1"

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

        TargetSSID =
            $TargetSSID

        FinalClassification =
            "SWITCH_NOT_EXECUTED_DRY_RUN"
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "FIN CONTEXTUALRECOVERYTEST v0.1"
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

$EthernetPreserved = $true

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

    Write-Host `
        "$($PreviousAdapter.Name) : $($CurrentAdapter.Status)"
}

Write-Host `
    "EthernetPreserved : $EthernetPreserved"

# ============================================================
# 12. REVALIDAR CONNECTIVITY ANALYZER
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "11. REVALIDACION DE IMPRESORA"
Write-Host "========================================"

$ConnectivityAfter = & $ConnectivityAnalyzerPath `
    -PrinterName $PrinterName `
    -ConfigPath $ConfigPath

# ============================================================
# 13. REVALIDAR ROUTE ANALYZER
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "12. REVALIDACION DE RUTA"
Write-Host "========================================"

$RouteAfter = & $RouteAnalyzerPath `
    -TargetIP $TargetIP

# ============================================================
# 14. RESULTADO FINAL
# ============================================================

$RecoverySucceeded =
    (
        $NetworkResult.SwitchVerified -eq $true -and
        $EthernetPreserved -eq $true -and
        $ConnectivityAfter.Classification -eq
            "PRINTER_REACHABLE"
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
        "ContextualRecoveryTest"

    Version =
        "0.1"

    ExecutionMode =
        "EXECUTE"

    PrinterName =
        $PrinterName

    TargetIP =
        $TargetIP

    TargetSSID =
        $TargetSSID

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

    NetworkSwitchVerified =
        $NetworkResult.SwitchVerified

    PreserveEthernet =
        $SwitchResult.PreserveEthernet

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
Write-Host "13. RESULTADO FINAL"
Write-Host "========================================"

Write-Host `
    "SwitchDecision        : $($FinalResult.SwitchDecision)"

Write-Host `
    "NetworkSwitchVerified : $($FinalResult.NetworkSwitchVerified)"

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

Write-Host ""
Write-Host "========================================"
Write-Host "FIN CONTEXTUALRECOVERYTEST v0.1"
Write-Host "========================================"

$FinalResult