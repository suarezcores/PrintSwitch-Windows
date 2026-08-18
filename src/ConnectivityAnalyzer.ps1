$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - ConnectivityAnalyzer v0.3.1
# Diagnostico no intrusivo + salida programatica limpia
# ============================================================

$PrinterName  = "L365 Series(Red)"
$PrinterIP    = "192.168.1.108"
$RequiredSSID = "suarezcores"

Write-Host ""
Write-Host "PrintSwitch - ConnectivityAnalyzer v0.3.1" -ForegroundColor Cyan
Write-Host "Modo: DIAGNOSTICO NO INTRUSIVO" -ForegroundColor Yellow
Write-Host "Se realizaran consultas y pruebas de conectividad, sin modificar configuraciones."
Write-Host ""

# ============================================================
# 1. CONTEXTO DE RED
# ============================================================

Write-Host "========================================"
Write-Host "1. CONTEXTO DE RED"
Write-Host "========================================"

$WlanInfo = netsh wlan show interfaces

# Select-String produce objetos MatchInfo.
# Los convertimos a texto y los enviamos exclusivamente a pantalla.
$WlanDisplay = $WlanInfo |
    Select-String "Name|Nombre|State|Estado|SSID|BSSID|Signal|Señal|Radio"

foreach ($Line in $WlanDisplay) {
    Write-Host $Line.ToString()
}

# Obtener SSID actual sin enviar el resultado al pipeline.
$CurrentSSIDMatch = $WlanInfo |
    Select-String '^\s*SSID\s*:' |
    Select-Object -First 1

$CurrentSSID = $null

if ($CurrentSSIDMatch) {

    $CurrentSSID = (
        $CurrentSSIDMatch.ToString().Split(":", 2)[1]
    ).Trim()
}

# ============================================================
# 2. INFORMACION DE IMPRESORA - Get-Printer
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. INFORMACION DE IMPRESORA - Get-Printer"
Write-Host "========================================"

$PrinterStatus     = $null
$PrinterJobCount   = $null
$PrinterPortName   = $null
$PrinterDriverName = $null

try {

    $PrinterInfo = Get-Printer -Name $PrinterName

    $PrinterStatus     = $PrinterInfo.PrinterStatus
    $PrinterJobCount   = $PrinterInfo.JobCount
    $PrinterPortName   = $PrinterInfo.PortName
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

    Write-Host "No se pudo obtener informacion mediante Get-Printer."
    Write-Host $_.Exception.Message
}

# ============================================================
# 3. INFORMACION CIM - Win32_Printer
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. INFORMACION CIM - Win32_Printer"
Write-Host "========================================"

$CimPrinterStatus      = $null
$ExtendedPrinterStatus = $null
$DetectedErrorState    = $null
$WorkOffline           = $null

try {

    $CimPrinter = Get-CimInstance Win32_Printer |
        Where-Object { $_.Name -eq $PrinterName }

    if ($CimPrinter) {

        $CimPrinterStatus      = $CimPrinter.PrinterStatus
        $ExtendedPrinterStatus = $CimPrinter.ExtendedPrinterStatus
        $DetectedErrorState    = $CimPrinter.DetectedErrorState
        $WorkOffline           = $CimPrinter.WorkOffline

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

    Write-Host "No se pudo obtener informacion mediante CIM."
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

    Get-CimInstance Win32_PrintJob -ErrorAction SilentlyContinue |
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
# 5.1 ICMP / Ping
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
# 5.2 TCP puerto 9100
# ------------------------------------------------------------

Write-Host ""
Write-Host "Prueba TCP puerto 9100"

$Tcp9100Succeeded = $false

try {

    $Tcp9100 = Test-NetConnection `
        -ComputerName $PrinterIP `
        -Port 9100 `
        -WarningAction SilentlyContinue

    $Tcp9100Succeeded = $Tcp9100.TcpTestSucceeded

    Write-Host "Tcp9100Succeeded : $Tcp9100Succeeded"
}
catch {

    Write-Host "Tcp9100Succeeded : ERROR"
}

# ------------------------------------------------------------
# 5.3 HTTP puerto 80
# ------------------------------------------------------------

Write-Host ""
Write-Host "Prueba HTTP puerto 80"

$Tcp80Succeeded = $false

try {

    $Tcp80 = Test-NetConnection `
        -ComputerName $PrinterIP `
        -Port 80 `
        -WarningAction SilentlyContinue

    $Tcp80Succeeded = $Tcp80.TcpTestSucceeded

    Write-Host "Tcp80Succeeded : $Tcp80Succeeded"
}
catch {

    Write-Host "Tcp80Succeeded : ERROR"
}

# ============================================================
# 6. CLASIFICACION PROVISIONAL
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "6. CLASIFICACION PROVISIONAL"
Write-Host "========================================"

$AnyPositiveNetworkEvidence =
    $PingResult -or
    $Tcp9100Succeeded -or
    $Tcp80Succeeded

if ($CurrentSSID -ne $RequiredSSID) {

    $Classification = "NETWORK_MISMATCH"

}
elseif ($AnyPositiveNetworkEvidence) {

    $Classification = "PRINTER_REACHABLE"

}
else {

    $Classification = "PRINTER_UNREACHABLE_ON_TARGET_NETWORK"
}

Write-Host "SSID actual    : $CurrentSSID"
Write-Host "SSID requerido : $RequiredSSID"
Write-Host "Ping           : $PingResult"
Write-Host "TCP 9100       : $Tcp9100Succeeded"
Write-Host "HTTP 80        : $Tcp80Succeeded"
Write-Host ""
Write-Host "Resultado      : $Classification" -ForegroundColor Green

# ============================================================
# 7. CONSTRUCCION DEL RESULTADO ESTRUCTURADO
# ============================================================

$ConnectivityResult = [PSCustomObject]@{

    Component             = "ConnectivityAnalyzer"
    Version               = "0.3.1"

    Timestamp             = Get-Date

    PrinterName           = $PrinterName
    PrinterIP             = $PrinterIP

    RequiredSSID          = $RequiredSSID
    CurrentSSID           = $CurrentSSID

    Classification        = $Classification

    PingSucceeded         = $PingResult
    Tcp9100Succeeded      = $Tcp9100Succeeded
    Tcp80Succeeded        = $Tcp80Succeeded

    WindowsPrinterStatus  = $PrinterStatus
    WindowsJobCount       = $PrinterJobCount
    WindowsPortName       = $PrinterPortName
    WindowsDriverName     = $PrinterDriverName

    CimPrinterStatus      = $CimPrinterStatus
    ExtendedPrinterStatus = $ExtendedPrinterStatus
    DetectedErrorState    = $DetectedErrorState
    WorkOffline           = $WorkOffline

    CurrentJobCount       = $Jobs.Count
}

# ============================================================
# 8. RESUMEN HUMANO
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "8. RESULTADO ESTRUCTURADO"
Write-Host "========================================"

Write-Host "Component      : $($ConnectivityResult.Component)"
Write-Host "Version        : $($ConnectivityResult.Version)"
Write-Host "Timestamp      : $($ConnectivityResult.Timestamp)"
Write-Host "PrinterName    : $($ConnectivityResult.PrinterName)"
Write-Host "PrinterIP      : $($ConnectivityResult.PrinterIP)"
Write-Host "CurrentSSID    : $($ConnectivityResult.CurrentSSID)"
Write-Host "RequiredSSID   : $($ConnectivityResult.RequiredSSID)"
Write-Host "Classification : $($ConnectivityResult.Classification)"

# ============================================================
# FIN
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "FIN DEL ANALISIS"
Write-Host "========================================"

# IMPORTANTE:
# Esta debe ser la unica salida programatica del script.
$ConnectivityResult