param (
    [string]$PrinterName,

    [int]$FastTcpTimeoutMs = 1200,

    [string]$ConfigPath = (
        Join-Path `
            (Split-Path $PSScriptRoot -Parent) `
            "config\printers.json"
    )
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - PerformanceAnalyzer v0.2
#
# Compara:
# - Test-NetConnection
# - TcpClient con timeout controlado
#
# No modifica red ni estado de impresion.
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - PerformanceAnalyzer v0.2" `
    -ForegroundColor Cyan

Write-Host "Modo: COMPARACION DE LATENCIA TCP" `
    -ForegroundColor Yellow

Write-Host ""

# ============================================================
# 0. CONFIGURACION
# ============================================================

if (-not (Test-Path $ConfigPath)) {

    Write-Host `
        "ERROR: no se encontro el archivo de configuracion." `
        -ForegroundColor Red

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

    $PrinterProfile = @($Config.printers)[0]
}

$PrinterName = [string]$PrinterProfile.name
$PrinterIP = [string]$PrinterProfile.ip
$RequiredSSID = [string]$PrinterProfile.requiredSSID

Write-Host "Impresora       : $PrinterName"
Write-Host "IP              : $PrinterIP"
Write-Host "SSID requerido  : $RequiredSSID"
Write-Host "Fast TCP timeout: $FastTcpTimeoutMs ms"

# ============================================================
# FUNCION GENERICA DE MEDICION
# ============================================================

function Measure-PrintSwitchOperation {

    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]$Operation
    )

    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {

        $Value = & $Operation
        $Success = $true
        $ErrorMessage = $null

    }
    catch {

        $Value = $null
        $Success = $false
        $ErrorMessage = $_.Exception.Message
    }

    $Stopwatch.Stop()

    [PSCustomObject]@{
        Success      = $Success
        ElapsedMs    = $Stopwatch.ElapsedMilliseconds
        Value        = $Value
        ErrorMessage = $ErrorMessage
    }
}

# ============================================================
# FUNCION TCP RAPIDA
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

        $ConnectTask = $Client.ConnectAsync(
            $ComputerName,
            $Port
        )

        $Completed = $ConnectTask.Wait(
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
# 1. SSID
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "1. SSID ACTUAL"
Write-Host "========================================"

$SSIDMeasurement = Measure-PrintSwitchOperation {

    $InterfaceInfo = netsh wlan show interfaces

    $CurrentSSIDMatch = $InterfaceInfo |
        Select-String '^\s*SSID\s*:' |
        Select-Object -First 1

    if ($CurrentSSIDMatch) {

        $CurrentSSIDText = $CurrentSSIDMatch.ToString()

        return (
            $CurrentSSIDText.Split(":", 2)[1]
        ).Trim()
    }

    return $null
}

Write-Host "SSID   : $($SSIDMeasurement.Value)"
Write-Host "Tiempo : $($SSIDMeasurement.ElapsedMs) ms"

# ============================================================
# 2. PING
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "2. PING"
Write-Host "========================================"

$PingMeasurement = Measure-PrintSwitchOperation {

    Test-Connection `
        -ComputerName $PrinterIP `
        -Count 1 `
        -Quiet `
        -ErrorAction Stop
}

Write-Host "Resultado : $($PingMeasurement.Value)"
Write-Host "Tiempo    : $($PingMeasurement.ElapsedMs) ms"

# ============================================================
# 3. TCP 9100 - TEST-NETCONNECTION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "3. TCP 9100 - TEST-NETCONNECTION"
Write-Host "========================================"

$Tcp9100Classic = Measure-PrintSwitchOperation {

    $Result = Test-NetConnection `
        -ComputerName $PrinterIP `
        -Port 9100 `
        -WarningAction SilentlyContinue `
        -ErrorAction Stop

    return $Result.TcpTestSucceeded
}

Write-Host "Resultado : $($Tcp9100Classic.Value)"
Write-Host "Tiempo    : $($Tcp9100Classic.ElapsedMs) ms"

# ============================================================
# 4. TCP 9100 - TCPCLIENT RAPIDO
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "4. TCP 9100 - TCPCLIENT RAPIDO"
Write-Host "========================================"

$Tcp9100Fast = Measure-PrintSwitchOperation {

    Test-FastTcpPort `
        -ComputerName $PrinterIP `
        -Port 9100 `
        -TimeoutMs $FastTcpTimeoutMs
}

Write-Host "Resultado : $($Tcp9100Fast.Value)"
Write-Host "Tiempo    : $($Tcp9100Fast.ElapsedMs) ms"

# ============================================================
# 5. TCP 80 - TEST-NETCONNECTION
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "5. TCP 80 - TEST-NETCONNECTION"
Write-Host "========================================"

$Tcp80Classic = Measure-PrintSwitchOperation {

    $Result = Test-NetConnection `
        -ComputerName $PrinterIP `
        -Port 80 `
        -WarningAction SilentlyContinue `
        -ErrorAction Stop

    return $Result.TcpTestSucceeded
}

Write-Host "Resultado : $($Tcp80Classic.Value)"
Write-Host "Tiempo    : $($Tcp80Classic.ElapsedMs) ms"

# ============================================================
# 6. TCP 80 - TCPCLIENT RAPIDO
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "6. TCP 80 - TCPCLIENT RAPIDO"
Write-Host "========================================"

$Tcp80Fast = Measure-PrintSwitchOperation {

    Test-FastTcpPort `
        -ComputerName $PrinterIP `
        -Port 80 `
        -TimeoutMs $FastTcpTimeoutMs
}

Write-Host "Resultado : $($Tcp80Fast.Value)"
Write-Host "Tiempo    : $($Tcp80Fast.ElapsedMs) ms"

# ============================================================
# RESULTADO
# ============================================================

$PerformanceResult = [PSCustomObject]@{

    Component =
        "PerformanceAnalyzer"

    Version =
        "0.2"

    Timestamp =
        Get-Date

    PrinterName =
        $PrinterName

    PrinterIP =
        $PrinterIP

    CurrentSSID =
        $SSIDMeasurement.Value

    FastTcpTimeoutMs =
        $FastTcpTimeoutMs

    PingSucceeded =
        $PingMeasurement.Value

    Ping_ms =
        $PingMeasurement.ElapsedMs

    Tcp9100ClassicSucceeded =
        $Tcp9100Classic.Value

    Tcp9100Classic_ms =
        $Tcp9100Classic.ElapsedMs

    Tcp9100FastSucceeded =
        $Tcp9100Fast.Value

    Tcp9100Fast_ms =
        $Tcp9100Fast.ElapsedMs

    Tcp80ClassicSucceeded =
        $Tcp80Classic.Value

    Tcp80Classic_ms =
        $Tcp80Classic.ElapsedMs

    Tcp80FastSucceeded =
        $Tcp80Fast.Value

    Tcp80Fast_ms =
        $Tcp80Fast.ElapsedMs
}

# ============================================================
# RESUMEN COMPARATIVO
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "COMPARACION"
Write-Host "========================================"

Write-Host ""
Write-Host "TCP 9100"

Write-Host `
    "Test-NetConnection : $($PerformanceResult.Tcp9100Classic_ms) ms -> $($PerformanceResult.Tcp9100ClassicSucceeded)"

Write-Host `
    "TcpClient rapido   : $($PerformanceResult.Tcp9100Fast_ms) ms -> $($PerformanceResult.Tcp9100FastSucceeded)"

Write-Host ""
Write-Host "TCP 80"

Write-Host `
    "Test-NetConnection : $($PerformanceResult.Tcp80Classic_ms) ms -> $($PerformanceResult.Tcp80ClassicSucceeded)"

Write-Host `
    "TcpClient rapido   : $($PerformanceResult.Tcp80Fast_ms) ms -> $($PerformanceResult.Tcp80FastSucceeded)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN PERFORMANCEANALYZER v0.2"
Write-Host "========================================"

$PerformanceResult