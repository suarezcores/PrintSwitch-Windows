param (
    [Parameter(Mandatory = $true)]
    $RouteResult,

    [string]$TargetSSID
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - ConnectivityPolicy v0.1
#
# Responsabilidad:
# convertir observaciones de RouteAnalyzer en una decision.
#
# NO:
# - cambia Wi-Fi
# - modifica Ethernet
# - altera rutas
# - comprueba impresoras
#
# Solo decide.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - ConnectivityPolicy v0.1" `
    -ForegroundColor Cyan

Write-Host "Modo: DECISION NO INTRUSIVA" `
    -ForegroundColor Yellow

Write-Host ""

# ============================================================
# 1. VALIDAR ENTRADA
# ============================================================

if ($null -eq $RouteResult) {

    Write-Host `
        "ERROR: RouteResult es nulo." `
        -ForegroundColor Red

    return
}

if (
    [string]::IsNullOrWhiteSpace(
        [string]$RouteResult.Classification
    )
) {

    Write-Host `
        "ERROR: RouteResult no contiene Classification." `
        -ForegroundColor Red

    return
}

Write-Host "========================================"
Write-Host "1. CONTEXTO RECIBIDO"
Write-Host "========================================"

Write-Host `
    "RouteClassification : $($RouteResult.Classification)"

Write-Host `
    "TargetReachable     : $($RouteResult.TargetReachable)"

Write-Host `
    "SelectedInterface   : $($RouteResult.SelectedInterface)"

Write-Host `
    "SelectedType        : $($RouteResult.SelectedInterfaceType)"

Write-Host `
    "PrimaryInternet     : $($RouteResult.PrimaryInternetInterface)"

Write-Host `
    "PrimaryInternetType : $($RouteResult.PrimaryInternetInterfaceType)"

Write-Host `
    "TargetSSID          : $TargetSSID"

# ============================================================
# 2. DECISION
# ============================================================

$PolicyDecision =
    "POLICY_UNDETERMINED"

$ShouldSwitchWiFi =
    $false

$PreserveEthernet =
    $false

$Reason =
    ""

switch ($RouteResult.Classification) {

    # --------------------------------------------------------
    # HAPPY PATH:
    # impresora alcanzable por Ethernet
    # --------------------------------------------------------

    "TARGET_REACHABLE_VIA_ETHERNET" {

        $PolicyDecision =
            "NO_ACTION"

        $ShouldSwitchWiFi =
            $false

        $PreserveEthernet =
            $true

        $Reason =
            "Printer already reachable via Ethernet."
    }

    # --------------------------------------------------------
    # HAPPY PATH:
    # impresora alcanzable por Wi-Fi
    # --------------------------------------------------------

    "TARGET_REACHABLE_VIA_WIFI" {

        $PolicyDecision =
            "NO_ACTION"

        $ShouldSwitchWiFi =
            $false

        $PreserveEthernet =
            (
                $RouteResult.PrimaryInternetInterfaceType `
                    -eq "Ethernet"
            )

        $Reason =
            "Printer already reachable via Wi-Fi."
    }

    # --------------------------------------------------------
    # Existe ruta pero destino no responde
    # --------------------------------------------------------

    "TARGET_ROUTE_EXISTS_BUT_UNREACHABLE" {

        if (
            $RouteResult.PrimaryInternetInterfaceType `
                -eq "Ethernet"
        ) {

            $PolicyDecision =
                "PRESERVE_ETHERNET_EVALUATE_WIFI"

            $ShouldSwitchWiFi =
                $false

            $PreserveEthernet =
                $true

            $Reason =
                "Ethernet preserves general connectivity while printer is currently unreachable."
        }
        else {

            $PolicyDecision =
                "EVALUATE_WIFI_RECOVERY"

            $ShouldSwitchWiFi =
                $false

            $PreserveEthernet =
                $false

            $Reason =
                "Printer unreachable and no protected Ethernet path was detected."
        }
    }

    # --------------------------------------------------------
    # Ruta desconocida
    # --------------------------------------------------------

    "ROUTE_UNKNOWN" {

        $PolicyDecision =
            "INSUFFICIENT_ROUTE_INFORMATION"

        $ShouldSwitchWiFi =
            $false

        $PreserveEthernet =
            (
                $RouteResult.PrimaryInternetInterfaceType `
                    -eq "Ethernet"
            )

        $Reason =
            "Route information is insufficient to authorize a network change."
    }

    # --------------------------------------------------------
    # Otros estados
    # --------------------------------------------------------

    default {

        $PolicyDecision =
            "UNSUPPORTED_ROUTE_STATE"

        $ShouldSwitchWiFi =
            $false

        $PreserveEthernet =
            (
                $RouteResult.PrimaryInternetInterfaceType `
                    -eq "Ethernet"
            )

        $Reason =
            "Route classification is not yet supported by ConnectivityPolicy."
    }
}

# ============================================================
# 3. INTERPRETACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. DECISION"
Write-Host "========================================"

switch ($PolicyDecision) {

    "NO_ACTION" {

        Write-Host `
            "Decision : NO_ACTION" `
            -ForegroundColor Green

        Write-Host `
            "La impresora ya es alcanzable."

        Write-Host `
            "PrintSwitch no debe modificar Wi-Fi."
    }

    "PRESERVE_ETHERNET_EVALUATE_WIFI" {

        Write-Host `
            "Decision : PRESERVE_ETHERNET_EVALUATE_WIFI" `
            -ForegroundColor Yellow

        Write-Host `
            "Ethernet mantiene la conectividad general."

        Write-Host `
            "Debe preservarse."

        Write-Host `
            "Wi-Fi puede evaluarse como camino alternativo hacia la impresora."
    }

    "EVALUATE_WIFI_RECOVERY" {

        Write-Host `
            "Decision : EVALUATE_WIFI_RECOVERY" `
            -ForegroundColor Yellow

        Write-Host `
            "La impresora no es alcanzable."

        Write-Host `
            "Debe evaluarse una posible recuperacion Wi-Fi."
    }

    default {

        Write-Host `
            "Decision : $PolicyDecision" `
            -ForegroundColor Yellow

        Write-Host `
            "No se autoriza ningun cambio automatico."
    }
}

# ============================================================
# 4. RESULTADO ESTRUCTURADO
# ============================================================

$PolicyResult = [PSCustomObject]@{

    Component =
        "ConnectivityPolicy"

    Version =
        "0.1"

    Timestamp =
        Get-Date

    RouteClassification =
        $RouteResult.Classification

    Decision =
        $PolicyDecision

    TargetSSID =
        $TargetSSID

    TargetReachable =
        $RouteResult.TargetReachable

    SelectedInterface =
        $RouteResult.SelectedInterface

    SelectedInterfaceType =
        $RouteResult.SelectedInterfaceType

    PrimaryInternetInterface =
        $RouteResult.PrimaryInternetInterface

    PrimaryInternetInterfaceType =
        $RouteResult.PrimaryInternetInterfaceType

    PreserveEthernet =
        $PreserveEthernet

    ShouldSwitchWiFi =
        $ShouldSwitchWiFi

    Reason =
        $Reason
}

Write-Host ""
Write-Host "========================================"
Write-Host "3. RESULTADO ESTRUCTURADO"
Write-Host "========================================"

Write-Host `
    "Decision            : $($PolicyResult.Decision)"

Write-Host `
    "PreserveEthernet    : $($PolicyResult.PreserveEthernet)"

Write-Host `
    "ShouldSwitchWiFi    : $($PolicyResult.ShouldSwitchWiFi)"

Write-Host `
    "TargetSSID          : $($PolicyResult.TargetSSID)"

Write-Host `
    "SelectedInterface   : $($PolicyResult.SelectedInterface)"

Write-Host `
    "PrimaryInternet     : $($PolicyResult.PrimaryInternetInterface)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN CONNECTIVITYPOLICY v0.1"
Write-Host "========================================"

$PolicyResult