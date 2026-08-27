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


$PrintRecoveryOrchestratorPath = Join-Path `
    $PSScriptRoot `
    "PrintRecoveryOrchestrator.ps1"
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
        "Modo: RECOVERY AUTOMATICO HABILITADO" `
        -ForegroundColor Yellow

    Write-Host `
        "Cambios de Wi-Fi permitidos." `
        -ForegroundColor Yellow
}
else {

    Write-Host `
        "Modo: DRY-RUN" `
        -ForegroundColor Green

    Write-Host `
        "No se modificara ninguna red Wi-Fi." `
        -ForegroundColor Green
}

Write-Host ""
Write-Host "Configuracion       : $ConfigPath"
Write-Host "Impresora observada : $PrinterName"
Write-Host "Intervalo           : $PollingMilliseconds ms"
Write-Host "Logger              : $LoggerPath"
Write-Host "ConfigValidator     : $ConfigValidatorPath"


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


# ============================================================
# FUNCION: resumen
# ============================================================


# ============================================================
# VALIDAR PRINT RECOVERY ORCHESTRATOR
# ============================================================

if (-not (Test-Path $PrintRecoveryOrchestratorPath)) {

    Write-Host ""
    Write-Host `
        "ERROR: PrintRecoveryOrchestrator no encontrado." `
        -ForegroundColor Red

    Write-Host `
        "Ruta esperada: $PrintRecoveryOrchestratorPath"

    Write-PrintSwitchLog `
        -Component "QueueWatcher" `
        -Event "RECOVERY_ORCHESTRATOR_NOT_FOUND" `
        -Level "ERROR" `
        -Data @{
            Path = $PrintRecoveryOrchestratorPath
        } |
        Out-Null

    return
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
# NUEVO ORQUESTADOR - DRY RUN
# =================================================

Write-Host ""
Write-Host "========================================"
Write-Host "PRINT RECOVERY ORCHESTRATOR"
Write-Host "========================================"

try {

   $OrchestratorParameters = @{
    PrinterName = $PrinterName
}

if ($EnableRecovery) {

    $OrchestratorParameters.Execute = $true
}

$OrchestratorResult = & $PrintRecoveryOrchestratorPath `
    @OrchestratorParameters
}
catch {

    Write-PrintSwitchLog `
        -Component "QueueWatcher" `
        -Event "RECOVERY_ORCHESTRATOR_ERROR" `
        -Level "ERROR" `
        -Data @{
            Printer = $PrinterName
            JobId   = $Event.JobId
            Message = $_.Exception.Message
        } |
        Out-Null

    Write-Host ""
    Write-Host `
        "ERROR ejecutando PrintRecoveryOrchestrator." `
        -ForegroundColor Red

    continue
}

if ($null -eq $OrchestratorResult) {

    Write-PrintSwitchLog `
        -Component "QueueWatcher" `
        -Event "RECOVERY_ORCHESTRATOR_NO_RESULT" `
        -Level "ERROR" `
        -Data @{
            Printer = $PrinterName
            JobId   = $Event.JobId
        } |
        Out-Null

    continue
}

Write-Host ""
Write-Host "Resultado del orquestador:"
Write-Host "FinalClassification : $($OrchestratorResult.FinalClassification)"
Write-Host "SwitchDecision      : $($OrchestratorResult.SwitchDecision)"
Write-Host "SwitchAuthorized    : $($OrchestratorResult.SwitchAuthorized)"
Write-Host "SwitchExecuted      : $($OrchestratorResult.SwitchExecuted)"

Write-PrintSwitchLog `
    -Component "QueueWatcher" `
    -Event "RECOVERY_ORCHESTRATOR_RESULT" `
    -Level "INFO" `
    -Data @{
        Printer            = $PrinterName
        JobId              = $Event.JobId
        FinalClassification =
            $OrchestratorResult.FinalClassification
        SwitchDecision =
            $OrchestratorResult.SwitchDecision
        SwitchExecuted =
            $OrchestratorResult.SwitchExecuted
    } |
    Out-Null


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