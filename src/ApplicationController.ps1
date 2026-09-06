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

$script:ControllerVersion = "0.1"

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

        RecoveryEnabled =
            $false

        SelectedPrinter =
            $null

        CurrentQueueContext =
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

                RecoveryEnabled =
                    $script:ControllerState.RecoveryEnabled

                SelectedPrinter =
                    $script:ControllerState.SelectedPrinter

                CurrentQueueContext =
                    $script:ControllerState.CurrentQueueContext

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
        [string]$PrinterName
    )

    return New-PrintSwitchControllerResult `
        -Operation "StartMonitoring" `
        -Success $false `
        -Classification "MONITORING_NOT_IMPLEMENTED_P7_A3" `
        -Data (
            [PSCustomObject]@{
                RequestedPrinter = $PrinterName
                PlannedStage     = "P7-A4"
            }
        )
}

# ============================================================
# 18. STOP MONITORING - P7-A3 CONTRACT STUB
# ============================================================

function Stop-PrintSwitchMonitoring {

    [CmdletBinding()]
    param ()

    return New-PrintSwitchControllerResult `
        -Operation "StopMonitoring" `
        -Success $false `
        -Classification "MONITORING_NOT_IMPLEMENTED_P7_A3" `
        -Data (
            [PSCustomObject]@{
                PlannedStage = "P7-A4"
            }
        )
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
            "P7-A3"

        MonitoringImplemented =
            $false

        NetworkMutationDirect =
            $false

        Baseline =
            "core-p6-validated"

        LoadedAt =
            Get-Date
    }
}