param (
    [Parameter(Mandatory = $true)]
    [string]$TargetSSID,

    [string]$WiFiInterfaceName = "Wi-Fi"
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - WiFiCandidateEvaluator v0.1
#
# Objetivo:
# determinar si Wi-Fi puede utilizarse como camino alternativo
# hacia una impresora sin ejecutar todavía ningun cambio.
#
# Comprueba:
# - existencia de interfaz Wi-Fi
# - estado de interfaz
# - SSID actual
# - perfil objetivo conocido por Windows
# - red objetivo visible
#
# NO cambia la red.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - WiFiCandidateEvaluator v0.1" `
    -ForegroundColor Cyan

Write-Host "Modo: EVALUACION NO INTRUSIVA" `
    -ForegroundColor Yellow

Write-Host ""
Write-Host "SSID objetivo : $TargetSSID"

# ============================================================
# 1. INTERFAZ WI-FI
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "1. INTERFAZ WI-FI"
Write-Host "========================================"

$WiFiAdapter = Get-NetAdapter `
    -Name $WiFiInterfaceName `
    -ErrorAction SilentlyContinue

if ($null -eq $WiFiAdapter) {

    $WiFiAdapter = Get-NetAdapter `
        -ErrorAction SilentlyContinue |
        Where-Object {

            $_.Status -ne "Disabled" -and
            (
                $_.InterfaceDescription -match "Wireless|Wi-Fi|802\.11|WLAN" -or
                $_.Name -match "Wi-Fi|WiFi|Wireless|WLAN"
            )
        } |
        Select-Object -First 1
}

$InterfaceExists =
    ($null -ne $WiFiAdapter)

$InterfaceUp =
    (
        $InterfaceExists -and
        $WiFiAdapter.Status -eq "Up"
    )

Write-Host "Existe interfaz : $InterfaceExists"
Write-Host "Estado Up       : $InterfaceUp"

if ($InterfaceExists) {

    Write-Host `
        "Descripcion     : $($WiFiAdapter.InterfaceDescription)"

    Write-Host `
        "InterfaceIndex  : $($WiFiAdapter.ifIndex)"
}

# ============================================================
# 2. SSID ACTUAL
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. SSID ACTUAL"
Write-Host "========================================"

$CurrentSSID = $null

try {

    $WlanInfo = netsh wlan show interfaces

    $SSIDMatch = $WlanInfo |
        Select-String '^\s*SSID\s*:' |
        Select-Object -First 1

    if ($SSIDMatch) {

        $CurrentSSID = (
            $SSIDMatch.ToString().Split(":", 2)[1]
        ).Trim()
    }
}
catch {

    $CurrentSSID = $null
}

Write-Host "SSID actual : $CurrentSSID"

$AlreadyOnTarget =
    (
        -not [string]::IsNullOrWhiteSpace($CurrentSSID) -and
        $CurrentSSID -eq $TargetSSID
    )

Write-Host "Ya en objetivo : $AlreadyOnTarget"

# ============================================================
# 3. PERFIL WI-FI CONOCIDO
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. PERFIL OBJETIVO"
Write-Host "========================================"

$ProfileKnown = $false

try {

    $ProfilesOutput =
        netsh wlan show profiles

    $ProfileLines = $ProfilesOutput |
        Select-String `
            "Perfil de todos los usuarios|All User Profile"

    foreach ($Line in $ProfileLines) {

        $ProfileName = (
            $Line.ToString().Split(":", 2)[1]
        ).Trim()

        if ($ProfileName -eq $TargetSSID) {

            $ProfileKnown = $true
            break
        }
    }
}
catch {

    $ProfileKnown = $false
}

Write-Host "Perfil conocido : $ProfileKnown"

# ============================================================
# 4. RED OBJETIVO VISIBLE
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "4. VISIBILIDAD DE RED"
Write-Host "========================================"

$TargetVisible = $false

try {

    $VisibleNetworks =
        netsh wlan show networks mode=bssid

    $VisibleSSIDLines = $VisibleNetworks |
        Select-String '^\s*SSID\s+\d+\s*:'

    foreach ($Line in $VisibleSSIDLines) {

        $VisibleSSID = (
            $Line.ToString().Split(":", 2)[1]
        ).Trim()

        if ($VisibleSSID -eq $TargetSSID) {

            $TargetVisible = $true
            break
        }
    }
}
catch {

    $TargetVisible = $false
}

Write-Host "Red visible : $TargetVisible"

# ============================================================
# 5. CLASIFICACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "5. CLASIFICACION"
Write-Host "========================================"

$Classification =
    "WIFI_CANDIDATE_UNKNOWN"

$CanAttemptSwitch =
    $false

if (-not $InterfaceExists) {

    $Classification =
        "WIFI_INTERFACE_NOT_FOUND"
}
elseif (-not $InterfaceUp) {

    $Classification =
        "WIFI_INTERFACE_NOT_ACTIVE"
}
elseif ($AlreadyOnTarget) {

    $Classification =
        "ALREADY_ON_TARGET_WIFI"

    $CanAttemptSwitch =
        $false
}
elseif (-not $ProfileKnown) {

    $Classification =
        "TARGET_WIFI_PROFILE_NOT_FOUND"
}
elseif (-not $TargetVisible) {

    $Classification =
        "TARGET_WIFI_NOT_VISIBLE"
}
else {

    $Classification =
        "WIFI_SWITCH_CANDIDATE_AVAILABLE"

    $CanAttemptSwitch =
        $true
}

Write-Host `
    "Resultado : $Classification" `
    -ForegroundColor Green

# ============================================================
# 6. INTERPRETACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "6. INTERPRETACION PRINTSWITCH"
Write-Host "========================================"

switch ($Classification) {

    "WIFI_SWITCH_CANDIDATE_AVAILABLE" {

        Write-Host `
            "Wi-Fi puede evaluarse como camino alternativo." `
            -ForegroundColor Green

        Write-Host `
            "El cambio todavia NO fue ejecutado."
    }

    "ALREADY_ON_TARGET_WIFI" {

        Write-Host `
            "Wi-Fi ya esta conectado a la red objetivo." `
            -ForegroundColor Green
    }

    "TARGET_WIFI_NOT_VISIBLE" {

        Write-Host `
            "La red objetivo no esta visible actualmente." `
            -ForegroundColor Yellow
    }

    "TARGET_WIFI_PROFILE_NOT_FOUND" {

        Write-Host `
            "Windows no posee un perfil conocido para la red objetivo." `
            -ForegroundColor Yellow
    }

    default {

        Write-Host `
            "Wi-Fi no puede considerarse un candidato seguro." `
            -ForegroundColor Yellow
    }
}

# ============================================================
# 7. RESULTADO ESTRUCTURADO
# ============================================================

$WiFiResult = [PSCustomObject]@{

    Component =
        "WiFiCandidateEvaluator"

    Version =
        "0.1"

    Timestamp =
        Get-Date

    TargetSSID =
        $TargetSSID

    InterfaceName =
        $WiFiInterfaceName

    InterfaceExists =
        $InterfaceExists

    InterfaceUp =
        $InterfaceUp

    CurrentSSID =
        $CurrentSSID

    AlreadyOnTarget =
        $AlreadyOnTarget

    ProfileKnown =
        $ProfileKnown

    TargetVisible =
        $TargetVisible

    Classification =
        $Classification

    CanAttemptSwitch =
        $CanAttemptSwitch
}

Write-Host ""
Write-Host "========================================"
Write-Host "7. RESULTADO ESTRUCTURADO"
Write-Host "========================================"

Write-Host `
    "Classification : $($WiFiResult.Classification)"

Write-Host `
    "CurrentSSID    : $($WiFiResult.CurrentSSID)"

Write-Host `
    "TargetSSID     : $($WiFiResult.TargetSSID)"

Write-Host `
    "ProfileKnown   : $($WiFiResult.ProfileKnown)"

Write-Host `
    "TargetVisible  : $($WiFiResult.TargetVisible)"

Write-Host `
    "CanAttemptSwitch: $($WiFiResult.CanAttemptSwitch)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN WIFICANDIDATEEVALUATOR v0.1"
Write-Host "========================================"

$WiFiResult