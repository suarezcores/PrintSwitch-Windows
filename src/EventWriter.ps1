Set-StrictMode -Version Latest

# ============================================================
# PrintSwitch - EventWriter v0.1
# Punto 7 - P7-A5.3.2
#
# Responsabilidad:
# - construir PrintSwitchEvent v1
# - serializarlo
# - persistirlo como JSON Lines
#
# No interpreta decisiones del Core.
# No modifica red.
# No depende de UI.
# ============================================================

$script:PrintSwitchEventVersion =
    1

function ConvertTo-PrintSwitchSerializableValue {

    [CmdletBinding()]
    param (
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {

        return $null
    }

    if ($Value -is [datetime]) {

        return ([datetime]$Value).ToString("o")
    }

    if ($Value -is [datetimeoffset]) {

        return ([datetimeoffset]$Value).ToString("o")
    }

    if (
        $Value -is [string] -or
        $Value -is [char] -or
        $Value -is [bool] -or
        $Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64] -or
        $Value -is [single] -or
        $Value -is [double] -or
        $Value -is [decimal]
    ) {

        return $Value
    }

    if ($Value -is [System.Collections.IDictionary]) {

        $DictionaryResult =
            [ordered]@{}

        foreach ($Key in $Value.Keys) {

            $DictionaryResult[[string]$Key] =
                ConvertTo-PrintSwitchSerializableValue `
                    -Value $Value[$Key]
        }

        return [PSCustomObject]$DictionaryResult
    }

    if (
        $Value -is [System.Collections.IEnumerable] -and
        $Value -isnot [string]
    ) {

        $Items =
            @()

        foreach ($Item in $Value) {

            $Items +=
                ConvertTo-PrintSwitchSerializableValue `
                    -Value $Item
        }

        return $Items
    }

    $Properties =
        @(
            $Value.PSObject.Properties |
            Where-Object {
                $_.MemberType -eq "NoteProperty" -or
                $_.MemberType -eq "Property"
            }
        )

    if ($Properties.Count -gt 0) {

        $ObjectResult =
            [ordered]@{}

        foreach ($Property in $Properties) {

            try {

                $ObjectResult[$Property.Name] =
                    ConvertTo-PrintSwitchSerializableValue `
                        -Value $Property.Value
            }
            catch {

                $ObjectResult[$Property.Name] =
                    $null
            }
        }

        return [PSCustomObject]$ObjectResult
    }

    return [string]$Value
}

function New-PrintSwitchEvent {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$EventType,

        [Parameter(Mandatory)]
        [string]$Source,

        [string]$PrinterName = $null,

        [string]$CorrelationId = $null,

        [ValidateSet(
            "DEBUG",
            "INFO",
            "WARNING",
            "ERROR"
        )]
        [string]$Severity = "INFO",

        [object]$Data = $null,

        [long]$SequenceNumber = 0
    )

    if ([string]::IsNullOrWhiteSpace($CorrelationId)) {

        $CorrelationId =
            [guid]::NewGuid().ToString()
    }

    $EventId =
        [guid]::NewGuid().ToString()

    return [PSCustomObject]@{

        Component =
            "PrintSwitchEvent"

        EventVersion =
            $script:PrintSwitchEventVersion

        EventId =
            $EventId

        SequenceNumber =
            $SequenceNumber

        EventType =
            $EventType

        Timestamp =
            (Get-Date).ToString("o")

        Source =
            $Source

        PrinterName =
            $PrinterName

        CorrelationId =
            $CorrelationId

        Severity =
            $Severity

        Data =
            $Data
    }
}

function Write-PrintSwitchEvent {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Event,

        [Parameter(Mandatory)]
        [string]$Path,

        [int]$Depth = 12
    )

    if ($null -eq $Event) {

        throw "Event no puede ser null."
    }

    if (
        -not (
            $Event.PSObject.Properties.Name -contains "Component"
        ) -or
        $Event.Component -ne "PrintSwitchEvent"
    ) {

        throw "Objeto incompatible con PrintSwitchEvent."
    }

    $Directory =
        Split-Path `
            $Path `
            -Parent

    if (
        -not [string]::IsNullOrWhiteSpace($Directory) -and
        -not (Test-Path $Directory)
    ) {

        New-Item `
            -ItemType Directory `
            -Path $Directory `
            -Force |
            Out-Null
    }

    $SerializableEvent =
        ConvertTo-PrintSwitchSerializableValue `
            -Value $Event

    $Json =
        $SerializableEvent |
        ConvertTo-Json `
            -Depth $Depth `
            -Compress

    [System.IO.File]::AppendAllText(
        $Path,
        $Json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    return [PSCustomObject]@{

        Component =
            "EventWriter"

        Version =
            "0.1"

        Success =
            $true

        Path =
            $Path

        EventId =
            $Event.EventId

        EventType =
            $Event.EventType

        CorrelationId =
            $Event.CorrelationId

        Timestamp =
            Get-Date
    }
}

function Read-PrintSwitchEvents {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [int]$MaxEvents = 0
    )

    if (-not (Test-Path $Path)) {

        return @()
    }

    $Lines =
        @(
            Get-Content `
                $Path `
                -Encoding UTF8 |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
        )

    if (
        $MaxEvents -gt 0 -and
        $Lines.Count -gt $MaxEvents
    ) {

        $StartIndex =
            $Lines.Count - $MaxEvents

        $Lines =
            @(
                $Lines[
                    $StartIndex..($Lines.Count - 1)
                ]
            )
    }

    $Events =
        @()

    foreach ($Line in $Lines) {

        try {

            $Decoded =
                $Line |
                ConvertFrom-Json `
                    -ErrorAction Stop

            $Events +=
                $Decoded
        }
        catch {

            $Events +=
                [PSCustomObject]@{

                    Component =
                        "PrintSwitchEventReadError"

                    RawLine =
                        $Line

                    Error =
                        $_.Exception.Message
                }
        }
    }

    return $Events
}

function Test-PrintSwitchEventContract {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Event
    )

    $RequiredFields =
        @(
            "Component",
            "EventVersion",
            "EventId",
            "SequenceNumber",
            "EventType",
            "Timestamp",
            "Source",
            "PrinterName",
            "CorrelationId",
            "Severity",
            "Data"
        )

    $Missing =
        @()

    foreach ($Field in $RequiredFields) {

        if (
            -not (
                $Event.PSObject.Properties.Name -contains $Field
            )
        ) {

            $Missing +=
                $Field
        }
    }

    $Valid =
        (
            $Missing.Count -eq 0 -and
            $Event.Component -eq "PrintSwitchEvent" -and
            [int]$Event.EventVersion -eq 1
        )

    return [PSCustomObject]@{

        Component =
            "EventContractValidator"

        Valid =
            $Valid

        MissingFields =
            $Missing

        EventType =
            if (
                $Event.PSObject.Properties.Name -contains "EventType"
            ) {
                $Event.EventType
            }
            else {
                $null
            }

        EventId =
            if (
                $Event.PSObject.Properties.Name -contains "EventId"
            ) {
                $Event.EventId
            }
            else {
                $null
            }
    }
}
