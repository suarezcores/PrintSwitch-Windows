$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - QueueWatcher v0.2
# Deteccion de trabajos + analisis de conectividad
# DRY-RUN
# ============================================================

$PrinterName = "L365 Series(Red)"
$PollingMilliseconds = 500

$ConnectivityAnalyzerPath = Join-Path `
    $PSScriptRoot `
    "ConnectivityAnalyzer.ps1"

$KnownJobs = @{}

Write-Host ""
Write-Host "PrintSwitch - QueueWatcher v0.2" -ForegroundColor Cyan
Write-Host "Modo: DRY-RUN" -ForegroundColor Yellow
Write-Host "No se modificara ninguna red Wi-Fi."
Write-Host ""
Write-Host "Impresora observada : $PrinterName"
Write-Host "Intervalo           : $PollingMilliseconds ms"
Write-Host "Analyzer            : $ConnectivityAnalyzerPath"
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
# LOOP PRINCIPAL
# ============================================================

while ($true) {

    $Jobs = @(Get-PrintJobs -TargetPrinter $PrinterName)

    foreach ($Job in $Jobs) {

        $JobKey = "$($Job.JobId)-$($Job.Name)"

        if (-not $KnownJobs.ContainsKey($JobKey)) {

            $KnownJobs[$JobKey] = $true

            # ------------------------------------------------
            # Evento de nuevo trabajo
            # ------------------------------------------------

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
            # Ejecutar ConnectivityAnalyzer
            # =================================================

            Write-Host ""
            Write-Host "----------------------------------------"
            Write-Host "ANALIZANDO CONECTIVIDAD"
            Write-Host "----------------------------------------"

            if (-not (Test-Path $ConnectivityAnalyzerPath)) {

                Write-Host "ERROR: ConnectivityAnalyzer no encontrado." `
                    -ForegroundColor Red

                continue
            }

            try {

                $Connectivity = & $ConnectivityAnalyzerPath

            }
            catch {

                Write-Host "ERROR ejecutando ConnectivityAnalyzer." `
                    -ForegroundColor Red

                Write-Host $_.Exception.Message

                continue
            }

            # =================================================
            # Validar resultado
            # =================================================

            if ($null -eq $Connectivity) {

                Write-Host ""
                Write-Host "ERROR: ConnectivityAnalyzer no devolvio resultado." `
                    -ForegroundColor Red

                continue
            }

            Write-Host ""
            Write-Host "----------------------------------------"
            Write-Host "RESULTADO DE CONECTIVIDAD"
            Write-Host "----------------------------------------"

            Write-Host "Clasificacion : $($Connectivity.Classification)"
            Write-Host "SSID actual   : $($Connectivity.CurrentSSID)"
            Write-Host "SSID requerido: $($Connectivity.RequiredSSID)"
            Write-Host "Ping          : $($Connectivity.PingSucceeded)"
            Write-Host "TCP 9100      : $($Connectivity.Tcp9100Succeeded)"
            Write-Host "HTTP 80       : $($Connectivity.Tcp80Succeeded)"

            # =================================================
            # Decision DRY-RUN
            # =================================================

            Write-Host ""
            Write-Host "----------------------------------------"
            Write-Host "DECISION PRINTSWITCH - DRY-RUN"
            Write-Host "----------------------------------------"

            switch ($Connectivity.Classification) {

                "NETWORK_MISMATCH" {

                    Write-Host `
                        "ACCION PROPUESTA: cambiar a '$($Connectivity.RequiredSSID)'." `
                        -ForegroundColor Yellow

                    Write-Host `
                        "DRY-RUN: NO se modifico la red."
                }

                "PRINTER_REACHABLE" {

                    Write-Host `
                        "ACCION PROPUESTA: ninguna." `
                        -ForegroundColor Green

                    Write-Host `
                        "La impresora ya resulta alcanzable."
                }

                "PRINTER_UNREACHABLE_ON_TARGET_NETWORK" {

                    Write-Host `
                        "ACCION PROPUESTA: no cambiar de red." `
                        -ForegroundColor Yellow

                    Write-Host `
                        "La PC ya esta en la red esperada, pero la impresora no responde."

                    Write-Host `
                        "No se infiere la causa fisica."
                }

                default {

                    Write-Host `
                        "ACCION PROPUESTA: ninguna." `
                        -ForegroundColor Yellow

                    Write-Host `
                        "Clasificacion no reconocida o evidencia insuficiente."
                }
            }

            Write-Host ""
            Write-Host "========================================"
            Write-Host "FIN DEL CICLO DRY-RUN"
            Write-Host "========================================"
        }
    }

    # ========================================================
    # Eliminar de memoria trabajos que ya desaparecieron
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
            Write-Host "Trabajo finalizado o eliminado: $KnownKey" `
                -ForegroundColor DarkGray
        }
    }

    Start-Sleep -Milliseconds $PollingMilliseconds
}