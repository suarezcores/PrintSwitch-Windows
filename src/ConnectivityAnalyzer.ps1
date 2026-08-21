param (
    [string]$PrinterName,

    [string]$ConfigPath = (
        Join-Path `
            (Split-Path $PSScriptRoot -Parent) `
            "config\printers.json"
    )
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - ConnectivityAnalyzer v0.4
#
# Diagnostico no intrusivo.
# Configuracion externa mediante config/printers.json
#
# No modifica configuraciones de red.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - ConnectivityAnalyzer v0.4" `
    -ForegroundColor Cyan

Write-Host "Modo: DIAGNOSTICO NO INTRUSIVO" `
    -ForegroundColor Yellow

Write-Host `
    "Configuracion externa: $ConfigPath"

Write-Host ""

# ============================================================
# 0. CARGAR CONFIGURACION
# ============================================================

Write-Host "========================================"
Write-Host "0. CONFIGURACION"
Write-Host "========================================"

if (-not (Test-Path $ConfigPath)) {

    Write-Host `
        "ERROR: no se encontro el archivo de configuracion." `
        -ForegroundColor Red

    Write-Host "Ruta esperada: $ConfigPath"

    return
}

try {

    $Config = Get-Content `
        $ConfigPath `
        -Raw `
        -ErrorAction Stop |
        ConvertFrom-Json `
            -ErrorAction Stop

}
catch {

    Write-Host `
        "ERROR: no se pudo leer printers.json." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message

    return
}

if (
    $null -eq $Config.printers -or
    @($Config.printers).Count -eq 0
) {

    Write-Host `
        "ERROR: printers.json no contiene perfiles de impresora." `
        -ForegroundColor Red

    return
}

# ============================================================
# 0.1 SELECCIONAR PERFIL
# ============================================================

$PrinterProfile = $null

if ($PrinterName) {

    $PrinterProfile = @(
        $Config.printers |
            Where-Object {
                $_.name -eq $PrinterName
            }
    ) | Select-Object -First 1

    if ($null -eq $PrinterProfile) {

        Write-Host `
            "ERROR: no existe un perfil para '$PrinterName'." `
            -ForegroundColor Red

        return
    }

}
else {

    # Por ahora, si no se especifica una impresora,
    # se utiliza el primer perfil configurado.
    #
    # QueueWatcher sera posteriormente quien indique
    # explicitamente que perfil debe analizarse.

    $PrinterProfile = @($Config.printers)[0]
}

# ============================================================
# 0.2 VALIDAR PERFIL
# ============================================================

if (
    [string]::IsNullOrWhiteSpace(
        [string]$PrinterProfile.name
    )
) {

    Write-Host `
        "ERROR: el perfil no contiene 'name'." `
        -ForegroundColor Red

    return
}

if (
    [string]::IsNullOrWhiteSpace(
        [string]$PrinterProfile.ip
    )
) {

    Write-Host `
        "ERROR: el perfil no contiene 'ip'." `
        -ForegroundColor Red

    return
}

if (
    [string]::IsNullOrWhiteSpace(
        [string]$PrinterProfile.requiredSSID
    )
) {

    Write-Host `
        "ERROR: el perfil no contiene 'requiredSSID'." `
        -ForegroundColor Red

    return
}

# ============================================================
# 0.3 EXTRAER CONFIGURACION
# ============================================================

$PrinterName = [string]$PrinterProfile.name
$PrinterIP = [string]$PrinterProfile.ip
$RequiredSSID = [string]$PrinterProfile.requiredSSID

Write-Host "Perfil seleccionado:"
Write-Host "PrinterName  : $PrinterName"
Write-Host "PrinterIP    : $PrinterIP"
Write-Host "RequiredSSID : $RequiredSSID"

# ============================================================
# FUNCION: obtener SSID actual
# ============================================================

function Get-CurrentSSID {

    $InterfaceInfo = netsh wlan show interfaces

    $CurrentSSIDMatch = $InterfaceInfo |
        Select-String '^\s*SSID\s*:' |
        Select-Object -First 1

    if ($CurrentSSIDMatch) {

        $CurrentSSIDText = $CurrentSSIDMatch.ToString()

        $CurrentSSID = (
            $CurrentSSIDText.Split(":", 2)[1]
        ).Trim()

        return $CurrentSSID
    }

    return $null
}

# ============================================================
# 1. CONTEXTO DE RED
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "1. CONTEXTO DE RED"
Write-Host "========================================"

$WlanInfo = netsh wlan show interfaces

$WlanDisplay = $WlanInfo |
    Select-String `
        "Name|Nombre|State|Estado|SSID|BSSID|Signal|Señal|Radio"

foreach ($Line in $WlanDisplay) {

    Write-Host $Line.ToString()
}

$CurrentSSID = Get-CurrentSSID

# ============================================================
# 2. INFORMACION DE IMPRESORA - Get-Printer
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. INFORMACION DE IMPRESORA - Get-Printer"
Write-Host "========================================"

$PrinterStatus = $null
$PrinterJobCount = $null
$PrinterPortName = $null
$PrinterDriverName = $null

try {

    $PrinterInfo = Get-Printer `
        -Name $PrinterName `
        -ErrorAction Stop

    $PrinterStatus = $PrinterInfo.PrinterStatus
    $PrinterJobCount = $PrinterInfo.JobCount
    $PrinterPortName = $PrinterInfo.PortName
    $PrinterDriverName = $PrinterInfo.DriverName

    $PrinterDisplay = $PrinterInfo |
        Select-Object `
            Name,
            DriverName,
            PortName,
            PrinterStatus,
            JobCount,
            Shared,
            Published |
        Format-List |
        Out-String

    Write-Host $PrinterDisplay

}
catch {

    Write-Host `
        "No se pudo obtener informacion mediante Get-Printer."

    Write-Host $_.Exception.Message
}

# ============================================================
# 3. INFORMACION CIM - Win32_Printer
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. INFORMACION CIM - Win32_Printer"
Write-Host "========================================"

$CimPrinterStatus = $null
$ExtendedPrinterStatus = $null
$DetectedErrorState = $null
$WorkOffline = $null

try {

    $CimPrinter = Get-CimInstance Win32_Printer |
        Where-Object {
            $_.Name -eq $PrinterName
        }

    if ($CimPrinter) {

        $CimPrinterStatus =
            $CimPrinter.PrinterStatus

        $ExtendedPrinterStatus =
            $CimPrinter.ExtendedPrinterStatus

        $DetectedErrorState =
            $CimPrinter.DetectedErrorState

        $WorkOffline =
            $CimPrinter.WorkOffline

        $CimDisplay = $CimPrinter |
            Select-Object `
                Name,
                PrinterStatus,
                ExtendedPrinterStatus,
                DetectedErrorState,
                WorkOffline,
                PortName,
                DriverName |
            Format-List |
            Out-String

        Write-Host $CimDisplay
    }

}
catch {

    Write-Host `
        "No se pudo obtener informacion mediante CIM."

    Write-Host $_.Exception.Message
}

# ============================================================
# 4. TRABAJOS ACTUALES
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "4. TRABAJOS ACTUALES"
Write-Host "========================================"

$Jobs = @(

    Get-CimInstance `
        Win32_PrintJob `
        -ErrorAction SilentlyContinue |

        Where-Object {

            $_.Name -like "$PrinterName,*" -or
            $_.Name -like "*$PrinterName*"
        }
)

if ($Jobs.Count -eq 0) {

    Write-Host "No se encontraron trabajos."

}
else {

    $JobsDisplay = $Jobs |
        Select-Object `
            JobId,
            Document,
            Status,
            JobStatus,
            TotalPages,
            PagesPrinted,
            Size |
        Format-List |
        Out-String

    Write-Host $JobsDisplay
}

# ============================================================
# 5. PRUEBAS ACTIVAS DE CONECTIVIDAD
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "5. PRUEBAS ACTIVAS DE CONECTIVIDAD"
Write-Host "========================================"

Write-Host "IP objetivo: $PrinterIP"

# ------------------------------------------------------------
# 5.1 ICMP
# ------------------------------------------------------------

Write-Host ""
Write-Host "Prueba ICMP / Ping"

$PingResult = $false

try {

    $PingResult = Test-Connection `
        -ComputerName $PrinterIP `
        -Count 1 `
        -Quiet `
        -ErrorAction SilentlyContinue

    Write-Host "PingSucceeded : $PingResult"

}
catch {

    Write-Host "PingSucceeded : ERROR"
}

# ------------------------------------------------------------
# 5.2 TCP 9100
# ------------------------------------------------------------

Write-Host ""
Write-Host "Prueba TCP puerto 9100"

$Tcp9100Succeeded = $false

try {

    $Tcp9100 = Test-NetConnection `
        -ComputerName $PrinterIP `
        -Port 9100 `
        -WarningAction SilentlyContinue

    $Tcp9100Succeeded =
        $Tcp9100.TcpTestSucceeded

    Write-Host `
        "Tcp9100Succeeded : $Tcp9100Succeeded"

}
catch {

    Write-Host "Tcp9100Succeeded : ERROR"
}

# ------------------------------------------------------------
# 5.3 HTTP 80
# ------------------------------------------------------------

Write-Host ""
Write-Host "Prueba HTTP puerto 80"

$Tcp80Succeeded = $false

try {

    $Tcp80 = Test-NetConnection `
        -ComputerName $PrinterIP `
        -Port 80 `
        -WarningAction SilentlyContinue

    $Tcp80Succeeded =
        $Tcp80.TcpTestSucceeded

    Write-Host `
        "Tcp80Succeeded : $Tcp80Succeeded"

}
catch {

    Write-Host "Tcp80Succeeded : ERROR"
}

# ============================================================
# 6. CLASIFICACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "6. CLASIFICACION"
Write-Host "========================================"

$AnyPositiveNetworkEvidence =
    $PingResult -or
    $Tcp9100Succeeded -or
    $Tcp80Succeeded

if ($CurrentSSID -ne $RequiredSSID) {

    $Classification =
        "NETWORK_MISMATCH"

}
elseif ($AnyPositiveNetworkEvidence) {

    $Classification =
        "PRINTER_REACHABLE"

}
else {

    $Classification =
        "PRINTER_UNREACHABLE_ON_TARGET_NETWORK"
}

Write-Host "SSID actual    : $CurrentSSID"
Write-Host "SSID requerido : $RequiredSSID"
Write-Host "Ping           : $PingResult"
Write-Host "TCP 9100       : $Tcp9100Succeeded"
Write-Host "HTTP 80        : $Tcp80Succeeded"

Write-Host ""
Write-Host `
    "Resultado      : $Classification" `
    -ForegroundColor Green

# ============================================================
# 7. RESULTADO ESTRUCTURADO
# ============================================================

$ConnectivityResult = [PSCustomObject]@{

    Component =
        "ConnectivityAnalyzer"

    Version =
        "0.4"

    Timestamp =
        Get-Date

    ConfigPath =
        $ConfigPath

    PrinterName =
        $PrinterName

    PrinterIP =
        $PrinterIP

    RequiredSSID =
        $RequiredSSID

    CurrentSSID =
        $CurrentSSID

    Classification =
        $Classification

    PingSucceeded =
        $PingResult

    Tcp9100Succeeded =
        $Tcp9100Succeeded

    Tcp80Succeeded =
        $Tcp80Succeeded

    WindowsPrinterStatus =
        $PrinterStatus

    WindowsJobCount =
        $PrinterJobCount

    WindowsPortName =
        $PrinterPortName

    WindowsDriverName =
        $PrinterDriverName

    CimPrinterStatus =
        $CimPrinterStatus

    ExtendedPrinterStatus =
        $ExtendedPrinterStatus

    DetectedErrorState =
        $DetectedErrorState

    WorkOffline =
        $WorkOffline

    CurrentJobCount =
        $Jobs.Count
}

# ============================================================
# 8. RESUMEN HUMANO
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "8. RESULTADO ESTRUCTURADO"
Write-Host "========================================"

Write-Host `
    "Component      : $($ConnectivityResult.Component)"

Write-Host `
    "Version        : $($ConnectivityResult.Version)"

Write-Host `
    "PrinterName    : $($ConnectivityResult.PrinterName)"

Write-Host `
    "PrinterIP      : $($ConnectivityResult.PrinterIP)"

Write-Host `
    "CurrentSSID    : $($ConnectivityResult.CurrentSSID)"

Write-Host `
    "RequiredSSID   : $($ConnectivityResult.RequiredSSID)"

Write-Host `
    "Classification : $($ConnectivityResult.Classification)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN DEL ANALISIS"
Write-Host "========================================"

# ============================================================
# UNICA SALIDA PROGRAMATICA
# ============================================================

$ConnectivityResult