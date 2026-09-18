#requires -Version 5.1
# Run from any directory; simulated providers only, no WLAN operations.
param([string]$ModulePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'src\NativeWifiDiscovery.ps1'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. $ModulePath
# Default native providers must never be used by these deterministic tests.
function Get-PrintSwitchNativeWifiVisibilitySnapshot { throw 'UNEXPECTED_NATIVE_QUERY' }
function Invoke-PrintSwitchNativeWifiScan { throw 'UNEXPECTED_NATIVE_SCAN' }
$Guid = [guid]'11111111-2222-3333-4444-555555555555'
$Cases = @(
    @{Name='CacheHit';Initial=@('Target');Allow=$true;Expected='CACHE_TARGET_VISIBLE';Visible='VISIBLE';Scans=0;Snapshots=1;Success=$true},
    @{Name='NoScanAuthorization';Initial=@();Allow=$false;Expected='CACHE_MISS_SCAN_NOT_ALLOWED';Visible='UNKNOWN';Scans=0;Snapshots=1;Success=$true},
    @{Name='ScanFindsTarget';Initial=@();After=@('Target');Allow=$true;Expected='POST_SCAN_TARGET_VISIBLE';Visible='VISIBLE';Scans=1;Snapshots=2;Success=$true},
    @{Name='ScanDoesNotProveAbsence';Initial=@();After=@();Allow=$true;Expected='POST_SCAN_TARGET_NOT_OBSERVED';Visible='UNKNOWN';Scans=1;Snapshots=2;Success=$true},
    @{Name='Timeout';Initial=@();Allow=$true;ScanStatus='TIMEOUT';Expected='SCAN_INCOMPLETE';Visible='UNKNOWN';Scans=1;Snapshots=1;Success=$false},
    @{Name='ScanFailure';Initial=@();Allow=$true;ScanStatus='SCAN_FAILED_OBSERVED';Expected='SCAN_INCOMPLETE';Visible='UNKNOWN';Scans=1;Snapshots=1;Success=$false},
    @{Name='Busy';Initial=@();Allow=$true;ScanStatus='BUSY';Expected='SCAN_INCOMPLETE';Visible='UNKNOWN';Scans=1;Snapshots=1;Success=$false},
    @{Name='InitialQueryError';Initial=@();Allow=$true;QueryFailAt=1;Expected='DISCOVERY_ERROR';Visible='UNKNOWN';Scans=0;Snapshots=1;Success=$false},
    @{Name='PostQueryError';Initial=@();Allow=$true;QueryFailAt=2;Expected='DISCOVERY_ERROR';Visible='UNKNOWN';Scans=1;Snapshots=2;Success=$false},
    @{Name='CaseSensitiveSsid';Initial=@('target');Allow=$false;Expected='CACHE_MISS_SCAN_NOT_ALLOWED';Visible='UNKNOWN';Scans=0;Snapshots=1;Success=$true},
    @{Name='ThrowingScanner';Initial=@();Allow=$true;ScanThrows=$true;Expected='DISCOVERY_ERROR';Visible='UNKNOWN';Scans=1;Snapshots=1;Success=$false},
    @{Name='WrongInterface';Initial=@();Allow=$true;WrongInterface=$true;Expected='DISCOVERY_ERROR';Visible='UNKNOWN';Scans=0;Snapshots=1;Success=$false}
)
foreach ($Case in $Cases) {
    $State = @{Snapshots=0;Scans=0;Case=$Case}
    $SnapshotProvider = {
        param($G,$S)
        $State.Snapshots++
        $C = $State.Case
        if ($C.ContainsKey('QueryFailAt') -and $State.Snapshots -eq $C.QueryFailAt) { return [pscustomobject]@{Success=$false} }
        $Names = @($C.Initial)
        if ($State.Snapshots -gt 1) { $Names = @(); if ($C.ContainsKey('After')) { $Names = @($C.After) } }
        $ActualGuid = $G
        if ($C.ContainsKey('WrongInterface')) { $ActualGuid = [guid]::Empty }
        [pscustomobject]@{Success=$true;Data=[pscustomobject]@{InterfaceGuid=$ActualGuid;Networks=@($Names | ForEach-Object { [pscustomobject]@{Ssid=$_} })}}
    }.GetNewClosure()
    $ScanProvider = {
        param($G,$Timeout)
        $State.Scans++
        $C = $State.Case
        if ($C.ContainsKey('ScanThrows')) { throw 'SIMULATED_SCAN_EXCEPTION' }
        $Status = 'SCAN_COMPLETE_OBSERVED'
        if ($C.ContainsKey('ScanStatus')) { $Status = $C.ScanStatus }
        [pscustomobject]@{
            InterfaceGuid=$G;Status=$Status;Success=($Status -eq 'SCAN_COMPLETE_OBSERVED')
            ScanRequested=($Status -ne 'BUSY');RequestAccepted=($Status -ne 'BUSY')
            UnregisterErrorCode=0;CloseErrorCode=0;CallbackError=$false
        }
    }.GetNewClosure()
    $Result = Invoke-PrintSwitchNativeWifiDiscovery -TargetSsid 'Target' -InterfaceGuid $Guid -AllowScan:$Case.Allow -SnapshotProvider $SnapshotProvider -ScanProvider $ScanProvider
    if ($Result.Status -cne $Case.Expected -or $Result.Visibility -cne $Case.Visible -or $Result.Success -ne $Case.Success) { throw "Incorrect outcome: $($Case.Name): $($Result | ConvertTo-Json -Compress -Depth 4)" }
    if ($State.Scans -ne $Case.Scans -or $State.Snapshots -ne $Case.Snapshots) { throw "Incorrect provider call counts: $($Case.Name)" }
    if ($Result.ConnectionRequested -or $Result.AbsenceConfirmed -or [string]::IsNullOrEmpty($Result.FinishedUtc)) { throw "Invalid contract: $($Case.Name)" }
    if ($Case.Name -eq 'ThrowingScanner' -and $null -ne $Result.ScanRequested) { throw 'Thrown scan must preserve unknown request state.' }
    "Test=$($Case.Name);Result=PASS"
}
'TESTS_PASS=12'
