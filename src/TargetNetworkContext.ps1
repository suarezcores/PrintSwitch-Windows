Set-StrictMode -Version Latest

function New-PrintSwitchTargetNetworkContextResult {
    param (
        [bool]$ResolutionRequested,
        [bool]$ResolutionPerformed,
        [bool]$Resolved,
        [AllowNull()]
        [string]$PrinterName,
        [AllowNull()]
        [string]$TargetSSID,
        [string]$ReasonCode,
        [string]$Reason,
        [AllowNull()]
        [string]$Source
    )

    [PSCustomObject]@{
        Component           = "TargetNetworkContext"
        SchemaVersion       = 1
        ResolutionRequested = $ResolutionRequested
        ResolutionPerformed = $ResolutionPerformed
        Resolved            = $Resolved
        PrinterName         = $PrinterName
        TargetSSID          = $TargetSSID
        ReasonCode          = $ReasonCode
        Reason              = $Reason
        Source              = $Source
    }
}

function Get-PrintSwitchTargetNetworkContext {
    param (
        [AllowNull()]
        [string]$PrinterName,

        [string]$ConfigPath = (
            Join-Path `
                (Split-Path $PSScriptRoot -Parent) `
                "config\printers.json"
        )
    )

    $RequestedPrinterName = $PrinterName

    if ([string]::IsNullOrWhiteSpace($RequestedPrinterName)) {
        return New-PrintSwitchTargetNetworkContextResult `
            -ResolutionRequested $true `
            -ResolutionPerformed $false `
            -Resolved $false `
            -PrinterName $RequestedPrinterName `
            -TargetSSID $null `
            -ReasonCode "PRINTER_NAME_MISSING" `
            -Reason "PrinterName is required to resolve target network context." `
            -Source $ConfigPath
    }

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        return New-PrintSwitchTargetNetworkContextResult `
            -ResolutionRequested $true `
            -ResolutionPerformed $false `
            -Resolved $false `
            -PrinterName $RequestedPrinterName `
            -TargetSSID $null `
            -ReasonCode "CONFIG_PATH_MISSING" `
            -Reason "ConfigPath is empty." `
            -Source $ConfigPath
    }

    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        return New-PrintSwitchTargetNetworkContextResult `
            -ResolutionRequested $true `
            -ResolutionPerformed $false `
            -Resolved $false `
            -PrinterName $RequestedPrinterName `
            -TargetSSID $null `
            -ReasonCode "CONFIG_NOT_FOUND" `
            -Reason "Printer configuration file was not found." `
            -Source $ConfigPath
    }

    try {
        $Config = Get-Content `
            -LiteralPath $ConfigPath `
            -Raw `
            -ErrorAction Stop |
        ConvertFrom-Json `
            -ErrorAction Stop
    }
    catch {
        return New-PrintSwitchTargetNetworkContextResult `
            -ResolutionRequested $true `
            -ResolutionPerformed $true `
            -Resolved $false `
            -PrinterName $RequestedPrinterName `
            -TargetSSID $null `
            -ReasonCode "CONFIG_INVALID" `
            -Reason "Printer configuration could not be parsed as valid JSON." `
            -Source $ConfigPath
    }

    if (
        $null -eq $Config -or
        -not (
            @($Config.PSObject.Properties.Name) -contains
                "printers"
        )
    ) {
        return New-PrintSwitchTargetNetworkContextResult `
            -ResolutionRequested $true `
            -ResolutionPerformed $true `
            -Resolved $false `
            -PrinterName $RequestedPrinterName `
            -TargetSSID $null `
            -ReasonCode "PRINTERS_COLLECTION_MISSING" `
            -Reason "Configuration does not contain a printers collection." `
            -Source $ConfigPath
    }

    $Printers = @(
        $Config.printers |
        Where-Object {
            $null -ne $_
        }
    )

    if ($Printers.Count -eq 0) {
        return New-PrintSwitchTargetNetworkContextResult `
            -ResolutionRequested $true `
            -ResolutionPerformed $true `
            -Resolved $false `
            -PrinterName $RequestedPrinterName `
            -TargetSSID $null `
            -ReasonCode "PRINTERS_COLLECTION_EMPTY" `
            -Reason "Configuration contains an empty printers collection." `
            -Source $ConfigPath
    }

    $Matches = @(
        $Printers |
        Where-Object {
            $null -ne $_ -and
            @($_.PSObject.Properties.Name) -contains "name" -and
            [string]$_.name -eq $RequestedPrinterName
        }
    )

    if ($Matches.Count -eq 0) {
        return New-PrintSwitchTargetNetworkContextResult `
            -ResolutionRequested $true `
            -ResolutionPerformed $true `
            -Resolved $false `
            -PrinterName $RequestedPrinterName `
            -TargetSSID $null `
            -ReasonCode "PROFILE_NOT_FOUND" `
            -Reason "No printer profile matches the requested PrinterName." `
            -Source $ConfigPath
    }

    if ($Matches.Count -gt 1) {
        return New-PrintSwitchTargetNetworkContextResult `
            -ResolutionRequested $true `
            -ResolutionPerformed $true `
            -Resolved $false `
            -PrinterName $RequestedPrinterName `
            -TargetSSID $null `
            -ReasonCode "PROFILE_AMBIGUOUS" `
            -Reason "More than one printer profile matches the requested PrinterName." `
            -Source $ConfigPath
    }

    $Profile = $Matches[0]

    if (
        -not (
            @($Profile.PSObject.Properties.Name) -contains
                "requiredSSID"
        )
    ) {
        return New-PrintSwitchTargetNetworkContextResult `
            -ResolutionRequested $true `
            -ResolutionPerformed $true `
            -Resolved $false `
            -PrinterName $RequestedPrinterName `
            -TargetSSID $null `
            -ReasonCode "REQUIRED_SSID_MISSING" `
            -Reason "Printer profile does not contain requiredSSID." `
            -Source $ConfigPath
    }

    $TargetSSID =
        [string]$Profile.requiredSSID

    if ([string]::IsNullOrWhiteSpace($TargetSSID)) {
        return New-PrintSwitchTargetNetworkContextResult `
            -ResolutionRequested $true `
            -ResolutionPerformed $true `
            -Resolved $false `
            -PrinterName $RequestedPrinterName `
            -TargetSSID $null `
            -ReasonCode "REQUIRED_SSID_MISSING" `
            -Reason "Printer profile requiredSSID is empty." `
            -Source $ConfigPath
    }

    return New-PrintSwitchTargetNetworkContextResult `
        -ResolutionRequested $true `
        -ResolutionPerformed $true `
        -Resolved $true `
        -PrinterName $RequestedPrinterName `
        -TargetSSID $TargetSSID.Trim() `
        -ReasonCode "TARGET_NETWORK_RESOLVED" `
        -Reason "Target network context resolved from printer profile." `
        -Source $ConfigPath
}

function Test-PrintSwitchTargetNetworkContextResult {
    param (
        [AllowNull()]
        [object]$Result
    )

    if ($null -eq $Result) {
        return $false
    }

    $RequiredProperties = @(
        "Component",
        "SchemaVersion",
        "ResolutionRequested",
        "ResolutionPerformed",
        "Resolved",
        "PrinterName",
        "TargetSSID",
        "ReasonCode",
        "Reason",
        "Source"
    )

    $PropertyNames =
        @(
            $Result.PSObject.Properties |
            ForEach-Object {
                $_.Name
            }
        )

    foreach ($Property in $RequiredProperties) {
        if (-not ($PropertyNames -contains $Property)) {
            return $false
        }
    }

    if ([string]$Result.Component -ne "TargetNetworkContext") {
        return $false
    }

    if ([int]$Result.SchemaVersion -ne 1) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace([string]$Result.ReasonCode)) {
        return $false
    }

    if ([bool]$Result.Resolved) {
        if ([string]::IsNullOrWhiteSpace([string]$Result.PrinterName)) {
            return $false
        }

        if ([string]::IsNullOrWhiteSpace([string]$Result.TargetSSID)) {
            return $false
        }

        if ([string]$Result.ReasonCode -ne "TARGET_NETWORK_RESOLVED") {
            return $false
        }
    }

    return $true
}
