# ============================================================
# PrintSwitch - Test-EthernetPreservation v0.1
#
# Simula estados Ethernet antes/despues del switch.
# NO modifica adaptadores, rutas ni redes.
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "PrintSwitch - Test-EthernetPreservation v0.1" `
    -ForegroundColor Cyan

Write-Host "Modo: SIMULACION PURA - SIN CAMBIOS DE RED" `
    -ForegroundColor Yellow

function Get-EthernetPreservationResult {

    param (
        [Parameter(Mandatory = $true)]
        [bool]$EthernetPresentBefore,

        [Parameter(Mandatory = $true)]
        [bool]$EthernetPresentAfter
    )

    $EthernetPreserved =
        (
            $EthernetPresentBefore -eq $true -and
            $EthernetPresentAfter -eq $true
        )

    return [PSCustomObject]@{
        EthernetPresentBefore =
            $EthernetPresentBefore

        EthernetPresentAfter =
            $EthernetPresentAfter

        EthernetPreserved =
            $EthernetPreserved
    }
}

# ============================================================
# CASOS DE PRUEBA
# ============================================================

$Tests = @(

    [PSCustomObject]@{
        Name = "Ethernet ausente antes y despues"

        Before =
            $false

        After =
            $false

        ExpectedPreserved =
            $false
    }

    [PSCustomObject]@{
        Name = "Ethernet presente antes y despues"

        Before =
            $true

        After =
            $true

        ExpectedPreserved =
            $true
    }

    [PSCustomObject]@{
        Name = "Ethernet se pierde durante recovery"

        Before =
            $true

        After =
            $false

        ExpectedPreserved =
            $false
    }

    [PSCustomObject]@{
        Name = "Ethernet aparece despues"

        Before =
            $false

        After =
            $true

        ExpectedPreserved =
            $false
    }
)

# ============================================================
# EJECUTAR TESTS
# ============================================================

$Results = @()

Write-Host ""
Write-Host "========================================"
Write-Host "CASOS DE PRUEBA"
Write-Host "========================================"

foreach ($Test in $Tests) {

    $Actual = Get-EthernetPreservationResult `
        -EthernetPresentBefore $Test.Before `
        -EthernetPresentAfter $Test.After

    $Passed =
        (
            $Actual.EthernetPreserved `
                -eq $Test.ExpectedPreserved
        )

    $Results += [PSCustomObject]@{

        Test =
            $Test.Name

        Before =
            $Actual.EthernetPresentBefore

        After =
            $Actual.EthernetPresentAfter

        Preserved =
            $Actual.EthernetPreserved

        Expected =
            $Test.ExpectedPreserved

        Passed =
            $Passed
    }
}

# ============================================================
# MOSTRAR RESULTADOS
# ============================================================

Write-Host ""

$Results |
    Format-Table `
        Test,
        Before,
        After,
        Preserved,
        Expected,
        Passed `
        -AutoSize

$PassedCount = @(
    $Results |
        Where-Object {
            $_.Passed -eq $true
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
Write-Host "FIN TEST-ETHERNETPRESERVATION v0.1"
Write-Host "========================================"

$Results