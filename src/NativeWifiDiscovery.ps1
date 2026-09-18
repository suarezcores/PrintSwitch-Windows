# PrintSwitch Native Wi-Fi discovery v0.1.0
# Load Adapter and Scanner before invoking with the default providers.
# Dot-sourcing this file only defines the function; it does not query Windows.
function Invoke-PrintSwitchNativeWifiDiscovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TargetSsid,
        [Parameter(Mandatory)][guid]$InterfaceGuid,
        [switch]$AllowScan,
        [ValidateRange(1000,30000)][int]$ScanTimeoutMs = 4000,
        [scriptblock]$SnapshotProvider = {
            param($Guid,$Ssid)
            Get-PrintSwitchNativeWifiVisibilitySnapshot -InterfaceGuid $Guid -TargetSsid $Ssid
        },
        [scriptblock]$ScanProvider = {
            param($Guid,$Timeout)
            Invoke-PrintSwitchNativeWifiScan -InterfaceGuid $Guid -TimeoutMs $Timeout -AllowScan
        }
    )
    if ($InterfaceGuid -eq [guid]::Empty) { throw 'An explicit interface GUID is required.' }
    $Result = [pscustomobject][ordered]@{
        Component = 'NativeWifiDiscovery'
        Version = '0.1.0'
        Operation = 'DISCOVER_TARGET_NETWORK'
        InterfaceGuid = $InterfaceGuid
        StartedUtc = [DateTime]::UtcNow.ToString('o')
        FinishedUtc = $null
        Success = $false
        Status = 'NOT_STARTED'
        Visibility = 'UNKNOWN'
        VisibilityBasis = 'NONE'
        ScanAllowed = [bool]$AllowScan
        ScanProviderInvoked = $false
        ScanRequested = $false
        ConnectionRequested = $false
        ConnectionOrigin = 'UNKNOWN'
        ScanResult = $null
        SnapshotCount = 0
        NetworkCount = $null
        SnapshotTimestampUtc = $null
        ErrorStage = ''
        ErrorMessage = ''
        AbsenceConfirmed = $false
        ScanTimeoutMs = $ScanTimeoutMs
    }
    $Stage = 'INITIAL_SNAPSHOT'
    try {
        $Snapshot = & $SnapshotProvider $InterfaceGuid $TargetSsid
        $Result.SnapshotCount++
        if ($null -eq $Snapshot -or $Snapshot.Success -isnot [bool]) { throw 'Invalid snapshot result.' }
        if (-not $Snapshot.Success) { throw 'Initial snapshot query failed.' }
        if ([guid]$Snapshot.Data.InterfaceGuid -ne $InterfaceGuid) { throw 'Snapshot interface mismatch.' }
        $Networks = @($Snapshot.Data.Networks)
        $Result.NetworkCount = $Networks.Count
        $Result.SnapshotTimestampUtc = [DateTime]::UtcNow.ToString('o')
        $Present = @($Networks | Where-Object { [string]::Equals([string]$_.Ssid,$TargetSsid,[StringComparison]::Ordinal) }).Count -gt 0
        if ($Present) {
            $Result.Success = $true
            $Result.Status = 'CACHE_TARGET_VISIBLE'
            $Result.Visibility = 'VISIBLE'
            $Result.VisibilityBasis = 'CACHED_SNAPSHOT'
            return $Result
        }
        if (-not $AllowScan) {
            $Result.Success = $true
            $Result.Status = 'CACHE_MISS_SCAN_NOT_ALLOWED'
            $Result.VisibilityBasis = 'CACHED_SNAPSHOT'
            return $Result
        }
        $Stage = 'SCAN'
        $Result.ScanProviderInvoked = $true
        # If a provider throws, whether it reached WlanScan is unknown.
        $Result.ScanRequested = $null
        $Scan = & $ScanProvider $InterfaceGuid $ScanTimeoutMs
        $Result.ScanResult = $Scan
        if ($null -eq $Scan -or $Scan.ScanRequested -isnot [bool] -or $Scan.Success -isnot [bool]) { throw 'Invalid scan result.' }
        $Result.ScanRequested = $Scan.ScanRequested
        if (-not $Scan.Success -or $Scan.Status -cne 'SCAN_COMPLETE_OBSERVED') {
            $Result.Status = 'SCAN_INCOMPLETE'
            $Result.ErrorStage = $Stage
            return $Result
        }
        if ($Scan.RequestAccepted -isnot [bool] -or -not $Scan.RequestAccepted -or -not $Scan.ScanRequested) { throw 'Completion without an accepted request.' }
        if ($Scan.UnregisterErrorCode -ne 0 -or $Scan.CloseErrorCode -ne 0 -or $Scan.CallbackError) { throw 'Scan cleanup or callback error.' }
        if ([guid]$Scan.InterfaceGuid -ne $InterfaceGuid) { throw 'Scan interface mismatch.' }
        $Stage = 'POST_SCAN_SNAPSHOT'
        $Snapshot = & $SnapshotProvider $InterfaceGuid $TargetSsid
        $Result.SnapshotCount++
        if ($null -eq $Snapshot -or $Snapshot.Success -isnot [bool]) { throw 'Invalid post-scan snapshot result.' }
        if (-not $Snapshot.Success) { throw 'Post-scan snapshot query failed.' }
        if ([guid]$Snapshot.Data.InterfaceGuid -ne $InterfaceGuid) { throw 'Post-scan interface mismatch.' }
        $Networks = @($Snapshot.Data.Networks)
        $Result.NetworkCount = $Networks.Count
        $Result.SnapshotTimestampUtc = [DateTime]::UtcNow.ToString('o')
        $Present = @($Networks | Where-Object { [string]::Equals([string]$_.Ssid,$TargetSsid,[StringComparison]::Ordinal) }).Count -gt 0
        $Result.Success = $true
        $Result.VisibilityBasis = 'SNAPSHOT_AFTER_SCAN_COMPLETE_OBSERVED'
        if ($Present) {
            $Result.Visibility = 'VISIBLE'
            $Result.Status = 'POST_SCAN_TARGET_VISIBLE'
        } else {
            # A single scan window is not a validated absence policy.
            $Result.Status = 'POST_SCAN_TARGET_NOT_OBSERVED'
        }
        return $Result
    } catch {
        $Result.Success = $false
        $Result.Status = 'DISCOVERY_ERROR'
        $Result.Visibility = 'UNKNOWN'
        $Result.ErrorStage = $Stage
        $Result.ErrorMessage = $_.Exception.Message
        return $Result
    } finally {
        $Result.FinishedUtc = [DateTime]::UtcNow.ToString('o')
    }
}
