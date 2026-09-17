Set-StrictMode -Version Latest

function Get-PrintSwitchObjectPropertyValue {
    param(
        [AllowNull()]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property) {
        return $null
    }

    return $Property.Value
}

function New-PrintSwitchRecoveryExecutionResult {
    param(
        [bool]$ExecutionRequested,
        [bool]$ExecutionAuthorized,
        [bool]$ExecutionPerformed,
        [bool]$SwitchAuthorized,
        [bool]$SwitchExecuted,
        [bool]$NetworkSwitchVerified,
        [bool]$RecoveryValidationConfirmed,
        [bool]$RecoverySucceeded,
        [AllowNull()][string]$PrinterName,
        [AllowNull()][object]$JobId,
        [AllowNull()][string]$CorrelationId,
        [AllowNull()][string]$CurrentSSID,
        [AllowNull()][string]$TargetSSID,
        [AllowNull()][string]$AuthorizationReasonCode,
        [Parameter(Mandatory)][string]$ReasonCode,
        [Parameter(Mandatory)][string]$Reason,
        [AllowNull()][object]$AuthorizationSnapshot
    )

    [PSCustomObject]@{
        Component                   = "RecoveryExecutionAdapter"
        SchemaVersion               = 1
        ExecutionRequested          = $ExecutionRequested
        ExecutionAuthorized         = $ExecutionAuthorized
        ExecutionPerformed          = $ExecutionPerformed
        SwitchAuthorized            = $SwitchAuthorized
        SwitchExecuted              = $SwitchExecuted
        NetworkSwitchVerified       = $NetworkSwitchVerified
        RecoveryValidationConfirmed = $RecoveryValidationConfirmed
        RecoverySucceeded           = $RecoverySucceeded
        PrinterName                 = $PrinterName
        JobId                       = $JobId
        CorrelationId               = $CorrelationId
        CurrentSSID                 = $CurrentSSID
        TargetSSID                  = $TargetSSID
        AuthorizationReasonCode     = $AuthorizationReasonCode
        ReasonCode                  = $ReasonCode
        Reason                      = $Reason
        AuthorizationSnapshot       = $AuthorizationSnapshot
    }
}

function Get-PrintSwitchRecoveryExecutionRequest {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$RecoveryAuthorization,

        [AllowNull()]
        [string]$ExpectedPrinterName,

        [AllowNull()]
        [string]$ExpectedTargetSSID,

        [AllowNull()]
        [object]$ExpectedJobId,

        [AllowNull()]
        [string]$CorrelationId
    )

    $DefaultResult = @{
        ExecutionRequested          = $true
        ExecutionAuthorized         = $false
        ExecutionPerformed          = $false
        SwitchAuthorized            = $false
        SwitchExecuted              = $false
        NetworkSwitchVerified       = $false
        RecoveryValidationConfirmed = $false
        RecoverySucceeded           = $false
        PrinterName                 = $ExpectedPrinterName
        JobId                       = $ExpectedJobId
        CorrelationId               = $CorrelationId
        CurrentSSID                 = $null
        TargetSSID                  = $ExpectedTargetSSID
        AuthorizationReasonCode     = $null
        AuthorizationSnapshot       = $RecoveryAuthorization
    }

    if ($null -eq $RecoveryAuthorization) {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "AUTHORIZATION_MISSING" `
            -Reason "Recovery authorization is missing."
    }

    $SchemaVersion = Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "SchemaVersion"
    $Decision = [string](Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "AuthorizationDecision")
    $Authorized = Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "Authorized"
    $RecoveryRelevant = Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "RecoveryRelevant"
    $RecoveryEnabled = Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "RecoveryEnabled"
    $EndpointResolved = Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "EndpointResolved"
    $AuthPrinterName = [string](Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "PrinterName")
    $AuthCurrentSSID = [string](Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "CurrentSSID")
    $AuthTargetSSID = [string](Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "TargetSSID")
    $AuthReasonCode = [string](Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "ReasonCode")

    $DefaultResult.PrinterName = $AuthPrinterName
    $DefaultResult.CurrentSSID = $AuthCurrentSSID
    $DefaultResult.TargetSSID = $AuthTargetSSID
    $DefaultResult.AuthorizationReasonCode = $AuthReasonCode
    # Harden the AUTHORIZED contract before any execution boundary can be opened.
    $AuthorizationRequested = Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "AuthorizationRequested"
    $AuthorizationPerformed = Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "AuthorizationPerformed"

    $RequiredBooleanFields = @(
        [PSCustomObject]@{ Name = "AuthorizationRequested"; Value = $AuthorizationRequested },
        [PSCustomObject]@{ Name = "AuthorizationPerformed"; Value = $AuthorizationPerformed },
        [PSCustomObject]@{ Name = "Authorized"; Value = $Authorized },
        [PSCustomObject]@{ Name = "RecoveryRelevant"; Value = $RecoveryRelevant },
        [PSCustomObject]@{ Name = "RecoveryEnabled"; Value = $RecoveryEnabled },
        [PSCustomObject]@{ Name = "EndpointResolved"; Value = $EndpointResolved }
    )

    foreach ($Field in $RequiredBooleanFields) {
        if ($null -eq $Field.Value -or $Field.Value -isnot [bool]) {
            return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
                -ReasonCode "AUTHORIZATION_CONTRACT_INVALID" `
                -Reason ("Recovery authorization field '{0}' is missing or is not Boolean." -f $Field.Name)
        }
    }

    if ($AuthorizationRequested -ne $true -or $AuthorizationPerformed -ne $true) {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "AUTHORIZATION_CONTRACT_INVALID" `
            -Reason "Recovery authorization was not both requested and performed."
    }

    if ($Decision -eq "AUTHORIZED") {
        if ([string]::IsNullOrWhiteSpace($AuthReasonCode) -or $AuthReasonCode -ne "RECOVERY_AUTHORIZED") {
            return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
                -ReasonCode "AUTHORIZATION_CONTRACT_INVALID" `
                -Reason "AUTHORIZED decision has an invalid or contradictory authorization reason code."
        }

        if ([string]::IsNullOrWhiteSpace($ExpectedPrinterName)) {
            return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
                -ReasonCode "EXPECTED_PRINTER_CONTEXT_MISSING" `
                -Reason "Current Controller printer context is missing."
        }

        if ([string]::IsNullOrWhiteSpace($ExpectedTargetSSID)) {
            return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
                -ReasonCode "EXPECTED_TARGET_CONTEXT_MISSING" `
                -Reason "Current Controller target SSID context is missing."
        }

        if ($null -eq $ExpectedJobId -or [string]::IsNullOrWhiteSpace([string]$ExpectedJobId)) {
            return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
                -ReasonCode "EXPECTED_JOB_CONTEXT_MISSING" `
                -Reason "Current Controller job context is missing."
        }

        if ([string]::IsNullOrWhiteSpace($CorrelationId)) {
            return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
                -ReasonCode "CORRELATION_ID_MISSING" `
                -Reason "Execution correlation ID is missing."
        }
    }

    if ($null -eq $SchemaVersion -or [string]$SchemaVersion -ne "1") {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "AUTHORIZATION_CONTRACT_INVALID" `
            -Reason "Recovery authorization schema is missing or unsupported."
    }

    if ($Decision -ne "AUTHORIZED") {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "AUTHORIZATION_DENIED" `
            -Reason "Recovery authorization decision is not AUTHORIZED."
    }

    if ($Authorized -ne $true) {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "AUTHORIZED_FLAG_FALSE" `
            -Reason "Recovery authorization flag is not true."
    }

    if ($RecoveryRelevant -ne $true) {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "RECOVERY_NOT_RELEVANT" `
            -Reason "Recovery is not relevant for the current context."
    }

    if ($RecoveryEnabled -ne $true) {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "RECOVERY_DISABLED" `
            -Reason "Recovery execution gate is disabled."
    }

    if ($EndpointResolved -ne $true) {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "ENDPOINT_UNRESOLVED" `
            -Reason "Printer endpoint is unresolved."
    }

    if ([string]::IsNullOrWhiteSpace($AuthPrinterName)) {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "PRINTER_NAME_MISSING" `
            -Reason "Authorized printer name is missing."
    }

    if ([string]::IsNullOrWhiteSpace($AuthCurrentSSID)) {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "CURRENT_SSID_MISSING" `
            -Reason "Authorized current SSID is missing."
    }

    if ([string]::IsNullOrWhiteSpace($AuthTargetSSID)) {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "TARGET_SSID_MISSING" `
            -Reason "Authorized target SSID is missing."
    }

    if ($AuthCurrentSSID -eq $AuthTargetSSID) {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "ALREADY_ON_TARGET_SSID" `
            -Reason "Current SSID already matches the authorized target SSID."
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedPrinterName) -and $AuthPrinterName -ne $ExpectedPrinterName) {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "PRINTER_CONTEXT_MISMATCH" `
            -Reason "Authorization printer does not match current Controller context."
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedTargetSSID) -and $AuthTargetSSID -ne $ExpectedTargetSSID) {
        return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
            -ReasonCode "TARGET_SSID_CONTEXT_MISMATCH" `
            -Reason "Authorization target SSID does not match current Controller context."
    }

    $SourceEvaluation = Get-PrintSwitchObjectPropertyValue $RecoveryAuthorization "SourceRecoveryEvaluation"
    $SourceJobId = Get-PrintSwitchObjectPropertyValue $SourceEvaluation "JobId"

    if ($null -ne $ExpectedJobId) {
        if ($null -eq $SourceJobId -or [string]$SourceJobId -ne [string]$ExpectedJobId) {
            return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
                -ReasonCode "JOB_CONTEXT_MISMATCH" `
                -Reason "Authorization job context does not match current Controller context."
        }
    }

    $DefaultResult.ExecutionAuthorized = $true
    $DefaultResult.SwitchAuthorized = $true

    return New-PrintSwitchRecoveryExecutionResult @DefaultResult `
        -ReasonCode "EXECUTION_BOUNDARY_DISCONNECTED" `
        -Reason "Authorization is valid, but downstream recovery execution is intentionally disconnected."
}

function Test-PrintSwitchRecoveryExecutionResult {
    param(
        [AllowNull()]
        [object]$Result
    )

    if ($null -eq $Result) {
        return $false
    }

    $Required = @(
        "Component",
        "SchemaVersion",
        "ExecutionRequested",
        "ExecutionAuthorized",
        "ExecutionPerformed",
        "SwitchAuthorized",
        "SwitchExecuted",
        "NetworkSwitchVerified",
        "RecoveryValidationConfirmed",
        "RecoverySucceeded",
        "PrinterName",
        "JobId",
        "CorrelationId",
        "CurrentSSID",
        "TargetSSID",
        "AuthorizationReasonCode",
        "ReasonCode",
        "Reason",
        "AuthorizationSnapshot"
    )

    $Names = @(
        $Result.PSObject.Properties |
        ForEach-Object { $_.Name }
    )

    foreach ($Name in $Required) {
        if ($Names -notcontains $Name) {
            return $false
        }
    }

    if ([string](Get-PrintSwitchObjectPropertyValue $Result "Component") -ne "RecoveryExecutionAdapter") {
        return $false
    }

    if ([int](Get-PrintSwitchObjectPropertyValue $Result "SchemaVersion") -ne 1) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace([string](Get-PrintSwitchObjectPropertyValue $Result "ReasonCode"))) {
        return $false
    }

    if ((Get-PrintSwitchObjectPropertyValue $Result "ExecutionPerformed") -eq $true) {
        return $false
    }

    if ((Get-PrintSwitchObjectPropertyValue $Result "SwitchExecuted") -eq $true) {
        return $false
    }

    if ((Get-PrintSwitchObjectPropertyValue $Result "NetworkSwitchVerified") -eq $true) {
        return $false
    }

    if ((Get-PrintSwitchObjectPropertyValue $Result "RecoveryValidationConfirmed") -eq $true) {
        return $false
    }

    if ((Get-PrintSwitchObjectPropertyValue $Result "RecoverySucceeded") -eq $true) {
        return $false
    }

    return $true
}

# ============================================================
# I9-DRY - Authorized execution bridge to Orchestrator dry-run
# Physical execution is intentionally impossible here:
# PrintRecoveryOrchestrator is invoked WITHOUT -Execute.
# ============================================================
function Invoke-PrintSwitchRecoveryExecutionDryRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ExecutionRequest,

        [string]$OrchestratorPath = (
            Join-Path $PSScriptRoot "PrintRecoveryOrchestrator.ps1"
        )
    )

    $Result = [ordered]@{
        Component                  = "RecoveryExecutionAdapter"
        SchemaVersion              = 1
        DryRunInvoked              = $false
        DryRunCompleted            = $false
        ExecutionRequested         = $false
        ExecutionAuthorized        = $false
        SwitchAuthorized           = $false
        ExecutionPerformed         = $false
        SwitchExecuted             = $false
        NetworkSwitchVerified      = $false
        RecoverySucceeded          = $false
        PrinterName                = $null
        JobId                      = $null
        CorrelationId              = $null
        CurrentSSID                = $null
        TargetSSID                 = $null
        AuthorizationReasonCode    = $null
        OrchestratorExecutionMode  = $null
        OrchestratorSwitchDecision = $null
        ReasonCode                 = "DRY_RUN_REQUEST_INVALID"
        Reason                     = "Execution request is missing or invalid."
        OrchestratorResult         = $null
    }

    if ($null -eq $ExecutionRequest) {
        return [PSCustomObject]$Result
    }

    $RequestValid = $false

    try {
        $RequestValid = [bool](
            Test-PrintSwitchRecoveryExecutionResult -Result $ExecutionRequest
        )
    }
    catch {
        $RequestValid = $false
    }

    if (-not $RequestValid) {
        $Result.ReasonCode = "DRY_RUN_REQUEST_INVALID"
        $Result.Reason = "Execution request failed adapter contract validation."
        return [PSCustomObject]$Result
    }

    $Result.ExecutionRequested = [bool](
        Get-PrintSwitchObjectPropertyValue `
            $ExecutionRequest `
            "ExecutionRequested"
    )

    $Result.ExecutionAuthorized = [bool](
        Get-PrintSwitchObjectPropertyValue `
            $ExecutionRequest `
            "ExecutionAuthorized"
    )

    $Result.SwitchAuthorized = [bool](
        Get-PrintSwitchObjectPropertyValue `
            $ExecutionRequest `
            "SwitchAuthorized"
    )

    $Result.PrinterName = [string](
        Get-PrintSwitchObjectPropertyValue `
            $ExecutionRequest `
            "PrinterName"
    )

    $Result.JobId =
        Get-PrintSwitchObjectPropertyValue `
            $ExecutionRequest `
            "JobId"

    $Result.CorrelationId = [string](
        Get-PrintSwitchObjectPropertyValue `
            $ExecutionRequest `
            "CorrelationId"
    )

    $Result.CurrentSSID = [string](
        Get-PrintSwitchObjectPropertyValue `
            $ExecutionRequest `
            "CurrentSSID"
    )

    $Result.TargetSSID = [string](
        Get-PrintSwitchObjectPropertyValue `
            $ExecutionRequest `
            "TargetSSID"
    )

    $Result.AuthorizationReasonCode = [string](
        Get-PrintSwitchObjectPropertyValue `
            $ExecutionRequest `
            "AuthorizationReasonCode"
    )

    if (
        -not $Result.ExecutionRequested -or
        -not $Result.ExecutionAuthorized -or
        -not $Result.SwitchAuthorized
    ) {
        $Result.ReasonCode = "DRY_RUN_NOT_AUTHORIZED"
        $Result.Reason = "Execution request is not authorized for Orchestrator dry-run."
        return [PSCustomObject]$Result
    }

    if ([string]::IsNullOrWhiteSpace([string]$Result.PrinterName)) {
        $Result.ReasonCode = "DRY_RUN_PRINTER_MISSING"
        $Result.Reason = "PrinterName is required for Orchestrator dry-run."
        return [PSCustomObject]$Result
    }

    if ([string]::IsNullOrWhiteSpace([string]$Result.TargetSSID)) {
        $Result.ReasonCode = "DRY_RUN_TARGET_SSID_MISSING"
        $Result.Reason = "TargetSSID is required for Orchestrator dry-run."
        return [PSCustomObject]$Result
    }

    if (-not (Test-Path -LiteralPath $OrchestratorPath)) {
        $Result.ReasonCode = "ORCHESTRATOR_NOT_FOUND"
        $Result.Reason = "PrintRecoveryOrchestrator path was not found."
        return [PSCustomObject]$Result
    }

    try {
        # SAFETY INVARIANT: I9-DRY never passes -Execute.
        $RawOutput = @(
            & $OrchestratorPath `
                -PrinterName ([string]$Result.PrinterName) `
                -TargetSSID ([string]$Result.TargetSSID)
        )

        $Result.DryRunInvoked = $true
        $Candidate = $null

        foreach ($Item in $RawOutput) {
            if ($null -eq $Item) {
                continue
            }

            $HasExecutionMode =
                $null -ne $Item.PSObject.Properties["ExecutionMode"]

            $HasSwitchAuthorized =
                $null -ne $Item.PSObject.Properties["SwitchAuthorized"]

            $HasSwitchDecision =
                $null -ne $Item.PSObject.Properties["SwitchDecision"]

            if (
                $HasExecutionMode -or
                $HasSwitchAuthorized -or
                $HasSwitchDecision
            ) {
                $Candidate = $Item
            }
        }

        if ($null -eq $Candidate) {
            $Result.ReasonCode = "ORCHESTRATOR_DRY_RUN_NO_RESULT"
            $Result.Reason = "Orchestrator dry-run returned no recognizable result object."
            return [PSCustomObject]$Result
        }

        $Result.OrchestratorResult = $Candidate

        $Result.OrchestratorExecutionMode = [string](
            Get-PrintSwitchObjectPropertyValue `
                $Candidate `
                "ExecutionMode"
        )

        $Result.OrchestratorSwitchDecision = [string](
            Get-PrintSwitchObjectPropertyValue `
                $Candidate `
                "SwitchDecision"
        )

        $OrchestratorSwitchAuthorized =
            Get-PrintSwitchObjectPropertyValue `
                $Candidate `
                "SwitchAuthorized"

        $OrchestratorSwitchExecuted =
            Get-PrintSwitchObjectPropertyValue `
                $Candidate `
                "SwitchExecuted"

        $OrchestratorNetworkVerified =
            Get-PrintSwitchObjectPropertyValue `
                $Candidate `
                "NetworkSwitchVerified"

        $OrchestratorRecoverySucceeded =
            Get-PrintSwitchObjectPropertyValue `
                $Candidate `
                "RecoverySucceeded"

        if ($null -ne $OrchestratorSwitchAuthorized) {
            $Result.SwitchAuthorized = [bool]$OrchestratorSwitchAuthorized
        }

        if (
            [string]$Result.OrchestratorExecutionMode -eq "EXECUTE" -or
            ($null -ne $OrchestratorSwitchExecuted -and [bool]$OrchestratorSwitchExecuted) -or
            ($null -ne $OrchestratorNetworkVerified -and [bool]$OrchestratorNetworkVerified) -or
            ($null -ne $OrchestratorRecoverySucceeded -and [bool]$OrchestratorRecoverySucceeded)
        ) {
            $Result.ReasonCode = "ORCHESTRATOR_DRY_RUN_SAFETY_VIOLATION"
            $Result.Reason = "Dry-run invocation reported an execution-only state."
            return [PSCustomObject]$Result
        }

        $Result.DryRunCompleted = $true
        $Result.ExecutionPerformed = $false
        $Result.SwitchExecuted = $false
        $Result.NetworkSwitchVerified = $false
        $Result.RecoverySucceeded = $false
        $Result.ReasonCode = "ORCHESTRATOR_DRY_RUN_COMPLETED"
        $Result.Reason = "Authorized execution request reached PrintRecoveryOrchestrator in dry-run mode; physical execution remained disabled."

        return [PSCustomObject]$Result
    }
    catch {
        $Result.ReasonCode = "ORCHESTRATOR_DRY_RUN_FAILED"
        $Result.Reason = $_.Exception.Message
        return [PSCustomObject]$Result
    }
}
