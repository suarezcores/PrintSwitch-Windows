$ErrorActionPreference = "Continue"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDirectory = Join-Path $ProjectRoot "logs"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ReportPath = Join-Path $LogDirectory "inspeccion_impresora_$Timestamp.txt"

$PrinterName = "L365 Series(Red)"
$PrinterIP = "192.168.1.108"

New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null

function Add-Section {
    param([string]$Title)

    "" | Out-File $ReportPath -Append -Encoding utf8
    ("=" * 80) | Out-File $ReportPath -Append -Encoding utf8
    $Title | Out-File $ReportPath -Append -Encoding utf8
    ("=" * 80) | Out-File $ReportPath -Append -Encoding utf8
}

function Write-Safe {
    param(
        [scriptblock]$Command,
        [string]$ErrorLabel
    )

    try {
        & $Command |
            Out-String -Width 400 |
            Out-File $ReportPath -Append -Encoding utf8
    }
    catch {
        "$ErrorLabel : $($_.Exception.Message)" |
            Out-File $ReportPath -Append -Encoding utf8
    }
}

"PRINTSWITCH - INSPECCIÓN PROFUNDA DE IMPRESORA" |
    Out-File $ReportPath -Encoding utf8

"Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" |
    Out-File $ReportPath -Append -Encoding utf8

"Equipo: $env:COMPUTERNAME" |
    Out-File $ReportPath -Append -Encoding utf8

"Usuario: $env:USERNAME" |
    Out-File $ReportPath -Append -Encoding utf8

"Impresora objetivo: $PrinterName" |
    Out-File $ReportPath -Append -Encoding utf8

"IP conocida: $PrinterIP" |
    Out-File $ReportPath -Append -Encoding utf8


Add-Section "RED WIFI ACTUAL"

Write-Safe {
    netsh wlan show interfaces
} "No se pudo consultar la interfaz Wi-Fi"


Add-Section "IMPRESORA OBJETIVO"

Write-Safe {
    Get-Printer -Name $PrinterName |
        Format-List *
} "No se pudo obtener la impresora"


Add-Section "IMPRESORA MEDIANTE CIM"

Write-Safe {
    Get-CimInstance Win32_Printer |
        Where-Object { $_.Name -eq $PrinterName } |
        Format-List *
} "No se pudo obtener Win32_Printer"


Add-Section "PUERTO ASIGNADO"

Write-Safe {
    $Printer = Get-Printer -Name $PrinterName -ErrorAction Stop

    "Puerto asignado: $($Printer.PortName)"
    ""

    Get-PrinterPort -Name $Printer.PortName |
        Format-List *
} "No se pudo inspeccionar el puerto asignado"


Add-Section "PUERTOS RELACIONADOS"

Write-Safe {
    Get-PrinterPort |
        Where-Object {
            $_.Name -match "EPSON|EPE2EB06|192\.168\.1\.108|L365" -or
            $_.PrinterHostAddress -eq $PrinterIP
        } |
        Format-List *
} "No se pudieron consultar los puertos relacionados"


Add-Section "CONTROLADOR EPSON"

Write-Safe {
    Get-PrinterDriver |
        Where-Object {
            $_.Name -match "EPSON|L365"
        } |
        Format-List *
} "No se pudo consultar el controlador Epson"


Add-Section "MONITORES DE PUERTO"

Write-Safe {
    Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors" |
        Select-Object PSChildName, Name |
        Format-Table -AutoSize
} "No se pudieron consultar los monitores"


Add-Section "MONITORES EPSON EN EL REGISTRO"

Write-Safe {
    $Root = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors"

    Get-ChildItem $Root |
        Where-Object {
            $_.PSChildName -match "EPSON|EpsonNet"
        } |
        ForEach-Object {
            "CLAVE: $($_.Name)"
            Get-ItemProperty $_.PSPath |
                Format-List *
            ""
        }
} "No se pudieron inspeccionar los monitores Epson"


Add-Section "SERVICIOS EPSON"

Write-Safe {
    Get-CimInstance Win32_Service |
        Where-Object {
            $_.Name -match "EPSON|EpsonNet" -or
            $_.DisplayName -match "EPSON|EpsonNet" -or
            $_.PathName -match "EPSON|EpsonNet"
        } |
        Select-Object Name,
                      DisplayName,
                      State,
                      StartMode,
                      PathName,
                      ProcessId |
        Format-List
} "No se pudieron consultar los servicios Epson"


Add-Section "PROCESOS EPSON"

Write-Safe {
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -match "EPSON|EpsonNet|EEvent|E_IAT" -or
            $_.ExecutablePath -match "EPSON|EpsonNet"
        } |
        Select-Object Name,
                      ProcessId,
                      ExecutablePath,
                      CommandLine |
        Format-List
} "No se pudieron consultar los procesos Epson"


Add-Section "RESOLUCIÓN DE NOMBRE"

Write-Safe {
    $Names = @(
        "EPSONE2EB06",
        "EPSONE2EB06.local"
    )

    foreach ($Name in $Names) {
        "Nombre probado: $Name"

        try {
            Resolve-DnsName $Name -ErrorAction Stop |
                Format-Table -AutoSize
        }
        catch {
            "No resuelto."
        }

        ""
    }
} "No se pudo ejecutar la resolución de nombres"


Add-Section "TABLA ARP"

Write-Safe {
    arp -a
} "No se pudo consultar la tabla ARP"


Add-Section "RUTA HACIA LA IMPRESORA"

Write-Safe {
    Test-NetConnection -ComputerName $PrinterIP -InformationLevel Detailed |
        Format-List *
} "No se pudo ejecutar Test-NetConnection"


Add-Section "PRUEBA DE PUERTOS"

Write-Safe {
    $Ports = @(80, 515, 631, 9100)

    $Results = foreach ($Port in $Ports) {
        $Result = Test-NetConnection `
            -ComputerName $PrinterIP `
            -Port $Port `
            -WarningAction SilentlyContinue

        [PSCustomObject]@{
            IP               = $PrinterIP
            Puerto           = $Port
            TcpTestSucceeded = $Result.TcpTestSucceeded
            InterfaceAlias   = $Result.InterfaceAlias
            SourceAddress    = $Result.SourceAddress
        }
    }

    $Results | Format-Table -AutoSize
} "No se pudieron probar los puertos"


Add-Section "COLA DE IMPRESIÓN"

Write-Safe {
    Get-CimInstance Win32_PrintJob -ErrorAction SilentlyContinue |
        Format-List *
} "No se pudo consultar la cola"


Add-Section "RESUMEN"

Write-Safe {
    $Printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue

    $StandardPort = Get-PrinterPort -ErrorAction SilentlyContinue |
        Where-Object {
            $_.PrinterHostAddress -eq $PrinterIP
        }

    [PSCustomObject]@{
        PrinterFound         = [bool]$Printer
        PrinterName          = $Printer.Name
        AssignedPort         = $Printer.PortName
        PrinterDriver        = $Printer.DriverName
        StandardTCPPortFound = [bool]$StandardPort
        StandardTCPPortName  = $StandardPort.Name
        StandardTCPPort      = $StandardPort.PortNumber
        CurrentSSID          = (
            netsh wlan show interfaces |
            Select-String '^\s*SSID\s*:' |
            Select-Object -First 1 |
            ForEach-Object {
                ($_.ToString().Split(":", 2)[1]).Trim()
            }
        )
    } |
        Format-List
} "No se pudo generar el resumen"


Write-Host ""
Write-Host "Inspección terminada correctamente." -ForegroundColor Green
Write-Host ""
Write-Host "Reporte generado en:" -ForegroundColor Cyan
Write-Host $ReportPath
Write-Host ""
Write-Host "No se modificó ninguna configuración." -ForegroundColor Yellow
