param (
    [string]$ConfigPath = (
        Join-Path `
            (Split-Path $PSScriptRoot -Parent) `
            "config\printers.json"
    )
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - ConfigValidator v0.1
#
# Valida config/printers.json
# No modifica configuraciones ni conectividad.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - ConfigValidator v0.1" `
    -ForegroundColor Cyan

Write-Host "Modo: VALIDACION DE CONFIGURACION" `
    -ForegroundColor Yellow

Write-Host ""
Write-Host "Archivo: $ConfigPath"

# ============================================================
# VARIABLES DE RESULTADO
# ============================================================

$Errors = @()
$Warnings = @()
$PrinterCount = 0

# ============================================================
# 1. EXISTENCIA DEL ARCHIVO
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "1. ARCHIVO DE CONFIGURACION"
Write-Host "========================================"

if (-not (Test-Path $ConfigPath)) {

    $Errors += "CONFIG_FILE_NOT_FOUND"

    Write-Host `
        "ERROR: no se encontro printers.json." `
        -ForegroundColor Red

}
else {

    Write-Host "Archivo encontrado : True"
}

# ============================================================
# 2. LEER JSON
# ============================================================

$Config = $null

if ($Errors.Count -eq 0) {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "2. SINTAXIS JSON"
    Write-Host "========================================"

    try {

        $Config = Get-Content `
            $ConfigPath `
            -Raw `
            -ErrorAction Stop |
            ConvertFrom-Json `
                -ErrorAction Stop

        Write-Host "JSON valido : True"
    }
    catch {

        $Errors += "INVALID_JSON"

        Write-Host `
            "JSON valido : False" `
            -ForegroundColor Red

        Write-Host $_.Exception.Message
    }
}

# ============================================================
# 3. VALIDAR COLECCION printers
# ============================================================

$Printers = @()

if ($null -ne $Config) {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "3. COLECCION DE IMPRESORAS"
    Write-Host "========================================"

    if ($null -eq $Config.printers) {

        $Errors += "PRINTERS_COLLECTION_MISSING"

        Write-Host `
            "ERROR: falta la propiedad 'printers'." `
            -ForegroundColor Red

    }
    else {

        $Printers = @($Config.printers)
        $PrinterCount = $Printers.Count

        Write-Host "Perfiles encontrados : $PrinterCount"

        if ($PrinterCount -eq 0) {

            $Errors += "NO_PRINTER_PROFILES"

            Write-Host `
                "ERROR: no existen perfiles de impresora." `
                -ForegroundColor Red
        }
    }
}

# ============================================================
# 4. VALIDAR CADA PERFIL
# ============================================================

$SeenNames = @{}

if ($PrinterCount -gt 0) {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "4. VALIDACION DE PERFILES"
    Write-Host "========================================"

    for ($Index = 0; $Index -lt $Printers.Count; $Index++) {

        $Printer = $Printers[$Index]

        Write-Host ""
        Write-Host "Perfil [$Index]"

        $Name = [string]$Printer.name
        $IP = [string]$Printer.ip
        $RequiredSSID = [string]$Printer.requiredSSID

        # ----------------------------------------------------
        # NAME
        # ----------------------------------------------------

        if ([string]::IsNullOrWhiteSpace($Name)) {

            $Errors += "PROFILE_${Index}_NAME_MISSING"

            Write-Host `
                "name         : INVALIDO" `
                -ForegroundColor Red

        }
        else {

            Write-Host "name         : $Name"

            if ($SeenNames.ContainsKey($Name)) {

                $Errors += "DUPLICATE_PRINTER_NAME:$Name"

                Write-Host `
                    "ERROR: nombre de impresora duplicado." `
                    -ForegroundColor Red
            }
            else {

                $SeenNames[$Name] = $true
            }
        }

        # ----------------------------------------------------
        # IP
        # ----------------------------------------------------

        if ([string]::IsNullOrWhiteSpace($IP)) {

            $Errors += "PROFILE_${Index}_IP_MISSING"

            Write-Host `
                "ip           : INVALIDO" `
                -ForegroundColor Red

        }
        else {

            $ParsedIP = $null

            $IPValid = [System.Net.IPAddress]::TryParse(
                $IP,
                [ref]$ParsedIP
            )

            if (-not $IPValid) {

                $Errors += "PROFILE_${Index}_IP_INVALID:$IP"

                Write-Host `
                    "ip           : $IP [INVALIDA]" `
                    -ForegroundColor Red
            }
            else {

                Write-Host "ip           : $IP"
            }
        }

        # ----------------------------------------------------
        # REQUIRED SSID
        # ----------------------------------------------------

        if ([string]::IsNullOrWhiteSpace($RequiredSSID)) {

            $Errors += "PROFILE_${Index}_SSID_MISSING"

            Write-Host `
                "requiredSSID : INVALIDO" `
                -ForegroundColor Red

        }
        else {

            Write-Host "requiredSSID : $RequiredSSID"
        }
    }
}

# ============================================================
# 5. RESULTADO
# ============================================================

$IsValid = ($Errors.Count -eq 0)

if ($IsValid) {

    $Classification = "CONFIG_VALID"

}
else {

    $Classification = "CONFIG_INVALID"
}

$ValidationResult = [PSCustomObject]@{

    Component =
        "ConfigValidator"

    Version =
        "0.1"

    Timestamp =
        Get-Date

    ConfigPath =
        $ConfigPath

    IsValid =
        $IsValid

    PrinterCount =
        $PrinterCount

    ErrorCount =
        $Errors.Count

    WarningCount =
        $Warnings.Count

    Classification =
        $Classification

    Errors =
        $Errors

    Warnings =
        $Warnings
}

# ============================================================
# 6. RESUMEN
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "6. RESULTADO ESTRUCTURADO"
Write-Host "========================================"

Write-Host "Component      : $($ValidationResult.Component)"
Write-Host "Version        : $($ValidationResult.Version)"
Write-Host "IsValid        : $($ValidationResult.IsValid)"
Write-Host "PrinterCount   : $($ValidationResult.PrinterCount)"
Write-Host "ErrorCount     : $($ValidationResult.ErrorCount)"
Write-Host "WarningCount   : $($ValidationResult.WarningCount)"
Write-Host "Classification : $($ValidationResult.Classification)"

if ($Errors.Count -gt 0) {

    Write-Host ""
    Write-Host "Errores:"

    foreach ($ErrorItem in $Errors) {

        Write-Host " - $ErrorItem" `
            -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host "FIN CONFIGVALIDATOR v0.1"
Write-Host "========================================"

# ============================================================
# UNICA SALIDA PROGRAMATICA
# ============================================================

$ValidationResult