# ============================================================
# PrintSwitch - Test-InterfacePathSelection v0.1
#
# Simula resultados de alcanzabilidad por interfaz.
# NO modifica red, rutas, IPs ni adaptadores.
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "PrintSwitch - Test-InterfacePathSelection v0.1" `
    -ForegroundColor Cyan

Write-Host "Modo: SIMULACION PURA" `
    -ForegroundColor Yellow

# ============================================================
# FUNCION DE CLASIFICACION
# ============================================================

function Get-PathSelectionResult {

    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Candidates
    )

    $ReachablePaths = @(
        $Candidates |
            Where-Object {
                $_.Reachable -eq $true
            }
    )

    $Classification =
        "PATH_CONTEXT_UNKNOWN"

    $SelectedInterface =
        $null

    if ($ReachablePaths.Count -eq 1) {

        $Classification =
            "UNIQUE_REACHABLE_PATH"

        $SelectedInterface =
            $ReachablePaths[0].Name
    }
    elseif ($ReachablePaths.Count -gt 1) {

        $Classification =
            "MULTIPLE_REACHABLE_PATHS"
    }
    elseif ($Candidates.Count -gt 0) {

        $Classification =
            "CANDIDATE_PATHS_UNREACHABLE"
    }
    else {

        $Classification =
            "NO_PATH_IDENTIFIED"
    }

    return [PSCustomObject]@{
        Classification    = $Classification
        CandidateCount    = $Candidates.Count
        ReachablePathCount = $ReachablePaths.Count
        SelectedInterface = $SelectedInterface
    }
}

# ============================================================
# CASOS
# ============================================================

$Tests = @(

    # --------------------------------------------------------
    # 1. Solo Wi-Fi responde
    # --------------------------------------------------------

    [PSCustomObject]@{
        Name = "Overlap - solo WiFi responde"

        Candidates = @(
            [PSCustomObject]@{
                Name      = "Ethernet"
                LocalIP   = "192.168.1.50"
                Reachable = $false
            }

            [PSCustomObject]@{
                Name      = "Wi-Fi"
                LocalIP   = "192.168.1.70"
                Reachable = $true
            }
        )

        ExpectedClassification =
            "UNIQUE_REACHABLE_PATH"

        ExpectedReachableCount =
            1

        ExpectedSelectedInterface =
            "Wi-Fi"
    }

    # --------------------------------------------------------
    # 2. Solo Ethernet responde
    # --------------------------------------------------------

    [PSCustomObject]@{
        Name = "Overlap - solo Ethernet responde"

        Candidates = @(
            [PSCustomObject]@{
                Name      = "Ethernet"
                LocalIP   = "192.168.1.50"
                Reachable = $true
            }

            [PSCustomObject]@{
                Name      = "Wi-Fi"
                LocalIP   = "192.168.1.70"
                Reachable = $false
            }
        )

        ExpectedClassification =
            "UNIQUE_REACHABLE_PATH"

        ExpectedReachableCount =
            1

        ExpectedSelectedInterface =
            "Ethernet"
    }

    # --------------------------------------------------------
    # 3. Ambos responden
    # --------------------------------------------------------

    [PSCustomObject]@{
        Name = "Overlap - ambos caminos responden"

        Candidates = @(
            [PSCustomObject]@{
                Name      = "Ethernet"
                LocalIP   = "192.168.1.50"
                Reachable = $true
            }

            [PSCustomObject]@{
                Name      = "Wi-Fi"
                LocalIP   = "192.168.1.70"
                Reachable = $true
            }
        )

        ExpectedClassification =
            "MULTIPLE_REACHABLE_PATHS"

        ExpectedReachableCount =
            2

        ExpectedSelectedInterface =
            $null
    }

    # --------------------------------------------------------
    # 4. Ninguno responde
    # --------------------------------------------------------

    [PSCustomObject]@{
        Name = "Overlap - ningun camino responde"

        Candidates = @(
            [PSCustomObject]@{
                Name      = "Ethernet"
                LocalIP   = "192.168.1.50"
                Reachable = $false
            }

            [PSCustomObject]@{
                Name      = "Wi-Fi"
                LocalIP   = "192.168.1.70"
                Reachable = $false
            }
        )

        ExpectedClassification =
            "CANDIDATE_PATHS_UNREACHABLE"

        ExpectedReachableCount =
            0

        ExpectedSelectedInterface =
            $null
    }

    # --------------------------------------------------------
    # 5. Sin candidatos
    # --------------------------------------------------------

    [PSCustomObject]@{
        Name = "Sin caminos candidatos"

        Candidates = @()

        ExpectedClassification =
            "NO_PATH_IDENTIFIED"

        ExpectedReachableCount =
            0

        ExpectedSelectedInterface =
            $null
    }
)

# ============================================================
# EJECUTAR
# ============================================================

$Results = @()

Write-Host ""
Write-Host "========================================"
Write-Host "CASOS DE PRUEBA"
Write-Host "========================================"

foreach ($Test in $Tests) {

    $Actual = Get-PathSelectionResult `
        -Candidates $Test.Candidates

    $Passed =
        (
            $Actual.Classification `
                -eq $Test.ExpectedClassification
        ) -and
        (
            $Actual.ReachablePathCount `
                -eq $Test.ExpectedReachableCount
        ) -and
        (
            $Actual.SelectedInterface `
                -eq $Test.ExpectedSelectedInterface
        )

    $Results += [PSCustomObject]@{

        Test =
            $Test.Name

        Classification =
            $Actual.Classification

        Reachable =
            $Actual.ReachablePathCount

        Selected =
            $Actual.SelectedInterface

        Passed =
            $Passed
    }
}

# ============================================================
# MOSTRAR
# ============================================================

Write-Host ""

$Results |
    Format-Table `
        Test,
        Classification,
        Reachable,
        Selected,
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
Write-Host "FIN TEST-INTERFACEPATHSELECTION v0.1"
Write-Host "========================================"

$Results