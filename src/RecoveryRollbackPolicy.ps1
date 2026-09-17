Set-StrictMode -Version Latest

function Get-PrintSwitchRollbackPropertyValue {
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

function New-PrintSwitchRecoveryRollbackDecision {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet(
            "ROLLBACK_REQUIRED",
            "NO_ROLLBACK",
            "MANUAL_INTERVENTION",
            "INSUFFICIENT_CONTEXT"
        )]
        [string]$Decision,

        [Parameter(Mandatory)]
        [bool]$RollbackRequired,

        [Parameter(Mandatory)]
        [bool]$AutomaticRollbackAllowed,

        [AllowNull()]
        [string]$SourceSSID,

        [AllowNull()]
        [string]$TargetSSID,

        [AllowNull()]
        [string]$CurrentSSID,

        [AllowNull()]
        [string]$RollbackTargetSSID,

        [AllowNull()]
        [object]$SwitchExecuted,

        [AllowNull()]
        [object]$NetworkSwitchVerified,

        [AllowNull()]
        [object]$RecoverySucceeded,

        [Parameter(Mandatory)]
        [string]$ReasonCode,

        [Parameter(Mandatory)]
        [string]$Reason,

        [AllowNull()]
        [object]$SourceExecutionResult
    )

    return [PSCustomObject]@{
        Component                = "RecoveryRollbackPolicy"
        SchemaVersion            = 1
        Decision                 = $Decision
        RollbackRequired         = $RollbackRequired
        AutomaticRollbackAllowed = $AutomaticRollbackAllowed
        SourceSSID               = $SourceSSID
        TargetSSID               = $TargetSSID
        CurrentSSID              = $CurrentSSID
        RollbackTargetSSID       = $RollbackTargetSSID
        SwitchExecuted           = $SwitchExecuted
        NetworkSwitchVerified    = $NetworkSwitchVerified
        RecoverySucceeded        = $RecoverySucceeded
        ReasonCode               = $ReasonCode
        Reason                   = $Reason
        SourceExecutionResult    = $SourceExecutionResult
    }
}

function Get-PrintSwitchRecoveryRollbackDecision {
    [CmdletBinding()]
    param (
        [AllowNull()]
        [object]$ExecutionResult,

        [AllowNull()]
        [string]$SourceSSID,

        [AllowNull()]
        [string]$TargetSSID,

        [AllowNull()]
        [string]$CurrentSSID
    )

    if ($null -eq $ExecutionResult) {
        return New-PrintSwitchRecoveryRollbackDecision `
            -Decision "INSUFFICIENT_CONTEXT" `
            -RollbackRequired $false `
            -AutomaticRollbackAllowed $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -CurrentSSID $CurrentSSID `
            -RollbackTargetSSID $null `
            -SwitchExecuted $null `
            -NetworkSwitchVerified $null `
            -RecoverySucceeded $null `
            -ReasonCode "SOURCE_EXECUTION_RESULT_MISSING" `
            -Reason "Physical execution result is missing." `
            -SourceExecutionResult $ExecutionResult
    }

    $SwitchExecuted =
        Get-PrintSwitchRollbackPropertyValue `
            -Object $ExecutionResult `
            -Name "SwitchExecuted"

    $NetworkSwitchVerified =
        Get-PrintSwitchRollbackPropertyValue `
            -Object $ExecutionResult `
            -Name "NetworkSwitchVerified"

    $RecoverySucceeded =
        Get-PrintSwitchRollbackPropertyValue `
            -Object $ExecutionResult `
            -Name "RecoverySucceeded"

    if (
        $SwitchExecuted -isnot [bool] -or
        $NetworkSwitchVerified -isnot [bool] -or
        $RecoverySucceeded -isnot [bool]
    ) {
        return New-PrintSwitchRecoveryRollbackDecision `
            -Decision "INSUFFICIENT_CONTEXT" `
            -RollbackRequired $false `
            -AutomaticRollbackAllowed $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -CurrentSSID $CurrentSSID `
            -RollbackTargetSSID $null `
            -SwitchExecuted $SwitchExecuted `
            -NetworkSwitchVerified $NetworkSwitchVerified `
            -RecoverySucceeded $RecoverySucceeded `
            -ReasonCode "SOURCE_EXECUTION_RESULT_INVALID" `
            -Reason "SwitchExecuted, NetworkSwitchVerified and RecoverySucceeded must be Boolean values." `
            -SourceExecutionResult $ExecutionResult
    }

    if ([string]::IsNullOrWhiteSpace($SourceSSID)) {
        return New-PrintSwitchRecoveryRollbackDecision `
            -Decision "INSUFFICIENT_CONTEXT" `
            -RollbackRequired $false `
            -AutomaticRollbackAllowed $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -CurrentSSID $CurrentSSID `
            -RollbackTargetSSID $null `
            -SwitchExecuted $SwitchExecuted `
            -NetworkSwitchVerified $NetworkSwitchVerified `
            -RecoverySucceeded $RecoverySucceeded `
            -ReasonCode "SOURCE_SSID_MISSING" `
            -Reason "The source SSID required for rollback is missing." `
            -SourceExecutionResult $ExecutionResult
    }

    if ([string]::IsNullOrWhiteSpace($TargetSSID)) {
        return New-PrintSwitchRecoveryRollbackDecision `
            -Decision "INSUFFICIENT_CONTEXT" `
            -RollbackRequired $false `
            -AutomaticRollbackAllowed $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -CurrentSSID $CurrentSSID `
            -RollbackTargetSSID $null `
            -SwitchExecuted $SwitchExecuted `
            -NetworkSwitchVerified $NetworkSwitchVerified `
            -RecoverySucceeded $RecoverySucceeded `
            -ReasonCode "TARGET_SSID_MISSING" `
            -Reason "The recovery target SSID is missing." `
            -SourceExecutionResult $ExecutionResult
    }

    if ($SourceSSID -eq $TargetSSID) {
        return New-PrintSwitchRecoveryRollbackDecision `
            -Decision "NO_ROLLBACK" `
            -RollbackRequired $false `
            -AutomaticRollbackAllowed $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -CurrentSSID $CurrentSSID `
            -RollbackTargetSSID $null `
            -SwitchExecuted $SwitchExecuted `
            -NetworkSwitchVerified $NetworkSwitchVerified `
            -RecoverySucceeded $RecoverySucceeded `
            -ReasonCode "SOURCE_EQUALS_TARGET" `
            -Reason "Source and target SSIDs are identical; rollback is not applicable." `
            -SourceExecutionResult $ExecutionResult
    }

    if ($RecoverySucceeded) {
        return New-PrintSwitchRecoveryRollbackDecision `
            -Decision "NO_ROLLBACK" `
            -RollbackRequired $false `
            -AutomaticRollbackAllowed $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -CurrentSSID $CurrentSSID `
            -RollbackTargetSSID $null `
            -SwitchExecuted $SwitchExecuted `
            -NetworkSwitchVerified $NetworkSwitchVerified `
            -RecoverySucceeded $RecoverySucceeded `
            -ReasonCode "RECOVERY_SUCCEEDED" `
            -Reason "Recovery succeeded; rollback is not required." `
            -SourceExecutionResult $ExecutionResult
    }

    if ([string]::IsNullOrWhiteSpace($CurrentSSID)) {
        return New-PrintSwitchRecoveryRollbackDecision `
            -Decision "MANUAL_INTERVENTION" `
            -RollbackRequired $true `
            -AutomaticRollbackAllowed $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -CurrentSSID $CurrentSSID `
            -RollbackTargetSSID $SourceSSID `
            -SwitchExecuted $SwitchExecuted `
            -NetworkSwitchVerified $NetworkSwitchVerified `
            -RecoverySucceeded $RecoverySucceeded `
            -ReasonCode "CURRENT_SSID_UNKNOWN" `
            -Reason "Recovery failed and current Wi-Fi state cannot be confirmed; automatic rollback is blocked." `
            -SourceExecutionResult $ExecutionResult
    }

    if ($CurrentSSID -eq $SourceSSID) {
        return New-PrintSwitchRecoveryRollbackDecision `
            -Decision "NO_ROLLBACK" `
            -RollbackRequired $false `
            -AutomaticRollbackAllowed $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -CurrentSSID $CurrentSSID `
            -RollbackTargetSSID $null `
            -SwitchExecuted $SwitchExecuted `
            -NetworkSwitchVerified $NetworkSwitchVerified `
            -RecoverySucceeded $RecoverySucceeded `
            -ReasonCode "ALREADY_ON_SOURCE_SSID" `
            -Reason "Recovery failed but the system is already on the source SSID." `
            -SourceExecutionResult $ExecutionResult
    }

    if ($CurrentSSID -ne $TargetSSID) {
        return New-PrintSwitchRecoveryRollbackDecision `
            -Decision "MANUAL_INTERVENTION" `
            -RollbackRequired $true `
            -AutomaticRollbackAllowed $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -CurrentSSID $CurrentSSID `
            -RollbackTargetSSID $SourceSSID `
            -SwitchExecuted $SwitchExecuted `
            -NetworkSwitchVerified $NetworkSwitchVerified `
            -RecoverySucceeded $RecoverySucceeded `
            -ReasonCode "CURRENT_SSID_UNEXPECTED" `
            -Reason "Recovery failed and current SSID is neither the source nor the expected recovery target." `
            -SourceExecutionResult $ExecutionResult
    }

    if (-not $SwitchExecuted -or -not $NetworkSwitchVerified) {
        return New-PrintSwitchRecoveryRollbackDecision `
            -Decision "MANUAL_INTERVENTION" `
            -RollbackRequired $true `
            -AutomaticRollbackAllowed $false `
            -SourceSSID $SourceSSID `
            -TargetSSID $TargetSSID `
            -CurrentSSID $CurrentSSID `
            -RollbackTargetSSID $SourceSSID `
            -SwitchExecuted $SwitchExecuted `
            -NetworkSwitchVerified $NetworkSwitchVerified `
            -RecoverySucceeded $RecoverySucceeded `
            -ReasonCode "EXECUTION_CONTEXT_INCONSISTENT" `
            -Reason "Current SSID is the recovery target, but the execution result does not prove a verified switch owned by this recovery flow." `
            -SourceExecutionResult $ExecutionResult
    }

    return New-PrintSwitchRecoveryRollbackDecision `
        -Decision "ROLLBACK_REQUIRED" `
        -RollbackRequired $true `
        -AutomaticRollbackAllowed $true `
        -SourceSSID $SourceSSID `
        -TargetSSID $TargetSSID `
        -CurrentSSID $CurrentSSID `
        -RollbackTargetSSID $SourceSSID `
        -SwitchExecuted $SwitchExecuted `
        -NetworkSwitchVerified $NetworkSwitchVerified `
        -RecoverySucceeded $RecoverySucceeded `
        -ReasonCode "RECOVERY_FAILED_ROLLBACK_REQUIRED" `
        -Reason "Wi-Fi switch was verified, recovery failed, and the system remains on the recovery target SSID." `
        -SourceExecutionResult $ExecutionResult
}

function Test-PrintSwitchRecoveryRollbackDecision {
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
        "Decision",
        "RollbackRequired",
        "AutomaticRollbackAllowed",
        "SourceSSID",
        "TargetSSID",
        "CurrentSSID",
        "RollbackTargetSSID",
        "SwitchExecuted",
        "NetworkSwitchVerified",
        "RecoverySucceeded",
        "ReasonCode",
        "Reason",
        "SourceExecutionResult"
    )

    foreach ($PropertyName in $RequiredProperties) {
        if ($null -eq $Result.PSObject.Properties[$PropertyName]) {
            return [PSCustomObject]@{
                Valid  = $false
                Reason = "Missing required property: $PropertyName"
            }
        }
    }

    if ([string]$Result.Component -ne "RecoveryRollbackPolicy") {
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

    $AllowedDecisions = @(
        "ROLLBACK_REQUIRED",
        "NO_ROLLBACK",
        "MANUAL_INTERVENTION",
        "INSUFFICIENT_CONTEXT"
    )

    if ($AllowedDecisions -notcontains [string]$Result.Decision) {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "Invalid Decision."
        }
    }

    if ($Result.RollbackRequired -isnot [bool]) {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "RollbackRequired must be Boolean."
        }
    }

    if ($Result.AutomaticRollbackAllowed -isnot [bool]) {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "AutomaticRollbackAllowed must be Boolean."
        }
    }

    $SwitchExecuted = $Result.SwitchExecuted
    $NetworkSwitchVerified = $Result.NetworkSwitchVerified
    $RecoverySucceeded = $Result.RecoverySucceeded

    $Decision = [string]$Result.Decision
    $ReasonCode = [string]$Result.ReasonCode

    $AllowInvalidSourceFieldTypes = (
        $Decision -eq "INSUFFICIENT_CONTEXT" -and
        $ReasonCode -eq "SOURCE_EXECUTION_RESULT_INVALID"
    )

    foreach ($Field in @(
        [PSCustomObject]@{ Name = "SwitchExecuted"; Value = $SwitchExecuted },
        [PSCustomObject]@{ Name = "NetworkSwitchVerified"; Value = $NetworkSwitchVerified },
        [PSCustomObject]@{ Name = "RecoverySucceeded"; Value = $RecoverySucceeded }
    )) {
        if (
            $null -ne $Field.Value -and
            $Field.Value -isnot [bool] -and
            -not $AllowInvalidSourceFieldTypes
        ) {
            return [PSCustomObject]@{
                Valid  = $false
                Reason = "$($Field.Name) must be Boolean or null."
            }
        }
    }

    $SourceSSID = [string]$Result.SourceSSID
    $TargetSSID = [string]$Result.TargetSSID
    $CurrentSSID = [string]$Result.CurrentSSID
    $RollbackTargetSSID = [string]$Result.RollbackTargetSSID

    switch ($Decision) {
        "ROLLBACK_REQUIRED" {
            if (
                $Result.RollbackRequired -ne $true -or
                $Result.AutomaticRollbackAllowed -ne $true
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_REQUIRED result is internally inconsistent."
                }
            }

            if (
                [string]::IsNullOrWhiteSpace($SourceSSID) -or
                [string]::IsNullOrWhiteSpace($TargetSSID) -or
                [string]::IsNullOrWhiteSpace($CurrentSSID) -or
                [string]::IsNullOrWhiteSpace($RollbackTargetSSID)
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_REQUIRED requires complete SSID context."
                }
            }

            if ($SourceSSID -eq $TargetSSID) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_REQUIRED requires SourceSSID and TargetSSID to differ."
                }
            }

            if ($CurrentSSID -ne $TargetSSID) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_REQUIRED requires CurrentSSID to equal TargetSSID."
                }
            }

            if ($RollbackTargetSSID -ne $SourceSSID) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "RollbackTargetSSID must equal SourceSSID."
                }
            }

            if (
                $SwitchExecuted -ne $true -or
                $NetworkSwitchVerified -ne $true -or
                $RecoverySucceeded -ne $false
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_REQUIRED execution context is inconsistent."
                }
            }

            if ($ReasonCode -ne "RECOVERY_FAILED_ROLLBACK_REQUIRED") {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "ROLLBACK_REQUIRED has invalid ReasonCode."
                }
            }
        }

        "NO_ROLLBACK" {
            if (
                $Result.RollbackRequired -ne $false -or
                $Result.AutomaticRollbackAllowed -ne $false
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "NO_ROLLBACK result is internally inconsistent."
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($RollbackTargetSSID)) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "NO_ROLLBACK must not carry RollbackTargetSSID."
                }
            }

            switch ($ReasonCode) {
                "RECOVERY_SUCCEEDED" {
                    if ($RecoverySucceeded -ne $true) {
                        return [PSCustomObject]@{
                            Valid  = $false
                            Reason = "RECOVERY_SUCCEEDED reason requires RecoverySucceeded=True."
                        }
                    }
                }

                "ALREADY_ON_SOURCE_SSID" {
                    if (
                        [string]::IsNullOrWhiteSpace($SourceSSID) -or
                        [string]::IsNullOrWhiteSpace($CurrentSSID) -or
                        $CurrentSSID -ne $SourceSSID -or
                        $RecoverySucceeded -ne $false
                    ) {
                        return [PSCustomObject]@{
                            Valid  = $false
                            Reason = "ALREADY_ON_SOURCE_SSID context is inconsistent."
                        }
                    }
                }

                "SOURCE_EQUALS_TARGET" {
                    if (
                        [string]::IsNullOrWhiteSpace($SourceSSID) -or
                        [string]::IsNullOrWhiteSpace($TargetSSID) -or
                        $SourceSSID -ne $TargetSSID
                    ) {
                        return [PSCustomObject]@{
                            Valid  = $false
                            Reason = "SOURCE_EQUALS_TARGET context is inconsistent."
                        }
                    }
                }

                default {
                    return [PSCustomObject]@{
                        Valid  = $false
                        Reason = "NO_ROLLBACK has invalid ReasonCode."
                    }
                }
            }
        }

        "MANUAL_INTERVENTION" {
            if (
                $Result.RollbackRequired -ne $true -or
                $Result.AutomaticRollbackAllowed -ne $false
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "MANUAL_INTERVENTION result is internally inconsistent."
                }
            }

            if (
                [string]::IsNullOrWhiteSpace($SourceSSID) -or
                [string]::IsNullOrWhiteSpace($TargetSSID) -or
                $SourceSSID -eq $TargetSSID
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "MANUAL_INTERVENTION requires distinct source and target SSIDs."
                }
            }

            if (
                [string]::IsNullOrWhiteSpace($RollbackTargetSSID) -or
                $RollbackTargetSSID -ne $SourceSSID
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "MANUAL_INTERVENTION must retain SourceSSID as RollbackTargetSSID."
                }
            }

            if ($RecoverySucceeded -ne $false) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "MANUAL_INTERVENTION requires RecoverySucceeded=False."
                }
            }

            switch ($ReasonCode) {
                "CURRENT_SSID_UNKNOWN" {
                    if (-not [string]::IsNullOrWhiteSpace($CurrentSSID)) {
                        return [PSCustomObject]@{
                            Valid  = $false
                            Reason = "CURRENT_SSID_UNKNOWN reason requires an unknown CurrentSSID."
                        }
                    }
                }

                "CURRENT_SSID_UNEXPECTED" {
                    if (
                        [string]::IsNullOrWhiteSpace($CurrentSSID) -or
                        $CurrentSSID -eq $SourceSSID -or
                        $CurrentSSID -eq $TargetSSID
                    ) {
                        return [PSCustomObject]@{
                            Valid  = $false
                            Reason = "CURRENT_SSID_UNEXPECTED context is inconsistent."
                        }
                    }
                }

                "EXECUTION_CONTEXT_INCONSISTENT" {
                    if (
                        $CurrentSSID -ne $TargetSSID -or
                        (
                            $SwitchExecuted -eq $true -and
                            $NetworkSwitchVerified -eq $true
                        )
                    ) {
                        return [PSCustomObject]@{
                            Valid  = $false
                            Reason = "EXECUTION_CONTEXT_INCONSISTENT context is inconsistent."
                        }
                    }
                }

                default {
                    return [PSCustomObject]@{
                        Valid  = $false
                        Reason = "MANUAL_INTERVENTION has invalid ReasonCode."
                    }
                }
            }
        }

        "INSUFFICIENT_CONTEXT" {
            if (
                $Result.RollbackRequired -ne $false -or
                $Result.AutomaticRollbackAllowed -ne $false
            ) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "INSUFFICIENT_CONTEXT must fail closed."
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($RollbackTargetSSID)) {
                return [PSCustomObject]@{
                    Valid  = $false
                    Reason = "INSUFFICIENT_CONTEXT must not carry RollbackTargetSSID."
                }
            }

            switch ($ReasonCode) {
                "SOURCE_EXECUTION_RESULT_MISSING" {
                    if ($null -ne $Result.SourceExecutionResult) {
                        return [PSCustomObject]@{
                            Valid  = $false
                            Reason = "SOURCE_EXECUTION_RESULT_MISSING context is inconsistent."
                        }
                    }
                }

                "SOURCE_EXECUTION_RESULT_INVALID" {
                    if (
                        $null -eq $Result.SourceExecutionResult -or
                        (
                            $SwitchExecuted -is [bool] -and
                            $NetworkSwitchVerified -is [bool] -and
                            $RecoverySucceeded -is [bool]
                        )
                    ) {
                        return [PSCustomObject]@{
                            Valid  = $false
                            Reason = "SOURCE_EXECUTION_RESULT_INVALID context is inconsistent."
                        }
                    }
                }

                "SOURCE_SSID_MISSING" {
                    if (-not [string]::IsNullOrWhiteSpace($SourceSSID)) {
                        return [PSCustomObject]@{
                            Valid  = $false
                            Reason = "SOURCE_SSID_MISSING context is inconsistent."
                        }
                    }
                }

                "TARGET_SSID_MISSING" {
                    if (-not [string]::IsNullOrWhiteSpace($TargetSSID)) {
                        return [PSCustomObject]@{
                            Valid  = $false
                            Reason = "TARGET_SSID_MISSING context is inconsistent."
                        }
                    }
                }

                default {
                    return [PSCustomObject]@{
                        Valid  = $false
                        Reason = "INSUFFICIENT_CONTEXT has invalid ReasonCode."
                    }
                }
            }
        }
    }

    return [PSCustomObject]@{
        Valid  = $true
        Reason = "VALID"
    }
}
