$ErrorActionPreference = "Stop"

$PrinterName = "L365 Series(Red)"
$PollingMilliseconds = 500

$KnownJobs = @{}

function Get-PrintJobs {
    param(
        [string]$TargetPrinter
    )

    Get-CimInstance Win32_PrintJob -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like "$TargetPrinter,*" -or
            $_.Name -like "*$TargetPrinter*"
        }
}

Write-Host ""
Write-Host "PrintSwitch - QueueWatcher" -ForegroundColor Cyan
Write-Host "Impresora observada: $PrinterName"
Write-Host "Intervalo: $PollingMilliseconds ms"
Write-Host ""
Write-Host "Esperando trabajos de impresion..." -ForegroundColor Yellow
Write-Host "Ctrl+C para finalizar."
Write-Host ""

while ($true) {

    $Jobs = @(Get-PrintJobs -TargetPrinter $PrinterName)

    foreach ($Job in $Jobs) {

        $JobKey = "$($Job.JobId)-$($Job.Name)"

        if (-not $KnownJobs.ContainsKey($JobKey)) {

            $KnownJobs[$JobKey] = $true

            $Event = [PSCustomObject]@{
                EventType    = "PrintJobDetected"
                Timestamp    = Get-Date
                PrinterName  = $PrinterName
                JobId        = $Job.JobId
                Document     = $Job.Document
                Owner        = $Job.Owner
                Status       = $Job.Status
                JobStatus    = $Job.JobStatus
                TotalPages   = $Job.TotalPages
                PagesPrinted = $Job.PagesPrinted
                SizeBytes    = $Job.Size
            }

            Write-Host "----------------------------------------" `
                -ForegroundColor DarkGray

            Write-Host "NUEVO TRABAJO DETECTADO" `
                -ForegroundColor Green

            $Event | Format-List
        }
    }

    $CurrentKeys = @(
        $Jobs | ForEach-Object {
            "$($_.JobId)-$($_.Name)"
        }
    )

    foreach ($KnownKey in @($KnownJobs.Keys)) {

        if ($KnownKey -notin $CurrentKeys) {

            $KnownJobs.Remove($KnownKey)

            Write-Host "Trabajo finalizado o eliminado: $KnownKey" `
                -ForegroundColor DarkGray
        }
    }

    Start-Sleep -Milliseconds $PollingMilliseconds
}