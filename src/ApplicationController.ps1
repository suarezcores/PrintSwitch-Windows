Set-StrictMode -Version Latest

# ============================================================
# PrintSwitch - ApplicationController v0.1
# Punto 7 - P7-A3
#
# Primera frontera ejecutable entre:
#
# UI / Application Layer
#          |
#          v
# ApplicationController
#          |
#          v
# PrintSwitch Core
#
# P7-A3:
# - queries reales
# - estado interno
# - recovery enable/disable
# - adaptación de output
# - SIN QueueWatcher lifecycle real
# - SIN NetworkManager directo
# - SIN cambio Wi-Fi
# ============================================================

$script:ControllerVersion = "0.5"

$script:RootPath =
    Split-Path `
        $PSScriptRoot `
        -Parent

$script:PrinterDiscoveryPath =
    Join-Path `
        $PSScriptRoot `
        "PrinterDiscovery.ps1"

$script:PrinterEndpointResolverPath =
    Join-Path `
        $PSScriptRoot `
        "PrinterEndpointResolver.ps1"

$script:PrinterEndpointReachabilityPath =
    Join-Path `
        $PSScriptRoot `
        "PrinterEndpointReachability.ps1"

$script:PrinterServiceProbePath =
    Join-Path `
        $PSScriptRoot `
        "PrinterServiceProbe.ps1"

$script:LoggerPath =
    Join-Path `
        $PSScriptRoot `
        "Logger.ps1"

$script:QueueWatcherPath =
    Join-Path `
        $PSScriptRoot `
        "QueueWatcher.ps1"

$script:QueuePolicyPath =
    Join-Path `
        $PSScriptRoot `
        "QueuePolicy.ps1"

$script:RecoveryAuthorizationPath =
    Join-Path `
        $PSScriptRoot `
        "RecoveryAuthorization.ps1"

$script:TargetNetworkContextPath =
    Join-Path `
        $PSScriptRoot `
        "TargetNetworkContext.ps1"

$script:RecoveryExecutionAdapterPath =
    Join-Path `
        $PSScriptRoot `
        "RecoveryExecutionAdapter.ps1"

$script:EventWriterPath =
    Join-Path `
        $PSScriptRoot `
        "EventWriter.ps1"

$script:LogsPath =
    Join-Path `
        $script:RootPath `
        "logs"

# ============================================================
# 1. LOAD SAFE FUNCTION LIBRARIES
# ============================================================

foreach (
    $DependencyPath in @(
        $script:PrinterEndpointResolverPath,
        $script:PrinterEndpointReachabilityPath,
        $script:PrinterServiceProbePath,
        $script:QueuePolicyPath,
        $script:RecoveryAuthorizationPath,
        $script:TargetNetworkContextPath,
        $script:RecoveryExecutionAdapterPath,
        $script:EventWriterPath,
        $script:LoggerPath
    )
) {

    if (-not (Test-Path $DependencyPath)) {

        throw "Dependencia requerida no encontrada: $DependencyPath"
    }

    . $DependencyPath
}

# ============================================================
# 2. CONTROLLER STATE
# ============================================================

$script:ControllerState =
    [PSCustomObject]@{

        ApplicationState =
            "RUNNING"

        MonitoringState =
            "NOT_STARTED"


        MonitoringJob =
            $null

        MonitoringJobId =
            $null

        MonitoringStartedAt =
            $null

        MonitoringStoppedAt =
            $null
        RecoveryEnabled =
            $false

        MonitoringEventPath =
            $null


        ProcessedMonitoringEventIds =
            @{}
        SelectedPrinter =
            $null

        CurrentQueueContext =
            $null


        LastPrintJob =
            $null

        LastQueuePolicyResult =
            $null

        LastRecoveryEvaluation =
            $null

        LastTargetNetworkContext =
            $null

        LastRecoveryAuthorization =
            $null

        LastRecoveryExecution =
            $null

        CurrentEndpoint =
            $null

        CurrentReachability =
            $null

        CurrentSSID =
            $null

        LastDecision =
            $null

        LastRecovery =
            $null

        LastError =
            $null

        StartedAt =
            Get-Date

        LastUpdatedAt =
            Get-Date
    }


# ============================================================
# MONITORING EVENT SYNCHRONIZATION
# ============================================================

function Sync-PrintSwitchMonitoringEvents {

    [CmdletBinding()]
    param ()

    $EventPath =
        $script:ControllerState.MonitoringEventPath

    if ([string]::IsNullOrWhiteSpace($EventPath)) {

        return [PSCustomObject]@{
            EventsRead      = 0
            EventsProcessed = 0
            EventsSkipped   = 0
            ReadErrors      = 0
        }
    }

    $Events =
        @(
            Read-PrintSwitchEvents `
                -Path $EventPath
        )

    $Processed  = 0
    $Skipped    = 0
    $ReadErrors = 0

    foreach ($Event in $Events) {

        if ($null -eq $Event) {

            $ReadErrors++
            continue
        }

        if (
            $Event.PSObject.Properties.Name -contains "Component" -and
            $Event.Component -eq "PrintSwitchEventReadError"
        ) {

            $ReadErrors++
            continue
        }

        $Contract =
            Test-PrintSwitchEventContract `
                -Event $Event

        if (-not $Contract.Valid) {
            $Skipped++
            continue
        }

        $EventId =
            [string]$Event.EventId

        if ([string]::IsNullOrWhiteSpace($EventId)) {
            $Skipped++
            continue
        }

        if (
            $script:ControllerState.ProcessedMonitoringEventIds.ContainsKey(
                $EventId
            )
        ) {
            $Skipped++
            continue
        }

        switch ([string]$Event.EventType) {

            "PrintJobDetected" {

                $script:ControllerState.LastPrintJob =
                    $Event.Data

                $QueueJobContext =
                    $null

                if (
                    $null -ne $Event.Data -and
                    $Event.Data.PSObject.Properties.Name -contains
                        "QueueJobContext"
                ) {

                    $QueueJobContext =
                        $Event.Data.QueueJobContext
                }

                try {

                    $QueuePolicyResult =
                        Get-PrintSwitchQueuePolicy `
                            -QueueJobContext $QueueJobContext

                    $QueuePolicyValidation =
                        Test-PrintSwitchQueuePolicyResult `
                            -Result $QueuePolicyResult

                    if (-not $QueuePolicyValidation.Valid) {

                        $QueuePolicyResult =
                            New-PrintSwitchQueuePolicyResult `
                                -Decision "INSUFFICIENT_CONTEXT" `
                                -Actionable $false `
                                -AllowRecoveryEvaluation $false `
                                -ReasonCode "QUEUE_POLICY_RESULT_INVALID" `
                                -Reason "QueuePolicy returned an invalid result contract." `
                                -SourceContext $QueueJobContext
                    }
                }
                catch {

                    $QueuePolicyResult =
                        New-PrintSwitchQueuePolicyResult `
                            -Decision "INSUFFICIENT_CONTEXT" `
                            -Actionable $false `
                            -AllowRecoveryEvaluation $false `
                            -ReasonCode "QUEUE_POLICY_EVALUATION_FAILED" `
                            -Reason $_.Exception.Message `
                            -SourceContext $QueueJobContext
                }

                $script:ControllerState.LastQueuePolicyResult =
                    $QueuePolicyResult

                $script:ControllerState.LastRecoveryEvaluation =
                    $null

                $script:ControllerState.LastRecoveryAuthorization =
                    $null

                $script:ControllerState.LastRecoveryExecution =
                    $null

                if (
                    $null -ne $QueuePolicyResult -and
                    $QueuePolicyResult.Decision -eq "EVALUATE_RECOVERY" -and
                    [bool]$QueuePolicyResult.AllowRecoveryEvaluation
                ) {

                    $EvaluationPrinterName = $null
                    $EvaluationJobId = $null

                    if ($null -ne $QueueJobContext) {
                        if ($QueueJobContext.PSObject.Properties.Name -contains "PrinterName") {
                            $EvaluationPrinterName = [string]$QueueJobContext.PrinterName
                        }
                        if ($QueueJobContext.PSObject.Properties.Name -contains "JobId") {
                            $EvaluationJobId = $QueueJobContext.JobId
                        }
                    }

                    if (-not [string]::IsNullOrWhiteSpace($EvaluationPrinterName)) {
                        $script:ControllerState.LastRecoveryEvaluation =
                            Invoke-PrintSwitchRecoveryEvaluation -QueuePolicyResult $QueuePolicyResult -PrinterName $EvaluationPrinterName -JobId $EvaluationJobId

                        $script:ControllerState.LastRecoveryAuthorization =
                            $null

                        if ($null -ne $script:ControllerState.LastRecoveryEvaluation) {

                            $AuthorizationCurrentSSID =
                                Get-PrintSwitchCurrentSSID

                            $script:ControllerState.LastTargetNetworkContext =
                                Get-PrintSwitchTargetNetworkContext `
                                    -PrinterName $EvaluationPrinterName

                            $AuthorizationTargetSSID =
                                $null

                            if (
                                $null -ne $script:ControllerState.LastTargetNetworkContext -and
                                [bool]$script:ControllerState.LastTargetNetworkContext.Resolved
                            ) {
                                $AuthorizationTargetSSID =
                                    [string]$script:ControllerState.LastTargetNetworkContext.TargetSSID
                            }

                            $script:ControllerState.LastRecoveryAuthorization =
                                Get-PrintSwitchRecoveryAuthorization -RecoveryEvaluationResult $script:ControllerState.LastRecoveryEvaluation -RecoveryEnabled ([bool]$script:ControllerState.RecoveryEnabled) -CurrentSSID $AuthorizationCurrentSSID -TargetSSID $AuthorizationTargetSSID -PrinterName $EvaluationPrinterName

                            $RecoveryExecutionCorrelationId =
                                "CONTROLLER-JOB-{0}-{1}" -f @(
                                    [string]$EvaluationJobId,
                                    [guid]::NewGuid().ToString("N")
                                )

                            $script:ControllerState.LastRecoveryExecution =
                                Get-PrintSwitchRecoveryExecutionRequest `
                                    -RecoveryAuthorization $script:ControllerState.LastRecoveryAuthorization `
                                    -ExpectedPrinterName $EvaluationPrinterName `
                                    -ExpectedTargetSSID $AuthorizationTargetSSID `
                                    -ExpectedJobId $EvaluationJobId `
                                    -CorrelationId $RecoveryExecutionCorrelationId

if (
    $null -ne $script:ControllerState.LastRecoveryExecution -and
    $script:ControllerState.LastRecoveryExecution.ExecutionAuthorized -eq $true -and
    $script:ControllerState.LastRecoveryExecution.SwitchAuthorized -eq $true
) {
    $script:ControllerState.LastRecoveryExecution =
        Invoke-PrintSwitchRecoveryExecutionDryRun `
            -ExecutionRequest $script:ControllerState.LastRecoveryExecution
}
                        }
                    }
                }
            }

            "DecisionProduced" {

                $script:ControllerState.LastDecision =
                    $Event.Data
            }

            "RecoveryCompleted" {

                $script:ControllerState.LastRecovery =
                    $Event.Data
            }
        }

        $script:ControllerState.ProcessedMonitoringEventIds[$EventId] =
            $true

        $Processed++
    }

    if ($Processed -gt 0) {

        $script:ControllerState.LastUpdatedAt =
            Get-Date
    }

    return [PSCustomObject]@{
        EventsRead      = $Events.Count
        EventsProcessed = $Processed
        EventsSkipped   = $Skipped
        ReadErrors      = $ReadErrors
    }
}
# ============================================================
# 3. RESULT CONTRACT
# ============================================================

function New-PrintSwitchControllerResult {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [bool]$Success,

        [Parameter(Mandatory)]
        [string]$Classification,

        [object]$Data = $null,

        [object]$ErrorObject = $null
    )

    return [PSCustomObject]@{

        Component =
            "ApplicationController"

        ContractVersion =
            1

        ControllerVersion =
            $script:ControllerVersion

        Operation =
            $Operation

        Success =
            $Success

        Classification =
            $Classification

        Timestamp =
            Get-Date

        Data =
            $Data

        Error =
            $ErrorObject
    }
}

# ============================================================
# 4. ERROR CONTRACT
# ============================================================

function New-PrintSwitchControllerError {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Code,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$SourceComponent = "ApplicationController",

        [string]$ExceptionType = ""
    )

    return [PSCustomObject]@{

        Code =
            $Code

        Message =
            $Message

        SourceComponent =
            $SourceComponent

        ExceptionType =
            $ExceptionType

        Timestamp =
            Get-Date
    }
}

function Set-PrintSwitchControllerError {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$ErrorObject
    )

    $script:ControllerState.LastError =
        $ErrorObject

    $script:ControllerState.LastUpdatedAt =
        Get-Date
}

function Clear-PrintSwitchControllerError {

    [CmdletBinding()]
    param ()

    $script:ControllerState.LastError =
        $null

    $script:ControllerState.LastUpdatedAt =
        Get-Date
}

# ============================================================
# 5. NON-MUTATING WIFI CONTEXT
# ============================================================

function Get-PrintSwitchCurrentSSID {

    [CmdletBinding()]
    param ()

    try {

        $Output =
            netsh wlan show interfaces 2>$null

        $SSIDLine =
            $Output |
            Select-String `
                -Pattern '^\s*SSID\s*:\s*(.+)$' |
            Select-Object `
                -First 1

        if ($null -eq $SSIDLine) {

            return $null
        }

        $Match =
            [regex]::Match(
                $SSIDLine.Line,
                '^\s*SSID\s*:\s*(.+)$'
            )

        if (-not $Match.Success) {

            return $null
        }

        return $Match.Groups[1].Value.Trim()
    }
    catch {

        return $null
    }
}

# ============================================================
# 6. GET STATUS
# ============================================================

function Get-PrintSwitchStatus {

    [CmdletBinding()]
    param ()

    try {


        $MonitoringSync =
            Sync-PrintSwitchMonitoringEvents
        # --------------------------------------------------------
        # Reconciliar MonitoringState con el PowerShell Job real.
        # --------------------------------------------------------

        if ($null -ne $script:ControllerState.MonitoringJobId) {

            $CurrentJob =
                Get-Job `
                    -Id $script:ControllerState.MonitoringJobId `
                    -ErrorAction SilentlyContinue

            if ($null -eq $CurrentJob) {

                $script:ControllerState.MonitoringJob =
                    $null

                $script:ControllerState.MonitoringJobId =
                    $null

                $script:ControllerState.MonitoringState =
                    "STOPPED"
            }
            else {

                $script:ControllerState.MonitoringJob =
                    $CurrentJob

                switch ($CurrentJob.State) {

                    "Running" {

                        $script:ControllerState.MonitoringState =
                            "WATCHING"
                    }

                    "Completed" {

                        $script:ControllerState.MonitoringState =
                            "STOPPED"
                    }

                    "Stopped" {

                        $script:ControllerState.MonitoringState =
                            "STOPPED"
                    }

                    "Failed" {

                        $script:ControllerState.MonitoringState =
                            "FAULTED"
                    }

                    "Blocked" {

                        $script:ControllerState.MonitoringState =
                            "FAULTED"
                    }

                    default {

                        $script:ControllerState.MonitoringState =
                            [string]$CurrentJob.State
                    }
                }
            }
        }

        $CurrentSSID =
            Get-PrintSwitchCurrentSSID

        $script:ControllerState.CurrentSSID =
            $CurrentSSID

        $script:ControllerState.LastUpdatedAt =
            Get-Date

        $Status =
            [PSCustomObject]@{

                ApplicationState =
                    $script:ControllerState.ApplicationState

                MonitoringState =
                    $script:ControllerState.MonitoringState

                MonitoringJobId =
                    $script:ControllerState.MonitoringJobId

                MonitoringStartedAt =
                    $script:ControllerState.MonitoringStartedAt

                MonitoringStoppedAt =
                    $script:ControllerState.MonitoringStoppedAt

                RecoveryEnabled =
                    $script:ControllerState.RecoveryEnabled

                SelectedPrinter =
                    $script:ControllerState.SelectedPrinter

                CurrentQueueContext =
                    $script:ControllerState.CurrentQueueContext


                LastPrintJob =
                    $script:ControllerState.LastPrintJob

                LastQueuePolicyResult =
                    $script:ControllerState.LastQueuePolicyResult

                LastRecoveryEvaluation =
                    $script:ControllerState.LastRecoveryEvaluation

                LastTargetNetworkContext =
                    $script:ControllerState.LastTargetNetworkContext

                LastRecoveryAuthorization =
                    $script:ControllerState.LastRecoveryAuthorization

                LastRecoveryExecution =
                    $script:ControllerState.LastRecoveryExecution

                CurrentEndpoint =
                    $script:ControllerState.CurrentEndpoint

                CurrentReachability =
                    $script:ControllerState.CurrentReachability

                CurrentSSID =
                    $script:ControllerState.CurrentSSID

                LastDecision =
                    $script:ControllerState.LastDecision

                LastRecovery =
                    $script:ControllerState.LastRecovery

                LastError =
                    $script:ControllerState.LastError

                StartedAt =
                    $script:ControllerState.StartedAt

                LastUpdatedAt =
                    $script:ControllerState.LastUpdatedAt
            }

        return New-PrintSwitchControllerResult `
            -Operation "GetStatus" `
            -Success $true `
            -Classification "STATUS_AVAILABLE" `
            -Data $Status
    }
    catch {

        $ControllerError =
            New-PrintSwitchControllerError `
                -Code "STATUS_FAILED" `
                -Message $_.Exception.Message `
                -SourceComponent "ApplicationController" `
                -ExceptionType $_.Exception.GetType().FullName

        Set-PrintSwitchControllerError `
            -ErrorObject $ControllerError

        return New-PrintSwitchControllerResult `
            -Operation "GetStatus" `
            -Success $false `
            -Classification "STATUS_FAILED" `
            -ErrorObject $ControllerError
    }
}

# ============================================================
# 7. GET PRINTERS
# ============================================================

function Get-PrintSwitchPrinters {

    [CmdletBinding()]
    param (
        [switch]$IncludeVirtual
    )

    try {

        if (-not (Test-Path $script:PrinterDiscoveryPath)) {

            throw "PrinterDiscovery.ps1 no encontrado."
        }

        $Arguments = @{}

        if ($IncludeVirtual) {

            $Arguments["IncludeVirtual"] =
                $true
        }

        $RawResults =
            @(
                & $script:PrinterDiscoveryPath @Arguments 6>$null
            )

        $QueueContexts =
            @(
                $RawResults |
                Where-Object {

                    $null -ne $_ -and
                    $_.PSObject.Properties.Name -contains "QueueName"
                }
            )

        Clear-PrintSwitchControllerError

        return New-PrintSwitchControllerResult `
            -Operation "GetPrinters" `
            -Success $true `
            -Classification "PRINTERS_DISCOVERED" `
            -Data $QueueContexts
    }
    catch {

        $ControllerError =
            New-PrintSwitchControllerError `
                -Code "DISCOVERY_FAILED" `
                -Message $_.Exception.Message `
                -SourceComponent "PrinterDiscovery" `
                -ExceptionType $_.Exception.GetType().FullName

        Set-PrintSwitchControllerError `
            -ErrorObject $ControllerError

        return New-PrintSwitchControllerResult `
            -Operation "GetPrinters" `
            -Success $false `
            -Classification "DISCOVERY_FAILED" `
            -ErrorObject $ControllerError
    }
}

# ============================================================
# 8. GET QUEUE CONTEXT
# ============================================================

function Get-PrintSwitchQueueContext {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$PrinterName
    )

    try {

        $DiscoveryResult =
            Get-PrintSwitchPrinters

        if (-not $DiscoveryResult.Success) {

            return New-PrintSwitchControllerResult `
                -Operation "GetQueueContext" `
                -Success $false `
                -Classification "DISCOVERY_FAILED" `
                -ErrorObject $DiscoveryResult.Error
        }

        $Matches =
            @(
                $DiscoveryResult.Data |
                Where-Object {
                    $_.QueueName -eq $PrinterName
                }
            )

        if ($Matches.Count -eq 0) {

            return New-PrintSwitchControllerResult `
                -Operation "GetQueueContext" `
                -Success $false `
                -Classification "QUEUE_NOT_FOUND"
        }

        if ($Matches.Count -gt 1) {

            return New-PrintSwitchControllerResult `
                -Operation "GetQueueContext" `
                -Success $false `
                -Classification "QUEUE_AMBIGUOUS" `
                -Data $Matches
        }

        $QueueContext =
            $Matches[0]

        $script:ControllerState.SelectedPrinter =
            $PrinterName

        $script:ControllerState.CurrentQueueContext =
            $QueueContext

        $script:ControllerState.LastUpdatedAt =
            Get-Date

        Clear-PrintSwitchControllerError

        return New-PrintSwitchControllerResult `
            -Operation "GetQueueContext" `
            -Success $true `
            -Classification "QUEUE_FOUND" `
            -Data $QueueContext
    }
    catch {

        $ControllerError =
            New-PrintSwitchControllerError `
                -Code "QUEUE_CONTEXT_FAILED" `
                -Message $_.Exception.Message `
                -SourceComponent "ApplicationController" `
                -ExceptionType $_.Exception.GetType().FullName

        Set-PrintSwitchControllerError `
            -ErrorObject $ControllerError

        return New-PrintSwitchControllerResult `
            -Operation "GetQueueContext" `
            -Success $false `
            -Classification "QUEUE_CONTEXT_FAILED" `
            -ErrorObject $ControllerError
    }
}

# ============================================================
# 9. GET ENDPOINT
# ============================================================

function Get-PrintSwitchEndpoint {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$PrinterName
    )

    try {

        $Endpoint =
            Resolve-PrintSwitchEndpoint `
                -PrinterName $PrinterName

        if ($null -eq $Endpoint) {

            return New-PrintSwitchControllerResult `
                -Operation "GetEndpoint" `
                -Success $false `
                -Classification "ENDPOINT_UNKNOWN"
        }

        $script:ControllerState.SelectedPrinter =
            $PrinterName

        $script:ControllerState.CurrentEndpoint =
            $Endpoint

        $script:ControllerState.LastUpdatedAt =
            Get-Date

        Clear-PrintSwitchControllerError

        return New-PrintSwitchControllerResult `
            -Operation "GetEndpoint" `
            -Success $true `
            -Classification "ENDPOINT_RESOLVED" `
            -Data $Endpoint
    }
    catch {

        $ControllerError =
            New-PrintSwitchControllerError `
                -Code "ENDPOINT_RESOLUTION_FAILED" `
                -Message $_.Exception.Message `
                -SourceComponent "PrinterEndpointResolver" `
                -ExceptionType $_.Exception.GetType().FullName

        Set-PrintSwitchControllerError `
            -ErrorObject $ControllerError

        return New-PrintSwitchControllerResult `
            -Operation "GetEndpoint" `
            -Success $false `
            -Classification "ENDPOINT_RESOLUTION_FAILED" `
            -ErrorObject $ControllerError
    }
}

# ============================================================
# 10. GET REACHABILITY
# ============================================================

function Get-PrintSwitchReachability {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$PrinterName,

        [int]$TimeoutMs = 1500
    )

    try {

        $EndpointResult =
            Get-PrintSwitchEndpoint `
                -PrinterName $PrinterName

        if (-not $EndpointResult.Success) {

            return New-PrintSwitchControllerResult `
                -Operation "GetReachability" `
                -Success $false `
                -Classification "ENDPOINT_NOT_AVAILABLE" `
                -ErrorObject $EndpointResult.Error
        }

        $Reachability =
            Test-PrintSwitchEndpointReachability `
                -Endpoint $EndpointResult.Data `
                -TimeoutMs $TimeoutMs

        if ($null -eq $Reachability) {

            return New-PrintSwitchControllerResult `
                -Operation "GetReachability" `
                -Success $false `
                -Classification "REACHABILITY_UNKNOWN"
        }

        $script:ControllerState.CurrentReachability =
            $Reachability

        $script:ControllerState.LastUpdatedAt =
            Get-Date

        Clear-PrintSwitchControllerError

        return New-PrintSwitchControllerResult `
            -Operation "GetReachability" `
            -Success $true `
            -Classification "REACHABILITY_AVAILABLE" `
            -Data $Reachability
    }
    catch {

        $ControllerError =
            New-PrintSwitchControllerError `
                -Code "REACHABILITY_FAILED" `
                -Message $_.Exception.Message `
                -SourceComponent "PrinterEndpointReachability" `
                -ExceptionType $_.Exception.GetType().FullName

        Set-PrintSwitchControllerError `
            -ErrorObject $ControllerError

        return New-PrintSwitchControllerResult `
            -Operation "GetReachability" `
            -Success $false `
            -Classification "REACHABILITY_FAILED" `
            -ErrorObject $ControllerError
    }
}

# ============================================================
# 11. ENABLE RECOVERY
# ============================================================

function Enable-PrintSwitchRecovery {

    [CmdletBinding()]
    param ()

    $script:ControllerState.RecoveryEnabled =
        $true

    $script:ControllerState.LastUpdatedAt =
        Get-Date

    return New-PrintSwitchControllerResult `
        -Operation "EnableRecovery" `
        -Success $true `
        -Classification "RECOVERY_ENABLED" `
        -Data (
            [PSCustomObject]@{
                RecoveryEnabled = $true
            }
        )
}

# ============================================================
# 12. DISABLE RECOVERY
# ============================================================

function Disable-PrintSwitchRecovery {

    [CmdletBinding()]
    param ()

    $script:ControllerState.RecoveryEnabled =
        $false

    $script:ControllerState.LastUpdatedAt =
        Get-Date

    return New-PrintSwitchControllerResult `
        -Operation "DisableRecovery" `
        -Success $true `
        -Classification "RECOVERY_DISABLED" `
        -Data (
            [PSCustomObject]@{
                RecoveryEnabled = $false
            }
        )
}

# ============================================================
# 13. LAST DECISION
# ============================================================

function Get-PrintSwitchLastDecision {

    [CmdletBinding()]
    param ()

    return New-PrintSwitchControllerResult `
        -Operation "GetLastDecision" `
        -Success $true `
        -Classification $(
            if ($null -eq $script:ControllerState.LastDecision) {
                "NO_DECISION_AVAILABLE"
            }
            else {
                "DECISION_AVAILABLE"
            }
        ) `
        -Data $script:ControllerState.LastDecision
}

# ============================================================
# 14. LAST RECOVERY
# ============================================================

function Get-PrintSwitchLastRecovery {

    [CmdletBinding()]
    param ()

    return New-PrintSwitchControllerResult `
        -Operation "GetLastRecovery" `
        -Success $true `
        -Classification $(
            if ($null -eq $script:ControllerState.LastRecovery) {
                "NO_RECOVERY_AVAILABLE"
            }
            else {
                "RECOVERY_AVAILABLE"
            }
        ) `
        -Data $script:ControllerState.LastRecovery
}

# ============================================================
# 15. LAST ERROR
# ============================================================

function Get-PrintSwitchLastError {

    [CmdletBinding()]
    param ()

    return New-PrintSwitchControllerResult `
        -Operation "GetLastError" `
        -Success $true `
        -Classification $(
            if ($null -eq $script:ControllerState.LastError) {
                "NO_ERROR"
            }
            else {
                "ERROR_AVAILABLE"
            }
        ) `
        -Data $script:ControllerState.LastError
}

# ============================================================
# 16. LOGS
# ============================================================

function Get-PrintSwitchLogs {

    [CmdletBinding()]
    param (
        [int]$MaxFiles = 10
    )

    try {

        $Files =
            @(
                if (Test-Path $script:LogsPath) {

                    Get-ChildItem `
                        $script:LogsPath `
                        -File `
                        -ErrorAction SilentlyContinue |
                    Sort-Object `
                        LastWriteTime `
                        -Descending |
                    Select-Object `
                        -First $MaxFiles `
                        Name,
                        FullName,
                        Length,
                        LastWriteTime
                }
            )

        $Data =
            [PSCustomObject]@{

                LogDirectory =
                    $script:LogsPath

                Exists =
                    Test-Path $script:LogsPath

                Files =
                    $Files
            }

        return New-PrintSwitchControllerResult `
            -Operation "GetLogs" `
            -Success $true `
            -Classification "LOGS_AVAILABLE" `
            -Data $Data
    }
    catch {

        $ControllerError =
            New-PrintSwitchControllerError `
                -Code "LOG_QUERY_FAILED" `
                -Message $_.Exception.Message `
                -SourceComponent "Logger" `
                -ExceptionType $_.Exception.GetType().FullName

        Set-PrintSwitchControllerError `
            -ErrorObject $ControllerError

        return New-PrintSwitchControllerResult `
            -Operation "GetLogs" `
            -Success $false `
            -Classification "LOG_QUERY_FAILED" `
            -ErrorObject $ControllerError
    }
}

# ============================================================
# 17. START MONITORING - P7-A3 CONTRACT STUB
# ============================================================

function Start-PrintSwitchMonitoring {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$PrinterName
    )

    try {

        # --------------------------------------------------------
        # Detectar worker ya activo.
        # --------------------------------------------------------

        if ($null -ne $script:ControllerState.MonitoringJobId) {

            $ExistingJob =
                Get-Job `
                    -Id $script:ControllerState.MonitoringJobId `
                    -ErrorAction SilentlyContinue

            if (
                $null -ne $ExistingJob -and
                $ExistingJob.State -eq "Running"
            ) {

                return New-PrintSwitchControllerResult `
                    -Operation "StartMonitoring" `
                    -Success $true `
                    -Classification "ALREADY_RUNNING" `
                    -Data (
                        [PSCustomObject]@{

                            PrinterName =
                                $script:ControllerState.SelectedPrinter

                            JobId =
                                $ExistingJob.Id

                            JobState =
                                [string]$ExistingJob.State

                            MonitoringState =
                                "WATCHING"
                        }
                    )
            }

            if ($null -ne $ExistingJob) {

                Remove-Job `
                    -Id $ExistingJob.Id `
                    -Force `
                    -ErrorAction SilentlyContinue
            }

            $script:ControllerState.MonitoringJob =
                $null

            $script:ControllerState.MonitoringJobId =
                $null
        }

        # --------------------------------------------------------
        # Validar cola mediante la frontera del Controller.
        # --------------------------------------------------------

        $QueueResult =
            Get-PrintSwitchQueueContext `
                -PrinterName $PrinterName

        if (-not $QueueResult.Success) {

            return New-PrintSwitchControllerResult `
                -Operation "StartMonitoring" `
                -Success $false `
                -Classification "PRINTER_NOT_AVAILABLE" `
                -ErrorObject $QueueResult.Error
        }

        if (-not (Test-Path $script:QueueWatcherPath)) {

            throw "QueueWatcher.ps1 no encontrado."
        }

        $WatcherPath =
            $script:QueueWatcherPath

        # Reset monitoring event consumption for new session.
        $script:ControllerState.ProcessedMonitoringEventIds =
            @{}

        $script:ControllerState.LastPrintJob =
            $null

        $script:ControllerState.LastQueuePolicyResult =
            $null

        $script:ControllerState.LastRecoveryEvaluation =
            $null

        $script:ControllerState.LastTargetNetworkContext =
            $null

        $script:ControllerState.LastRecoveryAuthorization =
            $null

        $script:ControllerState.LastRecoveryExecution =
            $null

        $script:ControllerState.LastDecision =
            $null

        $script:ControllerState.LastRecovery =
            $null
        $Job =
        $MonitoringEventDirectory =
            Join-Path `
                $script:RootPath `
                "runtime\events"

        if (-not (Test-Path $MonitoringEventDirectory)) {

            New-Item `
                -ItemType Directory `
                -Path $MonitoringEventDirectory `
                -Force |
                Out-Null
        }

        $MonitoringEventPath =
            Join-Path `
                $MonitoringEventDirectory `
                (
                    "PrintSwitch-Events-{0}-{1}.jsonl" -f `
                        (Get-Date -Format "yyyyMMdd-HHmmss"),
                        ([guid]::NewGuid().ToString("N").Substring(0,8))
                )

        $script:ControllerState.MonitoringEventPath =
            $MonitoringEventPath

        $Job =
            Start-Job `
                -Name (
                    "PrintSwitch-Monitor-{0}-{1}" -f `
                        (Get-Date -Format "yyyyMMddHHmmss"),
                        ([guid]::NewGuid().ToString("N").Substring(0,8))
                ) `
                -ScriptBlock {

                    param (
                        [string]$QueueWatcherPath,
                        [string]$SelectedPrinter,
                        [string]$ApplicationEventPath
                    )

                    & $QueueWatcherPath `
                        -PrinterName $SelectedPrinter `
                        -EventPath $ApplicationEventPath

                } `
                -ArgumentList `
                    $WatcherPath,
                    $PrinterName,
                    $MonitoringEventPath

        if ($null -eq $Job) {

            throw "Start-Job no devolvio un worker."
        }

        Start-Sleep `
            -Milliseconds 750

        $Job =
            Get-Job `
                -Id $Job.Id `
                -ErrorAction SilentlyContinue

        if ($null -eq $Job) {

            throw "El worker desaparecio durante inicializacion."
        }

        if ($Job.State -ne "Running") {

            $StartupOutput =
                @(
                    Receive-Job `
                        -Id $Job.Id `
                        -Keep `
                        -ErrorAction SilentlyContinue
                )

            $StartupState =
                [string]$Job.State

            Remove-Job `
                -Id $Job.Id `
                -Force `
                -ErrorAction SilentlyContinue

            throw (
                "QueueWatcher no quedo residente. State={0}. Output={1}" -f `
                    $StartupState,
                    ($StartupOutput -join " | ")
            )
        }

        $script:ControllerState.SelectedPrinter =
            $PrinterName

        $script:ControllerState.MonitoringJob =
            $Job

        $script:ControllerState.MonitoringJobId =
            $Job.Id

        $script:ControllerState.MonitoringStartedAt =
            Get-Date

        $script:ControllerState.MonitoringStoppedAt =
            $null

        $script:ControllerState.MonitoringState =
            "WATCHING"

        $script:ControllerState.LastUpdatedAt =
            Get-Date

        Clear-PrintSwitchControllerError

        return New-PrintSwitchControllerResult `
            -Operation "StartMonitoring" `
            -Success $true `
            -Classification "MONITORING_STARTED" `
            -Data (
                [PSCustomObject]@{

                    PrinterName =
                        $PrinterName

                    JobId =
                        $Job.Id

                    JobName =
                        $Job.Name

                    JobState =
                        [string]$Job.State

                    MonitoringState =
                        $script:ControllerState.MonitoringState

                    RecoveryEnabled =

                        [bool]$script:ControllerState.RecoveryEnabled
                    StartedAt =
                        $script:ControllerState.MonitoringStartedAt
                }
            )
    }
    catch {

        $ControllerError =
            New-PrintSwitchControllerError `
                -Code "MONITORING_START_FAILED" `
                -Message $_.Exception.Message `
                -SourceComponent "QueueWatcher" `
                -ExceptionType $_.Exception.GetType().FullName

        Set-PrintSwitchControllerError `
            -ErrorObject $ControllerError

        $script:ControllerState.MonitoringState =
            "FAULTED"

        $script:ControllerState.LastUpdatedAt =
            Get-Date

        return New-PrintSwitchControllerResult `
            -Operation "StartMonitoring" `
            -Success $false `
            -Classification "START_FAILED" `
            -ErrorObject $ControllerError
    }
}

# ============================================================
# 18. STOP MONITORING - P7-A3 CONTRACT STUB
# ============================================================

function Stop-PrintSwitchMonitoring {

    [CmdletBinding()]
    param ()

    try {

        $JobId =
            $script:ControllerState.MonitoringJobId

        if ($null -eq $JobId) {

            $script:ControllerState.MonitoringJob =
                $null

            $script:ControllerState.MonitoringState =
                "STOPPED"

            $script:ControllerState.MonitoringStoppedAt =
                Get-Date

            $script:ControllerState.LastUpdatedAt =
                Get-Date

            return New-PrintSwitchControllerResult `
                -Operation "StopMonitoring" `
                -Success $true `
                -Classification "ALREADY_STOPPED"
        }

        $Job =
            Get-Job `
                -Id $JobId `
                -ErrorAction SilentlyContinue

        $PreviousPrinter =
            $script:ControllerState.SelectedPrinter

        $PreviousState =
            if ($null -ne $Job) {
                [string]$Job.State
            }
            else {
                "NOT_FOUND"
            }

        if ($null -ne $Job) {

            if (
                $Job.State -eq "Running" -or
                $Job.State -eq "Blocked"
            ) {

                Stop-Job `
                    -Id $Job.Id `
                    -ErrorAction Stop
            }

            $Job =
                Get-Job `
                    -Id $JobId `
                    -ErrorAction SilentlyContinue

            $FinalState =
                if ($null -ne $Job) {
                    [string]$Job.State
                }
                else {
                    "NOT_FOUND"
                }

            Remove-Job `
                -Id $JobId `
                -Force `
                -ErrorAction SilentlyContinue
        }
        else {

            $FinalState =
                "NOT_FOUND"
        }

        $script:ControllerState.MonitoringJob =
            $null

        $script:ControllerState.MonitoringJobId =
            $null

        $script:ControllerState.MonitoringState =
            "STOPPED"

        $script:ControllerState.MonitoringStoppedAt =
            Get-Date

        $script:ControllerState.LastUpdatedAt =
            Get-Date

        Clear-PrintSwitchControllerError

        return New-PrintSwitchControllerResult `
            -Operation "StopMonitoring" `
            -Success $true `
            -Classification "MONITORING_STOPPED" `
            -Data (
                [PSCustomObject]@{

                    PrinterName =
                        $PreviousPrinter

                    PreviousJobId =
                        $JobId

                    PreviousJobState =
                        $PreviousState

                    FinalJobState =
                        $FinalState

                    MonitoringState =
                        $script:ControllerState.MonitoringState

                    StoppedAt =
                        $script:ControllerState.MonitoringStoppedAt
                }
            )
    }
    catch {

        $ControllerError =
            New-PrintSwitchControllerError `
                -Code "MONITORING_STOP_FAILED" `
                -Message $_.Exception.Message `
                -SourceComponent "QueueWatcher" `
                -ExceptionType $_.Exception.GetType().FullName

        Set-PrintSwitchControllerError `
            -ErrorObject $ControllerError

        $script:ControllerState.MonitoringState =
            "FAULTED"

        $script:ControllerState.LastUpdatedAt =
            Get-Date

        return New-PrintSwitchControllerResult `
            -Operation "StopMonitoring" `
            -Success $false `
            -Classification "STOP_FAILED" `
            -ErrorObject $ControllerError
    }
}

# ============================================================
# 19. CONTROLLER INFO
# ============================================================

function Get-PrintSwitchControllerInfo {

    [CmdletBinding()]
    param ()

    return [PSCustomObject]@{

        Component =
            "ApplicationController"

        Version =
            $script:ControllerVersion

        Stage =
            "P7-A4"

        MonitoringImplemented =
            $true

        MonitoringModel =
            "BACKGROUND_JOB"

        NetworkMutationDirect =
            $false

        Baseline =
            "core-p6-validated"

        LoadedAt =
            Get-Date
    }
}

function Invoke-PrintSwitchRecoveryEvaluation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$QueuePolicyResult,

        [Parameter(Mandatory = $true)]
        [string]$PrinterName,

        [Parameter(Mandatory = $false)]
        [object]$JobId
    )

    $result = [ordered]@{
        SchemaVersion           = 1
        EvaluationRequested     = $false
        EvaluationPerformed     = $false
        PrinterName             = $PrinterName
        JobId                   = $JobId
        QueuePolicyDecision     = $null
        EndpointResolved        = $false
        Endpoint                = $null
        ReachabilityState       = "NOT_EVALUATED"
        RecoveryRelevant        = $false
        ReasonCode              = "QUEUE_POLICY_DID_NOT_REQUEST_EVALUATION"
        Reason                  = "QueuePolicy did not request recovery evaluation."
        SourceQueuePolicyResult = $QueuePolicyResult
    }

    try {

        if ($null -eq $QueuePolicyResult) {

            $result.ReasonCode =
                "INVALID_QUEUE_POLICY_RESULT"

            $result.Reason =
                "QueuePolicyResult is null."

            return [PSCustomObject]$result
        }

        $decisionProperty =
            $QueuePolicyResult.PSObject.Properties["Decision"]

        $allowProperty =
            $QueuePolicyResult.PSObject.Properties["AllowRecoveryEvaluation"]

        if (
            $null -eq $decisionProperty -or
            $null -eq $allowProperty
        ) {

            $result.ReasonCode =
                "INVALID_QUEUE_POLICY_RESULT"

            $result.Reason =
                "QueuePolicyResult does not expose the required evaluation contract."

            return [PSCustomObject]$result
        }

        $result.QueuePolicyDecision =
            [string]$QueuePolicyResult.Decision

        if (
            $result.QueuePolicyDecision -ne "EVALUATE_RECOVERY" -or
            -not [bool]$QueuePolicyResult.AllowRecoveryEvaluation
        ) {

            return [PSCustomObject]$result
        }

        $result.EvaluationRequested =
            $true

        $result.EvaluationPerformed =
            $true

        $reachability =
            Get-PrintSwitchReachability `
                -PrinterName $PrinterName

        if (
            $null -eq $reachability -or
            -not $reachability.Success -or
            $null -eq $reachability.Data
        ) {

            $result.ReachabilityState =
                "UNKNOWN"

            $result.ReasonCode =
                "CONNECTIVITY_EVALUATION_FAILED"

            $result.Reason =
                "Read-only reachability evaluation did not return a valid result."

            return [PSCustomObject]$result
        }

        $data =
            $reachability.Data

        # --------------------------------------------------------
        # REAL CONTRACT:
        # Data is PrinterEndpointReachability v0.3 directly.
        #
        # Expected fields include:
        # QueueName
        # TransportType
        # ReachabilityStrategy
        # ConfiguredDestination
        # ResolvedDestination
        # TcpPort
        # Reachable
        # ReachabilityState
        # ProbeResult
        # --------------------------------------------------------

        $stateProperty =
            $data.PSObject.Properties["ReachabilityState"]

        $reachableProperty =
            $data.PSObject.Properties["Reachable"]

        $resolvedProperty =
            $data.PSObject.Properties["ResolvedDestination"]

        $configuredProperty =
            $data.PSObject.Properties["ConfiguredDestination"]

        if ($null -eq $stateProperty) {

            $result.ReachabilityState =
                "UNKNOWN"

            $result.ReasonCode =
                "REACHABILITY_UNKNOWN_FAIL_CLOSED"

            $result.Reason =
                "Reachability result does not expose ReachabilityState."

            return [PSCustomObject]$result
        }

        $realState =
            [string]$data.ReachabilityState

        if ([string]::IsNullOrWhiteSpace($realState)) {

            $result.ReachabilityState =
                "UNKNOWN"

            $result.ReasonCode =
                "REACHABILITY_UNKNOWN_FAIL_CLOSED"

            $result.Reason =
                "ReachabilityState is empty."

            return [PSCustomObject]$result
        }

        $resolvedDestination =
            $null

        if (
            $null -ne $resolvedProperty -and
            -not [string]::IsNullOrWhiteSpace(
                [string]$data.ResolvedDestination
            )
        ) {

            $resolvedDestination =
                [string]$data.ResolvedDestination
        }
        elseif (
            $null -ne $configuredProperty -and
            -not [string]::IsNullOrWhiteSpace(
                [string]$data.ConfiguredDestination
            )
        ) {

            $resolvedDestination =
                [string]$data.ConfiguredDestination
        }

        if ([string]::IsNullOrWhiteSpace($resolvedDestination)) {

            $result.ReachabilityState =
                "UNKNOWN"

            $result.ReasonCode =
                "ENDPOINT_UNRESOLVED"

            $result.Reason =
                "No operational printer destination could be resolved."

            return [PSCustomObject]$result
        }

        $result.EndpointResolved =
            $true

        $result.Endpoint =
            [PSCustomObject]@{
                QueueName =
                    $(if ($data.PSObject.Properties["QueueName"]) {
                        $data.QueueName
                    }
                    else {
                        $PrinterName
                    })

                TransportType =
                    $(if ($data.PSObject.Properties["TransportType"]) {
                        $data.TransportType
                    }
                    else {
                        $null
                    })

                ReachabilityStrategy =
                    $(if ($data.PSObject.Properties["ReachabilityStrategy"]) {
                        $data.ReachabilityStrategy
                    }
                    else {
                        $null
                    })

                ConfiguredDestination =
                    $(if ($data.PSObject.Properties["ConfiguredDestination"]) {
                        $data.ConfiguredDestination
                    }
                    else {
                        $null
                    })

                ResolvedDestination =
                    $resolvedDestination

                TcpPort =
                    $(if ($data.PSObject.Properties["TcpPort"]) {
                        $data.TcpPort
                    }
                    else {
                        $null
                    })

                ProbeResult =
                    $(if ($data.PSObject.Properties["ProbeResult"]) {
                        $data.ProbeResult
                    }
                    else {
                        $null
                    })
            }

        $result.ReachabilityState =
            $realState

        switch ($realState) {

            "REACHABLE" {

                $result.RecoveryRelevant =
                    $false

                $result.ReasonCode =
                    "ENDPOINT_REACHABLE_NO_CONNECTIVITY_RECOVERY"

                $result.Reason =
                    "Printer endpoint is reachable; connectivity recovery is not relevant."

                return [PSCustomObject]$result
            }

            "UNREACHABLE" {

                if (
                    $null -eq $reachableProperty -or
                    [bool]$data.Reachable
                ) {

                    $result.ReachabilityState =
                        "UNKNOWN"

                    $result.RecoveryRelevant =
                        $false

                    $result.ReasonCode =
                        "REACHABILITY_CONTRACT_INCONSISTENT"

                    $result.Reason =
                        "Reachability contract is internally inconsistent."

                    return [PSCustomObject]$result
                }

                $result.RecoveryRelevant =
                    $true

                $result.ReasonCode =
                    "ENDPOINT_UNREACHABLE_RECOVERY_RELEVANT"

                $result.Reason =
                    "Printer endpoint is unreachable; connectivity recovery remains relevant."

                return [PSCustomObject]$result
            }

            default {

                $result.ReachabilityState =
                    "UNKNOWN"

                $result.RecoveryRelevant =
                    $false

                $result.ReasonCode =
                    "REACHABILITY_UNKNOWN_FAIL_CLOSED"

                $result.Reason =
                    "Printer endpoint reachability is not sufficiently determined."

                return [PSCustomObject]$result
            }
        }
    }
    catch {

        $result.EvaluationPerformed =
            $false

        $result.EndpointResolved =
            $false

        $result.Endpoint =
            $null

        $result.ReachabilityState =
            "UNKNOWN"

        $result.RecoveryRelevant =
            $false

        $result.ReasonCode =
            "CONNECTIVITY_EVALUATION_FAILED"

        $result.Reason =
            $_.Exception.Message

        return [PSCustomObject]$result
    }
}
