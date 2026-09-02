param (
    [Parameter(Mandatory = $true)]
    [string]$TargetIP,

    [int]$TcpPort = 9100,

    [int]$TcpTimeoutMs = 1200
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "PrintSwitch - InterfacePathAnalyzer v0.2" `
    -ForegroundColor Cyan

Write-Host "Modo: ANALISIS DE CAMINOS NO INTRUSIVO" `
    -ForegroundColor Yellow

Write-Host ""
Write-Host "Destino analizado : $TargetIP"
Write-Host "Puerto TCP        : $TcpPort"
Write-Host "Timeout TCP       : $TcpTimeoutMs ms"

# ============================================================
# FUNCION: OBTENER NETWORK ADDRESS
# ============================================================

function Get-NetworkAddress {

    param (
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 32)]
        [int]$PrefixLength
    )

    $IPBytes = (
        [System.Net.IPAddress]::Parse($IPAddress)
    ).GetAddressBytes()

    if ($IPBytes.Length -ne 4) {
        throw "Solo se soportan direcciones IPv4."
    }

    $MaskBytes = New-Object byte[] 4
    $RemainingBits = $PrefixLength

    for ($I = 0; $I -lt 4; $I++) {

        if ($RemainingBits -ge 8) {

            $MaskBytes[$I] = 255
            $RemainingBits -= 8
        }
        elseif ($RemainingBits -gt 0) {

            $MaskBytes[$I] = [byte](
                256 - [math]::Pow(
                    2,
                    8 - $RemainingBits
                )
            )

            $RemainingBits = 0
        }
        else {

            $MaskBytes[$I] = 0
        }
    }

    $NetworkBytes = New-Object byte[] 4

    for ($I = 0; $I -lt 4; $I++) {

        $NetworkBytes[$I] =
            $IPBytes[$I] -band $MaskBytes[$I]
    }

    return (
        New-Object System.Net.IPAddress(
            ,$NetworkBytes
        )
    ).ToString()
}

# ============================================================
# FUNCION: IP EN SUBRED
# ============================================================

function Test-IPInSubnet {

    param (
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,

        [Parameter(Mandatory = $true)]
        [string]$NetworkAddress,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 32)]
        [int]$PrefixLength
    )

    try {

        $CandidateNetwork = Get-NetworkAddress `
            -IPAddress $IPAddress `
            -PrefixLength $PrefixLength

        return (
            $CandidateNetwork -eq $NetworkAddress
        )
    }
    catch {

        return $false
    }
}

# ============================================================
# FUNCION: TCP LIGADO A IP LOCAL
# ============================================================

function Test-BoundTcpPath {

    param (
        [Parameter(Mandatory = $true)]
        [string]$LocalIPAddress,

        [Parameter(Mandatory = $true)]
        [string]$RemoteIPAddress,

        [Parameter(Mandatory = $true)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutMs
    )

    $Stopwatch =
        [System.Diagnostics.Stopwatch]::StartNew()

    $Client = $null

    try {

        $LocalIP =
            [System.Net.IPAddress]::Parse(
                $LocalIPAddress
            )

        $RemoteIP =
            [System.Net.IPAddress]::Parse(
                $RemoteIPAddress
            )

        $LocalEndpoint =
            New-Object System.Net.IPEndPoint(
                $LocalIP,
                0
            )

        $Client =
            New-Object System.Net.Sockets.TcpClient(
                [System.Net.Sockets.AddressFamily]::InterNetwork
            )

        # Fuerza al socket a utilizar esta IP local.
        $Client.Client.Bind($LocalEndpoint)

        $ConnectTask =
            $Client.ConnectAsync(
                $RemoteIP,
                $Port
            )

        $Completed =
            $ConnectTask.Wait(
                $TimeoutMs
            )

        if (-not $Completed) {

            return [PSCustomObject]@{
                Reachable    = $false
                ElapsedMs    = $Stopwatch.ElapsedMilliseconds
                LocalIP      = $LocalIPAddress
                RemoteIP     = $RemoteIPAddress
                Port         = $Port
                Result       = "TIMEOUT"
                ErrorMessage = $null
            }
        }

        if ($Client.Connected) {

            return [PSCustomObject]@{
                Reachable    = $true
                ElapsedMs    = $Stopwatch.ElapsedMilliseconds
                LocalIP      = $LocalIPAddress
                RemoteIP     = $RemoteIPAddress
                Port         = $Port
                Result       = "CONNECTED"
                ErrorMessage = $null
            }
        }

        return [PSCustomObject]@{
            Reachable    = $false
            ElapsedMs    = $Stopwatch.ElapsedMilliseconds
            LocalIP      = $LocalIPAddress
            RemoteIP     = $RemoteIPAddress
            Port         = $Port
            Result       = "NOT_CONNECTED"
            ErrorMessage = $null
        }
    }
    catch {

        return [PSCustomObject]@{
            Reachable    = $false
            ElapsedMs    = $Stopwatch.ElapsedMilliseconds
            LocalIP      = $LocalIPAddress
            RemoteIP     = $RemoteIPAddress
            Port         = $Port
            Result       = "ERROR"
            ErrorMessage = $_.Exception.Message
        }
    }
    finally {

        $Stopwatch.Stop()

        if ($null -ne $Client) {

            $Client.Close()
            $Client.Dispose()
        }
    }
}

# ============================================================
# 1. INTERFACES ACTIVAS
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "1. INTERFACES IPv4 ACTIVAS"
Write-Host "========================================"

$Adapters = @(
    Get-NetAdapter `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Status -eq "Up"
        }
)

$InterfaceResults = @()

foreach ($Adapter in $Adapters) {

    $Addresses = @(
        Get-NetIPAddress `
            -InterfaceIndex $Adapter.ifIndex `
            -AddressFamily IPv4 `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "169.254.*"
        }
    )

    foreach ($Address in $Addresses) {

        $InterfaceType = "Other"

        if (
            $Adapter.InterfaceDescription `
                -match "Wireless|Wi-Fi|802\.11|WLAN"
        ) {

            $InterfaceType = "WiFi"
        }
        elseif (
            $Adapter.InterfaceDescription `
                -match "Ethernet|PCIe|GbE|Gigabit"
        ) {

            $InterfaceType = "Ethernet"
        }

        $NetworkAddress = Get-NetworkAddress `
            -IPAddress $Address.IPAddress `
            -PrefixLength $Address.PrefixLength

        $TargetInsideLocalSubnet = Test-IPInSubnet `
            -IPAddress $TargetIP `
            -NetworkAddress $NetworkAddress `
            -PrefixLength $Address.PrefixLength

        $IPConfig = Get-NetIPConfiguration `
            -InterfaceIndex $Adapter.ifIndex `
            -ErrorAction SilentlyContinue

        $Gateway = $null

        if ($IPConfig.IPv4DefaultGateway) {

            $Gateway =
                $IPConfig.IPv4DefaultGateway.NextHop
        }

        $InterfaceResults += [PSCustomObject]@{

            Name =
                $Adapter.Name

            InterfaceIndex =
                $Adapter.ifIndex

            InterfaceType =
                $InterfaceType

            IPv4Address =
                $Address.IPAddress

            PrefixLength =
                $Address.PrefixLength

            NetworkAddress =
                $NetworkAddress

            NetworkPrefix =
                "$NetworkAddress/$($Address.PrefixLength)"

            Gateway =
                $Gateway

            TargetInsideLocalSubnet =
                $TargetInsideLocalSubnet
        }
    }
}

$InterfaceResults |
    Format-Table `
        Name,
        InterfaceType,
        IPv4Address,
        NetworkPrefix,
        Gateway,
        TargetInsideLocalSubnet `
        -AutoSize |
    Out-Host

# ============================================================
# 2. SOLAPAMIENTO
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. SOLAPAMIENTO DE REDES"
Write-Host "========================================"

$OverlapPairs = @()

for ($I = 0; $I -lt $InterfaceResults.Count; $I++) {

    for ($J = $I + 1; $J -lt $InterfaceResults.Count; $J++) {

        $A = $InterfaceResults[$I]
        $B = $InterfaceResults[$J]

        $AInsideB = Test-IPInSubnet `
            -IPAddress $A.IPv4Address `
            -NetworkAddress $B.NetworkAddress `
            -PrefixLength $B.PrefixLength

        $BInsideA = Test-IPInSubnet `
            -IPAddress $B.IPv4Address `
            -NetworkAddress $A.NetworkAddress `
            -PrefixLength $A.PrefixLength

        if ($AInsideB -or $BInsideA) {

            $OverlapPairs += [PSCustomObject]@{
                InterfaceA = $A.Name
                PrefixA    = $A.NetworkPrefix
                InterfaceB = $B.Name
                PrefixB    = $B.NetworkPrefix
            }
        }
    }
}

$OverlapDetected =
    ($OverlapPairs.Count -gt 0)

Write-Host "OverlapDetected : $OverlapDetected"

foreach ($Pair in $OverlapPairs) {

    Write-Host `
        "$($Pair.InterfaceA) [$($Pair.PrefixA)] <-> $($Pair.InterfaceB) [$($Pair.PrefixB)]" `
        -ForegroundColor Yellow
}

# ============================================================
# 3. CANDIDATOS DIRECTOS
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. CAMINOS CANDIDATOS"
Write-Host "========================================"

$DirectCandidates = @(
    $InterfaceResults |
        Where-Object {
            $_.TargetInsideLocalSubnet -eq $true
        }
)

if ($DirectCandidates.Count -eq 0) {

    Write-Host `
        "No existen caminos locales directos."
}
else {

    foreach ($Candidate in $DirectCandidates) {

        Write-Host ""
        Write-Host "Interfaz   : $($Candidate.Name)"
        Write-Host "Tipo       : $($Candidate.InterfaceType)"
        Write-Host "IPv4 local : $($Candidate.IPv4Address)"
        Write-Host "Red        : $($Candidate.NetworkPrefix)"
    }
}

# ============================================================
# 4. PRUEBAS TCP POR INTERFAZ
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "4. ALCANZABILIDAD POR INTERFAZ"
Write-Host "========================================"

$PathTests = @()

foreach ($Candidate in $DirectCandidates) {

    Write-Host ""
    Write-Host `
        "Probando $($Candidate.Name) [$($Candidate.IPv4Address)] -> $TargetIP`:$TcpPort"

    $TcpTest = Test-BoundTcpPath `
        -LocalIPAddress $Candidate.IPv4Address `
        -RemoteIPAddress $TargetIP `
        -Port $TcpPort `
        -TimeoutMs $TcpTimeoutMs

    $PathTests += [PSCustomObject]@{

        Name =
            $Candidate.Name

        InterfaceIndex =
            $Candidate.InterfaceIndex

        InterfaceType =
            $Candidate.InterfaceType

        LocalIP =
            $Candidate.IPv4Address

        NetworkPrefix =
            $Candidate.NetworkPrefix

        Reachable =
            $TcpTest.Reachable

        ElapsedMs =
            $TcpTest.ElapsedMs

        TcpResult =
            $TcpTest.Result

        ErrorMessage =
            $TcpTest.ErrorMessage
    }

    Write-Host "Reachable : $($TcpTest.Reachable)"
    Write-Host "Resultado : $($TcpTest.Result)"
    Write-Host "Tiempo    : $($TcpTest.ElapsedMs) ms"

    if ($TcpTest.ErrorMessage) {

        Write-Host `
            "Error     : $($TcpTest.ErrorMessage)" `
            -ForegroundColor Yellow
    }
}

$ReachablePaths = @(
    $PathTests |
        Where-Object {
            $_.Reachable -eq $true
        }
)

# ============================================================
# 5. RUTA PREFERIDA WINDOWS
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "5. RUTA PREFERIDA WINDOWS"
Write-Host "========================================"

$BestRoute = $null

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

if ($BestRoute) {

    Write-Host "InterfaceAlias : $($BestRoute.InterfaceAlias)"
    Write-Host "InterfaceIndex : $($BestRoute.InterfaceIndex)"
    Write-Host "Prefix         : $($BestRoute.DestinationPrefix)"
    Write-Host "NextHop        : $($BestRoute.NextHop)"
}

# ============================================================
# 6. CLASIFICACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "6. CLASIFICACION"
Write-Host "========================================"

$Classification =
    "PATH_CONTEXT_UNKNOWN"

$SelectedReachablePath =
    $null

if (
    $ReachablePaths.Count -eq 1
) {

    $Classification =
        "UNIQUE_REACHABLE_PATH"

    $SelectedReachablePath =
        $ReachablePaths[0]

}
elseif (
    $ReachablePaths.Count -gt 1
) {

    $Classification =
        "MULTIPLE_REACHABLE_PATHS"
}
elseif (
    $DirectCandidates.Count -gt 0
) {

    $Classification =
        "CANDIDATE_PATHS_UNREACHABLE"
}
elseif (
    $null -ne $BestRoute
) {

    $Classification =
        "ROUTED_PATH_ONLY"
}
else {

    $Classification =
        "NO_PATH_IDENTIFIED"
}

Write-Host `
    "Resultado : $Classification" `
    -ForegroundColor Green

# ============================================================
# 7. INTERPRETACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "7. INTERPRETACION PRINTSWITCH"
Write-Host "========================================"

switch ($Classification) {

    "UNIQUE_REACHABLE_PATH" {

        Write-Host `
            "Existe un unico camino comprobado hacia la impresora." `
            -ForegroundColor Green

        Write-Host `
            "Interfaz : $($SelectedReachablePath.Name)"

        Write-Host `
            "Tipo     : $($SelectedReachablePath.InterfaceType)"
    }

    "MULTIPLE_REACHABLE_PATHS" {

        Write-Host `
            "Varias interfaces alcanzan la impresora." `
            -ForegroundColor Yellow

        Write-Host `
            "No es necesario modificar rutas automaticamente."
    }

    "CANDIDATE_PATHS_UNREACHABLE" {

        Write-Host `
            "Existen caminos candidatos, pero ninguno responde." `
            -ForegroundColor Yellow

        Write-Host `
            "Debe evaluarse recuperacion de conectividad."
    }

    "ROUTED_PATH_ONLY" {

        Write-Host `
            "No existe camino local directo."

        Write-Host `
            "Windows dispone de una ruta enrutada."
    }

    default {

        Write-Host `
            "No hay evidencia suficiente para seleccionar camino." `
            -ForegroundColor Yellow
    }
}

# ============================================================
# 8. RESULTADO
# ============================================================

$PathResult = [PSCustomObject]@{

    Component =
        "InterfacePathAnalyzer"

    Version =
        "0.2"

    Timestamp =
        Get-Date

    TargetIP =
        $TargetIP

    TcpPort =
        $TcpPort

    Classification =
        $Classification

    OverlapDetected =
        $OverlapDetected

    OverlapCount =
        $OverlapPairs.Count

    DirectCandidateCount =
        $DirectCandidates.Count

    ReachablePathCount =
        $ReachablePaths.Count

    SelectedReachableInterface =
    $(if ($null -ne $SelectedReachablePath) {
        $SelectedReachablePath.Name
    }
    else {
        $null
    })

    SelectedReachableInterfaceType =
    $(if ($null -ne $SelectedReachablePath) {
        $SelectedReachablePath.InterfaceType
    }
    else {
        $null
    })

    SelectedReachableLocalIP =
    $(if ($null -ne $SelectedReachablePath) {
        $SelectedReachablePath.LocalIP
    }
    else {
        $null
    })

    PreferredInterface =
        $BestRoute.InterfaceAlias

    Interfaces =
        $InterfaceResults

    DirectCandidates =
        $DirectCandidates

    PathTests =
        $PathTests

    ReachablePaths =
        $ReachablePaths

    Overlaps =
        $OverlapPairs
}

Write-Host ""
Write-Host "========================================"
Write-Host "8. RESULTADO ESTRUCTURADO"
Write-Host "========================================"

Write-Host `
    "Classification              : $($PathResult.Classification)"

Write-Host `
    "OverlapDetected             : $($PathResult.OverlapDetected)"

Write-Host `
    "DirectCandidateCount        : $($PathResult.DirectCandidateCount)"

Write-Host `
    "ReachablePathCount          : $($PathResult.ReachablePathCount)"

Write-Host `
    "SelectedReachableInterface  : $($PathResult.SelectedReachableInterface)"

Write-Host `
    "SelectedReachableType       : $($PathResult.SelectedReachableInterfaceType)"

Write-Host `
    "PreferredInterface          : $($PathResult.PreferredInterface)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN INTERFACEPATHANALYZER v0.2"
Write-Host "========================================"

$PathResult


