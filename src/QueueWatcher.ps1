param (
    [switch]$EnableRecovery,

    [string]$PrinterName
)

$ErrorActionPreference = "Continue"

# PrintSwitch - QueueWatcher v0.7
#
# Orquestador de observacion de trabajos.
#
# Funciones:
#   - descubre colas instaladas mediante PrinterDiscovery
#   - selecciona la cola observada mediante QueueContext
#   - observa trabajos
#   - solicita diagnostico
#   - solicita recuperacion de red
#   - registra eventos importantes mediante Logger
#
# v0.7:
# - elimina la dependencia operacional de config/printers.json
# - deja de usar ConfigValidator para seleccionar impresoras
# - usa PrinterDiscovery como fuente operacional de colas
# - no selecciona arbitrariamente una cola cuando existen varias

$PollingMilliseconds = 500

$LoggerPath = Join-Path `
    $PSScriptRoot `
    "Logger.ps1"

$PrinterDiscoveryPath = Join-Path `
    $PSScriptRoot `
    "PrinterDiscovery.ps1"

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
Write-Host "PrintSwitch - QueueWatcher v0.7" `
    -ForegroundColor Cyan

Write-Host ""

Write-PrintSwitchLog `
    -Component "QueueWatcher" `
    -Event "PRINTSWITCH_STARTED" `
    -Level "INFO" `
    -Data @{
        RecoveryEnabled = [bool]$EnableRecovery
        RequestedPrinter = $PrinterName
    } |
    Out-Null

# ============================================================
# 2. VALIDAR PRINTER DISCOVERY
# ============================================================

Write-Host "========================================"
Write-Host "1. PRINTER DISCOVERY"
Write-Host "========================================"

if (-not (Test-Path -LiteralPath $PrinterDiscoveryPath)) {

    Write-Host ""
    Write-Host `
        "ERROR: PrinterDiscovery no encontrado." `
        -ForegroundColor Red

    Write-Host "Ruta esperada: $PrinterDiscoveryPath"

    Write-PrintSwitchLog `
        -Component "QueueWatcher" `
        -Event "PRINTER_DISCOVERY_NOT_FOUND" `
        -Level "ERROR" `
        -Data @{
            Path = $PrinterDiscoveryPath
        } |
        Out-Null

    return
}

# ============================================================
# 3. EJECUTAR DISCOVERY
# ============================================================

$QueueContexts = @()

try {

    $QueueContexts = @(
        & $PrinterDiscoveryPath
    )
}
catch {

    Write-Host ""
    Write-Host `
        "ERROR ejecutando PrinterDiscovery." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message

    Write-PrintSwitchLog `
        -Component "QueueWatcher" `
        -Event "PRINTER_DISCOVERY_ERROR" `
        -Level "ERROR" `
        -Data @{
            Message = $_.Exception.Message
        } |
        Out-Null

    return
}

if ($QueueContexts.Count -eq 0) {

    Write-Host ""
    Write-Host `
        "ERROR: PrinterDiscovery no encontro colas fisicas." `
        -ForegroundColor Red

    Write-PrintSwitchLog `
        -Component "QueueWatcher" `
        -Event "NO_PHYSICAL_PRINTER_QUEUES" `
        -Level "ERROR" |
        Out-Null

    return
}

Write-Host ""
Write-Host "QueueContexts descubiertos : $($QueueContexts.Count)"

# ============================================================
# 4. SELECCIONAR COLA
# ============================================================

$SelectedQueueContext = $null

if (
    -not [string]::IsNullOrWhiteSpace($PrinterName)
) {

    $SelectedQueueContext =
        $QueueContexts |
            Where-Object {
                $_.QueueName -eq $PrinterName
            } |
            Select-Object -First 1

    if ($null -eq $SelectedQueueContext) {

        Write-Host ""
        Write-Host `
            "ERROR: Windows no contiene una cola fisica llamada '$PrinterName'." `
            -ForegroundColor Red

        Write-Host ""
        Write-Host "Colas descubiertas:"

        $QueueContexts |
            ForEach-Object {
                Write-Host " - $($_.QueueName)"
            }

        Write-PrintSwitchLog `
            -Component "QueueWatcher" `
            -Event "PRINTER_QUEUE_NOT_FOUND" `
            -Level "ERROR" `
            -Data @{
                RequestedPrinter = $PrinterName
                DiscoveredCount  = $QueueContexts.Count
            } |
            Out-Null

        return
    }
}
elseif ($QueueContexts.Count -eq 1) {

    $SelectedQueueContext =
        $QueueContexts[0]

    $PrinterName =
        [string]$SelectedQueueContext.QueueName
}
else {

    Write-Host ""
    Write-Host `
        "ERROR: se descubrieron varias colas fisicas y no se especifico -PrinterName." `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Colas disponibles:"

    $QueueContexts |
        ForEach-Object {
            Write-Host " - $($_.QueueName)"
        }

    Write-Host ""
    Write-Host `
        "Especifique explicitamente la cola mediante -PrinterName." `
        -ForegroundColor Yellow

    Write-PrintSwitchLog `
        -Component "QueueWatcher" `
        -Event "AMBIGUOUS_PRINTER_SELECTION" `
        -Level "ERROR" `
        -Data @{
            DiscoveredCount = $QueueContexts.Count
        } |
        Out-Null

    return
}

$PrinterName =
    [string]$SelectedQueueContext.QueueName

Write-Host ""
Write-Host "----------------------------------------"
Write-Host "QUEUECONTEXT SELECCIONADO"
Write-Host "----------------------------------------"

Write-Host `
    "QueueName             : $($SelectedQueueContext.QueueName)"

Write-Host `
    "DiscoveryStatus       : $($SelectedQueueContext.DiscoveryStatus)"

Write-Host `
    "TransportType         : $($SelectedQueueContext.TransportType)"

Write-Host `
    "Protocol              : $($SelectedQueueContext.Protocol)"

Write-Host `
    "ConfiguredDestination : $($SelectedQueueContext.ConfiguredDestination)"

Write-Host `
    "TcpPort               : $($SelectedQueueContext.TcpPort)"

Write-Host `
    "ReachabilityStrategy  : $($SelectedQueueContext.ReachabilityStrategy)"

Write-PrintSwitchLog `
    -Component "QueueWatcher" `
    -Event "PRINTER_QUEUE_SELECTED" `
    -Level "INFO" `
    -Data @{
        PrinterName =
            $SelectedQueueContext.QueueName

        DiscoveryStatus =
            $SelectedQueueContext.DiscoveryStatus

        TransportType =
            $SelectedQueueContext.TransportType

        Protocol =
            $SelectedQueueContext.Protocol
    } |
    Out-Null

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

Write-Host "Fuente de colas      : Windows / PrinterDiscovery"
Write-Host "Impresora observada  : $PrinterName"
Write-Host "DiscoveryStatus      : $($SelectedQueueContext.DiscoveryStatus)"
Write-Host "Intervalo            : $PollingMilliseconds ms"
Write-Host "Logger               : $LoggerPath"
Write-Host "PrinterDiscovery     : $PrinterDiscoveryPath"


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