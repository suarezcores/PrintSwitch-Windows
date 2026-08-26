param (
    [Parameter(Mandatory = $true)]
    [string]$TargetIP,

    [int]$TcpPort = 9100,

    [int]$FastWindowMs = 3000,

    [int]$StabilizationWindowMs = 7000,

    [int]$ExtendedWindowMs = 15000,

    [int]$ProbeIntervalMs = 250,

    [int]$TcpProbeTimeoutMs = 500
)

$ErrorActionPreference = "Continue"

# ============================================================
# PrintSwitch - RecoveryValidator v0.1
# Validacion temporal post-switch
# ============================================================

Write-Host ""
Write-Host "PrintSwitch - RecoveryValidator v0.1" `
    -ForegroundColor Cyan

Write-Host "Modo: VALIDACION POST-RECOVERY" `
    -ForegroundColor Yellow

Write-Host ""
Write-Host "Destino       : $TargetIP"
Write-Host "Puerto TCP    : $TcpPort"
Write-Host "FAST          : $FastWindowMs ms"
Write-Host "STABILIZATION : $StabilizationWindowMs ms"
Write-Host "EXTENDED      : $ExtendedWindowMs ms"

# ============================================================
# FUNCION: TCP RAPIDO
# ============================================================

function Test-FastTcp {

    param (
        [string]$ComputerName,
        [int]$Port,
        [int]$TimeoutMs
    )

    $Client = New-Object System.Net.Sockets.TcpClient

    try {

        $Task = $Client.ConnectAsync(
            $ComputerName,
            $Port
        )

        if (-not $Task.Wait($TimeoutMs)) {
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
# FUNCION: RUTA DISPONIBLE
# Solo diagnostica. NO determina exito.
# ============================================================

function Test-RouteAvailable {

    param (
        [string]$RemoteIPAddress
    )

    try {

        $Result = Find-NetRoute `
            -RemoteIPAddress $RemoteIPAddress `
            -ErrorAction Stop

        return ($null -ne $Result)
    }
    catch {
        return $false
    }
}

# ============================================================
# FUNCION: VENTANA TEMPORAL
# ============================================================

function Invoke-RecoveryWindow {

    param (
        [string]$WindowName,
        [int]$WindowMs
    )

    Write-Host ""
    Write-Host "========================================"
    Write-Host "VENTANA $WindowName"
    Write-Host "========================================"

    $Watch = [System.Diagnostics.Stopwatch]::StartNew()

    $ProbeCount = 0
    $LastRouteAvailable = $false

    while ($Watch.ElapsedMilliseconds -lt $WindowMs) {

        $ProbeCount++

        $RouteAvailable = Test-RouteAvailable `
            -RemoteIPAddress $TargetIP

        $TcpSucceeded = Test-FastTcp `
            -ComputerName $TargetIP `
            -Port $TcpPort `
            -TimeoutMs $TcpProbeTimeoutMs

        $LastRouteAvailable = $RouteAvailable

        Write-Host (
            "[{0,5} ms] Ruta: {1} | TCP {2}: {3}" -f `
            $Watch.ElapsedMilliseconds,
            $RouteAvailable,
            $TcpPort,
            $TcpSucceeded
        )

        if ($TcpSucceeded) {

            $Watch.Stop()

            return [PSCustomObject]@{
                Success        = $true
                Window         = $WindowName
                ElapsedMs      = $Watch.ElapsedMilliseconds
                ProbeCount     = $ProbeCount
                RouteAvailable = $RouteAvailable
                TcpSucceeded   = $true
            }
        }

        $RemainingMs = $WindowMs - $Watch.ElapsedMilliseconds

        if ($RemainingMs -le 0) {
            break
        }

        $SleepMs = [Math]::Min(
            $ProbeIntervalMs,
            $RemainingMs
        )

        Start-Sleep -Milliseconds $SleepMs
    }

    $Watch.Stop()

    return [PSCustomObject]@{
        Success        = $false
        Window         = $WindowName
        ElapsedMs      = $Watch.ElapsedMilliseconds
        ProbeCount     = $ProbeCount
        RouteAvailable = $LastRouteAvailable
        TcpSucceeded   = $false
    }
}

# ============================================================
# EJECUCION
# ============================================================

$TotalWatch = [System.Diagnostics.Stopwatch]::StartNew()

$FinalWindowResult = $null
$Classification = $null

# ------------------------------------------------------------
# FAST
# ------------------------------------------------------------

$FastResult = Invoke-RecoveryWindow `
    -WindowName "FAST" `
    -WindowMs $FastWindowMs

if ($FastResult.Success) {

    $FinalWindowResult = $FastResult
    $Classification = "RECOVERY_CONFIRMED_FAST"
}

# ------------------------------------------------------------
# STABILIZATION
# ------------------------------------------------------------

if (-not $FinalWindowResult) {

    Write-Host ""
    Write-Host "FAST expiro." -ForegroundColor Yellow
    Write-Host "La recuperacion necesita tiempo adicional."

    $StabilizationResult = Invoke-RecoveryWindow `
        -WindowName "STABILIZATION" `
        -WindowMs $StabilizationWindowMs

    if ($StabilizationResult.Success) {

        $FinalWindowResult = $StabilizationResult
        $Classification = "RECOVERY_CONFIRMED_DELAYED"
    }
}

# ------------------------------------------------------------
# EXTENDED
# ------------------------------------------------------------

if (-not $FinalWindowResult) {

    Write-Host ""
    Write-Host "ADVERTENCIA:" -ForegroundColor Yellow
    Write-Host "La recuperacion excedio el tiempo normal."
    Write-Host "Se inicia la ventana EXTENDED."

    $ExtendedResult = Invoke-RecoveryWindow `
        -WindowName "EXTENDED" `
        -WindowMs $ExtendedWindowMs

    if ($ExtendedResult.Success) {

        $FinalWindowResult = $ExtendedResult
        $Classification = "RECOVERY_CONFIRMED_SLOW"
    }
}

# ============================================================
# TIMEOUT
# ============================================================

if (-not $FinalWindowResult) {

    $Classification = "RECOVERY_TIMEOUT"

    $FinalWindowResult = $ExtendedResult
}

$TotalWatch.Stop()

# ============================================================
# RESULTADO
# ============================================================

$RecoveryConfirmed =
    $Classification -ne "RECOVERY_TIMEOUT"

$RecoveryResult = [PSCustomObject]@{

    Component =
        "RecoveryValidator"

    Version =
        "0.1"

    Timestamp =
        Get-Date

    TargetIP =
        $TargetIP

    TcpPort =
        $TcpPort

    Classification =
        $Classification

    RecoveryConfirmed =
        $RecoveryConfirmed

    CompletedWindow =
        $FinalWindowResult.Window

    TotalElapsedMs =
        $TotalWatch.ElapsedMilliseconds

    FinalRouteAvailable =
        $FinalWindowResult.RouteAvailable

    TcpSucceeded =
        $FinalWindowResult.TcpSucceeded
}

Write-Host ""
Write-Host "========================================"
Write-Host "RESULTADO FINAL"
Write-Host "========================================"

Write-Host "Classification      : $($RecoveryResult.Classification)"
Write-Host "RecoveryConfirmed   : $($RecoveryResult.RecoveryConfirmed)"
Write-Host "CompletedWindow     : $($RecoveryResult.CompletedWindow)"
Write-Host "TotalElapsedMs      : $($RecoveryResult.TotalElapsedMs)"
Write-Host "FinalRouteAvailable : $($RecoveryResult.FinalRouteAvailable)"
Write-Host "TcpSucceeded        : $($RecoveryResult.TcpSucceeded)"

Write-Host ""
Write-Host "========================================"
Write-Host "FIN RECOVERYVALIDATOR v0.1"
Write-Host "========================================"

$RecoveryResult