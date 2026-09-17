# ============================================================
# PrintSwitch-Windows
# QueuePolicy.ps1
#
# Pure deterministic policy over QueueJobContext v1.
#
# RESPONSIBILITY
# Determine whether the normalized state of a print job
# justifies entering connectivity/recovery evaluation.
#
# IMPORTANT
# EVALUATE_RECOVERY does NOT authorize a network switch.
#
# This component MUST NOT:
# - mutate the print queue
# - change Wi-Fi
# - alter Ethernet
# - evaluate network reachability
# - resolve printer endpoints
# - execute recovery
# - contain vendor-specific logic
# ============================================================

Set-StrictMode -Version Latest

$script:QueuePolicySchemaVersion = 1

$script:QueuePolicyDecisionValues =
    @(
        "EVALUATE_RECOVERY",
        "WAIT",
        "NO_ACTION",
        "INSUFFICIENT_CONTEXT"
    )

$script:QueuePolicySummaryValues =
    @(
        "ACTIVE_OR_QUEUED",
        "PRINTING_UNCONFIRMED",
        "PROGRESSING",
        "PAUSED",
        "TRANSITIONING",
        "ERROR_ACTIVE",
        "STALLED_ERROR",
        "STALLED_NO_ERROR",
        "COMPLETE"
    )


function New-PrintSwitchQueuePolicyResult {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet(
            "EVALUATE_RECOVERY",
            "WAIT",
            "NO_ACTION",
            "INSUFFICIENT_CONTEXT"
        )]
        [string]$Decision,

        [Parameter(Mandatory)]
        [bool]$Actionable,

        [Parameter(Mandatory)]
        [bool]$AllowRecoveryEvaluation,

        [Parameter(Mandatory)]
        [string]$ReasonCode,

        [Parameter(Mandatory)]
        [string]$Reason,

        [AllowNull()]
        [object]$SourceContext
    )

    return [PSCustomObject]@{
        SchemaVersion =
            $script:QueuePolicySchemaVersion

        Decision =
            $Decision

        Actionable =
            $Actionable

        AllowRecoveryEvaluation =
            $AllowRecoveryEvaluation

        ReasonCode =
            $ReasonCode

        Reason =
            $Reason

        SourceContext =
            $SourceContext
    }
}


function Get-PrintSwitchQueuePolicy {

    [CmdletBinding()]
    param (
        [AllowNull()]
        [object]$QueueJobContext
    )

    # --------------------------------------------------------
    # FAIL-CLOSED INPUT VALIDATION
    # --------------------------------------------------------

    if ($null -eq $QueueJobContext) {

        return New-PrintSwitchQueuePolicyResult `
            -Decision "INSUFFICIENT_CONTEXT" `
            -Actionable $false `
            -AllowRecoveryEvaluation $false `
            -ReasonCode "QUEUE_CONTEXT_NULL" `
            -Reason "QueueJobContext is null." `
            -SourceContext $null
    }

    $SchemaProperty =
        $QueueJobContext.PSObject.Properties["SchemaVersion"]

    $SummaryProperty =
        $QueueJobContext.PSObject.Properties["SummaryClassification"]

    if (
        $null -eq $SchemaProperty -or
        $null -eq $SummaryProperty
    ) {

        return New-PrintSwitchQueuePolicyResult `
            -Decision "INSUFFICIENT_CONTEXT" `
            -Actionable $false `
            -AllowRecoveryEvaluation $false `
            -ReasonCode "QUEUE_CONTEXT_CONTRACT_INCOMPLETE" `
            -Reason "QueueJobContext does not expose required policy fields." `
            -SourceContext $QueueJobContext
    }

    if (
        $null -eq $SchemaProperty.Value -or
        [int]$SchemaProperty.Value -ne 1
    ) {

        return New-PrintSwitchQueuePolicyResult `
            -Decision "INSUFFICIENT_CONTEXT" `
            -Actionable $false `
            -AllowRecoveryEvaluation $false `
            -ReasonCode "QUEUE_CONTEXT_SCHEMA_UNSUPPORTED" `
            -Reason "QueueJobContext SchemaVersion is not supported." `
            -SourceContext $QueueJobContext
    }

    $Summary =
        if ($null -eq $SummaryProperty.Value) {
            $null
        }
        else {
            [string]$SummaryProperty.Value
        }

    if (
        [string]::IsNullOrWhiteSpace($Summary) -or
        $Summary -notin $script:QueuePolicySummaryValues
    ) {

        return New-PrintSwitchQueuePolicyResult `
            -Decision "INSUFFICIENT_CONTEXT" `
            -Actionable $false `
            -AllowRecoveryEvaluation $false `
            -ReasonCode "QUEUE_SUMMARY_OUT_OF_CONTRACT" `
            -Reason "SummaryClassification is missing or outside QueueJobContext v1." `
            -SourceContext $QueueJobContext
    }

    # --------------------------------------------------------
    # COMPLETE 9/9 POLICY
    # --------------------------------------------------------

    switch ($Summary) {

        "ACTIVE_OR_QUEUED" {

            return New-PrintSwitchQueuePolicyResult `
                -Decision "EVALUATE_RECOVERY" `
                -Actionable $true `
                -AllowRecoveryEvaluation $true `
                -ReasonCode "JOB_ACTIVE_OR_QUEUED" `
                -Reason "An active or queued print demand exists." `
                -SourceContext $QueueJobContext
        }

        "PRINTING_UNCONFIRMED" {

            return New-PrintSwitchQueuePolicyResult `
                -Decision "WAIT" `
                -Actionable $false `
                -AllowRecoveryEvaluation $false `
                -ReasonCode "JOB_PRINTING_UNCONFIRMED" `
                -Reason "Printing is reported but progress is not yet confirmed." `
                -SourceContext $QueueJobContext
        }

        "PROGRESSING" {

            return New-PrintSwitchQueuePolicyResult `
                -Decision "NO_ACTION" `
                -Actionable $false `
                -AllowRecoveryEvaluation $false `
                -ReasonCode "JOB_PROGRESSING" `
                -Reason "The print job is making observable progress." `
                -SourceContext $QueueJobContext
        }

        "PAUSED" {

            return New-PrintSwitchQueuePolicyResult `
                -Decision "WAIT" `
                -Actionable $false `
                -AllowRecoveryEvaluation $false `
                -ReasonCode "JOB_PAUSED" `
                -Reason "The print job is paused." `
                -SourceContext $QueueJobContext
        }

        "TRANSITIONING" {

            return New-PrintSwitchQueuePolicyResult `
                -Decision "WAIT" `
                -Actionable $false `
                -AllowRecoveryEvaluation $false `
                -ReasonCode "JOB_TRANSITIONING" `
                -Reason "The print job is transitioning lifecycle state." `
                -SourceContext $QueueJobContext
        }

        "ERROR_ACTIVE" {

            return New-PrintSwitchQueuePolicyResult `
                -Decision "EVALUATE_RECOVERY" `
                -Actionable $true `
                -AllowRecoveryEvaluation $true `
                -ReasonCode "JOB_ERROR_ACTIVE" `
                -Reason "The print job has an active error that may justify connectivity evaluation." `
                -SourceContext $QueueJobContext
        }

        "STALLED_ERROR" {

            return New-PrintSwitchQueuePolicyResult `
                -Decision "EVALUATE_RECOVERY" `
                -Actionable $true `
                -AllowRecoveryEvaluation $true `
                -ReasonCode "JOB_STALLED_ERROR" `
                -Reason "The print job is stale, has no progress, and reports an error." `
                -SourceContext $QueueJobContext
        }

        "STALLED_NO_ERROR" {

            return New-PrintSwitchQueuePolicyResult `
                -Decision "EVALUATE_RECOVERY" `
                -Actionable $true `
                -AllowRecoveryEvaluation $true `
                -ReasonCode "JOB_STALLED_NO_ERROR" `
                -Reason "The print job is stale and has no progress even without an explicit error." `
                -SourceContext $QueueJobContext
        }

        "COMPLETE" {

            return New-PrintSwitchQueuePolicyResult `
                -Decision "NO_ACTION" `
                -Actionable $false `
                -AllowRecoveryEvaluation $false `
                -ReasonCode "JOB_COMPLETE" `
                -Reason "The print job is complete." `
                -SourceContext $QueueJobContext
        }
    }

    # Defensive fail-closed fallback.
    return New-PrintSwitchQueuePolicyResult `
        -Decision "INSUFFICIENT_CONTEXT" `
        -Actionable $false `
        -AllowRecoveryEvaluation $false `
        -ReasonCode "QUEUE_POLICY_UNREACHABLE_FALLBACK" `
        -Reason "QueuePolicy reached an unexpected fallback path." `
        -SourceContext $QueueJobContext
}


function Test-PrintSwitchQueuePolicyResult {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Result
    )

    $Errors = @()

    foreach (
        $RequiredProperty in
        @(
            "SchemaVersion",
            "Decision",
            "Actionable",
            "AllowRecoveryEvaluation",
            "ReasonCode",
            "Reason",
            "SourceContext"
        )
    ) {

        if (
            $null -eq
            $Result.PSObject.Properties[$RequiredProperty]
        ) {

            $Errors +=
                "MISSING_PROPERTY_$RequiredProperty"
        }
    }

    if ($Errors.Count -eq 0) {

        if ([int]$Result.SchemaVersion -ne 1) {
            $Errors += "INVALID_SCHEMA_VERSION"
        }

        if (
            [string]$Result.Decision -notin
            $script:QueuePolicyDecisionValues
        ) {
            $Errors += "INVALID_DECISION"
        }

        if (
            $Result.Decision -eq "EVALUATE_RECOVERY"
        ) {

            if (
                -not [bool]$Result.Actionable -or
                -not [bool]$Result.AllowRecoveryEvaluation
            ) {
                $Errors +=
                    "EVALUATE_RECOVERY_INVARIANT_BROKEN"
            }
        }
        else {

            if (
                [bool]$Result.Actionable -or
                [bool]$Result.AllowRecoveryEvaluation
            ) {
                $Errors +=
                    "NON_ACTIONABLE_INVARIANT_BROKEN"
            }
        }

        if (
            [string]::IsNullOrWhiteSpace(
                [string]$Result.ReasonCode
            )
        ) {
            $Errors += "EMPTY_REASON_CODE"
        }
    }

    return [PSCustomObject]@{
        Valid =
            ($Errors.Count -eq 0)

        ErrorCount =
            $Errors.Count

        Errors =
            @($Errors)
    }
}
