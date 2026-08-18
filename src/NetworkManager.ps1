$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - NetworkManager v0.1
# Inspeccion de redes + decision DRY-RUN
# NO modifica la conectividad
# ============================================================

$TargetSSID = "suarezcores"

Write-Host ""
Write-Host "PrintSwitch - NetworkManager v0.1" -ForegroundColor Cyan
Write-Host "Modo: DRY-RUN" -ForegroundColor Yellow
Write-Host "No se realizaran cambios de red."
Write-Host ""

# ============================================================
# 1. SSID ACTUAL
# ============================================================

Write-Host "========================================"
Write-Host "1. RED ACTUAL"
Write-Host "========================================"

$InterfaceInfo = netsh wlan show interfaces

$CurrentSSIDMatch = $InterfaceInfo |
    Select-String '^\s*SSID\s*:' |
    Select-Object -First 1

$CurrentSSID = $null

if ($CurrentSSIDMatch) {

    $CurrentSSID = (
        $CurrentSSIDMatch.ToString().Split(":", 2)[1]
    ).Trim()
}

if ($CurrentSSID) {

    Write-Host "SSID actual : $CurrentSSID"

}
else {

    Write-Host "SSID actual : NO DETECTADO" -ForegroundColor Yellow
}

# ============================================================
# 2. PERFILES WIFI CONOCIDOS POR WINDOWS
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. PERFIL WIFI OBJETIVO"
Write-Host "========================================"

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

Write-Host "SSID objetivo   : $TargetSSID"
Write-Host "Perfil conocido : $TargetProfileKnown"

# ============================================================
# 3. REDES WIFI VISIBLES
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. RED OBJETIVO VISIBLE"
Write-Host "========================================"

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

Write-Host "SSID objetivo : $TargetSSID"
Write-Host "Red visible   : $TargetNetworkVisible"

# ============================================================
# 4. CLASIFICACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "4. CLASIFICACION"
Write-Host "========================================"

if ($CurrentSSID -eq $TargetSSID) {

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

Write-Host "Resultado : $Classification" -ForegroundColor Green

# ============================================================
# 5. DECISION DRY-RUN
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "5. DECISION PRINTSWITCH - DRY-RUN"
Write-Host "========================================"

switch ($Classification) {

    "ALREADY_ON_TARGET_NETWORK" {

        Write-Host "ACCION PROPUESTA: ninguna." -ForegroundColor Green
        Write-Host "La PC ya esta conectada a '$TargetSSID'."
    }

    "TARGET_PROFILE_NOT_FOUND" {

        Write-Host "ACCION PROPUESTA: no conectar." -ForegroundColor Yellow
        Write-Host "Windows no posee un perfil Wi-Fi conocido para '$TargetSSID'."
    }

    "TARGET_NETWORK_NOT_VISIBLE" {

        Write-Host "ACCION PROPUESTA: esperar / informar." -ForegroundColor Yellow
        Write-Host "El perfil existe, pero '$TargetSSID' no aparece entre las redes visibles."
    }

    "NETWORK_SWITCH_AVAILABLE" {

        Write-Host "ACCION PROPUESTA:" -ForegroundColor Yellow
        Write-Host "$CurrentSSID -> $TargetSSID"

        Write-Host ""
        Write-Host "DRY-RUN:"
        Write-Host "El cambio parece posible, pero NO se ejecutara."
    }

    default {

        Write-Host "ACCION PROPUESTA: ninguna." -ForegroundColor Yellow
        Write-Host "No existe evidencia suficiente para decidir."
    }
}

# ============================================================
# 6. RESULTADO ESTRUCTURADO
# ============================================================

$NetworkResult = [PSCustomObject]@{

    Component            = "NetworkManager"
    Version              = "0.1"

    Timestamp            = Get-Date

    CurrentSSID          = $CurrentSSID
    TargetSSID           = $TargetSSID

    TargetProfileKnown   = $TargetProfileKnown
    TargetNetworkVisible = $TargetNetworkVisible

    Classification       = $Classification

    DryRun               = $true
}

Write-Host ""
Write-Host "========================================"
Write-Host "6. RESULTADO ESTRUCTURADO"
Write-Host "========================================"

Write-Host "Component             : $($NetworkResult.Component)"
Write-Host "Version               : $($NetworkResult.Version)"
Write-Host "CurrentSSID           : $($NetworkResult.CurrentSSID)"
Write-Host "TargetSSID            : $($NetworkResult.TargetSSID)"
Write-Host "TargetProfileKnown    : $($NetworkResult.TargetProfileKnown)"
Write-Host "TargetNetworkVisible  : $($NetworkResult.TargetNetworkVisible)"
Write-Host "Classification        : $($NetworkResult.Classification)"
Write-Host "DryRun                : $($NetworkResult.DryRun)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN DEL ANALISIS DE RED"
Write-Host "========================================"

# Unica salida programatica
$NetworkResult