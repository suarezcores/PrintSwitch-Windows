Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# PrintSwitch-Windows
# QueueJobClassifier
#
# Responsibility:
#   Windows Print Job
#       ->
#   QueueJobContext v1
#
# Guarantees:
# - Deterministic normalization
# - Contract validation
# - No queue mutation
# - No network mutation
# - No recovery authorization
# - No policy execution
# ============================================================

$script:QueueJobClassifierVersion = "0.1"
$script:QueueJobContextSchemaVersion = 1

$script:QueueJobOriginValues =
    @(
        "PREEXISTING",
        "NEW",
        "UNKNOWN"
    )

$script:QueueJobAgeValues =
    @(
        "FRESH",
        "AGING",
        "STALE",
        "UNKNOWN"
    )

$script:QueueJobHealthValues =
    @(
        "NORMAL",
        "ERROR",
        "UNKNOWN"
    )

$script:QueueJobProgressValues =
    @(
        "NO_PROGRESS",
        "PARTIAL_PROGRESS",
        "COMPLETE",
        "UNKNOWN"
    )

$script:QueueJobSummaryValues =
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

# ============================================================
# INTERNAL PROPERTY READER
# ============================================================

function Get-PrintSwitchJobPropertyValue {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Job,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $Property =
        $Job.PSObject.Properties[$Name]

    if ($null -eq $Property) {
        return $null
    }

    return $Property.Value
}

# ============================================================
# QUEUE JOB NORMALIZER
# ============================================================

function ConvertTo-PrintSwitchQueueJobContext {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Job,

        [Parameter(Mandatory)]
        [datetime]$ObservationStartedAt,

        [string]$PrinterName,

        [double]$FreshThresholdMinutes = 2,

        [double]$StaleThresholdMinutes = 15
    )

    if ($FreshThresholdMinutes -lt 0) {
        throw "FreshThresholdMinutes no puede ser negativo."
    }

    if ($StaleThresholdMinutes -le $FreshThresholdMinutes) {
        throw "StaleThresholdMinutes debe ser mayor que FreshThresholdMinutes."
    }

    # --------------------------------------------------------
    # RAW VALUES
    # --------------------------------------------------------

    $JobId =
        Get-PrintSwitchJobPropertyValue `
            -Job $Job `
            -Name "ID"

    if ($null -eq $JobId) {

        $JobId =
            Get-PrintSwitchJobPropertyValue `
                -Job $Job `
                -Name "JobId"
    }

    $JobPrinterName =
        Get-PrintSwitchJobPropertyValue `
            -Job $Job `
            -Name "PrinterName"

    $ResolvedPrinterName =
        if (
            -not [string]::IsNullOrWhiteSpace(
                [string]$JobPrinterName
            )
        ) {
            [string]$JobPrinterName
        }
        elseif (
            -not [string]::IsNullOrWhiteSpace(
                [string]$PrinterName
            )
        ) {
            [string]$PrinterName
        }
        else {
            $null
        }

    $DocumentName =
        Get-PrintSwitchJobPropertyValue `
            -Job $Job `
            -Name "DocumentName"

    if ($null -eq $DocumentName) {

        $DocumentName =
            Get-PrintSwitchJobPropertyValue `
                -Job $Job `
                -Name "Document"
    }

    $SubmittedTimeRaw =
        Get-PrintSwitchJobPropertyValue `
            -Job $Job `
            -Name "SubmittedTime"

    if ($null -eq $SubmittedTimeRaw) {

        $SubmittedTimeRaw =
            Get-PrintSwitchJobPropertyValue `
                -Job $Job `
                -Name "TimeSubmitted"
    }

    $RawJobStatusValue =
        Get-PrintSwitchJobPropertyValue `
            -Job $Job `
            -Name "JobStatus"

    $PagesPrintedRaw =
        Get-PrintSwitchJobPropertyValue `
            -Job $Job `
            -Name "PagesPrinted"

    $TotalPagesRaw =
        Get-PrintSwitchJobPropertyValue `
            -Job $Job `
            -Name "TotalPages"

    $SizeRaw =
        Get-PrintSwitchJobPropertyValue `
            -Job $Job `
            -Name "Size"

    $RawJobStatus =
        if ($null -eq $RawJobStatusValue) {
            $null
        }
        else {
            [string]$RawJobStatusValue
        }

    $NormalizedStatus =
        if ([string]::IsNullOrWhiteSpace($RawJobStatus)) {
            ""
        }
        else {
            $RawJobStatus.ToUpperInvariant()
        }

    # --------------------------------------------------------
    # SAFE TYPE NORMALIZATION
    # --------------------------------------------------------

    $SubmittedTime =
        if ($null -eq $SubmittedTimeRaw) {

            $null
        }
        else {

            try {
                [datetime]$SubmittedTimeRaw
            }
            catch {
                $null
            }
        }

    $PagesPrinted =
        if ($null -eq $PagesPrintedRaw) {

            $null
        }
        else {

            try {
                [int]$PagesPrintedRaw
            }
            catch {
                $null
            }
        }

    $TotalPages =
        if ($null -eq $TotalPagesRaw) {

            $null
        }
        else {

            try {
                [int]$TotalPagesRaw
            }
            catch {
                $null
            }
        }

    $SizeBytes =
        if ($null -eq $SizeRaw) {

            $null
        }
        else {

            try {
                [int64]$SizeRaw
            }
            catch {
                $null
            }
        }

    # --------------------------------------------------------
    # LIFECYCLE FLAGS
    # --------------------------------------------------------

    $Flags =
        [PSCustomObject]@{

            Printing =
                (
                    $NormalizedStatus -match '\bPRINTING\b' -or
                    $NormalizedStatus -match 'IMPRIMIENDO'
                )

            Retained =
                $NormalizedStatus -match '\bRETAINED\b'

            Paused =
                (
                    $NormalizedStatus -match '\bPAUSED\b' -or
                    $NormalizedStatus -match 'PAUSADO'
                )

            Deleting =
                (
                    $NormalizedStatus -match '\bDELETING\b' -or
                    $NormalizedStatus -match 'ELIMINANDO'
                )

            Offline =
                (
                    $NormalizedStatus -match '\bOFFLINE\b' -or
                    $NormalizedStatus -match 'SIN CONEXION'
                )

            Error =
                $NormalizedStatus -match '\bERROR\b'
        }

    # --------------------------------------------------------
    # ORIGIN
    # --------------------------------------------------------

    $Origin =
        if ($null -eq $SubmittedTime) {

            "UNKNOWN"
        }
        elseif ($SubmittedTime -lt $ObservationStartedAt) {

            "PREEXISTING"
        }
        else {

            "NEW"
        }

    # --------------------------------------------------------
    # AGE
    # --------------------------------------------------------

    $AgeMinutes =
        if ($null -eq $SubmittedTime) {

            $null
        }
        else {

            (
                $ObservationStartedAt -
                $SubmittedTime
            ).TotalMinutes
        }

    $AgeBucket =
        if ($null -eq $AgeMinutes) {

            "UNKNOWN"
        }
        elseif ($AgeMinutes -le $FreshThresholdMinutes) {

            "FRESH"
        }
        elseif ($AgeMinutes -le $StaleThresholdMinutes) {

            "AGING"
        }
        else {

            "STALE"
        }

    # --------------------------------------------------------
    # HEALTH
    # --------------------------------------------------------

    $Health =
        if ($Flags.Error) {

            "ERROR"
        }
        elseif ([string]::IsNullOrWhiteSpace($RawJobStatus)) {

            "UNKNOWN"
        }
        else {

            "NORMAL"
        }

    # --------------------------------------------------------
    # PROGRESS
    # --------------------------------------------------------

    $Progress =
        if (
            $null -eq $PagesPrinted -or
            $null -eq $TotalPages -or
            $TotalPages -le 0
        ) {

            "UNKNOWN"
        }
        elseif ($PagesPrinted -le 0) {

            "NO_PROGRESS"
        }
        elseif ($PagesPrinted -lt $TotalPages) {

            "PARTIAL_PROGRESS"
        }
        else {

            "COMPLETE"
        }

    # --------------------------------------------------------
    # SUMMARY CLASSIFICATION
    #
    # Precedence is contractually defined in QueueJobContext v1.
    # --------------------------------------------------------

    $SummaryClassification =
        if ($Flags.Deleting) {

            "TRANSITIONING"
        }
        elseif ($Flags.Paused) {

            "PAUSED"
        }
        elseif (
            $Health -eq "ERROR" -and
            $AgeBucket -eq "STALE" -and
            $Progress -eq "NO_PROGRESS"
        ) {

            "STALLED_ERROR"
        }
        elseif ($Health -eq "ERROR") {

            "ERROR_ACTIVE"
        }
        elseif ($Progress -eq "PARTIAL_PROGRESS") {

            "PROGRESSING"
        }
        elseif (
            $Flags.Printing -and
            $Progress -eq "NO_PROGRESS"
        ) {

            "PRINTING_UNCONFIRMED"
        }
        elseif (
            $AgeBucket -eq "STALE" -and
            $Progress -eq "NO_PROGRESS"
        ) {

            "STALLED_NO_ERROR"
        }
        elseif ($Progress -eq "COMPLETE") {

            "COMPLETE"
        }
        else {

            "ACTIVE_OR_QUEUED"
        }

    # --------------------------------------------------------
    # OUTPUT
    # --------------------------------------------------------

    return [PSCustomObject]@{

        SchemaVersion =
            $script:QueueJobContextSchemaVersion

        JobId =
            if ($null -eq $JobId) {
                $null
            }
            else {
                [int64]$JobId
            }

        PrinterName =
            if ($null -eq $ResolvedPrinterName) {
                $null
            }
            else {
                [string]$ResolvedPrinterName
            }

        DocumentName =
            if ($null -eq $DocumentName) {
                $null
            }
            else {
                [string]$DocumentName
            }

        SubmittedTime =
            $SubmittedTime

        Raw =
            [PSCustomObject]@{

                JobStatus =
                    $RawJobStatus

                PagesPrinted =
                    $PagesPrinted

                TotalPages =
                    $TotalPages

                SizeBytes =
                    $SizeBytes
            }

        Origin =
            $Origin

        Age =
            [PSCustomObject]@{

                Bucket =
                    $AgeBucket

                Minutes =
                    if ($null -eq $AgeMinutes) {
                        $null
                    }
                    else {
                        [math]::Round(
                            $AgeMinutes,
                            2
                        )
                    }
            }

        Health =
            $Health

        Progress =
            $Progress

        Flags =
            $Flags

        SummaryClassification =
            $SummaryClassification
    }
}

# ============================================================
# QUEUE JOB CONTRACT VALIDATOR
# ============================================================

function Test-PrintSwitchQueueJobContextContract {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Context
    )

    $Errors =
        @()

    if ($null -eq $Context) {

        return [PSCustomObject]@{
            Valid       = $false
            ErrorCount  = 1
            Errors      = @("CONTEXT_NULL")
        }
    }

    # --------------------------------------------------------
    # REQUIRED ROOT PROPERTIES
    # --------------------------------------------------------

    $RequiredRoot =
        @(
            "SchemaVersion",
            "JobId",
            "PrinterName",
            "DocumentName",
            "SubmittedTime",
            "Raw",
            "Origin",
            "Age",
            "Health",
            "Progress",
            "Flags",
            "SummaryClassification"
        )

    foreach ($Name in $RequiredRoot) {

        if (
            $Context.PSObject.Properties.Name -notcontains
            $Name
        ) {

            $Errors +=
                "MISSING_PROPERTY:$Name"
        }
    }

    if ($Errors.Count -gt 0) {

        return [PSCustomObject]@{
            Valid       = $false
            ErrorCount  = $Errors.Count
            Errors      = @($Errors)
        }
    }

    # --------------------------------------------------------
    # ROOT CONTRACT
    # --------------------------------------------------------

    if ($Context.SchemaVersion -ne 1) {
        $Errors +=
            "INVALID_SCHEMA_VERSION"
    }

    if ($null -eq $Context.JobId) {
        $Errors +=
            "JOB_ID_MISSING"
    }

    if ([string]::IsNullOrWhiteSpace([string]$Context.PrinterName)) {
        $Errors +=
            "PRINTER_NAME_MISSING"
    }

    if (
        $script:QueueJobOriginValues -notcontains
        [string]$Context.Origin
    ) {
        $Errors +=
            "INVALID_ORIGIN"
    }

    if (
        $script:QueueJobHealthValues -notcontains
        [string]$Context.Health
    ) {
        $Errors +=
            "INVALID_HEALTH"
    }

    if (
        $script:QueueJobProgressValues -notcontains
        [string]$Context.Progress
    ) {
        $Errors +=
            "INVALID_PROGRESS"
    }

    if (
        $script:QueueJobSummaryValues -notcontains
        [string]$Context.SummaryClassification
    ) {
        $Errors +=
            "INVALID_SUMMARY"
    }

    # --------------------------------------------------------
    # NESTED OBJECTS
    # --------------------------------------------------------

    if ($null -eq $Context.Raw) {

        $Errors +=
            "RAW_NULL"
    }
    else {

        foreach (
            $Name in @(
                "JobStatus",
                "PagesPrinted",
                "TotalPages",
                "SizeBytes"
            )
        ) {

            if (
                $Context.Raw.PSObject.Properties.Name -notcontains
                $Name
            ) {

                $Errors +=
                    "RAW_MISSING_PROPERTY:$Name"
            }
        }
    }

    if ($null -eq $Context.Age) {

        $Errors +=
            "AGE_NULL"
    }
    else {

        foreach (
            $Name in @(
                "Bucket",
                "Minutes"
            )
        ) {

            if (
                $Context.Age.PSObject.Properties.Name -notcontains
                $Name
            ) {

                $Errors +=
                    "AGE_MISSING_PROPERTY:$Name"
            }
        }

        if (
            $Context.Age.PSObject.Properties.Name -contains
            "Bucket"
        ) {

            if (
                $script:QueueJobAgeValues -notcontains
                [string]$Context.Age.Bucket
            ) {

                $Errors +=
                    "INVALID_AGE_BUCKET"
            }
        }
    }

    if ($null -eq $Context.Flags) {

        $Errors +=
            "FLAGS_NULL"
    }
    else {

        foreach (
            $Name in @(
                "Printing",
                "Retained",
                "Paused",
                "Deleting",
                "Offline",
                "Error"
            )
        ) {

            if (
                $Context.Flags.PSObject.Properties.Name -notcontains
                $Name
            ) {

                $Errors +=
                    "FLAGS_MISSING_PROPERTY:$Name"
            }
        }
    }

    # --------------------------------------------------------
    # INVARIANTS
    # --------------------------------------------------------

    if (
        $Context.SummaryClassification -eq
        "STALLED_ERROR"
    ) {

        if (
            -not (
                $Context.Health -eq "ERROR" -and
                $Context.Age.Bucket -eq "STALE" -and
                $Context.Progress -eq "NO_PROGRESS"
            )
        ) {

            $Errors +=
                "STALLED_ERROR_INVARIANT_BROKEN"
        }
    }

    if (
        $Context.Progress -eq "PARTIAL_PROGRESS" -and
        $Context.SummaryClassification -notin
        @(
            "PROGRESSING",
            "PAUSED",
            "TRANSITIONING",
            "ERROR_ACTIVE"
        )
    ) {

        $Errors +=
            "PARTIAL_PROGRESS_SUMMARY_INCONSISTENT"
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
