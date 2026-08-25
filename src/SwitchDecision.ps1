param (
    [Parameter(Mandatory = $true)]
    $PolicyResult,

    [Parameter(Mandatory = $true)]
    $WiFiCandidateResult
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - SwitchDecision v0.1
#
# Responsabilidad:
# combinar ConnectivityPolicy + WiFiCandidateEvaluator
# y producir una decision final de alto nivel.
#
# NO:
# - cambia Wi-Fi
# - toca Ethernet
# - modifica rutas
# - llama a NetworkManager
#
# Solo decide.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - SwitchDecision v0.1" `
    -ForegroundColor Cyan

Write-Host "Modo: DECISION FINAL NO INTRUSIVA" `
    -ForegroundColor Yellow

Write-Host ""

# ============================================================
# 1. VALIDAR ENTRADAS
# ============================================================

if ($null -eq $PolicyResult) {

    Write-Host `
        "ERROR: PolicyResult es nulo." `
        -ForegroundColor Red

    return
}

if ($null -eq $WiFiCandidateResult) {

    Write-Host `
        "ERROR: WiFiCandidateResult es nulo." `
        -ForegroundColor Red

    return
}

Write-Host "========================================"
Write-Host "1. CONTEXTO RECIBIDO"
Write-Host "========================================"

Write-Host `
    "PolicyDecision      : $($PolicyResult.Decision)"

Write-Host `
    "PreserveEthernet    : $($PolicyResult.PreserveEthernet)"

Write-Host `
    "WiFiClassification  : $($WiFiCandidateResult.Classification)"

Write-Host `
    "CanAttemptSwitch    : $($WiFiCandidateResult.CanAttemptSwitch)"

Write-Host `
    "CurrentSSID         : $($WiFiCandidateResult.CurrentSSID)"

Write-Host `
    "TargetSSID          : $($WiFiCandidateResult.TargetSSID)"

# ============================================================
# 2. DECISION
# ============================================================

$Decision =
    "SWITCH_DECISION_UNDETERMINED"

$ShouldExecuteSwitch =
    $false

$PreserveEthernet =
    [bool]$PolicyResult.PreserveEthernet

$Reason =
    ""

# ------------------------------------------------------------
# CASO 1: no hay que hacer nada
# ------------------------------------------------------------

if ($PolicyResult.Decision -eq "NO_ACTION") {

    $Decision =
        "NO_ACTION"

    $ShouldExecuteSwitch =
        $false

    $Reason =
        "Current connectivity already satisfies printer requirements."
}

# ------------------------------------------------------------
# CASO 2:
# Ethernet debe preservarse y Wi-Fi es candidato válido
# ------------------------------------------------------------

elseif (
    $PolicyResult.Decision `
        -eq "PRESERVE_ETHERNET_EVALUATE_WIFI" -and

    $WiFiCandidateResult.Classification `
        -eq "WIFI_SWITCH_CANDIDATE_AVAILABLE" -and

    $WiFiCandidateResult.CanAttemptSwitch `
        -eq $true
) {

    $Decision =
        "PRESERVE_ETHERNET_AND_SWITCH_WIFI"

    $ShouldExecuteSwitch =
        $true

    $PreserveEthernet =
        $true

    $Reason =
        "Ethernet preserves general connectivity and Wi-Fi can safely attempt the target network."
}

# ------------------------------------------------------------
# CASO 3:
# Wi-Fi ya está en la red objetivo
# ------------------------------------------------------------

elseif (
    $WiFiCandidateResult.Classification `
        -eq "ALREADY_ON_TARGET_WIFI"
) {

    $Decision =
        "NO_WIFI_SWITCH_REQUIRED"

    $ShouldExecuteSwitch =
        $false

    $Reason =
        "Wi-Fi is already connected to the target SSID."
}

# ------------------------------------------------------------
# CASO 4:
# política permite evaluar recuperación,
# pero Wi-Fi no es candidato seguro
# ------------------------------------------------------------

elseif (
    $PolicyResult.Decision `
        -eq "PRESERVE_ETHERNET_EVALUATE_WIFI" -or

    $PolicyResult.Decision `
        -eq "EVALUATE_WIFI_RECOVERY"
) {

    $Decision =
        "SWITCH_NOT_SAFE"

    $ShouldExecuteSwitch =
        $false

    $Reason =
        "Wi-Fi conditions do not currently authorize a switch."
}

# ------------------------------------------------------------
# CASO 5:
# estado desconocido
# ------------------------------------------------------------

else {

    $Decision =
        "UNSUPPORTED_CONTEXT"

    $ShouldExecuteSwitch =
        $false

    $Reason =
        "The current combination of policy and Wi-Fi state is not supported."
}

# ============================================================
# 3. INTERPRETACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. DECISION FINAL"
Write-Host "========================================"

switch ($Decision) {

    "NO_ACTION" {

        Write-Host `
            "Decision : NO_ACTION" `
            -ForegroundColor Green

        Write-Host `
            "La impresora ya es alcanzable."

        Write-Host `
            "No debe modificarse ninguna interfaz."
    }

    "PRESERVE_ETHERNET_AND_SWITCH_WIFI" {

        Write-Host `
            "Decision : PRESERVE_ETHERNET_AND_SWITCH_WIFI" `
            -ForegroundColor Green

        Write-Host `
            "Ethernet debe preservarse."

        Write-Host `
            "Wi-Fi puede cambiarse a '$($WiFiCandidateResult.TargetSSID)'."

        Write-Host `
            "El cambio todavia NO fue ejecutado."
    }

    "NO_WIFI_SWITCH_REQUIRED" {

        Write-Host `
            "Decision : NO_WIFI_SWITCH_REQUIRED" `
            -ForegroundColor Green

        Write-Host `
            "Wi-Fi ya esta en la red objetivo."
    }

    "SWITCH_NOT_SAFE" {

        Write-Host `
            "Decision : SWITCH_NOT_SAFE" `
            -ForegroundColor Yellow

        Write-Host `
            "No se autoriza cambio automatico de Wi-Fi."
    }

    default {

        Write-Host `
            "Decision : $Decision" `
            -ForegroundColor Yellow

        Write-Host `
            "No se autoriza ninguna accion automatica."
    }
}

# ============================================================
# 4. RESULTADO ESTRUCTURADO
# ============================================================

$SwitchResult = [PSCustomObject]@{

    Component =
        "SwitchDecision"

    Version =
        "0.1"

    Timestamp =
        Get-Date

    Decision =
        $Decision

    ShouldExecuteSwitch =
        $ShouldExecuteSwitch

    PreserveEthernet =
        $PreserveEthernet

    TargetSSID =
        $WiFiCandidateResult.TargetSSID

    CurrentSSID =
        $WiFiCandidateResult.CurrentSSID

    PolicyDecision =
        $PolicyResult.Decision

    WiFiClassification =
        $WiFiCandidateResult.Classification

    CanAttemptSwitch =
        $WiFiCandidateResult.CanAttemptSwitch

    Reason =
        $Reason
}

Write-Host ""
Write-Host "========================================"
Write-Host "3. RESULTADO ESTRUCTURADO"
Write-Host "========================================"

Write-Host `
    "Decision            : $($SwitchResult.Decision)"

Write-Host `
    "ShouldExecuteSwitch : $($SwitchResult.ShouldExecuteSwitch)"

Write-Host `
    "PreserveEthernet    : $($SwitchResult.PreserveEthernet)"

Write-Host `
    "CurrentSSID         : $($SwitchResult.CurrentSSID)"

Write-Host `
    "TargetSSID          : $($SwitchResult.TargetSSID)"

Write-Host `
    "PolicyDecision      : $($SwitchResult.PolicyDecision)"

Write-Host `
    "WiFiClassification  : $($SwitchResult.WiFiClassification)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN SWITCHDECISION v0.1"
Write-Host "========================================"

$SwitchResult