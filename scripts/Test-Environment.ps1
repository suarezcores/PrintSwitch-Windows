$ErrorActionPreference = "Continue"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDirectory = Join-Path $ProjectRoot "logs"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ReportPath = Join-Path $LogDirectory "diagnostico_$Timestamp.txt"

New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null

function Add-Section {
    param([string]$Title)

    "" | Out-File $ReportPath -Append -Encoding utf8
    ("=" * 75) | Out-File $ReportPath -Append -Encoding utf8
    $Title | Out-File $ReportPath -Append -Encoding utf8
    ("=" * 75) | Out-File $ReportPath -Append -Encoding utf8
}

"PRINTSWITCH - DIAGNÓSTICO DEL ENTORNO" |
    Out-File $ReportPath -Encoding utf8

"Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" |
    Out-File $ReportPath -Append -Encoding utf8

"Equipo: $env:COMPUTERNAME" |
    Out-File $ReportPath -Append -Encoding utf8

"Usuario: $env:USERNAME" |
    Out-File $ReportPath -Append -Encoding utf8

Add-Section "VERSIÓN DE WINDOWS"

Get-ComputerInfo |
    Select-Object WindowsProductName,
                  WindowsVersion,
                  OsBuildNumber,
                  OsArchitecture |
    Format-List |
    Out-String -Width 250 |
    Out-File $ReportPath -Append -Encoding utf8

Add-Section "ADAPTADORES DE RED"

Get-NetAdapter |
    Sort-Object InterfaceIndex |
    Select-Object Name,
                  InterfaceDescription,
                  InterfaceIndex,
                  Status,
                  MacAddress,
                  LinkSpeed,
                  PhysicalMediaType |
    Format-Table -AutoSize |
    Out-String -Width 300 |
    Out-File $ReportPath -Append -Encoding utf8

Add-Section "CONFIGURACIÓN IP"

Get-NetIPConfiguration -All |
    Select-Object InterfaceAlias,
                  InterfaceIndex,
                  InterfaceDescription,
                  NetProfile,
                  IPv4Address,
                  IPv4DefaultGateway,
                  DNSServer |
    Format-List |
    Out-String -Width 300 |
    Out-File $ReportPath -Append -Encoding utf8

Add-Section "INTERFACES WIFI"

netsh wlan show interfaces |
    Out-File $ReportPath -Append -Encoding utf8

Add-Section "CONTROLADOR Y CAPACIDADES WIFI"

netsh wlan show drivers |
    Out-File $ReportPath -Append -Encoding utf8

Add-Section "PERFILES WIFI GUARDADOS"

netsh wlan show profiles |
    Out-File $ReportPath -Append -Encoding utf8

Add-Section "IMPRESORAS INSTALADAS"

Get-Printer |
    Select-Object Name,
                  Type,
                  DriverName,
                  PortName,
                  PrinterStatus,
                  WorkOffline,
                  Shared |
    Format-Table -AutoSize |
    Out-String -Width 300 |
    Out-File $ReportPath -Append -Encoding utf8

Add-Section "PUERTOS DE IMPRESIÓN"

Get-PrinterPort |
    Select-Object Name,
                  Description,
                  PrinterHostAddress,
                  PortNumber,
                  Protocol,
                  SNMPEnabled |
    Format-Table -AutoSize |
    Out-String -Width 300 |
    Out-File $ReportPath -Append -Encoding utf8

Add-Section "INFORMACIÓN DE IMPRESORAS MEDIANTE CIM"

Get-CimInstance Win32_Printer |
    Select-Object Name,
                  DriverName,
                  PortName,
                  Network,
                  Local,
                  Default,
                  WorkOffline,
                  PrinterStatus |
    Format-Table -AutoSize |
    Out-String -Width 300 |
    Out-File $ReportPath -Append -Encoding utf8

Add-Section "TRABAJOS ACTUALES DE IMPRESIÓN"

Get-CimInstance Win32_PrintJob -ErrorAction SilentlyContinue |
    Select-Object Name,
                  Document,
                  Owner,
                  JobId,
                  Status,
                  TotalPages,
                  PagesPrinted |
    Format-Table -AutoSize |
    Out-String -Width 300 |
    Out-File $ReportPath -Append -Encoding utf8

Add-Section "SERVICIO DE IMPRESIÓN"

Get-Service Spooler |
    Select-Object Name,
                  DisplayName,
                  Status,
                  StartType |
    Format-List |
    Out-String |
    Out-File $ReportPath -Append -Encoding utf8

Add-Section "TABLA DE RUTAS IPV4"

Get-NetRoute -AddressFamily IPv4 |
    Sort-Object InterfaceIndex, DestinationPrefix |
    Select-Object InterfaceIndex,
                  InterfaceAlias,
                  DestinationPrefix,
                  NextHop,
                  RouteMetric,
                  State |
    Format-Table -AutoSize |
    Out-String -Width 300 |
    Out-File $ReportPath -Append -Encoding utf8

Write-Host ""
Write-Host "Diagnóstico terminado correctamente." -ForegroundColor Green
Write-Host ""
Write-Host "Reporte generado en:" -ForegroundColor Cyan
Write-Host $ReportPath
Write-Host ""
Write-Host "El informe no contiene contraseñas Wi-Fi." -ForegroundColor Yellow
