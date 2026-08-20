$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - NetworkManager v0.3
# Cambio real de Wi-Fi + verificacion
# ============================================================

$TargetSSID = "suarezcores"

Write-Host ""
Write-Host "PrintSwitch - NetworkManager v0.3" -ForegroundColor Cyan
Write-Host "Modo: CAMBIO CONTROLADO + VERIFICACION" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# FUNCION: obtener SSID actual
# ============================================================

function Get-CurrentSSID {

    $InterfaceInfo = netsh wlan show interfaces

    $CurrentSSIDMatch = $InterfaceInfo |
        Select-String '^\s*SSID\s*:' |
        Select-Object -First 1

    if ($CurrentSSIDMatch) {

        return (
            $CurrentSSIDMatch.ToString().Split(":", 2)[1]
        ).Trim()
    }

    return $null
}

# ============================================================
# 1. ESTADO INICIAL
# ============================================================

$InitialSSID = Get-CurrentSSID

Write-Host "SSID inicial  : $InitialSSID"
Write-Host "SSID objetivo : $TargetSSID"

# ============================================================
# 2. PERFIL OBJETIVO
# ============================================================

$ProfilesOutput = netsh wlan show profiles
$KnownProfiles = @()

foreach ($Line in $ProfilesOutput) {

    if ($Line -match ":\s*(.+)$") {

        $PossibleProfile = $Matches[1].Trim()

        if ($PossibleProfile) {
            $KnownProfiles += $PossibleProfile
        }
    }
}

$TargetProfileKnown = $KnownProfiles -contains $TargetSSID

# ============================================================
# 3. RED OBJETIVO VISIBLE
# ============================================================

$VisibleNetworksOutput = netsh wlan show networks mode=bssid
$VisibleSSIDs = @()

foreach ($Line in $VisibleNetworksOutput) {

    if ($Line -match '^\s*SSID\s+\d+\s*:\s*(.*)$') {

        $VisibleSSID = $Matches[1].Trim()

        if ($VisibleSSID) {
            $VisibleSSIDs += $VisibleSSID
        }
    }
}

$TargetNetworkVisible = $VisibleSSIDs -contains $TargetSSID

Write-Host "Perfil conocido : $TargetProfileKnown"
Write-Host "Red visible     : $TargetNetworkVisible"

# ============================================================
# 4. CLASIFICACION PREVIA
# ============================================================

if ($InitialSSID -eq $TargetSSID) {

    $Classification = "ALREADY_ON_TARGET_NETWORK"

}
elseif (-not $TargetProfileKnown) {

    $Classification = "TARGET_PROFILE_NOT_FOUND"

}
elseif (-not $TargetNetworkVisible) {

    $Classification = "TARGET_NETWORK_NOT_VISIBLE"

}
else {

    $Classification = "NETWORK_SWITCH_AVAILABLE"
}

Write-Host ""
Write-Host "Clasificacion inicial : $Classification" -ForegroundColor Green

# ============================================================
# 5. CAMBIO DE RED
# ============================================================

$SwitchRequested = $false
$CommandIssued = $false
$SwitchVerified = $false
$FinalSSID = $InitialSSID

if ($Classification -eq "NETWORK_SWITCH_AVAILABLE") {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "CAMBIO DE RED DISPONIBLE"
    Write-Host "========================================"

    Write-Host "$InitialSSID -> $TargetSSID"
    Write-Host ""

    $Confirmation = Read-Host "Escriba SI para autorizar el cambio"

    if ($Confirmation -eq "SI") {

        $SwitchRequested = $true

        Write-Host ""
        Write-Host "Solicitando conexion a '$TargetSSID'..."

        $ConnectOutput = netsh wlan connect `
            name="$TargetSSID" `
            ssid="$TargetSSID"

        $CommandIssued = $true

        Write-Host ""
        Write-Host "Respuesta de Windows:"

        foreach ($Line in $ConnectOutput) {
            Write-Host $Line
        }

        # ====================================================
        # 6. VERIFICACION
        # ====================================================

        Write-Host ""
        Write-Host "Esperando estabilizacion de Wi-Fi..."

        $MaximumAttempts = 10
        $DelaySeconds = 1

        for ($Attempt = 1; $Attempt -le $MaximumAttempts; $Attempt++) {

            Start-Sleep -Seconds $DelaySeconds

            $FinalSSID = Get-CurrentSSID

            Write-Host "Intento $Attempt/$MaximumAttempts - SSID detectado: $FinalSSID"

            if ($FinalSSID -eq $TargetSSID) {

                $SwitchVerified = $true
                break
            }
        }

        Write-Host ""
        Write-Host "========================================"
        Write-Host "VERIFICACION"
        Write-Host "========================================"

        Write-Host "SSID inicial    : $InitialSSID"
        Write-Host "SSID solicitado : $TargetSSID"
        Write-Host "SSID final      : $FinalSSID"
        Write-Host "Cambio verificado: $SwitchVerified"

        if ($SwitchVerified) {

            Write-Host ""
            Write-Host "RESULTADO: NETWORK_SWITCH_VERIFIED" `
                -ForegroundColor Green

        }
        else {

            Write-Host ""
            Write-Host "RESULTADO: NETWORK_SWITCH_NOT_VERIFIED" `
                -ForegroundColor Red
        }
    }
    else {

        Write-Host ""
        Write-Host "Cambio cancelado por el usuario."
    }

}
elseif ($Classification -eq "ALREADY_ON_TARGET_NETWORK") {

    $SwitchVerified = $true
    $FinalSSID = $InitialSSID

    Write-Host ""
    Write-Host "No se requiere cambio."

}
elseif ($Classification -eq "TARGET_PROFILE_NOT_FOUND") {

    Write-Host ""
    Write-Host "No se intentara conexion."
    Write-Host "Windows no posee el perfil '$TargetSSID'."

}
elseif ($Classification -eq "TARGET_NETWORK_NOT_VISIBLE") {

    Write-Host ""
    Write-Host "No se intentara conexion."
    Write-Host "La red '$TargetSSID' no esta visible."
}

# ============================================================
# 7. RESULTADO ESTRUCTURADO
# ============================================================

$NetworkResult = [PSCustomObject]@{

    Component            = "NetworkManager"
    Version              = "0.3"

    Timestamp            = Get-Date

    InitialSSID          = $InitialSSID
    TargetSSID           = $TargetSSID
    FinalSSID            = $FinalSSID

    TargetProfileKnown   = $TargetProfileKnown
    TargetNetworkVisible = $TargetNetworkVisible

    Classification       = $Classification

    SwitchRequested      = $SwitchRequested
    CommandIssued        = $CommandIssued
    SwitchVerified       = $SwitchVerified
}

Write-Host ""
Write-Host "========================================"
Write-Host "RESULTADO ESTRUCTURADO"
Write-Host "========================================"

Write-Host "Component             : $($NetworkResult.Component)"
Write-Host "Version               : $($NetworkResult.Version)"
Write-Host "InitialSSID           : $($NetworkResult.InitialSSID)"
Write-Host "TargetSSID            : $($NetworkResult.TargetSSID)"
Write-Host "FinalSSID             : $($NetworkResult.FinalSSID)"
Write-Host "TargetProfileKnown    : $($NetworkResult.TargetProfileKnown)"
Write-Host "TargetNetworkVisible  : $($NetworkResult.TargetNetworkVisible)"
Write-Host "Classification        : $($NetworkResult.Classification)"
Write-Host "SwitchRequested       : $($NetworkResult.SwitchRequested)"
Write-Host "CommandIssued         : $($NetworkResult.CommandIssued)"
Write-Host "SwitchVerified        : $($NetworkResult.SwitchVerified)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN NETWORKMANAGER v0.3"
Write-Host "========================================"

$NetworkResult