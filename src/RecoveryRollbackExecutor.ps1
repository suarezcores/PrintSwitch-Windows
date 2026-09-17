Set-StrictMode -Version Latest

function Get-PrintSwitchRollbackExecutorPropertyValue {
    [CmdletBinding()]
    param (
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

function New-PrintSwitchRollbackExecutionResult {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [bool]$RollbackRequested,

        [Parameter(Mandatory)]
        [bool]$RollbackAuthorized,

        [Parameter(Mandatory)]
        [bool]$RollbackPerformed,

        [Parameter(Mandatory)]
        [bool]$RollbackVerified,

        [AllowNull()]
        [string]$SourceSSID,

        [AllowNull()]
        [string]$TargetSSID,

        [AllowNull()]
        [string]$PreRollbackSSID,

        [AllowNull()]
        [string]$PostRollbackSSID,

        [AllowNull()]
        [string]$RollbackTargetSSID,

        [AllowNull()]
        [string]$CorrelationId,

        [Parameter(Mandatory)]
        [string]$ReasonCode,

        [Parameter(Mandatory)]
        [string]$Reason,

        [AllowNull()]
        [object]$RollbackPolicySnapshot
    )

    return [PSCustomObject]@{
        Component              = "RecoveryRollbackExecutor"
        SchemaVersion          = 1
        RollbackRequested      = $RollbackRequested
        RollbackAuthorized     = $RollbackAuthorized
        RollbackPerformed      = $RollbackPerformed
        RollbackVerified       = $RollbackVerified
        SourceSSID             = $SourceSSID
        TargetSSID             = $TargetSSID
        PreRollbackSSID        = $PreRollbackSSID
        PostRollbackSSID       = $PostRollbackSSID
        RollbackTargetSSID     = $RollbackTargetSSID
        CorrelationId          = $CorrelationId
        ReasonCode             = $ReasonCode
        Reason                 = $Reason
        RollbackPolicySnapshot = $RollbackPolicySnapshot
    }
}

function Get-PrintSwitchRollbackExecutionRequest {
    [CmdletBinding()]
    param (
        [AllowNull()]
        [object]$RollbackPolicyResult,

        [AllowNull()]
        [string]$CorrelationId
    )

    if ($null -eq $RollbackPolicyResult) {
        return New-PrintSwitchRollbackExecutionResult `
            -RollbackRequested $false `
            -RollbackAuthorized $false `
            -RollbackPerformed $false `
            -RollbackVerified $false `
            -SourceSSID $null `
            -TargetSSID $null `
            -PreRollbackSSID $null `
            -PostRollbackSSID $null `
            -RollbackTargetSSID $null `
            -CorrelationId $CorrelationId `
            -ReasonCode "ROLLBACK_POLICY_MISSING" `
            -Reason "Rollback policy result is missing." `
            -RollbackPolicySnapshot $RollbackPolicyResult
    }

    $Validation =
        Test-PrintSwitchRecoveryRollbackDecision `
            -Result $RollbackPolicyResult

    if ($null -eq $Validation -or $Validation.Valid -ne $true) {
        $ValidationReason = $null

        if ($null -ne $Validation) {
            $ValidationReason =
                Get-PrintSwitchRollbackExecutorPropertyValue `
                    -Object $Validation `
                    -Name "Reason"
        }

        return New-PrintSwitchRollbackExecutionResult `
            -RollbackRequested $false `
            -RollbackAuthorized $false `
            -RollbackPerformed $false `
            -RollbackVerified $false `
            -SourceSSID (Get-PrintSwitchRollbackExecutorPropertyValue -Object $RollbackPolicyResult -Name "SourceSSID") `
            -TargetSSID (Get-PrintSwitchRollbackExecutorPropertyValue -Object $RollbackPolicyResult -Name "TargetSSID") `
            -PreRollbackSSID (Get-PrintSwitchRollbackExecutorPropertyValue -Object $RollbackPolicyResult -Name "CurrentSSID") `
            -PostRollbackSSID $null `
            -RollbackTargetSSID (Get-PrintSwitchRollbackExecutorPropertyValue -Object $RollbackPolicyResult -Name "RollbackTargetSSID") `
            -CorrelationId $CorrelationId `
            -ReasonCode "ROLLBACK_POLICY_INVALID" `
            -Reason ("Rollback policy result is invalid: {0}" -f [string]$ValidationReason) `
            -RollbackPolicySnapshot $RollbackPolicyResult
    }

    $Decision =
        [string](
            Get-PrintSwitchRollbackExecutorPropertyValue `
                -Object $RollbackPolicyResult `
                -Name "Decision"
        )

    $RollbackRequired =
        Get-PrintSwitchRollbackExecutorPropertyValue `
            -Object $RollbackPolicyResult `
            -Name "RollbackRequired"

    $AutomaticRollbackAllowed =
        Get-PrintSwitchRollbackExecutorPropertyValue `
            -Object $RollbackPolicyResult `
            -Name "AutomaticRollbackAllowed"

    $SourceSSID =
        [string](
            Get-PrintSwitchRollbackExecutorPropertyValue `
                -Object $RollbackPolicyResult `
                -Name "SourceSSID"
        )

    $TargetSSID =
        [string](
            Get-PrintSwitchRollbackExecutorPropertyValue `
                -Object $RollbackPolicyResult `
                -Name "TargetSSID"
        )

    $CurrentSSID =
        [string](
            Get-PrintSwitchRollbackExecutorPropertyValue `
                -Object $RollbackPolicyResult `
                -Name "CurrentSSID"
        )

    $RollbackTargetSSID =
        [string](
            Get-PrintSwitchRollbackExecutorPropertyValue `
                -Object $RollbackPolicyResult `
                -Name "RollbackTargetSSID"
        )

    if ($Decision -eq "NO_ROLLBACK") {
        return New-PrintSwitchRollbackExecutionResult `
            -RollbackRequested $false `
            -RollbackAuthorized $false `
            -RollbackPerformed $false `
            -RollbackVerified $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -PreRollbackSSID $CurrentSSID `
            -PostRollbackSSID $CurrentSSID `
            -RollbackTargetSSID $null `
            -CorrelationId $CorrelationId `
            -ReasonCode "ROLLBACK_NOT_REQUIRED" `
            -Reason "Rollback policy does not require a rollback." `
            -RollbackPolicySnapshot $RollbackPolicyResult
    }

    if ($Decision -eq "MANUAL_INTERVENTION") {
        return New-PrintSwitchRollbackExecutionResult `
            -RollbackRequested $true `
            -RollbackAuthorized $false `
            -RollbackPerformed $false `
            -RollbackVerified $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -PreRollbackSSID $CurrentSSID `
            -PostRollbackSSID $CurrentSSID `
            -RollbackTargetSSID $RollbackTargetSSID `
            -CorrelationId $CorrelationId `
            -ReasonCode "ROLLBACK_MANUAL_INTERVENTION_REQUIRED" `
            -Reason "Rollback is required, but automatic execution is not authorized." `
            -RollbackPolicySnapshot $RollbackPolicyResult
    }

    if ($Decision -eq "INSUFFICIENT_CONTEXT") {
        return New-PrintSwitchRollbackExecutionResult `
            -RollbackRequested $false `
            -RollbackAuthorized $false `
            -RollbackPerformed $false `
            -RollbackVerified $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -PreRollbackSSID $CurrentSSID `
            -PostRollbackSSID $CurrentSSID `
            -RollbackTargetSSID $null `
            -CorrelationId $CorrelationId `
            -ReasonCode "ROLLBACK_CONTEXT_INSUFFICIENT" `
            -Reason "Rollback context is insufficient for automatic execution." `
            -RollbackPolicySnapshot $RollbackPolicyResult
    }

    if (
        $Decision -ne "ROLLBACK_REQUIRED" -or
        $RollbackRequired -ne $true -or
        $AutomaticRollbackAllowed -ne $true
    ) {
        return New-PrintSwitchRollbackExecutionResult `
            -RollbackRequested $false `
            -RollbackAuthorized $false `
            -RollbackPerformed $false `
            -RollbackVerified $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -PreRollbackSSID $CurrentSSID `
            -PostRollbackSSID $CurrentSSID `
            -RollbackTargetSSID $RollbackTargetSSID `
            -CorrelationId $CorrelationId `
            -ReasonCode "ROLLBACK_POLICY_CONTRADICTION" `
            -Reason "Rollback policy does not provide a coherent automatic rollback authorization." `
            -RollbackPolicySnapshot $RollbackPolicyResult
    }

    return New-PrintSwitchRollbackExecutionResult `
        -RollbackRequested $true `
        -RollbackAuthorized $true `
        -RollbackPerformed $false `
        -RollbackVerified $false `
        -SourceSSID $SourceSSID `
        -TargetSSID $TargetSSID `
        -PreRollbackSSID $CurrentSSID `
        -PostRollbackSSID $CurrentSSID `
        -RollbackTargetSSID $RollbackTargetSSID `
        -CorrelationId $CorrelationId `
        -ReasonCode "ROLLBACK_EXECUTION_BOUNDARY_DISCONNECTED" `
        -Reason "Rollback is authorized, but the physical execution boundary is disconnected." `
        -RollbackPolicySnapshot $RollbackPolicyResult
}

function Test-PrintSwitchRollbackExecutionResult {
    [CmdletBinding()]
    param (
        [AllowNull()]
        [object]$Result
    )

    if ($null -eq $Result) {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "Result is null."
        }
    }

    $RequiredProperties = @(
        "Component",
        "SchemaVersion",
        "RollbackRequested",
        "RollbackAuthorized",
        "RollbackPerformed",
        "RollbackVerified",
        "SourceSSID",
        "TargetSSID",
        "PreRollbackSSID",
        "PostRollbackSSID",
        "RollbackTargetSSID",
        "CorrelationId",
        "ReasonCode",
        "Reason",
        "RollbackPolicySnapshot"
    )

    foreach ($PropertyName in $RequiredProperties) {
        if ($null -eq $Result.PSObject.Properties[$PropertyName]) {
            return [PSCustomObject]@{
                Valid  = $false
                Reason = "Missing required property: $PropertyName"
            }
        }
    }

    if ([string]$Result.Component -ne "RecoveryRollbackExecutor") {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "Invalid Component."
        }
    }

    if ([int]$Result.SchemaVersion -ne 1) {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "Invalid SchemaVersion."
        }
    }

    foreach ($FieldName in @(
        "RollbackRequested",
        "RollbackAuthorized",
        "RollbackPerformed",
        "RollbackVerified"
    )) {
        $Value =
            Get-PrintSwitchRollbackExecutorPropertyValue `
                -Object $Result `
                -Name $FieldName

        if ($Value -isnot [bool]) {
            return [PSCustomObject]@{
                Valid  = $false
                Reason = "$FieldName must be Boolean."
            }
        }
    }

    if ($Result.RollbackPerformed -eq $true -and $Result.RollbackAuthorized -ne $true) {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "RollbackPerformed requires RollbackAuthorized=True."
        }
    }

    if ($Result.RollbackVerified -eq $true -and $Result.RollbackPerformed -ne $true) {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "RollbackVerified requires RollbackPerformed=True."
        }
    }

    $ReasonCode = [string]$Result.ReasonCode
    $SourceSSID = [string]$Result.SourceSSID
    $TargetSSID = [string]$Result.TargetSSID
    $PreRollbackSSID = [string]$Result.PreRollbackSSID
    $PostRollbackSSID = [string]$Result.PostRollbackSSID
    $RollbackTargetSSID = [string]$Result.RollbackTargetSSID

    $AllowedReasonCodes = @(
        "ROLLBACK_POLICY_MISSING",
        "ROLLBACK_POLICY_INVALID",
        "ROLLBACK_NOT_REQUIRED",
        "ROLLBACK_MANUAL_INTERVENTION_REQUIRED",
        "ROLLBACK_CONTEXT_INSUFFICIENT",
        "ROLLBACK_POLICY_CONTRADICTION",
        "ROLLBACK_EXECUTION_BOUNDARY_DISCONNECTED"
    )

    if ($AllowedReasonCodes -notcontains $ReasonCode) {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "Unknown ReasonCode."
        }
    }

    switch ($ReasonCode) {
        "ROLLBACK_EXECUTION_BOUNDARY_DISCONNECTED" {
            if (
                $Result.RollbackRequested -ne $true -or
                $Result.RollbackAuthorized -ne $true -or
                $Result.RollbackPerformed -ne $false -or
                $Result.RollbackVerified -ne $false
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "Disconnected rollback boundary result is inconsistent."
                }
            }

            if (
                [string]::IsNullOrWhiteSpace($SourceSSID) -or
                [string]::IsNullOrWhiteSpace($TargetSSID) -or
                [string]::IsNullOrWhiteSpace($PreRollbackSSID) -or
                [string]::IsNullOrWhiteSpace($RollbackTargetSSID)
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "Authorized disconnected rollback requires complete SSID context."
                }
            }

            if ($SourceSSID -eq $TargetSSID) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "Authorized rollback requires SourceSSID and TargetSSID to differ."
                }
            }

            if ($RollbackTargetSSID -ne $SourceSSID) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "RollbackTargetSSID must equal SourceSSID."
                }
            }

            if ($PreRollbackSSID -ne $TargetSSID) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "Authorized disconnected rollback requires PreRollbackSSID to equal TargetSSID."
                }
            }

            if ($PostRollbackSSID -ne $PreRollbackSSID) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "Disconnected rollback boundary must not report an SSID transition."
                }
            }
        }

        "ROLLBACK_NOT_REQUIRED" {
            if (
                $Result.RollbackRequested -ne $false -or
                $Result.RollbackAuthorized -ne $false -or
                $Result.RollbackPerformed -ne $false -or
                $Result.RollbackVerified -ne $false
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_NOT_REQUIRED result is inconsistent."
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($RollbackTargetSSID)) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_NOT_REQUIRED must not carry RollbackTargetSSID."
                }
            }
        }

        "ROLLBACK_MANUAL_INTERVENTION_REQUIRED" {
            if (
                $Result.RollbackRequested -ne $true -or
                $Result.RollbackAuthorized -ne $false -or
                $Result.RollbackPerformed -ne $false -or
                $Result.RollbackVerified -ne $false
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "Manual-intervention rollback result is inconsistent."
                }
            }

            if (
                [string]::IsNullOrWhiteSpace($SourceSSID) -or
                [string]::IsNullOrWhiteSpace($TargetSSID) -or
                [string]::IsNullOrWhiteSpace($RollbackTargetSSID)
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "Manual-intervention rollback requires source, target, and rollback target SSIDs."
                }
            }

            if ($SourceSSID -eq $TargetSSID -or $RollbackTargetSSID -ne $SourceSSID) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "Manual-intervention rollback SSID context is inconsistent."
                }
            }
        }

        "ROLLBACK_CONTEXT_INSUFFICIENT" {
            if (
                $Result.RollbackRequested -ne $false -or
                $Result.RollbackAuthorized -ne $false -or
                $Result.RollbackPerformed -ne $false -or
                $Result.RollbackVerified -ne $false
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_CONTEXT_INSUFFICIENT must fail closed."
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($RollbackTargetSSID)) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_CONTEXT_INSUFFICIENT must not carry RollbackTargetSSID."
                }
            }
        }

        "ROLLBACK_POLICY_MISSING" {
            if (
                $Result.RollbackRequested -ne $false -or
                $Result.RollbackAuthorized -ne $false -or
                $Result.RollbackPerformed -ne $false -or
                $Result.RollbackVerified -ne $false -or
                $null -ne $Result.RollbackPolicySnapshot
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_POLICY_MISSING result is inconsistent."
                }
            }
        }

        "ROLLBACK_POLICY_INVALID" {
            if (
                $Result.RollbackRequested -ne $false -or
                $Result.RollbackAuthorized -ne $false -or
                $Result.RollbackPerformed -ne $false -or
                $Result.RollbackVerified -ne $false -or
                $null -eq $Result.RollbackPolicySnapshot
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_POLICY_INVALID result is inconsistent."
                }
            }
        }

        "ROLLBACK_POLICY_CONTRADICTION" {
            if (
                $Result.RollbackRequested -ne $false -or
                $Result.RollbackAuthorized -ne $false -or
                $Result.RollbackPerformed -ne $false -or
                $Result.RollbackVerified -ne $false
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_POLICY_CONTRADICTION must fail closed."
                }
            }
        }
    }

    return [PSCustomObject]@{
        Valid  = $true
        Reason = "VALID"
    }
}
