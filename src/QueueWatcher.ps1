param (
    [switch]$EnableRecovery,

    [string]$PrinterName,

    [string]$ConfigPath = (
        Join-Path `
            (Split-Path $PSScriptRoot -Parent) `
            "config\printers.json"
    )
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - QueueWatcher v0.5
#
# Orquestador principal.
#
# Antes de observar trabajos:
#   1. valida config/printers.json mediante ConfigValidator
#   2. solo continua si la configuracion es valida
#
# Sin -EnableRecovery:
#   observa, analiza y NO modifica Wi-Fi.
#
# Con -EnableRecovery:
#   puede solicitar a NetworkManager un cambio real de Wi-Fi.
# ============================================================

$PollingMilliseconds = 500

$ConfigValidatorPath = Join-Path `
    $PSScriptRoot `
    "ConfigValidator.ps1"

$ConnectivityAnalyzerPath = Join-Path `
    $PSScriptRoot `
    "ConnectivityAnalyzer.ps1"

$NetworkManagerPath = Join-Path `
    $PSScriptRoot `
    "NetworkManager.ps1"

$KnownJobs = @{}

# ============================================================
# 0. ARRANQUE
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - QueueWatcher v0.5" `
    -ForegroundColor Cyan

Write-Host ""

# ============================================================
# 1. VALIDAR CONFIGURACION
# ============================================================

Write-Host "========================================"
Write-Host "1. VALIDACION DE CONFIGURACION"
Write-Host "========================================"

if (-not (Test-Path $ConfigValidatorPath)) {

    Write-Host ""
    Write-Host `
        "ERROR: ConfigValidator no encontrado." `
        -ForegroundColor Red

    Write-Host `
        "Ruta esperada: $ConfigValidatorPath"

    return
}

try {

    $ValidationResult = & $ConfigValidatorPath `
        -ConfigPath $ConfigPath
}
catch {

    Write-Host ""
    Write-Host `
        "ERROR ejecutando ConfigValidator." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message

    return
}

if ($null -eq $ValidationResult) {

    Write-Host ""
    Write-Host `
        "ERROR: ConfigValidator no devolvio resultado." `
        -ForegroundColor Red

    return
}

Write-Host ""
Write-Host "----------------------------------------"
Write-Host "RESULTADO CONFIGVALIDATOR"
Write-Host "----------------------------------------"

Write-Host `
    "Classification : $($ValidationResult.Classification)"

Write-Host `
    "IsValid        : $($ValidationResult.IsValid)"

Write-Host `
    "PrinterCount   : $($ValidationResult.PrinterCount)"

Write-Host `
    "ErrorCount     : $($ValidationResult.ErrorCount)"

if (-not $ValidationResult.IsValid) {

    Write-Host ""
    Write-Host "========================================"
    Write-Host `
        "PRINTSWITCH_STARTUP_ABORTED" `
        -ForegroundColor Red
    Write-Host "========================================"

    Write-Host `
        "La configuracion es invalida."

    Write-Host `
        "PrintSwitch no iniciara la observacion de trabajos."

    if ($ValidationResult.Errors.Count -gt 0) {

        Write-Host ""
        Write-Host "Errores detectados:"

        foreach ($ValidationError in $ValidationResult.Errors) {

            Write-Host `
                " - $ValidationError" `
                -ForegroundColor Red
        }
    }

    return
}

Write-Host ""
Write-Host `
    "Configuracion validada correctamente." `
    -ForegroundColor Green

# ============================================================
# 2. CARGAR CONFIGURACION VALIDADA
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. CARGA DE CONFIGURACION"
Write-Host "========================================"

try {

    $Config = Get-Content `
        $ConfigPath `
        -Raw `
        -ErrorAction Stop |
        ConvertFrom-Json `
            -ErrorAction Stop
}
catch {

    Write-Host ""
    Write-Host `
        "ERROR: la configuracion fue validada pero no pudo volver a cargarse." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message

    return
}

# ============================================================
# 3. SELECCIONAR IMPRESORA
# ============================================================

$PrinterProfile = $null

if ($PrinterName) {

    $PrinterProfile = @(
        $Config.printers |
            Where-Object {
                $_.name -eq $PrinterName
            }
    ) | Select-Object -First 1

    if ($null -eq $PrinterProfile) {

        Write-Host ""
        Write-Host `
            "ERROR: no existe un perfil para '$PrinterName'." `
            -ForegroundColor Red

        return
    }
}
else {

    $PrinterProfile = @($Config.printers)[0]
}

$PrinterName = [string]$PrinterProfile.name

# ============================================================
# 4. INFORMACION DE ARRANQUE
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. PRINTSWITCH READY"
Write-Host "========================================"

if ($EnableRecovery) {

    Write-Host `
        "Modo: RECUPERACION HABILITADA" `
        -ForegroundColor Yellow

    Write-Host `
        "PrintSwitch puede modificar la interfaz Wi-Fi."
}
else {

    Write-Host `
        "Modo: DRY-RUN" `
        -ForegroundColor Yellow

    Write-Host `
        "No se modificara ninguna red Wi-Fi."
}

Write-Host ""
Write-Host "Configuracion       : $ConfigPath"
Write-Host "Impresora observada : $PrinterName"
Write-Host "Intervalo           : $PollingMilliseconds ms"
Write-Host "ConfigValidator     : $ConfigValidatorPath"
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

    Get-CimInstance Win32_PrintJob `
        -ErrorAction SilentlyContinue |
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

        return & $ConnectivityAnalyzerPath `
            -PrinterName $PrinterName `
            -ConfigPath $ConfigPath
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

    Write-Host `
        "Clasificacion : $($Connectivity.Classification)"

    Write-Host `
        "Impresora     : $($Connectivity.PrinterName)"

    Write-Host `
        "IP            : $($Connectivity.PrinterIP)"

    Write-Host `
        "SSID actual   : $($Connectivity.CurrentSSID)"

    Write-Host `
        "SSID requerido: $($Connectivity.RequiredSSID)"

    Write-Host `
        "Ping          : $($Connectivity.PingSucceeded)"

    Write-Host `
        "TCP 9100      : $($Connectivity.Tcp9100Succeeded)"

    Write-Host `
        "HTTP 80       : $($Connectivity.Tcp80Succeeded)"
}

# ============================================================
# LOOP PRINCIPAL
# ============================================================

while ($true) {

    $Jobs = @(
        Get-PrintJobs `
            -TargetPrinter $PrinterName
    )

    foreach ($Job in $Jobs) {

        $JobKey = "$($Job.JobId)-$($Job.Name)"

        if (-not $KnownJobs.ContainsKey($JobKey)) {

            $KnownJobs[$JobKey] = $true

            # =================================================
            # NUEVO TRABAJO
            # =================================================

            $Event = [PSCustomObject]@{

                EventType =
                    "PrintJobDetected"

                Timestamp =
                    Get-Date

                PrinterName =
                    $PrinterName

                JobId =
                    $Job.JobId

                Document =
                    $Job.Document

                Owner =
                    $Job.Owner

                Status =
                    $Job.Status

                JobStatus =
                    $Job.JobStatus

                TotalPages =
                    $Job.TotalPages

                PagesPrinted =
                    $Job.PagesPrinted

                SizeBytes =
                    $Job.Size
            }

            Write-Host ""
            Write-Host "========================================"
            Write-Host `
                "NUEVO TRABAJO DETECTADO" `
                -ForegroundColor Green
            Write-Host "========================================"

            Write-Host "Impresora   : $($Event.PrinterName)"
            Write-Host "JobId       : $($Event.JobId)"
            Write-Host "Documento   : $($Event.Document)"
            Write-Host "Propietario : $($Event.Owner)"
            Write-Host "Estado      : $($Event.JobStatus)"

            # =================================================
            # FASE 1: ANALISIS INICIAL
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
            # DECISION PRINCIPAL
            # =================================================

            switch ($Connectivity.Classification) {

                # ---------------------------------------------
                # CASO 1: impresora alcanzable
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

                        Write-Host ""
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

                        Write-Host ""
                        Write-Host `
                            "ERROR ejecutando NetworkManager." `
                            -ForegroundColor Red

                        Write-Host $_.Exception.Message

                        break
                    }

                    if ($null -eq $NetworkResult) {

                        Write-Host ""
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
                        "Classification  : $($NetworkResult.Classification)"

                    Write-Host `
                        "SwitchRequested : $($NetworkResult.SwitchRequested)"

                    Write-Host `
                        "CommandIssued   : $($NetworkResult.CommandIssued)"

                    Write-Host `
                        "SwitchVerified  : $($NetworkResult.SwitchVerified)"

                    Write-Host `
                        "ExecutionResult : $($NetworkResult.ExecutionResult)"

                    # =================================================
                    # EVALUAR RECUPERACION
                    # =================================================

                    if (-not $NetworkResult.SwitchVerified) {

                        Write-Host ""
                        Write-Host "========================================"

                        if (
                            $NetworkResult.ExecutionResult `
                                -eq "SWITCH_NOT_AVAILABLE"
                        ) {

                            Write-Host `
                                "NETWORK_RECOVERY_UNAVAILABLE" `
                                -ForegroundColor Yellow

                            Write-Host "========================================"

                            Write-Host `
                                "No se intento cambiar de red porque las condiciones necesarias no estaban disponibles."

                            Write-Host `
                                "NetworkManager devolvio: $($NetworkResult.Classification)"
                        }
                        else {

                            Write-Host `
                                "RECOVERY_FAILED" `
                                -ForegroundColor Red

                            Write-Host "========================================"

                            Write-Host `
                                "Se intento recuperar la conectividad, pero el cambio de red no pudo ser verificado."
                        }

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
                        Write-Host "========================================"

                        Write-Host `
                            "RECOVERY_INDETERMINATE" `
                            -ForegroundColor Red

                        Write-Host "========================================"

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

                        Write-Host `
                            "RECOVERY_SUCCESS" `
                            -ForegroundColor Green

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
                # CASO 3: red correcta, impresora inaccesible
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
                # ESTADO DESCONOCIDO
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
    # LIMPIAR TRABAJOS QUE DESAPARECIERON
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

    Start-Sleep `
        -Milliseconds $PollingMilliseconds
}