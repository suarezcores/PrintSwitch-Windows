Set-StrictMode -Version Latest

function Get-PrintSwitchRollbackActuatorPropertyValue {
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

function New-PrintSwitchRollbackActuatorResult {
    [CmdletBinding()]
    param (
        [bool]$RollbackRequested = $false,
        [bool]$RollbackAuthorized = $false,
        [bool]$RollbackPerformed = $false,
        [bool]$RollbackVerified = $false,
        [AllowNull()][string]$SourceSSID,
        [AllowNull()][string]$RecoveryTargetSSID,
        [AllowNull()][string]$PreRollbackSSID,
        [AllowNull()][string]$PostRollbackSSID,
        [AllowNull()][string]$RollbackTargetSSID,
        [AllowNull()][string]$CorrelationId,
        [AllowNull()][string]$NetworkManagerClassification,
        [AllowNull()][object]$NetworkManagerSnapshot,
        [Parameter(Mandatory)][string]$ReasonCode,
        [Parameter(Mandatory)][string]$Reason,
        [AllowNull()][object]$RollbackExecutionRequest
    )

    return [PSCustomObject]@{
        Component                    = "RecoveryRollbackActuator"
        SchemaVersion                = 1
        RollbackRequested            = $RollbackRequested
        RollbackAuthorized           = $RollbackAuthorized
        RollbackPerformed            = $RollbackPerformed
        RollbackVerified             = $RollbackVerified
        SourceSSID                   = $SourceSSID
        RecoveryTargetSSID           = $RecoveryTargetSSID
        PreRollbackSSID              = $PreRollbackSSID
        PostRollbackSSID             = $PostRollbackSSID
        RollbackTargetSSID           = $RollbackTargetSSID
        CorrelationId                = $CorrelationId
        NetworkManagerClassification = $NetworkManagerClassification
        NetworkManagerSnapshot       = $NetworkManagerSnapshot
        ReasonCode                   = $ReasonCode
        Reason                       = $Reason
        RollbackExecutionRequest     = $RollbackExecutionRequest
    }
}

function Test-PrintSwitchRollbackActuatorResult {
    [CmdletBinding()]
    param (
        [AllowNull()]
        [object]$Result
    )

    if ($null -eq $Result) {
        return [PSCustomObject]@{ Valid = $false; Reason = "Result is null." }
    }

    $Required = @(
        "Component",
        "SchemaVersion",
        "RollbackRequested",
        "RollbackAuthorized",
        "RollbackPerformed",
        "RollbackVerified",
        "SourceSSID",
        "RecoveryTargetSSID",
        "PreRollbackSSID",
        "PostRollbackSSID",
        "RollbackTargetSSID",
        "CorrelationId",
        "NetworkManagerClassification",
        "NetworkManagerSnapshot",
        "ReasonCode",
        "Reason",
        "RollbackExecutionRequest"
    )

    foreach ($Name in $Required) {
        if ($null -eq $Result.PSObject.Properties[$Name]) {
            return [PSCustomObject]@{ Valid = $false; Reason = "Missing required property: $Name" }
        }
    }

    if ([string]$Result.Component -ne "RecoveryRollbackActuator") {
        return [PSCustomObject]@{ Valid = $false; Reason = "Invalid Component." }
    }

    if ([int]$Result.SchemaVersion -ne 1) {
        return [PSCustomObject]@{ Valid = $false; Reason = "Invalid SchemaVersion." }
    }

    foreach ($Name in @("RollbackRequested","RollbackAuthorized","RollbackPerformed","RollbackVerified")) {
        $Value = Get-PrintSwitchRollbackActuatorPropertyValue -Object $Result -Name $Name
        if ($Value -isnot [bool]) {
            return [PSCustomObject]@{ Valid = $false; Reason = "$Name must be Boolean." }
        }
    }

    if ($Result.RollbackPerformed -eq $true -and $Result.RollbackAuthorized -ne $true) {
        return [PSCustomObject]@{ Valid = $false; Reason = "RollbackPerformed requires RollbackAuthorized=True." }
    }

    if ($Result.RollbackVerified -eq $true -and $Result.RollbackPerformed -ne $true) {
        return [PSCustomObject]@{ Valid = $false; Reason = "RollbackVerified requires RollbackPerformed=True." }
    }

    $ReasonCode = [string]$Result.ReasonCode
    $SourceSSID = [string]$Result.SourceSSID
    $RecoveryTargetSSID = [string]$Result.RecoveryTargetSSID
    $PreRollbackSSID = [string]$Result.PreRollbackSSID
    $PostRollbackSSID = [string]$Result.PostRollbackSSID
    $RollbackTargetSSID = [string]$Result.RollbackTargetSSID

    if (@(
        "ROLLBACK_ACTUATOR_REQUEST_INVALID",
        "ROLLBACK_ACTUATOR_NOT_AUTHORIZED",
        "ROLLBACK_NETWORK_MANAGER_FAILED",
        "ROLLBACK_EXECUTED_AND_VERIFIED",
        "ROLLBACK_EXECUTED_NOT_VERIFIED"
    ) -notcontains $ReasonCode) {
        return [PSCustomObject]@{ Valid = $false; Reason = "Unknown ReasonCode." }
    }

    switch ($ReasonCode) {
        "ROLLBACK_ACTUATOR_REQUEST_INVALID" {
            if ($Result.RollbackRequested -or $Result.RollbackAuthorized -or $Result.RollbackPerformed -or $Result.RollbackVerified) {
                return [PSCustomObject]@{ Valid = $false; Reason = "Invalid actuator request must fail closed." }
            }
        }

        "ROLLBACK_ACTUATOR_NOT_AUTHORIZED" {
            if (
                $Result.RollbackRequested -ne $true -or
                $Result.RollbackAuthorized -ne $false -or
                $Result.RollbackPerformed -ne $false -or
                $Result.RollbackVerified -ne $false
            ) {
                return [PSCustomObject]@{ Valid = $false; Reason = "Unauthorized actuator result is inconsistent." }
            }
        }

        "ROLLBACK_NETWORK_MANAGER_FAILED" {
            if (
                $Result.RollbackRequested -ne $true -or
                $Result.RollbackAuthorized -ne $true -or
                $Result.RollbackPerformed -ne $false -or
                $Result.RollbackVerified -ne $false
            ) {
                return [PSCustomObject]@{ Valid = $false; Reason = "NetworkManager failure result is inconsistent." }
            }
        }

        "ROLLBACK_EXECUTED_AND_VERIFIED" {
            if (
                $Result.RollbackRequested -ne $true -or
                $Result.RollbackAuthorized -ne $true -or
                $Result.RollbackPerformed -ne $true -or
                $Result.RollbackVerified -ne $true
            ) {
                return [PSCustomObject]@{ Valid = $false; Reason = "Verified rollback result is inconsistent." }
            }

            if (
                [string]::IsNullOrWhiteSpace($SourceSSID) -or
                [string]::IsNullOrWhiteSpace($RecoveryTargetSSID) -or
                [string]::IsNullOrWhiteSpace($PreRollbackSSID) -or
                [string]::IsNullOrWhiteSpace($RollbackTargetSSID) -or
                $SourceSSID -eq $RecoveryTargetSSID -or
                $RollbackTargetSSID -ne $SourceSSID -or
                $PreRollbackSSID -ne $RecoveryTargetSSID -or
                $PostRollbackSSID -ne $SourceSSID
            ) {
                return [PSCustomObject]@{ Valid = $false; Reason = "Verified rollback SSID context is inconsistent." }
            }
        }

        "ROLLBACK_EXECUTED_NOT_VERIFIED" {
            if (
                $Result.RollbackRequested -ne $true -or
                $Result.RollbackAuthorized -ne $true -or
                $Result.RollbackPerformed -ne $true -or
                $Result.RollbackVerified -ne $false
            ) {
                return [PSCustomObject]@{ Valid = $false; Reason = "Unverified rollback result is inconsistent." }
            }

            if (
                [string]::IsNullOrWhiteSpace($SourceSSID) -or
                [string]::IsNullOrWhiteSpace($RecoveryTargetSSID) -or
                [string]::IsNullOrWhiteSpace($PreRollbackSSID) -or
                [string]::IsNullOrWhiteSpace($RollbackTargetSSID) -or
                $SourceSSID -eq $RecoveryTargetSSID -or
                $RollbackTargetSSID -ne $SourceSSID -or
                $PreRollbackSSID -ne $RecoveryTargetSSID -or
                $PostRollbackSSID -eq $SourceSSID
            ) {
                return [PSCustomObject]@{ Valid = $false; Reason = "Unverified rollback SSID context is inconsistent." }
            }
        }
    }

    return [PSCustomObject]@{ Valid = $true; Reason = "VALID" }
}

function Invoke-PrintSwitchRollbackActuator {
    [CmdletBinding()]
    param (
        [AllowNull()]
        [object]$RollbackExecutionRequest,

        [Parameter(Mandatory)]
        [scriptblock]$NetworkManagerInvoker
    )

    if ($null -eq $RollbackExecutionRequest) {
        return New-PrintSwitchRollbackActuatorResult `
            -ReasonCode "ROLLBACK_ACTUATOR_REQUEST_INVALID" `
            -Reason "Rollback execution request is missing." `
            -RollbackExecutionRequest $null
    }

    $RequestValidation =
        Test-PrintSwitchRollbackExecutionResult `
            -Result $RollbackExecutionRequest

    if ($RequestValidation.Valid -ne $true) {
        return New-PrintSwitchRollbackActuatorResult `
            -ReasonCode "ROLLBACK_ACTUATOR_REQUEST_INVALID" `
            -Reason ("Rollback execution request is invalid: {0}" -f $RequestValidation.Reason) `
            -RollbackExecutionRequest $RollbackExecutionRequest
    }

    $Requested = [bool]$RollbackExecutionRequest.RollbackRequested
    $Authorized = [bool]$RollbackExecutionRequest.RollbackAuthorized
    $SourceSSID = [string]$RollbackExecutionRequest.SourceSSID
    $RecoveryTargetSSID = [string]$RollbackExecutionRequest.TargetSSID
    $PreRollbackSSID = [string]$RollbackExecutionRequest.PreRollbackSSID
    $RollbackTargetSSID = [string]$RollbackExecutionRequest.RollbackTargetSSID
    $CorrelationId = [string]$RollbackExecutionRequest.CorrelationId

    if (-not $Requested -or -not $Authorized) {
        return New-PrintSwitchRollbackActuatorResult `
            -RollbackRequested $Requested `
            -RollbackAuthorized $false `
            -RollbackPerformed $false `
            -RollbackVerified $false `
            -SourceSSID $SourceSSID `
            -RecoveryTargetSSID $RecoveryTargetSSID `
            -PreRollbackSSID $PreRollbackSSID `
            -PostRollbackSSID $PreRollbackSSID `
            -RollbackTargetSSID $RollbackTargetSSID `
            -CorrelationId $CorrelationId `
            -ReasonCode "ROLLBACK_ACTUATOR_NOT_AUTHORIZED" `
            -Reason "Rollback execution request is not authorized for automatic actuation." `
            -RollbackExecutionRequest $RollbackExecutionRequest
    }

    $NetworkResult = $null

    try {
        $NetworkResult = & $NetworkManagerInvoker $RollbackTargetSSID
    }
    catch {
        return New-PrintSwitchRollbackActuatorResult `
            -RollbackRequested $true `
            -RollbackAuthorized $true `
            -RollbackPerformed $false `
            -RollbackVerified $false `
            -SourceSSID $SourceSSID `
            -RecoveryTargetSSID $RecoveryTargetSSID `
            -PreRollbackSSID $PreRollbackSSID `
            -PostRollbackSSID $PreRollbackSSID `
            -RollbackTargetSSID $RollbackTargetSSID `
            -CorrelationId $CorrelationId `
            -ReasonCode "ROLLBACK_NETWORK_MANAGER_FAILED" `
            -Reason ("NetworkManager invoker failed: {0}" -f $_.Exception.Message) `
            -RollbackExecutionRequest $RollbackExecutionRequest
    }

    $SwitchRequested =
        Get-PrintSwitchRollbackActuatorPropertyValue `
            -Object $NetworkResult `
            -Name "SwitchRequested"

    $SwitchAuthorized =
        Get-PrintSwitchRollbackActuatorPropertyValue `
            -Object $NetworkResult `
            -Name "SwitchAuthorized"

    $SwitchVerified =
        Get-PrintSwitchRollbackActuatorPropertyValue `
            -Object $NetworkResult `
            -Name "SwitchVerified"

    $FinalSSID =
        [string](Get-PrintSwitchRollbackActuatorPropertyValue `
            -Object $NetworkResult `
            -Name "FinalSSID")

    $Classification =
        [string](Get-PrintSwitchRollbackActuatorPropertyValue `
            -Object $NetworkResult `
            -Name "Classification")

    if (
        $SwitchRequested -isnot [bool] -or
        $SwitchAuthorized -isnot [bool] -or
        $SwitchVerified -isnot [bool]
    ) {
        return New-PrintSwitchRollbackActuatorResult `
            -RollbackRequested $true `
            -RollbackAuthorized $true `
            -RollbackPerformed $false `
            -RollbackVerified $false `
            -SourceSSID $SourceSSID `
            -RecoveryTargetSSID $RecoveryTargetSSID `
            -PreRollbackSSID $PreRollbackSSID `
            -PostRollbackSSID $PreRollbackSSID `
            -RollbackTargetSSID $RollbackTargetSSID `
            -CorrelationId $CorrelationId `
            -NetworkManagerClassification $Classification `
            -NetworkManagerSnapshot $NetworkResult `
            -ReasonCode "ROLLBACK_NETWORK_MANAGER_FAILED" `
            -Reason "NetworkManager result is missing required Boolean execution fields." `
            -RollbackExecutionRequest $RollbackExecutionRequest
    }

    $Performed = ($SwitchRequested -eq $true -and $SwitchAuthorized -eq $true)

    if (-not $Performed) {
        return New-PrintSwitchRollbackActuatorResult `
            -RollbackRequested $true `
            -RollbackAuthorized $true `
            -RollbackPerformed $false `
            -RollbackVerified $false `
            -SourceSSID $SourceSSID `
            -RecoveryTargetSSID $RecoveryTargetSSID `
            -PreRollbackSSID $PreRollbackSSID `
            -PostRollbackSSID $PreRollbackSSID `
            -RollbackTargetSSID $RollbackTargetSSID `
            -CorrelationId $CorrelationId `
            -NetworkManagerClassification $Classification `
            -NetworkManagerSnapshot $NetworkResult `
            -ReasonCode "ROLLBACK_NETWORK_MANAGER_FAILED" `
            -Reason "NetworkManager did not report an authorized switch attempt." `
            -RollbackExecutionRequest $RollbackExecutionRequest
    }

    $Verified = (
        $SwitchVerified -eq $true -and
        -not [string]::IsNullOrWhiteSpace($FinalSSID) -and
        $FinalSSID -eq $RollbackTargetSSID
    )

    if ($Verified) {
        return New-PrintSwitchRollbackActuatorResult `
            -RollbackRequested $true `
            -RollbackAuthorized $true `
            -RollbackPerformed $true `
            -RollbackVerified $true `
            -SourceSSID $SourceSSID `
            -RecoveryTargetSSID $RecoveryTargetSSID `
            -PreRollbackSSID $PreRollbackSSID `
            -PostRollbackSSID $FinalSSID `
            -RollbackTargetSSID $RollbackTargetSSID `
            -CorrelationId $CorrelationId `
            -NetworkManagerClassification $Classification `
            -NetworkManagerSnapshot $NetworkResult `
            -ReasonCode "ROLLBACK_EXECUTED_AND_VERIFIED" `
            -Reason "Rollback switch was executed and verified at the source SSID." `
            -RollbackExecutionRequest $RollbackExecutionRequest
    }

    if ([string]::IsNullOrWhiteSpace($FinalSSID)) {
        $FinalSSID = $PreRollbackSSID
    }

    return New-PrintSwitchRollbackActuatorResult `
        -RollbackRequested $true `
        -RollbackAuthorized $true `
        -RollbackPerformed $true `
        -RollbackVerified $false `
        -SourceSSID $SourceSSID `
        -RecoveryTargetSSID $RecoveryTargetSSID `
        -PreRollbackSSID $PreRollbackSSID `
        -PostRollbackSSID $FinalSSID `
        -RollbackTargetSSID $RollbackTargetSSID `
        -CorrelationId $CorrelationId `
        -NetworkManagerClassification $Classification `
        -NetworkManagerSnapshot $NetworkResult `
        -ReasonCode "ROLLBACK_EXECUTED_NOT_VERIFIED" `
        -Reason "Rollback switch was attempted but the source SSID was not verified." `
        -RollbackExecutionRequest $RollbackExecutionRequest
}
