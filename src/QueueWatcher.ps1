param (
    [switch]$EnableRecovery
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - QueueWatcher v0.3
# Integracion End-to-End
#
# Sin -EnableRecovery:
#   observa, analiza y NO modifica Wi-Fi.
#
# Con -EnableRecovery:
#   puede solicitar a NetworkManager un cambio real de Wi-Fi.
# ============================================================

$PrinterName = "L365 Series(Red)"
$PollingMilliseconds = 500

$ConnectivityAnalyzerPath = Join-Path `
    $PSScriptRoot `
    "ConnectivityAnalyzer.ps1"

$NetworkManagerPath = Join-Path `
    $PSScriptRoot `
    "NetworkManager.ps1"

$KnownJobs = @{}

Write-Host ""
Write-Host "PrintSwitch - QueueWatcher v0.3" -ForegroundColor Cyan

if ($EnableRecovery) {

    Write-Host "Modo: RECUPERACION HABILITADA" -ForegroundColor Yellow
    Write-Host "PrintSwitch puede modificar la interfaz Wi-Fi."

}
else {

    Write-Host "Modo: DRY-RUN" -ForegroundColor Yellow
    Write-Host "No se modificara ninguna red Wi-Fi."
}

Write-Host ""
Write-Host "Impresora observada : $PrinterName"
Write-Host "Intervalo           : $PollingMilliseconds ms"
Write-Host "ConnectivityAnalyzer: $ConnectivityAnalyzerPath"
Write-Host "NetworkManager      : $NetworkManagerPath"
Write-Host ""
Write-Host "Esperando trabajos de impresion..."
Write-Host "Ctrl+C para finalizar."
Write-Host ""

# ============================================================
# FUNCION: obtener trabajos
# ============================================================

function Get-PrintJobs {

    param(
        [string]$TargetPrinter
    )

    Get-CimInstance Win32_PrintJob -ErrorAction SilentlyContinue |
        Where-Object {

            $_.Name -like "$TargetPrinter,*" -or
            $_.Name -like "*$TargetPrinter*"
        }
}

# ============================================================
# FUNCION: ejecutar ConnectivityAnalyzer
# ============================================================

function Invoke-ConnectivityAnalysis {

    if (-not (Test-Path $ConnectivityAnalyzerPath)) {

        Write-Host `
            "ERROR: ConnectivityAnalyzer no encontrado." `
            -ForegroundColor Red

        return $null
    }

    try {

        return & $ConnectivityAnalyzerPath

    }
    catch {

        Write-Host `
            "ERROR ejecutando ConnectivityAnalyzer." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message

        return $null
    }
}

# ============================================================
# FUNCION: mostrar resumen de conectividad
# ============================================================

function Show-ConnectivitySummary {

    param(
        $Connectivity
    )

    Write-Host ""
    Write-Host "----------------------------------------"
    Write-Host "RESUMEN DE CONECTIVIDAD"
    Write-Host "----------------------------------------"

    Write-Host "Clasificacion : $($Connectivity.Classification)"
    Write-Host "SSID actual   : $($Connectivity.CurrentSSID)"
    Write-Host "SSID requerido: $($Connectivity.RequiredSSID)"
    Write-Host "Ping          : $($Connectivity.PingSucceeded)"
    Write-Host "TCP 9100      : $($Connectivity.Tcp9100Succeeded)"
    Write-Host "HTTP 80       : $($Connectivity.Tcp80Succeeded)"
}

# ============================================================
# LOOP PRINCIPAL
# ============================================================

while ($true) {

    $Jobs = @(Get-PrintJobs -TargetPrinter $PrinterName)

    foreach ($Job in $Jobs) {

        $JobKey = "$($Job.JobId)-$($Job.Name)"

        if (-not $KnownJobs.ContainsKey($JobKey)) {

            $KnownJobs[$JobKey] = $true

            # =================================================
            # NUEVO TRABAJO
            # =================================================

            $Event = [PSCustomObject]@{

                EventType    = "PrintJobDetected"
                Timestamp    = Get-Date

                PrinterName  = $PrinterName
                JobId        = $Job.JobId
                Document     = $Job.Document
                Owner        = $Job.Owner

                Status       = $Job.Status
                JobStatus    = $Job.JobStatus

                TotalPages   = $Job.TotalPages
                PagesPrinted = $Job.PagesPrinted
                SizeBytes    = $Job.Size
            }

            Write-Host ""
            Write-Host "========================================"
            Write-Host "NUEVO TRABAJO DETECTADO" -ForegroundColor Green
            Write-Host "========================================"

            Write-Host "JobId       : $($Event.JobId)"
            Write-Host "Documento   : $($Event.Document)"
            Write-Host "Propietario : $($Event.Owner)"
            Write-Host "Estado      : $($Event.JobStatus)"

            # =================================================
            # PRIMER ANALISIS
            # =================================================

            Write-Host ""
            Write-Host "========================================"
            Write-Host "FASE 1 - ANALISIS INICIAL"
            Write-Host "========================================"

            $Connectivity = Invoke-ConnectivityAnalysis

            if ($null -eq $Connectivity) {

                Write-Host ""
                Write-Host `
                    "No fue posible obtener un diagnostico." `
                    -ForegroundColor Red

                continue
            }

            Show-ConnectivitySummary `
                -Connectivity $Connectivity

            # =================================================
            # DECISION
            # =================================================

            switch ($Connectivity.Classification) {

                # ---------------------------------------------
                # CASO 1: impresora ya alcanzable
                # ---------------------------------------------

                "PRINTER_REACHABLE" {

                    Write-Host ""
                    Write-Host "========================================"
                    Write-Host "RESULTADO PRINTSWITCH"
                    Write-Host "========================================"

                    Write-Host `
                        "PRINTER_REACHABLE" `
                        -ForegroundColor Green

                    Write-Host `
                        "No se requiere intervencion de red."
                }

                # ---------------------------------------------
                # CASO 2: red incorrecta
                # ---------------------------------------------

                "NETWORK_MISMATCH" {

                    Write-Host ""
                    Write-Host "========================================"
                    Write-Host "FASE 2 - RECUPERACION DE RED"
                    Write-Host "========================================"

                    Write-Host `
                        "La PC no esta en la red requerida."

                    Write-Host `
                        "Red requerida: $($Connectivity.RequiredSSID)"

                    # -----------------------------------------
                    # DRY-RUN
                    # -----------------------------------------

                    if (-not $EnableRecovery) {

                        Write-Host ""
                        Write-Host `
                            "ACCION PROPUESTA: cambiar a '$($Connectivity.RequiredSSID)'." `
                            -ForegroundColor Yellow

                        Write-Host `
                            "DRY-RUN: no se modifico la red."

                        break
                    }

                    # -----------------------------------------
                    # Validar NetworkManager
                    # -----------------------------------------

                    if (-not (Test-Path $NetworkManagerPath)) {

                        Write-Host `
                            "ERROR: NetworkManager no encontrado." `
                            -ForegroundColor Red

                        break
                    }

                    # -----------------------------------------
                    # Ejecutar NetworkManager
                    # -----------------------------------------

                    Write-Host ""
                    Write-Host `
                        "Solicitando recuperacion a NetworkManager..."

                    try {

                        $NetworkResult = & $NetworkManagerPath `
                            -TargetSSID $Connectivity.RequiredSSID `
                            -AutoExecute

                    }
                    catch {

                        Write-Host `
                            "ERROR ejecutando NetworkManager." `
                            -ForegroundColor Red

                        Write-Host $_.Exception.Message

                        break
                    }

                    if ($null -eq $NetworkResult) {

                        Write-Host `
                            "ERROR: NetworkManager no devolvio resultado." `
                            -ForegroundColor Red

                        break
                    }

                    Write-Host ""
                    Write-Host "----------------------------------------"
                    Write-Host "RESULTADO NETWORKMANAGER"
                    Write-Host "----------------------------------------"

                    Write-Host `
                        "InitialSSID     : $($NetworkResult.InitialSSID)"

                    Write-Host `
                        "TargetSSID      : $($NetworkResult.TargetSSID)"

                    Write-Host `
                        "FinalSSID       : $($NetworkResult.FinalSSID)"

                    Write-Host `
                        "SwitchVerified  : $($NetworkResult.SwitchVerified)"

                    Write-Host `
                        "ExecutionResult : $($NetworkResult.ExecutionResult)"

                    # -----------------------------------------
                    # ¿El cambio fue realmente verificado?
                    # -----------------------------------------

                    if (-not $NetworkResult.SwitchVerified) {

                        Write-Host ""
                        Write-Host "========================================"
                        Write-Host "RECOVERY_FAILED" -ForegroundColor Red
                        Write-Host "========================================"

                        Write-Host `
                            "El cambio de red no pudo ser verificado."

                        break
                    }

                    # =================================================
                    # FASE 3: REVALIDAR IMPRESORA
                    # =================================================

                    Write-Host ""
                    Write-Host "========================================"
                    Write-Host "FASE 3 - REVALIDACION DE IMPRESORA"
                    Write-Host "========================================"

                    $ConnectivityAfterSwitch = `
                        Invoke-ConnectivityAnalysis

                    if ($null -eq $ConnectivityAfterSwitch) {

                        Write-Host ""
                        Write-Host `
                            "RECOVERY_INDETERMINATE" `
                            -ForegroundColor Red

                        Write-Host `
                            "La red cambio, pero no fue posible repetir el diagnostico."

                        break
                    }

                    Show-ConnectivitySummary `
                        -Connectivity $ConnectivityAfterSwitch

                    # -----------------------------------------
                    # Resultado final
                    # -----------------------------------------

                    if (
                        $ConnectivityAfterSwitch.Classification `
                            -eq "PRINTER_REACHABLE"
                    ) {

                        Write-Host ""
                        Write-Host "========================================"
                        Write-Host "RECOVERY_SUCCESS" -ForegroundColor Green
                        Write-Host "========================================"

                        Write-Host `
                            "Cambio de red verificado."

                        Write-Host `
                            "La impresora ahora resulta alcanzable."

                        Write-Host `
                            "Windows puede continuar el trabajo pendiente."

                    }
                    else {

                        Write-Host ""
                        Write-Host "========================================"
                        Write-Host `
                            "NETWORK_SWITCH_OK_BUT_PRINTER_UNREACHABLE" `
                            -ForegroundColor Yellow
                        Write-Host "========================================"

                        Write-Host `
                            "El cambio de red fue correcto, pero la impresora sigue sin ser alcanzable."

                        Write-Host `
                            "No se infiere la causa fisica."
                    }
                }

                # ---------------------------------------------
                # CASO 3: ya estamos en red correcta,
                # pero impresora no alcanzable
                # ---------------------------------------------

                "PRINTER_UNREACHABLE_ON_TARGET_NETWORK" {

                    Write-Host ""
                    Write-Host "========================================"
                    Write-Host "RESULTADO PRINTSWITCH"
                    Write-Host "========================================"

                    Write-Host `
                        "PRINTER_UNREACHABLE_ON_TARGET_NETWORK" `
                        -ForegroundColor Yellow

                    Write-Host `
                        "No se cambiara de red."

                    Write-Host `
                        "La PC ya esta en la red esperada."

                    Write-Host `
                        "No se infiere la causa fisica."
                }

                # ---------------------------------------------
                # CUALQUIER ESTADO FUTURO / DESCONOCIDO
                # ---------------------------------------------

                default {

                    Write-Host ""
                    Write-Host "========================================"
                    Write-Host "RESULTADO PRINTSWITCH"
                    Write-Host "========================================"

                    Write-Host `
                        "Clasificacion no reconocida." `
                        -ForegroundColor Yellow

                    Write-Host `
                        "No se realizara ninguna accion."
                }
            }

            Write-Host ""
            Write-Host "========================================"
            Write-Host "FIN DEL CICLO PRINTSWITCH"
            Write-Host "========================================"
        }
    }

    # ========================================================
    # LIMPIAR TRABAJOS DESAPARECIDOS
    # ========================================================

    $CurrentKeys = @(

        $Jobs | ForEach-Object {

            "$($_.JobId)-$($_.Name)"
        }
    )

    foreach ($KnownKey in @($KnownJobs.Keys)) {

        if ($KnownKey -notin $CurrentKeys) {

            $KnownJobs.Remove($KnownKey)

            Write-Host ""
            Write-Host `
                "Trabajo finalizado o eliminado: $KnownKey" `
                -ForegroundColor DarkGray
        }
    }

    Start-Sleep -Milliseconds $PollingMilliseconds
}