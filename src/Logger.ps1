param (
    [string]$LogDirectory = (
        Join-Path `
            (Split-Path $PSScriptRoot -Parent) `
            "logs"
    )
)

# ============================================================
# PrintSwitch - Logger v0.1
#
# Provee una funcion comun de logging persistente.
# No modifica red, configuracion ni estado de impresion.
# ============================================================

function Write-PrintSwitchLog {

    param (
        [Parameter(Mandatory = $true)]
        [string]$Component,

        [Parameter(Mandatory = $true)]
        [string]$Event,

        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO",

        [hashtable]$Data
    )

    # --------------------------------------------------------
    # Crear carpeta de logs si no existe
    # --------------------------------------------------------

    if (-not (Test-Path $LogDirectory)) {

        New-Item `
            -ItemType Directory `
            -Path $LogDirectory `
            -Force |
            Out-Null
    }

    # --------------------------------------------------------
    # Archivo diario
    # --------------------------------------------------------

    $DateString = Get-Date -Format "yyyy-MM-dd"

    $LogFile = Join-Path `
        $LogDirectory `
        "PrintSwitch-$DateString.log"

    # --------------------------------------------------------
    # Construir linea
    # --------------------------------------------------------

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $Parts = @(
        $Timestamp
        $Level
        $Component
        $Event
    )

    if ($null -ne $Data) {

        foreach ($Key in ($Data.Keys | Sort-Object)) {

            $Value = $Data[$Key]

            if ($null -ne $Value) {

                $CleanValue = (
                    [string]$Value
                ).Replace(
                    "`r",
                    " "
                ).Replace(
                    "`n",
                    " "
                )

                $Parts += "$Key=$CleanValue"
            }
        }
    }

    $LogLine = $Parts -join " | "

    # --------------------------------------------------------
    # Escribir
    # --------------------------------------------------------

    try {

        Add-Content `
            -Path $LogFile `
            -Value $LogLine `
            -Encoding UTF8 `
            -ErrorAction Stop

        return [PSCustomObject]@{

            Component = "Logger"
            Version   = "0.1"

            Success   = $true
            LogFile   = $LogFile
            LogLine   = $LogLine
        }
    }
    catch {

        return [PSCustomObject]@{

            Component = "Logger"
            Version   = "0.1"

            Success   = $false
            LogFile   = $LogFile
            LogLine   = $LogLine
            Error     = $_.Exception.Message
        }
    }
}