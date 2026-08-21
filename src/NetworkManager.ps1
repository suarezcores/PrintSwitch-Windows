param (
    [Parameter(Mandatory = $true)]
    [string]$TargetSSID,

    [switch]$AutoExecute
)
$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - NetworkManager v0.4
# Cambio Wi-Fi manual o programatico + verificacion
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - NetworkManager v0.4" -ForegroundColor Cyan

if ($AutoExecute) {
    Write-Host "Modo: EJECUCION PROGRAMATICA" -ForegroundColor Yellow
}
else {
    Write-Host "Modo: EJECUCION MANUAL CONTROLADA" -ForegroundColor Yellow
}

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
# FUNCION: obtener redes visibles
# ============================================================

function Get-VisibleSSIDs {

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

    return $VisibleSSIDs
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

Write-Host "Perfil conocido : $TargetProfileKnown"

# ============================================================
# 3. RED OBJETIVO VISIBLE
# Varios intentos para tolerar estados transitorios
# ============================================================

$TargetNetworkVisible = $false

$VisibilityAttempts = 3
$VisibilityDelaySeconds = 1

for (
    $Attempt = 1;
    $Attempt -le $VisibilityAttempts;
    $Attempt++
) {

    $VisibleSSIDs = Get-VisibleSSIDs

    if ($VisibleSSIDs -contains $TargetSSID) {

        $TargetNetworkVisible = $true
        break
    }

    if ($Attempt -lt $VisibilityAttempts) {

        Write-Host `
            "Red objetivo no detectada. Reintentando $Attempt/$VisibilityAttempts..."

        Start-Sleep -Seconds $VisibilityDelaySeconds
    }
}

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
Write-Host "Clasificacion inicial : $Classification" `
    -ForegroundColor Green

# ============================================================
# 5. VARIABLES DE RESULTADO
# ============================================================

$SwitchAuthorized = $false
$SwitchRequested = $false
$CommandIssued = $false
$SwitchVerified = $false

$FinalSSID = $InitialSSID

# ============================================================
# 6. DECISION DE EJECUCION
# ============================================================

if ($Classification -eq "NETWORK_SWITCH_AVAILABLE") {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "CAMBIO DE RED DISPONIBLE"
    Write-Host "========================================"

    Write-Host "$InitialSSID -> $TargetSSID"
    Write-Host ""

    if ($AutoExecute) {

        $SwitchAuthorized = $true

        Write-Host "Cambio autorizado por componente llamador."

    }
    else {

        $Confirmation = Read-Host `
            "Escriba SI para autorizar el cambio"

        if ($Confirmation -eq "SI") {
            $SwitchAuthorized = $true
        }
    }

    # ========================================================
    # 7. EJECUCION
    # ========================================================

    if ($SwitchAuthorized) {

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
        # 8. VERIFICACION
        # ====================================================

        Write-Host ""
        Write-Host "Esperando estabilizacion de Wi-Fi..."

        $MaximumAttempts = 10
        $DelaySeconds = 1

        for (
            $Attempt = 1;
            $Attempt -le $MaximumAttempts;
            $Attempt++
        ) {

            Start-Sleep -Seconds $DelaySeconds

            $FinalSSID = Get-CurrentSSID

            Write-Host `
                "Intento $Attempt/$MaximumAttempts - SSID detectado: $FinalSSID"

            if ($FinalSSID -eq $TargetSSID) {

                $SwitchVerified = $true
                break
            }
        }

    }
    else {

        Write-Host ""
        Write-Host "Cambio cancelado. No se modifico la red."
    }

}
elseif ($Classification -eq "ALREADY_ON_TARGET_NETWORK") {

    $FinalSSID = $InitialSSID
    $SwitchVerified = $true

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
# 9. RESULTADO FINAL
# ============================================================

if ($SwitchRequested) {

    if ($SwitchVerified) {

        $ExecutionResult = "NETWORK_SWITCH_VERIFIED"

    }
    else {

        $ExecutionResult = "NETWORK_SWITCH_NOT_VERIFIED"
    }

}
elseif ($Classification -eq "ALREADY_ON_TARGET_NETWORK") {

    $ExecutionResult = "NO_SWITCH_REQUIRED"

}
elseif (-not $SwitchAuthorized -and
        $Classification -eq "NETWORK_SWITCH_AVAILABLE") {

    $ExecutionResult = "SWITCH_NOT_AUTHORIZED"

}
else {

    $ExecutionResult = "SWITCH_NOT_AVAILABLE"
}

# ============================================================
# 10. RESULTADO ESTRUCTURADO
# ============================================================

$NetworkResult = [PSCustomObject]@{

    Component            = "NetworkManager"
    Version              = "0.4"

    Timestamp            = Get-Date

    InitialSSID          = $InitialSSID
    TargetSSID           = $TargetSSID
    FinalSSID            = $FinalSSID

    TargetProfileKnown   = $TargetProfileKnown
    TargetNetworkVisible = $TargetNetworkVisible

    Classification       = $Classification

    AutoExecute          = [bool]$AutoExecute
    SwitchAuthorized     = $SwitchAuthorized
    SwitchRequested      = $SwitchRequested
    CommandIssued        = $CommandIssued
    SwitchVerified       = $SwitchVerified

    ExecutionResult      = $ExecutionResult
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
Write-Host "AutoExecute           : $($NetworkResult.AutoExecute)"
Write-Host "SwitchAuthorized      : $($NetworkResult.SwitchAuthorized)"
Write-Host "SwitchRequested       : $($NetworkResult.SwitchRequested)"
Write-Host "CommandIssued         : $($NetworkResult.CommandIssued)"
Write-Host "SwitchVerified        : $($NetworkResult.SwitchVerified)"
Write-Host "ExecutionResult       : $($NetworkResult.ExecutionResult)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN NETWORKMANAGER v0.4"
Write-Host "========================================"

$NetworkResult