param (
    [Parameter(Mandatory = $true)]
    [string]$PrinterName,

    [Parameter(Mandatory = $true)]
    [string]$TargetIP,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int]$TcpPort,

    [int]$FastTcpTimeoutMs = 1200
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - ConnectivityAnalyzer v0.6
#
# Responsabilidad:
# - diagnosticar conectividad hacia un endpoint NETWORK
#   previamente resuelto por la arquitectura operacional
# - utilizar TargetIP y TcpPort explícitos
# - conservar evidencia auxiliar de Windows, CIM, trabajos e ICMP
#
# NO:
# - descubre endpoints
# - consume perfiles legacy de impresora
# - decide policy
# - decide si el SSID actual es correcto
# - modifica Wi-Fi
# - ejecuta recovery
# - asume TCP 9100 o TCP 80
#
# La evidencia TCP sobre TargetIP:TcpPort es la evidencia operacional
# primaria. ICMP se conserva solamente como evidencia diagnóstica auxiliar.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - ConnectivityAnalyzer v0.6" `
    -ForegroundColor Cyan

Write-Host "Modo: DIAGNOSTICO ENDPOINT-AWARE NO INTRUSIVO" `
    -ForegroundColor Yellow

Write-Host ""
Write-Host "PrinterName     : $PrinterName"
Write-Host "TargetIP        : $TargetIP"
Write-Host "TcpPort         : $TcpPort"
Write-Host "Fast TCP timeout: $FastTcpTimeoutMs ms"

# ============================================================
# FUNCION: PRUEBA TCP RAPIDA
# ============================================================

function Test-FastTcpPort {

    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutMs
    )

    $Client = New-Object System.Net.Sockets.TcpClient

    try {

        $ConnectTask =
            $Client.ConnectAsync(
                $ComputerName,
                $Port
            )

        $Completed =
            $ConnectTask.Wait(
                $TimeoutMs
            )

        if (-not $Completed) {
            return $false
        }

        return $Client.Connected
    }
    catch {
        return $false
    }
    finally {

        $Client.Close()
        $Client.Dispose()
    }
}

# ============================================================
# 1. CONTEXTO DE RED
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "1. CONTEXTO DE RED"
Write-Host "========================================"

try {

    $WlanInfo =
        netsh wlan show interfaces 2>$null

    $WlanDisplay =
        $WlanInfo |
            Select-String `
                "Name|Nombre|State|Estado|SSID|BSSID|Signal|Señal|Radio"

    foreach ($Line in $WlanDisplay) {
        Write-Host $Line.ToString()
    }
}
catch {

    Write-Host `
        "No se pudo obtener contexto WLAN." `
        -ForegroundColor Yellow
}

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

    $PrinterInfo =
        Get-Printer `
            -Name $PrinterName `
            -ErrorAction Stop

    $PrinterStatus =
        $PrinterInfo.PrinterStatus

    $PrinterJobCount =
        $PrinterInfo.JobCount

    $PrinterPortName =
        $PrinterInfo.PortName

    $PrinterDriverName =
        $PrinterInfo.DriverName

    $PrinterDisplay =
        $PrinterInfo |
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
        "No se pudo obtener informacion mediante Get-Printer." `
        -ForegroundColor Yellow

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

    $CimPrinter =
        Get-CimInstance `
            Win32_Printer `
            -ErrorAction Stop |
        Where-Object {
            $_.Name -eq $PrinterName
        } |
        Select-Object -First 1

    if ($null -ne $CimPrinter) {

        $CimPrinterStatus =
            $CimPrinter.PrinterStatus

        $ExtendedPrinterStatus =
            $CimPrinter.ExtendedPrinterStatus

        $DetectedErrorState =
            $CimPrinter.DetectedErrorState

        $WorkOffline =
            $CimPrinter.WorkOffline

        $CimDisplay =
            $CimPrinter |
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
        "No se pudo obtener informacion mediante CIM." `
        -ForegroundColor Yellow

    Write-Host $_.Exception.Message
}

# ============================================================
# 4. TRABAJOS ACTUALES
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "4. TRABAJOS ACTUALES"
Write-Host "========================================"

$Jobs = @()

try {

    $Jobs = @(
        Get-CimInstance `
            Win32_PrintJob `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like "$PrinterName,*" -or
            $_.Name -like "*$PrinterName*"
        }
    )
}
catch {

    $Jobs = @()
}

if ($Jobs.Count -eq 0) {

    Write-Host "No se encontraron trabajos."
}
else {

    $JobsDisplay =
        $Jobs |
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

Write-Host "Destino operacional : $TargetIP"
Write-Host "Puerto operacional  : $TcpPort"

# ------------------------------------------------------------
# 5.1 ICMP - evidencia auxiliar
# ------------------------------------------------------------

Write-Host ""
Write-Host "Prueba ICMP / Ping - evidencia auxiliar"

$PingResult = $false

try {

    $PingResult =
        Test-Connection `
            -ComputerName $TargetIP `
            -Count 1 `
            -Quiet `
            -ErrorAction SilentlyContinue

    Write-Host "PingSucceeded : $PingResult"
}
catch {

    Write-Host "PingSucceeded : ERROR"
}

# ------------------------------------------------------------
# 5.2 TCP operacional
# ------------------------------------------------------------

Write-Host ""
Write-Host "Prueba TCP operacional - FastTcp"

$OperationalTcpSucceeded =
    Test-FastTcpPort `
        -ComputerName $TargetIP `
        -Port $TcpPort `
        -TimeoutMs $FastTcpTimeoutMs

Write-Host `
    "OperationalTcpSucceeded : $OperationalTcpSucceeded"

# ============================================================
# 6. CLASIFICACION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "6. CLASIFICACION"
Write-Host "========================================"

if ($OperationalTcpSucceeded) {

    $Classification =
        "PRINTER_REACHABLE"
}
else {

    $Classification =
        "PRINTER_UNREACHABLE"
}

Write-Host "TargetIP        : $TargetIP"
Write-Host "TcpPort         : $TcpPort"
Write-Host "Ping            : $PingResult"
Write-Host "Operational TCP : $OperationalTcpSucceeded"

Write-Host ""
Write-Host `
    "Resultado       : $Classification" `
    -ForegroundColor Green

# ============================================================
# 7. RESULTADO ESTRUCTURADO
# ============================================================

$ConnectivityResult = [PSCustomObject]@{

    Component =
        "ConnectivityAnalyzer"

    Version =
        "0.6"

    Timestamp =
        Get-Date

    PrinterName =
        $PrinterName

    TargetIP =
        $TargetIP

    TcpPort =
        $TcpPort

    Classification =
        $Classification

    PingSucceeded =
        $PingResult

    OperationalTcpSucceeded =
        $OperationalTcpSucceeded

    FastTcpTimeoutMs =
        $FastTcpTimeoutMs

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

Write-Host "Component      : $($ConnectivityResult.Component)"
Write-Host "Version        : $($ConnectivityResult.Version)"
Write-Host "PrinterName    : $($ConnectivityResult.PrinterName)"
Write-Host "TargetIP       : $($ConnectivityResult.TargetIP)"
Write-Host "TcpPort        : $($ConnectivityResult.TcpPort)"
Write-Host "Classification : $($ConnectivityResult.Classification)"
Write-Host "OperationalTCP : $($ConnectivityResult.OperationalTcpSucceeded)"
Write-Host "FastTcpTimeout : $($ConnectivityResult.FastTcpTimeoutMs) ms"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN DEL ANALISIS"
Write-Host "========================================"

$ConnectivityResult
