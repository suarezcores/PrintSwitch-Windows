# Native Wi-Fi explicit scan primitive. Loading this file performs no WLAN calls.
# Requires explicit interface GUID and explicit opt-in at invocation time.
$script:PrintSwitchScanSource = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;
namespace PrintSwitch.NativeWifi.ScanV010 {
 public sealed class ScanOutcome {
  public string Status = "NOT_STARTED";
  public bool RequestIssued;
  public bool RequestAccepted;
  public uint ApiErrorCode;
  public uint ScanFailureReason;
  public uint UnregisterErrorCode;
  public uint CloseErrorCode;
  public bool CallbackError;
 }
 [StructLayout(LayoutKind.Sequential)]
 internal struct Notification {
  internal uint Source;
  internal uint Code;
  internal Guid InterfaceGuid;
  internal uint DataSize;
  internal IntPtr Data;
 }
 internal static class Native {
  [UnmanagedFunctionPointer(CallingConvention.Winapi)]
  internal delegate void Callback(ref Notification data, IntPtr context);
  [DllImport("wlanapi.dll")]
  internal static extern uint WlanOpenHandle(uint version, IntPtr reserved, out uint negotiated, out IntPtr handle);
  [DllImport("wlanapi.dll")]
  internal static extern uint WlanRegisterNotification(IntPtr handle, uint source, [MarshalAs(UnmanagedType.Bool)] bool ignoreDuplicates, Callback callback, IntPtr context, IntPtr reserved, out uint previous);
  [DllImport("wlanapi.dll")]
  internal static extern uint WlanScan(IntPtr handle, ref Guid guid, IntPtr ssid, IntPtr ie, IntPtr reserved);
  [DllImport("wlanapi.dll")]
  internal static extern uint WlanCloseHandle(IntPtr handle, IntPtr reserved);
 }
 public static class Scanner {
  // Keep callback alive if native cleanup fails; a stale callback must never enter freed memory.
  private static readonly List<object> Retained = new List<object>();
  private static readonly object Serial = new object();
  public static ScanOutcome Run(Guid guid, int timeoutMs) {
   if (guid == Guid.Empty) throw new ArgumentException("An explicit interface GUID is required.");
   if (timeoutMs < 1000 || timeoutMs > 30000) throw new ArgumentOutOfRangeException("timeoutMs");
   if (!Monitor.TryEnter(Serial)) return new ScanOutcome { Status = "BUSY" };
   IntPtr handle = IntPtr.Zero;
   ManualResetEvent completed = new ManualResetEvent(false);
   object gate = new object();
   ScanOutcome result = new ScanOutcome();
   bool armed = false;
   bool registered = false;
   bool terminal = false;
   Native.Callback callback = delegate(ref Notification n, IntPtr context) {
    try {
     lock (gate) {
      if (!armed || terminal || (n.Source & 8) == 0 || n.InterfaceGuid != guid) return;
      if (n.Code != 7 && n.Code != 8) return;
      terminal = true;
      if (n.Code == 7) result.Status = "SCAN_COMPLETE_OBSERVED";
      else {
       result.Status = "SCAN_FAILED_OBSERVED";
       if (n.Data != IntPtr.Zero && n.DataSize >= 4)
        result.ScanFailureReason = unchecked((uint)Marshal.ReadInt32(n.Data));
      }
      completed.Set();
     }
    } catch {
     lock (gate) {
      result.CallbackError = true;
      result.Status = "CALLBACK_ERROR";
      terminal = true;
      completed.Set();
     }
    }
   };
   try {
    uint negotiated, previous;
    uint code = Native.WlanOpenHandle(2, IntPtr.Zero, out negotiated, out handle);
    if (code != 0) { result.Status = "OPEN_FAILED"; result.ApiErrorCode = code; return result; }
    code = Native.WlanRegisterNotification(handle, 8, false, callback, IntPtr.Zero, IntPtr.Zero, out previous);
    if (code != 0) { result.Status = "REGISTER_FAILED"; result.ApiErrorCode = code; return result; }
    registered = true;
    lock (gate) { armed = true; result.RequestIssued = true; result.Status = "SCAN_PENDING"; }
    code = Native.WlanScan(handle, ref guid, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
    lock (gate) {
     result.ApiErrorCode = code;
     result.RequestAccepted = code == 0;
     if (code != 0) { armed = false; result.Status = "REQUEST_REJECTED"; return result; }
    }
    bool signaled = completed.WaitOne(timeoutMs);
    lock (gate) {
     armed = false;
     if (!signaled && !terminal) result.Status = "TIMEOUT";
    }
    return result;
   } finally {
    lock (gate) { armed = false; }
    bool safe = !registered;
    try {
     if (registered) {
      uint previous;
      result.UnregisterErrorCode = Native.WlanRegisterNotification(handle, 0, false, null, IntPtr.Zero, IntPtr.Zero, out previous);
      safe = result.UnregisterErrorCode == 0;
     }
    } finally {
     try {
      if (handle != IntPtr.Zero) {
       result.CloseErrorCode = Native.WlanCloseHandle(handle, IntPtr.Zero);
       if (result.CloseErrorCode == 0) safe = true;
      }
     } finally {
      if (safe) completed.Dispose();
      else { lock (Retained) { Retained.Add(callback); Retained.Add(completed); } }
      GC.KeepAlive(callback);
      Monitor.Exit(Serial);
     }
    }
   }
  }
 }
}
'@

function Initialize-PrintSwitchNativeWifiScanner {
    [CmdletBinding()]
    param()
    if (-not ('PrintSwitch.NativeWifi.ScanV010.Scanner' -as [type])) {
        Add-Type -TypeDefinition $script:PrintSwitchScanSource -Language CSharp -ErrorAction Stop
    }
}

function Invoke-PrintSwitchNativeWifiScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][guid]$InterfaceGuid,
        [ValidateRange(1000,30000)][int]$TimeoutMs = 4000,
        [switch]$AllowScan
    )
    if (-not $AllowScan) { throw 'Explicit scan requires -AllowScan. Windows may react autonomously to network discovery.' }
    if ($InterfaceGuid -eq [guid]::Empty) { throw 'Specify the actual interface GUID.' }
    Initialize-PrintSwitchNativeWifiScanner
    $Started = [DateTime]::UtcNow
    $Outcome = [PrintSwitch.NativeWifi.ScanV010.Scanner]::Run($InterfaceGuid, $TimeoutMs)
    [pscustomobject]@{
        Component = 'NativeWifiScanner'
        Version = '0.1.0'
        Operation = 'EXPLICIT_SCAN'
        InterfaceGuid = $InterfaceGuid
        StartedUtc = $Started.ToString('o')
        FinishedUtc = [DateTime]::UtcNow.ToString('o')
        Status = $Outcome.Status
        Success = ($Outcome.Status -eq 'SCAN_COMPLETE_OBSERVED' -and $Outcome.UnregisterErrorCode -eq 0 -and $Outcome.CloseErrorCode -eq 0)
        ScanRequested = $Outcome.RequestIssued
        RequestAccepted = $Outcome.RequestAccepted
        ConnectionRequested = $false
        ConnectionOrigin = 'UNKNOWN'
        Visibility = 'UNKNOWN'
        ApiErrorCode = $Outcome.ApiErrorCode
        ScanFailureReason = $Outcome.ScanFailureReason
        UnregisterErrorCode = $Outcome.UnregisterErrorCode
        CloseErrorCode = $Outcome.CloseErrorCode
        CallbackError = $Outcome.CallbackError
        Correlation = 'INTERFACE_AND_TIME_WINDOW_ONLY'
        ExclusiveRequestCorrelation = $false
        TimeoutMs = $TimeoutMs
    }
}
