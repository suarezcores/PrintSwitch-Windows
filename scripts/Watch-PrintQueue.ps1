$ErrorActionPreference = "Continue"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDirectory = Join-Path $ProjectRoot "logs"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ReportPath = Join-Path $LogDirectory "observacion_cola_$Timestamp.txt"

$PrinterName = "L365 Series(Red)"
$DurationSeconds = 180
$PollingMilliseconds = 500

New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null

function Write-Log {
    param([string]$Message)

    $Line = "{0} | {1}" -f `
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"),
        $Message

    $Line | Tee-Object -FilePath $ReportPath -Append
}

function Get-TargetJobs {
    Get-CimInstance Win32_PrintJob -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like "$PrinterName,*" -or
            $_.Name -like "*$PrinterName*"
        }
}

"PRINTSWITCH - OBSERVACIÓN DE COLA DE IMPRESIÓN" |
    Out-File $ReportPath -Encoding utf8

Write-Log "Inicio de observación"
Write-Log "Impresora objetivo: $PrinterName"
Write-Log "Duración máxima: $DurationSeconds segundos"
Write-Log "Intervalo de consulta: $PollingMilliseconds ms"

$Printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue

if (-not $Printer) {
    Write-Log "ERROR: No se encontró la impresora objetivo."
    Write-Host ""
    Write-Host "No se encontró la impresora objetivo." -ForegroundColor Red
    exit 1
}

Write-Log "Puerto asignado: $($Printer.PortName)"
Write-Log "Controlador: $($Printer.DriverName)"
Write-Log "Estado inicial: $($Printer.PrinterStatus)"
Write-Log "Trabajos iniciales: $($Printer.JobCount)"

$CurrentSSID = (
    netsh wlan show interfaces |
    Select-String '^\s*SSID\s*:' |
    Select-Object -First 1 |
    ForEach-Object {
        ($_.ToString().Split(":", 2)[1]).Trim()
    }
)

Write-Log "SSID actual: $CurrentSSID"

$KnownJobs = @{}
$StartTime = Get-Date
$EndTime = $StartTime.AddSeconds($DurationSeconds)

Write-Host ""
Write-Host "Observando la cola de impresión..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Ahora imprimí una página simple hacia:" -ForegroundColor Yellow
Write-Host $PrinterName -ForegroundColor Green
Write-Host ""
Write-Host "No cambies todavía de red." -ForegroundColor Yellow
Write-Host "La observación dura hasta 3 minutos." -ForegroundColor Yellow
Write-Host ""
Write-Host "Para terminar antes, presioná Ctrl+C." -ForegroundColor DarkGray
Write-Host ""

while ((Get-Date) -lt $EndTime) {

    $Jobs = @(Get-TargetJobs)

    foreach ($Job in $Jobs) {

        $Key = "$($Job.JobId)-$($Job.Name)"

        $Snapshot = [PSCustomObject]@{
            JobId        = $Job.JobId
            Name         = $Job.Name
            Document     = $Job.Document
            Owner        = $Job.Owner
            Status       = $Job.Status
            JobStatus    = $Job.JobStatus
            TotalPages   = $Job.TotalPages
            PagesPrinted = $Job.PagesPrinted
            Size         = $Job.Size
            TimeSubmitted = $Job.TimeSubmitted
        }

        $Serialized = $Snapshot | ConvertTo-Json -Compress

        if (-not $KnownJobs.ContainsKey($Key)) {
            $KnownJobs[$Key] = $Serialized

            Write-Log (
                "NUEVO TRABAJO | " +
                "JobId=$($Job.JobId) | " +
                "Documento=$($Job.Document) | " +
                "Estado=$($Job.Status) | " +
                "JobStatus=$($Job.JobStatus) | " +
                "Paginas=$($Job.TotalPages) | " +
                "Impresas=$($Job.PagesPrinted) | " +
                "Tamaño=$($Job.Size)"
            )
        }
        elseif ($KnownJobs[$Key] -ne $Serialized) {
            $KnownJobs[$Key] = $Serialized

            Write-Log (
                "CAMBIO DE TRABAJO | " +
                "JobId=$($Job.JobId) | " +
                "Documento=$($Job.Document) | " +
                "Estado=$($Job.Status) | " +
                "JobStatus=$($Job.JobStatus) | " +
                "Paginas=$($Job.TotalPages) | " +
                "Impresas=$($Job.PagesPrinted) | " +
                "Tamaño=$($Job.Size)"
            )
        }
    }

    $CurrentKeys = @(
        $Jobs | ForEach-Object {
            "$($_.JobId)-$($_.Name)"
        }
    )

    foreach ($KnownKey in @($KnownJobs.Keys)) {
        if ($KnownKey -notin $CurrentKeys) {
            Write-Log "TRABAJO DESAPARECIÓ DE LA COLA | Clave=$KnownKey"
            $KnownJobs.Remove($KnownKey)
        }
    }

    Start-Sleep -Milliseconds $PollingMilliseconds
}

Write-Log "Fin de observación"

$FinalPrinter = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue

if ($FinalPrinter) {
    Write-Log "Estado final impresora: $($FinalPrinter.PrinterStatus)"
    Write-Log "Trabajos finales: $($FinalPrinter.JobCount)"
}

Write-Host ""
Write-Host "Observación terminada." -ForegroundColor Green
Write-Host ""
Write-Host "Reporte generado en:" -ForegroundColor Cyan
Write-Host $ReportPath
Write-Host ""
Write-Host "No se modificó ninguna configuración." -ForegroundColor Yellow
