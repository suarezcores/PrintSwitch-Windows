# ============================================================
# PrintSwitch - Test-InterfacePathOverlap v0.1
#
# Prueba aislada del algoritmo de redes/subredes.
# NO modifica interfaces, IPs, rutas ni Wi-Fi.
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "PrintSwitch - Test-InterfacePathOverlap v0.1" `
    -ForegroundColor Cyan
Write-Host "Modo: SIMULACION PURA - SIN CAMBIOS DE RED" `
    -ForegroundColor Yellow


# ============================================================
# FUNCIONES
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

    $CandidateNetwork = Get-NetworkAddress `
        -IPAddress $IPAddress `
        -PrefixLength $PrefixLength

    return (
        $CandidateNetwork -eq $NetworkAddress
    )
}


function Test-NetworkOverlap {

    param (
        [Parameter(Mandatory = $true)]
        [string]$IPAddressA,

        [Parameter(Mandatory = $true)]
        [int]$PrefixLengthA,

        [Parameter(Mandatory = $true)]
        [string]$IPAddressB,

        [Parameter(Mandatory = $true)]
        [int]$PrefixLengthB
    )

    $NetworkA = Get-NetworkAddress `
        -IPAddress $IPAddressA `
        -PrefixLength $PrefixLengthA

    $NetworkB = Get-NetworkAddress `
        -IPAddress $IPAddressB `
        -PrefixLength $PrefixLengthB

    $AInsideB = Test-IPInSubnet `
        -IPAddress $IPAddressA `
        -NetworkAddress $NetworkB `
        -PrefixLength $PrefixLengthB

    $BInsideA = Test-IPInSubnet `
        -IPAddress $IPAddressB `
        -NetworkAddress $NetworkA `
        -PrefixLength $PrefixLengthA

    return ($AInsideB -or $BInsideA)
}


# ============================================================
# CASOS DE PRUEBA
# ============================================================

$Tests = @(

    [PSCustomObject]@{
        Name       = "Redes diferentes"
        IP_A       = "192.168.1.109"
        Prefix_A   = 24
        IP_B       = "192.168.100.7"
        Prefix_B   = 24
        TargetIP   = "192.168.1.108"
        ExpectedOverlap = $false
        ExpectedCandidates = 1
    }

    [PSCustomObject]@{
        Name       = "Misma subred"
        IP_A       = "192.168.1.50"
        Prefix_A   = 24
        IP_B       = "192.168.1.70"
        Prefix_B   = 24
        TargetIP   = "192.168.1.108"
        ExpectedOverlap = $true
        ExpectedCandidates = 2
    }

    [PSCustomObject]@{
        Name       = "Subredes solapadas"
        IP_A       = "192.168.1.50"
        Prefix_A   = 24
        IP_B       = "192.168.1.200"
        Prefix_B   = 25
        TargetIP   = "192.168.1.108"
        ExpectedOverlap = $true
        ExpectedCandidates = 1
    }

    [PSCustomObject]@{
        Name       = "Redes totalmente separadas"
        IP_A       = "10.0.0.20"
        Prefix_A   = 24
        IP_B       = "172.16.5.20"
        Prefix_B   = 24
        TargetIP   = "192.168.1.108"
        ExpectedOverlap = $false
        ExpectedCandidates = 0
    }
)


# ============================================================
# EJECUTAR PRUEBAS
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "CASOS DE PRUEBA"
Write-Host "========================================"

$Results = @()

foreach ($Test in $Tests) {

    $NetworkA = Get-NetworkAddress `
        -IPAddress $Test.IP_A `
        -PrefixLength $Test.Prefix_A

    $NetworkB = Get-NetworkAddress `
        -IPAddress $Test.IP_B `
        -PrefixLength $Test.Prefix_B

    $Overlap = Test-NetworkOverlap `
        -IPAddressA $Test.IP_A `
        -PrefixLengthA $Test.Prefix_A `
        -IPAddressB $Test.IP_B `
        -PrefixLengthB $Test.Prefix_B

    $TargetInA = Test-IPInSubnet `
        -IPAddress $Test.TargetIP `
        -NetworkAddress $NetworkA `
        -PrefixLength $Test.Prefix_A

    $TargetInB = Test-IPInSubnet `
        -IPAddress $Test.TargetIP `
        -NetworkAddress $NetworkB `
        -PrefixLength $Test.Prefix_B

    $CandidateCount = 0

    if ($TargetInA) {
        $CandidateCount++
    }

    if ($TargetInB) {
        $CandidateCount++
    }

    $Passed =
        ($Overlap -eq $Test.ExpectedOverlap) -and
        ($CandidateCount -eq $Test.ExpectedCandidates)

    $Results += [PSCustomObject]@{
        Test               = $Test.Name
        NetworkA           = "$NetworkA/$($Test.Prefix_A)"
        NetworkB           = "$NetworkB/$($Test.Prefix_B)"
        Overlap            = $Overlap
        ExpectedOverlap    = $Test.ExpectedOverlap
        CandidateCount     = $CandidateCount
        ExpectedCandidates = $Test.ExpectedCandidates
        Passed             = $Passed
    }
}


# ============================================================
# RESULTADOS
# ============================================================

Write-Host ""

$Results |
    Format-Table `
        Test,
        NetworkA,
        NetworkB,
        Overlap,
        CandidateCount,
        Passed `
        -AutoSize

$PassedCount = @(
    $Results |
        Where-Object {
            $_.Passed
        }
).Count

$FailedCount =
    $Results.Count - $PassedCount

Write-Host ""
Write-Host "========================================"
Write-Host "RESUMEN"
Write-Host "========================================"

Write-Host "Tests ejecutados : $($Results.Count)"
Write-Host "Correctos        : $PassedCount"
Write-Host "Fallidos         : $FailedCount"

if ($FailedCount -eq 0) {

    Write-Host ""
    Write-Host "RESULTADO: PASS" `
        -ForegroundColor Green
}
else {

    Write-Host ""
    Write-Host "RESULTADO: FAIL" `
        -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================"
Write-Host "FIN TEST-INTERFACEPATHOVERLAP v0.1"
Write-Host "========================================"

$Results