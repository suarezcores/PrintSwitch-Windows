$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - ConnectivityAnalyzer v0.2
# Diagnostico no intrusivo + clasificacion provisional
# ============================================================

$PrinterName  = "L365 Series(Red)"
$PrinterIP    = "192.168.1.108"
$RequiredSSID = "suarezcores"

Write-Host ""
Write-Host "PrintSwitch - ConnectivityAnalyzer v0.2" -ForegroundColor Cyan
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
    "Name|Nombre|State|Estado|SSID|BSSID|Signal|Señal|Radio"

# Obtener SSID actual para utilizarlo posteriormente
$CurrentSSID = (
    $WlanInfo |
    Select-String '^\s*SSID\s*:' |
    Select-Object -First 1 |
    ForEach-Object {
        ($_.ToString().Split(":", 2)[1]).Trim()
    }
)

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
# FIN
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "FIN DEL ANALISIS"
Write-Host "========================================"