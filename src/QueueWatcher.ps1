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
# PrintSwitch - QueueWatcher v0.6
#
# Orquestador principal.
#
# Funciones:
#   - valida configuracion
#   - observa trabajos
#   - solicita diagnostico
#   - solicita recuperacion de red
#   - registra eventos importantes mediante Logger
# ============================================================

$PollingMilliseconds = 500

$LoggerPath = Join-Path `
    $PSScriptRoot `
    "Logger.ps1"

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
# 0. CARGAR LOGGER
# ============================================================

if (-not (Test-Path $LoggerPath)) {

    Write-Host ""
    Write-Host `
        "ERROR: Logger no encontrado." `
        -ForegroundColor Red

    Write-Host "Ruta esperada: $LoggerPath"

    return
}

try {

    . $LoggerPath
}
catch {

    Write-Host ""
    Write-Host `
        "ERROR: no se pudo cargar Logger." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message

    return
}

# ============================================================
# 1. ARRANQUE
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - QueueWatcher v0.6" `
    -ForegroundColor Cyan

Write-Host ""

Write-PrintSwitchLog `
    -Component "QueueWatcher" `
    -Event "PRINTSWITCH_STARTED" `
    -Level "INFO" `
    -Data @{
        RecoveryEnabled = [bool]$EnableRecovery
        ConfigPath      = $ConfigPath
    } |
    Out-Null

# ============================================================
# 2. VALIDAR CONFIGURACION
# ============================================================

Write-Host "========================================"
Write-Host "1. VALIDACION DE CONFIGURACION"
Write-Host "========================================"

if (-not (Test-Path $ConfigValidatorPath)) {

    Write-Host ""
    Write-Host `
        "ERROR: ConfigValidator no encontrado." `
        -ForegroundColor Red

    Write-PrintSwitchLog `
        -Component "QueueWatcher" `
        -Event "CONFIG_VALIDATOR_NOT_FOUND" `
        -Level "ERROR" `
        -Data @{
            Path = $ConfigValidatorPath
        } |
        Out-Null

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

    Write-PrintSwitchLog `
        -Component "QueueWatcher" `
        -Event "CONFIG_VALIDATION_ERROR" `
        -Level "ERROR" `
        -Data @{
            Message = $_.Exception.Message
        } |
        Out-Null

    return
}

if ($null -eq $ValidationResult) {

    Write-Host ""
    Write-Host `
        "ERROR: ConfigValidator no devolvio resultado." `
        -ForegroundColor Red

    Write-PrintSwitchLog `
        -Component "QueueWatcher" `
        -Event "CONFIG_VALIDATION_NO_RESULT" `
        -Level "ERROR" |
        Out-Null

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

    Write-PrintSwitchLog `
        -Component "QueueWatcher" `
        -Event "CONFIG_INVALID" `
        -Level "ERROR" `
        -Data @{
            ErrorCount = $ValidationResult.ErrorCount
            Errors     = ($ValidationResult.Errors -join ",")
        } |
        Out-Null

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

Write-PrintSwitchLog `
    -Component "QueueWatcher" `
    -Event "CONFIG_VALID" `
    -Level "INFO" `
    -Data @{
        PrinterCount = $ValidationResult.PrinterCount
    } |
    Out-Null

Write-Host ""
Write-Host `
    "Configuracion validada correctamente." `
    -ForegroundColor Green

# ============================================================
# 3. CARGAR CONFIGURACION VALIDADA
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

    Write-PrintSwitchLog `
        -Component "QueueWatcher" `
        -Event "CONFIG_RELOAD_FAILED" `
        -Level "ERROR" `
        -Data @{
            Message = $_.Exception.Message
        } |
        Out-Null

    return
}

# ============================================================
# 4. SELECCIONAR IMPRESORA
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

        Write-PrintSwitchLog `
            -Component "QueueWatcher" `
            -Event "PRINTER_PROFILE_NOT_FOUND" `
            -Level "ERROR" `
            -Data @{
                Printer = $PrinterName
            } |
            Out-Null

        return
    }
}
else {

    $PrinterProfile = @($Config.printers)[0]
}

$PrinterName = [string]$PrinterProfile.name

# ============================================================
# 5. PRINTSWITCH READY
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
Write-Host "Logger              : $LoggerPath"
Write-Host "ConfigValidator     : $ConfigValidatorPath"
Write-Host "ConnectivityAnalyzer: $ConnectivityAnalyzerPath"
Write-Host "NetworkManager      : $NetworkManagerPath"

Write-PrintSwitchLog `
    -Component "QueueWatcher" `
    -Event "PRINTSWITCH_READY" `
    -Level "INFO" `
    -Data @{
        Printer         = $PrinterName
        RecoveryEnabled = [bool]$EnableRecovery
    } |
    Out-Null

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
# FUNCION: ConnectivityAnalyzer
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
# FUNCION: resumen
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

            Write-PrintSwitchLog `
                -Component "QueueWatcher" `
                -Event "PRINT_JOB_DETECTED" `
                -Level "INFO" `
                -Data @{
                    Printer = $Event.PrinterName
                    JobId   = $Event.JobId
                } |
                Out-Null

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
            # FASE 1
            # =================================================

            Write-Host ""
            Write-Host "========================================"
            Write-Host "FASE 1 - ANALISIS INICIAL"
            Write-Host "========================================"

            $Connectivity = Invoke-ConnectivityAnalysis

            if ($null -eq $Connectivity) {

                Write-PrintSwitchLog `
                    -Component "QueueWatcher" `
                    -Event "CONNECTIVITY_ANALYSIS_FAILED" `
                    -Level "ERROR" `
                    -Data @{
                        Printer = $PrinterName
                        JobId   = $Event.JobId
                    } |
                    Out-Null

                continue
            }

            Show-ConnectivitySummary `
                -Connectivity $Connectivity

            # =================================================
            # DECISION
            # =================================================

            switch ($Connectivity.Classification) {

                "PRINTER_REACHABLE" {

                    Write-PrintSwitchLog `
                        -Component "QueueWatcher" `
                        -Event "PRINTER_REACHABLE" `
                        -Level "INFO" `
                        -Data @{
                            Printer = $PrinterName
                            JobId   = $Event.JobId
                            SSID    = $Connectivity.CurrentSSID
                        } |
                        Out-Null

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

                "NETWORK_MISMATCH" {

                    Write-PrintSwitchLog `
                        -Component "QueueWatcher" `
                        -Event "NETWORK_MISMATCH" `
                        -Level "WARN" `
                        -Data @{
                            Printer     = $PrinterName
                            JobId       = $Event.JobId
                            CurrentSSID = $Connectivity.CurrentSSID
                            TargetSSID  = $Connectivity.RequiredSSID
                        } |
                        Out-Null

                    Write-Host ""
                    Write-Host "========================================"
                    Write-Host "FASE 2 - RECUPERACION DE RED"
                    Write-Host "========================================"

                    Write-Host `
                        "La PC no esta en la red requerida."

                    Write-Host `
                        "Red requerida: $($Connectivity.RequiredSSID)"

                    if (-not $EnableRecovery) {

                        Write-Host ""
                        Write-Host `
                            "DRY-RUN: no se modifico la red."

                        break
                    }

                    if (-not (Test-Path $NetworkManagerPath)) {

                        Write-PrintSwitchLog `
                            -Component "QueueWatcher" `
                            -Event "NETWORK_MANAGER_NOT_FOUND" `
                            -Level "ERROR" |
                            Out-Null

                        break
                    }

                    try {

                        $NetworkResult = & $NetworkManagerPath `
                            -TargetSSID $Connectivity.RequiredSSID `
                            -AutoExecute
                    }
                    catch {

                        Write-PrintSwitchLog `
                            -Component "QueueWatcher" `
                            -Event "NETWORK_MANAGER_ERROR" `
                            -Level "ERROR" `
                            -Data @{
                                Message = $_.Exception.Message
                            } |
                            Out-Null

                        break
                    }

                    if ($null -eq $NetworkResult) {

                        Write-PrintSwitchLog `
                            -Component "QueueWatcher" `
                            -Event "NETWORK_MANAGER_NO_RESULT" `
                            -Level "ERROR" |
                            Out-Null

                        break
                    }

                    if (-not $NetworkResult.SwitchVerified) {

                        if (
                            $NetworkResult.ExecutionResult `
                                -eq "SWITCH_NOT_AVAILABLE"
                        ) {

                            Write-PrintSwitchLog `
                                -Component "QueueWatcher" `
                                -Event "NETWORK_RECOVERY_UNAVAILABLE" `
                                -Level "WARN" `
                                -Data @{
                                    Classification =
                                        $NetworkResult.Classification

                                    TargetSSID =
                                        $NetworkResult.TargetSSID
                                } |
                                Out-Null
                        }
                        else {

                            Write-PrintSwitchLog `
                                -Component "QueueWatcher" `
                                -Event "RECOVERY_FAILED" `
                                -Level "ERROR" `
                                -Data @{
                                    InitialSSID =
                                        $NetworkResult.InitialSSID

                                    TargetSSID =
                                        $NetworkResult.TargetSSID
                                } |
                                Out-Null
                        }

                        break
                    }

                    Write-PrintSwitchLog `
                        -Component "QueueWatcher" `
                        -Event "NETWORK_SWITCH_VERIFIED" `
                        -Level "INFO" `
                        -Data @{
                            InitialSSID =
                                $NetworkResult.InitialSSID

                            FinalSSID =
                                $NetworkResult.FinalSSID
                        } |
                        Out-Null

                    # =================================================
                    # FASE 3
                    # =================================================

                    $ConnectivityAfterSwitch = `
                        Invoke-ConnectivityAnalysis

                    if ($null -eq $ConnectivityAfterSwitch) {

                        Write-PrintSwitchLog `
                            -Component "QueueWatcher" `
                            -Event "RECOVERY_INDETERMINATE" `
                            -Level "ERROR" |
                            Out-Null

                        break
                    }

                    if (
                        $ConnectivityAfterSwitch.Classification `
                            -eq "PRINTER_REACHABLE"
                    ) {

                        Write-PrintSwitchLog `
                            -Component "QueueWatcher" `
                            -Event "RECOVERY_SUCCESS" `
                            -Level "INFO" `
                            -Data @{
                                Printer = $PrinterName
                                JobId   = $Event.JobId
                                SSID    =
                                    $ConnectivityAfterSwitch.CurrentSSID
                            } |
                            Out-Null

                        Write-Host ""
                        Write-Host "========================================"

                        Write-Host `
                            "RECOVERY_SUCCESS" `
                            -ForegroundColor Green

                        Write-Host "========================================"

                        Write-Host `
                            "La impresora ahora resulta alcanzable."
                    }
                    else {

                        Write-PrintSwitchLog `
                            -Component "QueueWatcher" `
                            -Event "PRINTER_UNREACHABLE_AFTER_SWITCH" `
                            -Level "WARN" `
                            -Data @{
                                Printer =
                                    $PrinterName

                                Classification =
                                    $ConnectivityAfterSwitch.Classification
                            } |
                            Out-Null

                        Write-Host ""
                        Write-Host `
                            "NETWORK_SWITCH_OK_BUT_PRINTER_UNREACHABLE" `
                            -ForegroundColor Yellow
                    }
                }

                "PRINTER_UNREACHABLE_ON_TARGET_NETWORK" {

                    Write-PrintSwitchLog `
                        -Component "QueueWatcher" `
                        -Event "PRINTER_UNREACHABLE_ON_TARGET_NETWORK" `
                        -Level "WARN" `
                        -Data @{
                            Printer = $PrinterName
                            JobId   = $Event.JobId
                            SSID    = $Connectivity.CurrentSSID
                        } |
                        Out-Null

                    Write-Host ""
                    Write-Host `
                        "PRINTER_UNREACHABLE_ON_TARGET_NETWORK" `
                        -ForegroundColor Yellow

                    Write-Host `
                        "No se cambiara de red."
                }

                default {

                    Write-PrintSwitchLog `
                        -Component "QueueWatcher" `
                        -Event "UNKNOWN_CLASSIFICATION" `
                        -Level "WARN" `
                        -Data @{
                            Classification =
                                $Connectivity.Classification
                        } |
                        Out-Null
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

    Start-Sleep `
        -Milliseconds $PollingMilliseconds
}