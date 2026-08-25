param (
    [string]$TargetIP = "192.168.1.108",

    [int]$TcpPort = 9100,

    [int]$TcpTimeoutMs = 1200
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - RouteAnalyzer v0.2
#
# Analiza:
# - interfaces activas
# - ruta elegida por Windows
# - interfaz primaria estimada
# - alcanzabilidad real del destino
#
# No modifica red, rutas ni interfaces.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - RouteAnalyzer v0.2" `
    -ForegroundColor Cyan

Write-Host "Modo: ANALISIS NO INTRUSIVO" `
    -ForegroundColor Yellow

Write-Host ""
Write-Host "Destino analizado : $TargetIP"
Write-Host "Puerto TCP prueba : $TcpPort"
Write-Host "Timeout TCP       : $TcpTimeoutMs ms"

# ============================================================
# FUNCION: TCP RAPIDO
# ============================================================

function Test-FastTcpPort {

    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutMs
    )

    $Client = New-Object System.Net.Sockets.TcpClient

    try {

        $ConnectTask = $Client.ConnectAsync(
            $ComputerName,
            $Port
        )

        $Completed = $ConnectTask.Wait(
            $TimeoutMs
        )

        if (-not $Completed) {
            return $false
        }

        return $Client.Connected
    }
    catch {
        return $false
    }
    finally {

        $Client.Close()
        $Client.Dispose()
    }
}

# ============================================================
# 1. ADAPTADORES ACTIVOS
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "1. ADAPTADORES ACTIVOS"
Write-Host "========================================"

$Adapters = @(
    Get-NetAdapter `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Status -eq "Up"
        }
)

foreach ($Adapter in $Adapters) {

    Write-Host ""
    Write-Host "Nombre        : $($Adapter.Name)"
    Write-Host "Descripcion   : $($Adapter.InterfaceDescription)"
    Write-Host "Estado        : $($Adapter.Status)"
    Write-Host "Velocidad     : $($Adapter.LinkSpeed)"
    Write-Host "InterfaceIndex: $($Adapter.ifIndex)"
}

# ============================================================
# 2. INFORMACION IPv4
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. CONFIGURACION IPv4"
Write-Host "========================================"

$InterfaceResults = @()

foreach ($Adapter in $Adapters) {

    $IPConfig = Get-NetIPConfiguration `
        -InterfaceIndex $Adapter.ifIndex `
        -ErrorAction SilentlyContinue

    $IPv4Address = $null
    $Gateway = $null
    $DnsServers = @()

    if ($null -ne $IPConfig) {

        if ($null -ne $IPConfig.IPv4Address) {

            $IPv4Address =
                $IPConfig.IPv4Address.IPAddress |
                Select-Object -First 1
        }

        if ($null -ne $IPConfig.IPv4DefaultGateway) {

            $Gateway =
                $IPConfig.IPv4DefaultGateway.NextHop
        }

        if ($null -ne $IPConfig.DNSServer) {

            $DnsServers =
                @(
                    $IPConfig.DNSServer.ServerAddresses
                )
        }
    }

    # --------------------------------------------------------
    # TIPO DE INTERFAZ
    # --------------------------------------------------------

    $InterfaceType = "Other"

    if (
        $Adapter.InterfaceDescription -match "Wireless|Wi-Fi|802\.11"
    ) {

        $InterfaceType = "WiFi"
    }
    elseif (
        $Adapter.InterfaceDescription -match "Ethernet|PCIe|GbE|Gigabit"
    ) {

        $InterfaceType = "Ethernet"
    }

    # --------------------------------------------------------
    # METRICA
    # --------------------------------------------------------

    $IPv4Interface = Get-NetIPInterface `
        -InterfaceIndex $Adapter.ifIndex `
        -AddressFamily IPv4 `
        -ErrorAction SilentlyContinue

    $InterfaceMetric = $null

    if ($null -ne $IPv4Interface) {
        $InterfaceMetric = $IPv4Interface.InterfaceMetric
    }

    # --------------------------------------------------------
    # DEFAULT ROUTE
    # --------------------------------------------------------

    $DefaultRoute = Get-NetRoute `
        -InterfaceIndex $Adapter.ifIndex `
        -AddressFamily IPv4 `
        -DestinationPrefix "0.0.0.0/0" `
        -ErrorAction SilentlyContinue |
        Sort-Object RouteMetric |
        Select-Object -First 1

    $HasDefaultRoute = ($null -ne $DefaultRoute)

    $DefaultRouteMetric = $null

    if ($HasDefaultRoute) {
        $DefaultRouteMetric = $DefaultRoute.RouteMetric
    }

    $InterfaceResults += [PSCustomObject]@{

        Name =
            $Adapter.Name

        InterfaceIndex =
            $Adapter.ifIndex

        InterfaceType =
            $InterfaceType

        Status =
            $Adapter.Status

        IPv4Address =
            $IPv4Address

        Gateway =
            $Gateway

        DnsServers =
            ($DnsServers -join ",")

        InterfaceMetric =
            $InterfaceMetric

        HasDefaultRoute =
            $HasDefaultRoute

        DefaultRouteMetric =
            $DefaultRouteMetric
    }
}

$InterfaceResults |
    Format-Table `
        Name,
        InterfaceType,
        IPv4Address,
        Gateway,
        InterfaceMetric,
        HasDefaultRoute,
        DefaultRouteMetric `
        -AutoSize

# ============================================================
# 3. RUTA HACIA EL DESTINO
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. RUTA HACIA EL DESTINO"
Write-Host "========================================"

try {

    $BestRoute = Find-NetRoute `
        -RemoteIPAddress $TargetIP `
        -ErrorAction Stop |
        Where-Object {
            $_.CimClass.CimClassName -eq "MSFT_NetRoute"
        } |
        Select-Object -First 1

}
catch {

    $BestRoute = $null
}

$SelectedInterfaceIndex = $null
$SelectedInterfaceAlias = $null
$SelectedNextHop = $null
$SelectedRouteMetric = $null

if ($null -ne $BestRoute) {

    $SelectedInterfaceIndex =
        $BestRoute.InterfaceIndex

    $SelectedInterfaceAlias =
        $BestRoute.InterfaceAlias

    $SelectedNextHop =
        $BestRoute.NextHop

    $SelectedRouteMetric =
        $BestRoute.RouteMetric

    Write-Host "Interfaz elegida : $SelectedInterfaceAlias"
    Write-Host "InterfaceIndex    : $SelectedInterfaceIndex"
    Write-Host "NextHop           : $SelectedNextHop"
    Write-Host "RouteMetric       : $SelectedRouteMetric"

}
else {

    Write-Host `
        "No se pudo determinar una ruta." `
        -ForegroundColor Yellow
}

$SelectedInterface = $InterfaceResults |
    Where-Object {
        $_.InterfaceIndex -eq $SelectedInterfaceIndex
    } |
    Select-Object -First 1

# ============================================================
# 4. CONECTIVIDAD GENERAL
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "4. CONECTIVIDAD GENERAL"
Write-Host "========================================"

$DefaultCandidates = @(
    $InterfaceResults |
        Where-Object {
            $_.HasDefaultRoute -eq $true
        } |
        Sort-Object `
            InterfaceMetric,
            DefaultRouteMetric
)

$PrimaryInternetInterface = $null

if ($DefaultCandidates.Count -gt 0) {

    $PrimaryInternetInterface =
        $DefaultCandidates[0]

    Write-Host `
        "Interfaz primaria estimada : $($PrimaryInternetInterface.Name)"

    Write-Host `
        "Tipo                      : $($PrimaryInternetInterface.InterfaceType)"

    Write-Host `
        "IPv4                      : $($PrimaryInternetInterface.IPv4Address)"

    Write-Host `
        "Gateway                   : $($PrimaryInternetInterface.Gateway)"
}
else {

    Write-Host `
        "No se detecto una interfaz primaria." `
        -ForegroundColor Yellow
}

# ============================================================
# 5. ALCANZABILIDAD REAL
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "5. ALCANZABILIDAD REAL"
Write-Host "========================================"

$PingSucceeded = $false
$TcpSucceeded = $false

try {

    $PingSucceeded = Test-Connection `
        -ComputerName $TargetIP `
        -Count 1 `
        -Quiet `
        -ErrorAction SilentlyContinue
}
catch {

    $PingSucceeded = $false
}

$TcpSucceeded = Test-FastTcpPort `
    -ComputerName $TargetIP `
    -Port $TcpPort `
    -TimeoutMs $TcpTimeoutMs

$TargetReachable =
    $PingSucceeded -or
    $TcpSucceeded

Write-Host "PingSucceeded : $PingSucceeded"
Write-Host "TcpSucceeded  : $TcpSucceeded"
Write-Host "TargetReachable: $TargetReachable"

# ============================================================
# 6. CLASIFICACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "6. CLASIFICACION"
Write-Host "========================================"

$Classification = "ROUTE_UNKNOWN"

if ($null -eq $SelectedInterface) {

    $Classification =
        "ROUTE_UNKNOWN"
}
elseif (-not $TargetReachable) {

    $Classification =
        "TARGET_ROUTE_EXISTS_BUT_UNREACHABLE"
}
elseif ($SelectedInterface.InterfaceType -eq "Ethernet") {

    $Classification =
        "TARGET_REACHABLE_VIA_ETHERNET"
}
elseif ($SelectedInterface.InterfaceType -eq "WiFi") {

    $Classification =
        "TARGET_REACHABLE_VIA_WIFI"
}
else {

    $Classification =
        "TARGET_REACHABLE_VIA_OTHER"
}

Write-Host "Resultado : $Classification" `
    -ForegroundColor Green

# ============================================================
# 7. POLITICA OBSERVADA
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "7. INTERPRETACION PRINTSWITCH"
Write-Host "========================================"

$SuggestedAction =
    "NO_DECISION"

if ($Classification -eq "TARGET_REACHABLE_VIA_ETHERNET") {

    $SuggestedAction =
        "NO_WIFI_SWITCH_REQUIRED"

    Write-Host `
        "La impresora ya es alcanzable por Ethernet."

    Write-Host `
        "Wi-Fi no necesita modificarse." `
        -ForegroundColor Green

}
elseif ($Classification -eq "TARGET_REACHABLE_VIA_WIFI") {

    $SuggestedAction =
        "NO_NETWORK_CHANGE_REQUIRED"

    Write-Host `
        "La impresora ya es alcanzable por Wi-Fi."

    Write-Host `
        "No se requiere cambio de red." `
        -ForegroundColor Green

}
elseif (
    $Classification -eq
    "TARGET_ROUTE_EXISTS_BUT_UNREACHABLE"
) {

    if (
        $null -ne $PrimaryInternetInterface -and
        $PrimaryInternetInterface.InterfaceType -eq "Ethernet"
    ) {

        $SuggestedAction =
            "PRESERVE_ETHERNET_EVALUATE_WIFI"

        Write-Host `
            "Ethernet sostiene la conectividad general."

        Write-Host `
            "El destino no es alcanzable actualmente."

        Write-Host `
            "PrintSwitch podria preservar Ethernet y evaluar Wi-Fi." `
            -ForegroundColor Yellow
    }
    else {

        $SuggestedAction =
            "EVALUATE_CONNECTIVITY_RECOVERY"

        Write-Host `
            "El destino no es alcanzable actualmente."

        Write-Host `
            "Debe evaluarse una estrategia de recuperacion." `
            -ForegroundColor Yellow
    }
}

# ============================================================
# 8. RESULTADO ESTRUCTURADO
# ============================================================

$RouteResult = [PSCustomObject]@{

    Component =
        "RouteAnalyzer"

    Version =
        "0.2"

    Timestamp =
        Get-Date

    TargetIP =
        $TargetIP

    TcpPort =
        $TcpPort

    TcpTimeoutMs =
        $TcpTimeoutMs

    Classification =
        $Classification

    SuggestedAction =
        $SuggestedAction

    TargetReachable =
        $TargetReachable

    PingSucceeded =
        $PingSucceeded

    TcpSucceeded =
        $TcpSucceeded

    SelectedInterface =
        $SelectedInterfaceAlias

    SelectedInterfaceIndex =
        $SelectedInterfaceIndex

    SelectedInterfaceType =
        $SelectedInterface.InterfaceType

    SelectedNextHop =
        $SelectedNextHop

    SelectedRouteMetric =
        $SelectedRouteMetric

    PrimaryInternetInterface =
        $PrimaryInternetInterface.Name

    PrimaryInternetInterfaceType =
        $PrimaryInternetInterface.InterfaceType

    Interfaces =
        $InterfaceResults
}

Write-Host ""
Write-Host "========================================"
Write-Host "8. RESULTADO ESTRUCTURADO"
Write-Host "========================================"

Write-Host `
    "Classification        : $($RouteResult.Classification)"

Write-Host `
    "SuggestedAction       : $($RouteResult.SuggestedAction)"

Write-Host `
    "TargetReachable       : $($RouteResult.TargetReachable)"

Write-Host `
    "SelectedInterface     : $($RouteResult.SelectedInterface)"

Write-Host `
    "SelectedInterfaceType : $($RouteResult.SelectedInterfaceType)"

Write-Host `
    "PrimaryInternet       : $($RouteResult.PrimaryInternetInterface)"

Write-Host `
    "PrimaryInternetType   : $($RouteResult.PrimaryInternetInterfaceType)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN ROUTEANALYZER v0.2"
Write-Host "========================================"

$RouteResult