$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - ConnectivityAnalyzer v0.1
# Diagnostico no intrusivo
# ============================================================

$PrinterName = "L365 Series(Red)"
$PrinterIP   = "192.168.1.108"

Write-Host ""
Write-Host "PrintSwitch - ConnectivityAnalyzer v0.1" -ForegroundColor Cyan
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

$WlanInfo | Select-String `
    "Name|Nombre|State|Estado|SSID|BSSID|Signal|SeÃ±al|Radio"

# ============================================================
# 2. INFORMACION DE IMPRESORA - Get-Printer
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. INFORMACION DE IMPRESORA - Get-Printer"
Write-Host "========================================"

try {

    Get-Printer -Name $PrinterName |
        Select-Object `
            Name,
            DriverName,
            PortName,
            PrinterStatus,
            JobCount,
            Shared,
            Published |
        Format-List

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

try {

    Get-CimInstance Win32_Printer |
        Where-Object { $_.Name -eq $PrinterName } |
        Select-Object `
            Name,
            PrinterStatus,
            ExtendedPrinterStatus,
            DetectedErrorState,
            WorkOffline,
            PortName,
            DriverName |
        Format-List

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

    $Jobs |
        Select-Object `
            JobId,
            Document,
            Status,
            JobStatus,
            TotalPages,
            PagesPrinted,
            Size |
        Format-List
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

try {

    $Tcp9100 = Test-NetConnection `
        -ComputerName $PrinterIP `
        -Port 9100 `
        -WarningAction SilentlyContinue

    Write-Host "Tcp9100Succeeded : $($Tcp9100.TcpTestSucceeded)"

}
catch {

    Write-Host "Tcp9100Succeeded : ERROR"
}

# ------------------------------------------------------------
# 5.3 HTTP puerto 80
# ------------------------------------------------------------

Write-Host ""
Write-Host "Prueba HTTP puerto 80"

try {

    $Tcp80 = Test-NetConnection `
        -ComputerName $PrinterIP `
        -Port 80 `
        -WarningAction SilentlyContinue

    Write-Host "Tcp80Succeeded : $($Tcp80.TcpTestSucceeded)"

}
catch {

    Write-Host "Tcp80Succeeded : ERROR"
}

# ============================================================
# FIN
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "FIN DEL INVENTARIO"
Write-Host "========================================"
