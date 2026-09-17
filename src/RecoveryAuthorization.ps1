Set-StrictMode -Version Latest

# ============================================================
# PrintSwitch - RecoveryAuthorization v1
#
# Purpose:
# - Evaluate whether a previously relevant recovery condition
#   is authorized to proceed to a later execution boundary.
#
# This component NEVER:
# - invokes PrintRecoveryOrchestrator
# - invokes NetworkManager
# - changes Wi-Fi
# - mutates the print queue
# - executes recovery
# ============================================================

function New-PrintSwitchRecoveryAuthorizationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$AuthorizationRequested,

        [Parameter(Mandatory = $true)]
        [bool]$AuthorizationPerformed,

        [Parameter(Mandatory = $true)]
        [ValidateSet("AUTHORIZED","DENIED")]
        [string]$AuthorizationDecision,

        [Parameter(Mandatory = $true)]
        [bool]$RecoveryRelevant,

        [Parameter(Mandatory = $true)]
        [bool]$RecoveryEnabled,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$CurrentSSID,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$TargetSSID,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$PrinterName,

        [Parameter(Mandatory = $true)]
        [bool]$EndpointResolved,

        [Parameter(Mandatory = $true)]
        [string]$ReasonCode,

        [Parameter(Mandatory = $true)]
        [string]$Reason,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$SourceRecoveryEvaluation
    )

    return [PSCustomObject]@{
        SchemaVersion            = 1
        AuthorizationRequested   = $AuthorizationRequested
        AuthorizationPerformed   = $AuthorizationPerformed
        AuthorizationDecision    = $AuthorizationDecision
        Authorized               = ($AuthorizationDecision -eq "AUTHORIZED")
        RecoveryRelevant         = $RecoveryRelevant
        RecoveryEnabled          = $RecoveryEnabled
        CurrentSSID              = $CurrentSSID
        TargetSSID               = $TargetSSID
        PrinterName              = $PrinterName
        EndpointResolved         = $EndpointResolved
        ReasonCode               = $ReasonCode
        Reason                   = $Reason
        SourceRecoveryEvaluation = $SourceRecoveryEvaluation
    }
}


function Test-PrintSwitchRecoveryAuthorizationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Result
    )

    if ($null -eq $Result) {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "Result is null."
        }
    }

    $Required =
        @(
            "SchemaVersion",
            "AuthorizationRequested",
            "AuthorizationPerformed",
            "AuthorizationDecision",
            "Authorized",
            "RecoveryRelevant",
            "RecoveryEnabled",
            "EndpointResolved",
            "ReasonCode",
            "Reason",
            "SourceRecoveryEvaluation"
        )

    $ResultPropertyNames =
        @(
            $Result.PSObject.Properties |
            ForEach-Object {
                $_.Name
            }
        )

    foreach ($Name in $Required) {

        if (-not ($ResultPropertyNames -contains $Name)) {

            return [PSCustomObject]@{
                Valid  = $false
                Reason = "Missing property: $Name"
            }
        }
    }

    if ([int]$Result.SchemaVersion -ne 1) {

        return [PSCustomObject]@{
            Valid  = $false
            Reason = "Unsupported SchemaVersion."
        }
    }

    if (
        [string]$Result.AuthorizationDecision -notin
            @("AUTHORIZED","DENIED")
    ) {

        return [PSCustomObject]@{
            Valid  = $false
            Reason = "Invalid AuthorizationDecision."
        }
    }

    if ($Result.Authorized -isnot [bool]) {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "Authorized must be Boolean."
        }
    }

    $ExpectedAuthorized = ([string]$Result.AuthorizationDecision -eq "AUTHORIZED")

    if ([bool]$Result.Authorized -ne $ExpectedAuthorized) {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "Authorized is inconsistent with AuthorizationDecision."
        }
    }

    if (
        [string]::IsNullOrWhiteSpace(
            [string]$Result.ReasonCode
        )
    ) {

        return [PSCustomObject]@{
            Valid  = $false
            Reason = "ReasonCode is empty."
        }
    }

    return [PSCustomObject]@{
        Valid  = $true
        Reason = "OK"
    }
}


function Get-PrintSwitchRecoveryAuthorization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$RecoveryEvaluationResult,

        [Parameter(Mandatory = $true)]
        [bool]$RecoveryEnabled,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$CurrentSSID,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$TargetSSID,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$PrinterName
    )

    # --------------------------------------------------------
    # Validate source contract fail-closed.
    # --------------------------------------------------------

    if ($null -eq $RecoveryEvaluationResult) {

        return New-PrintSwitchRecoveryAuthorizationResult `
            -AuthorizationRequested $false `
            -AuthorizationPerformed $false `
            -AuthorizationDecision "DENIED" `
            -RecoveryRelevant $false `
            -RecoveryEnabled $RecoveryEnabled `
            -CurrentSSID $CurrentSSID `
            -TargetSSID $TargetSSID `
            -PrinterName $PrinterName `
            -EndpointResolved $false `
            -ReasonCode "INVALID_RECOVERY_EVALUATION" `
            -Reason "RecoveryEvaluationResult is null." `
            -SourceRecoveryEvaluation $RecoveryEvaluationResult
    }

    $RequiredSourceProperties =
        @(
            "SchemaVersion",
            "RecoveryRelevant",
            "EndpointResolved"
        )

    $SourcePropertyNames =
        @(
            $RecoveryEvaluationResult.PSObject.Properties |
            ForEach-Object {
                $_.Name
            }
        )

    foreach ($Name in $RequiredSourceProperties) {

        if (-not ($SourcePropertyNames -contains $Name)) {

            return New-PrintSwitchRecoveryAuthorizationResult `
                -AuthorizationRequested $false `
                -AuthorizationPerformed $false `
                -AuthorizationDecision "DENIED" `
                -RecoveryRelevant $false `
                -RecoveryEnabled $RecoveryEnabled `
                -CurrentSSID $CurrentSSID `
                -TargetSSID $TargetSSID `
                -PrinterName $PrinterName `
                -EndpointResolved $false `
                -ReasonCode "INVALID_RECOVERY_EVALUATION" `
                -Reason "RecoveryEvaluationResult does not expose the required contract." `
                -SourceRecoveryEvaluation $RecoveryEvaluationResult
        }
    }

    $Relevant =
        [bool]$RecoveryEvaluationResult.RecoveryRelevant

    $EndpointResolved =
        [bool]$RecoveryEvaluationResult.EndpointResolved

    if (
        [string]::IsNullOrWhiteSpace($PrinterName) -and
        $SourcePropertyNames -contains "PrinterName"
    ) {

        $PrinterName =
            [string]$RecoveryEvaluationResult.PrinterName
    }

    # --------------------------------------------------------
    # RECOVERY_NOT_RELEVANT
    # --------------------------------------------------------

    if (-not $Relevant) {

        return New-PrintSwitchRecoveryAuthorizationResult `
            -AuthorizationRequested $false `
            -AuthorizationPerformed $true `
            -AuthorizationDecision "DENIED" `
            -RecoveryRelevant $false `
            -RecoveryEnabled $RecoveryEnabled `
            -CurrentSSID $CurrentSSID `
            -TargetSSID $TargetSSID `
            -PrinterName $PrinterName `
            -EndpointResolved $EndpointResolved `
            -ReasonCode "RECOVERY_NOT_RELEVANT" `
            -Reason "Recovery evaluation did not identify a relevant recovery condition." `
            -SourceRecoveryEvaluation $RecoveryEvaluationResult
    }

    # From here onward authorization was requested.

    $AuthorizationRequested =
        $true

    # --------------------------------------------------------
    # RECOVERY_DISABLED
    # --------------------------------------------------------

    if (-not $RecoveryEnabled) {

        return New-PrintSwitchRecoveryAuthorizationResult `
            -AuthorizationRequested $AuthorizationRequested `
            -AuthorizationPerformed $true `
            -AuthorizationDecision "DENIED" `
            -RecoveryRelevant $true `
            -RecoveryEnabled $false `
            -CurrentSSID $CurrentSSID `
            -TargetSSID $TargetSSID `
            -PrinterName $PrinterName `
            -EndpointResolved $EndpointResolved `
            -ReasonCode "RECOVERY_DISABLED" `
            -Reason "Recovery execution gate is disabled." `
            -SourceRecoveryEvaluation $RecoveryEvaluationResult
    }

    # --------------------------------------------------------
    # ENDPOINT_UNRESOLVED
    # --------------------------------------------------------

    if (-not $EndpointResolved) {

        return New-PrintSwitchRecoveryAuthorizationResult `
            -AuthorizationRequested $AuthorizationRequested `
            -AuthorizationPerformed $true `
            -AuthorizationDecision "DENIED" `
            -RecoveryRelevant $true `
            -RecoveryEnabled $true `
            -CurrentSSID $CurrentSSID `
            -TargetSSID $TargetSSID `
            -PrinterName $PrinterName `
            -EndpointResolved $false `
            -ReasonCode "ENDPOINT_UNRESOLVED" `
            -Reason "Printer endpoint is not resolved." `
            -SourceRecoveryEvaluation $RecoveryEvaluationResult
    }

    # --------------------------------------------------------
    # CURRENT_SSID_UNKNOWN
    # --------------------------------------------------------

    if ([string]::IsNullOrWhiteSpace($CurrentSSID)) {

        return New-PrintSwitchRecoveryAuthorizationResult `
            -AuthorizationRequested $AuthorizationRequested `
            -AuthorizationPerformed $true `
            -AuthorizationDecision "DENIED" `
            -RecoveryRelevant $true `
            -RecoveryEnabled $true `
            -CurrentSSID $CurrentSSID `
            -TargetSSID $TargetSSID `
            -PrinterName $PrinterName `
            -EndpointResolved $true `
            -ReasonCode "CURRENT_SSID_UNKNOWN" `
            -Reason "Current Wi-Fi SSID is unknown." `
            -SourceRecoveryEvaluation $RecoveryEvaluationResult
    }

    # --------------------------------------------------------
    # TARGET_SSID_UNKNOWN
    # --------------------------------------------------------

    if ([string]::IsNullOrWhiteSpace($TargetSSID)) {

        return New-PrintSwitchRecoveryAuthorizationResult `
            -AuthorizationRequested $AuthorizationRequested `
            -AuthorizationPerformed $true `
            -AuthorizationDecision "DENIED" `
            -RecoveryRelevant $true `
            -RecoveryEnabled $true `
            -CurrentSSID $CurrentSSID `
            -TargetSSID $TargetSSID `
            -PrinterName $PrinterName `
            -EndpointResolved $true `
            -ReasonCode "TARGET_SSID_UNKNOWN" `
            -Reason "Target Wi-Fi SSID is unknown." `
            -SourceRecoveryEvaluation $RecoveryEvaluationResult
    }

    # --------------------------------------------------------
    # ALREADY_ON_TARGET_SSID
    # --------------------------------------------------------

    if (
        [string]::Equals(
            $CurrentSSID.Trim(),
            $TargetSSID.Trim(),
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {

        return New-PrintSwitchRecoveryAuthorizationResult `
            -AuthorizationRequested $AuthorizationRequested `
            -AuthorizationPerformed $true `
            -AuthorizationDecision "DENIED" `
            -RecoveryRelevant $true `
            -RecoveryEnabled $true `
            -CurrentSSID $CurrentSSID `
            -TargetSSID $TargetSSID `
            -PrinterName $PrinterName `
            -EndpointResolved $true `
            -ReasonCode "ALREADY_ON_TARGET_SSID" `
            -Reason "System is already connected to the target Wi-Fi SSID." `
            -SourceRecoveryEvaluation $RecoveryEvaluationResult
    }

    # --------------------------------------------------------
    # AUTHORIZED
    #
    # Important:
    # AUTHORIZED means only that this boundary allows a later
    # execution stage to be considered.
    #
    # No switch is executed here.
    # --------------------------------------------------------

    return New-PrintSwitchRecoveryAuthorizationResult `
        -AuthorizationRequested $AuthorizationRequested `
        -AuthorizationPerformed $true `
        -AuthorizationDecision "AUTHORIZED" `
        -RecoveryRelevant $true `
        -RecoveryEnabled $true `
        -CurrentSSID $CurrentSSID `
        -TargetSSID $TargetSSID `
        -PrinterName $PrinterName `
        -EndpointResolved $true `
        -ReasonCode "RECOVERY_AUTHORIZED" `
        -Reason "Recovery authorization requirements are satisfied." `
        -SourceRecoveryEvaluation $RecoveryEvaluationResult
}
