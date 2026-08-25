param (
    [Parameter(Mandatory = $true)]
    [string]$TargetIP,

    [int]$TcpPort = 9100,

    [int]$TcpTimeoutMs = 1200
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - InterfacePathAnalyzer v0.1
#
# Objetivo:
# - enumerar interfaces IPv4 activas
# - identificar redes/prefijos
# - detectar posibles solapamientos
# - identificar interfaces candidatas hacia un destino
#
# NO:
# - modifica rutas
# - cambia metricas
# - cambia Wi-Fi
# - toca Ethernet
#
# Solo observa y clasifica.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - InterfacePathAnalyzer v0.1" `
    -ForegroundColor Cyan

Write-Host "Modo: ANALISIS DE CAMINOS NO INTRUSIVO" `
    -ForegroundColor Yellow

Write-Host ""
Write-Host "Destino analizado : $TargetIP"
Write-Host "Puerto referencia : $TcpPort"
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
# FUNCION: DESTINO DENTRO DE PREFIJO
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
        -AutoSize

# ============================================================
# 2. DETECTAR SOLAPAMIENTOS
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. SOLAPAMIENTO DE REDES"
Write-Host "========================================"

$OverlapPairs = @()

for (
    $I = 0;
    $I -lt $InterfaceResults.Count;
    $I++
) {

    for (
        $J = $I + 1;
        $J -lt $InterfaceResults.Count;
        $J++
    ) {

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

                InterfaceA =
                    $A.Name

                PrefixA =
                    $A.NetworkPrefix

                InterfaceB =
                    $B.Name

                PrefixB =
                    $B.NetworkPrefix
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
# 3. INTERFACES CANDIDATAS
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
        "No existe una interfaz con el destino en su subred local."
}
else {

    foreach ($Candidate in $DirectCandidates) {

        Write-Host ""
        Write-Host "Interfaz       : $($Candidate.Name)"
        Write-Host "Tipo           : $($Candidate.InterfaceType)"
        Write-Host "IPv4 local     : $($Candidate.IPv4Address)"
        Write-Host "Red            : $($Candidate.NetworkPrefix)"
        Write-Host "Destino local  : True"
    }
}

# ============================================================
# 4. RUTA PREFERIDA DE WINDOWS
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "4. RUTA PREFERIDA WINDOWS"
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

    Write-Host `
        "InterfaceAlias : $($BestRoute.InterfaceAlias)"

    Write-Host `
        "InterfaceIndex : $($BestRoute.InterfaceIndex)"

    Write-Host `
        "Prefix         : $($BestRoute.DestinationPrefix)"

    Write-Host `
        "NextHop        : $($BestRoute.NextHop)"
}
else {

    Write-Host `
        "No se pudo determinar ruta preferida." `
        -ForegroundColor Yellow
}

# ============================================================
# 5. CLASIFICACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "5. CLASIFICACION"
Write-Host "========================================"

$Classification =
    "PATH_CONTEXT_UNKNOWN"

if (
    $OverlapDetected -and
    $DirectCandidates.Count -gt 1
) {

    $Classification =
        "OVERLAPPED_DIRECT_PATHS"

}
elseif (
    $DirectCandidates.Count -eq 1
) {

    $Classification =
        "SINGLE_DIRECT_PATH"

}
elseif (
    $DirectCandidates.Count -gt 1
) {

    $Classification =
        "MULTIPLE_DIRECT_PATHS"

}
elseif ($null -ne $BestRoute) {

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
# 6. INTERPRETACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "6. INTERPRETACION PRINTSWITCH"
Write-Host "========================================"

switch ($Classification) {

    "SINGLE_DIRECT_PATH" {

        Write-Host `
            "Existe un unico camino local evidente hacia el destino." `
            -ForegroundColor Green
    }

    "OVERLAPPED_DIRECT_PATHS" {

        Write-Host `
            "ADVERTENCIA: varias interfaces presentan redes solapadas." `
            -ForegroundColor Yellow

        Write-Host `
            "No debe inferirse el camino correcto solo por direccion IP."

        Write-Host `
            "Se requieren pruebas de alcanzabilidad por interfaz."
    }

    "MULTIPLE_DIRECT_PATHS" {

        Write-Host `
            "Existen multiples interfaces candidatas." `
            -ForegroundColor Yellow

        Write-Host `
            "Debe seleccionarse el camino usando evidencia adicional."
    }

    "ROUTED_PATH_ONLY" {

        Write-Host `
            "El destino no pertenece a una subred local directa."

        Write-Host `
            "Windows dispone de una ruta hacia el destino."
    }

    default {

        Write-Host `
            "No existe evidencia suficiente para seleccionar camino." `
            -ForegroundColor Yellow
    }
}

# ============================================================
# 7. RESULTADO ESTRUCTURADO
# ============================================================

$PathResult = [PSCustomObject]@{

    Component =
        "InterfacePathAnalyzer"

    Version =
        "0.1"

    Timestamp =
        Get-Date

    TargetIP =
        $TargetIP

    Classification =
        $Classification

    OverlapDetected =
        $OverlapDetected

    OverlapCount =
        $OverlapPairs.Count

    DirectCandidateCount =
        $DirectCandidates.Count

    PreferredInterface =
        $BestRoute.InterfaceAlias

    PreferredInterfaceIndex =
        $BestRoute.InterfaceIndex

    Interfaces =
        $InterfaceResults

    DirectCandidates =
        $DirectCandidates

    Overlaps =
        $OverlapPairs
}

Write-Host ""
Write-Host "========================================"
Write-Host "7. RESULTADO ESTRUCTURADO"
Write-Host "========================================"

Write-Host `
    "Classification      : $($PathResult.Classification)"

Write-Host `
    "OverlapDetected     : $($PathResult.OverlapDetected)"

Write-Host `
    "DirectCandidates    : $($PathResult.DirectCandidateCount)"

Write-Host `
    "PreferredInterface  : $($PathResult.PreferredInterface)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN INTERFACEPATHANALYZER v0.1"
Write-Host "========================================"

$PathResult