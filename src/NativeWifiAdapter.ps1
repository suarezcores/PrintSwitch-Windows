Set-StrictMode -Version Latest

$script:PrintSwitchNativeWifiAdapterVersion = "0.1.0"
$script:PrintSwitchNativeWifiInteropType = "PrintSwitch.NativeWifi.Reader"

$script:PrintSwitchNativeWifiInteropSource = @"
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace PrintSwitch.NativeWifi
{
    public sealed class InterfaceSnapshot
    {
        public Guid InterfaceGuid { get; set; }
        public string Description { get; set; }
        public int StateCode { get; set; }
    }

    public sealed class ConnectionSnapshot
    {
        public Guid InterfaceGuid { get; set; }
        public int InterfaceStateCode { get; set; }
        public int ConnectionModeCode { get; set; }
        public string ProfileName { get; set; }
        public string Ssid { get; set; }
        public string Bssid { get; set; }
        public uint SignalQuality { get; set; }
        public uint RxRate { get; set; }
        public uint TxRate { get; set; }
        public bool SecurityEnabled { get; set; }
    }

    public sealed class AvailableNetworkSnapshot
    {
        public string ProfileName { get; set; }
        public string Ssid { get; set; }
        public int BssTypeCode { get; set; }
        public uint BssidCount { get; set; }
        public bool Connectable { get; set; }
        public uint NotConnectableReason { get; set; }
        public uint SignalQuality { get; set; }
        public bool SecurityEnabled { get; set; }
        public uint AuthenticationAlgorithm { get; set; }
        public uint CipherAlgorithm { get; set; }
        public uint Flags { get; set; }
    }

    internal static class NativeMethods
    {
        internal const uint ClientVersion = 2;
        internal const int CurrentConnectionOpcode = 7;

        [DllImport("wlanapi.dll")]
        internal static extern uint WlanOpenHandle(
            uint clientVersion,
            IntPtr reserved,
            out uint negotiatedVersion,
            out IntPtr clientHandle
        );

        [DllImport("wlanapi.dll")]
        internal static extern uint WlanCloseHandle(
            IntPtr clientHandle,
            IntPtr reserved
        );

        [DllImport("wlanapi.dll")]
        internal static extern uint WlanEnumInterfaces(
            IntPtr clientHandle,
            IntPtr reserved,
            out IntPtr interfaceList
        );

        [DllImport("wlanapi.dll")]
        internal static extern uint WlanQueryInterface(
            IntPtr clientHandle,
            ref Guid interfaceGuid,
            int opcode,
            IntPtr reserved,
            out uint dataSize,
            out IntPtr data,
            out int opcodeValueType
        );

        [DllImport("wlanapi.dll")]
        internal static extern uint WlanGetAvailableNetworkList(
            IntPtr clientHandle,
            ref Guid interfaceGuid,
            uint flags,
            IntPtr reserved,
            out IntPtr availableNetworkList
        );

        [DllImport("wlanapi.dll")]
        internal static extern void WlanFreeMemory(
            IntPtr memory
        );
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct WLAN_INTERFACE_INFO
    {
        public Guid InterfaceGuid;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        public string InterfaceDescription;

        public int InterfaceState;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct DOT11_SSID
    {
        public uint SSIDLength;

        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)]
        public byte[] SSID;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct WLAN_ASSOCIATION_ATTRIBUTES
    {
        public DOT11_SSID Dot11Ssid;
        public int Dot11BssType;

        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 6)]
        public byte[] Dot11Bssid;

        public int Dot11PhyType;
        public uint Dot11PhyIndex;
        public uint SignalQuality;
        public uint RxRate;
        public uint TxRate;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct WLAN_SECURITY_ATTRIBUTES
    {
        [MarshalAs(UnmanagedType.Bool)]
        public bool SecurityEnabled;

        [MarshalAs(UnmanagedType.Bool)]
        public bool OneXEnabled;

        public uint AuthenticationAlgorithm;
        public uint CipherAlgorithm;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct WLAN_CONNECTION_ATTRIBUTES
    {
        public int InterfaceState;
        public int ConnectionMode;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        public string ProfileName;

        public WLAN_ASSOCIATION_ATTRIBUTES Association;
        public WLAN_SECURITY_ATTRIBUTES Security;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct WLAN_AVAILABLE_NETWORK
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        public string ProfileName;

        public DOT11_SSID Dot11Ssid;
        public int Dot11BssType;
        public uint BssidCount;

        [MarshalAs(UnmanagedType.Bool)]
        public bool NetworkConnectable;

        public uint NotConnectableReason;
        public uint NumberOfPhyTypes;

        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)]
        public int[] Dot11PhyTypes;

        [MarshalAs(UnmanagedType.Bool)]
        public bool MorePhyTypes;

        public uint SignalQuality;

        [MarshalAs(UnmanagedType.Bool)]
        public bool SecurityEnabled;

        public uint AuthenticationAlgorithm;
        public uint CipherAlgorithm;
        public uint Flags;
        public uint Reserved;
    }

    public static class Reader
    {
        private static void ThrowIfError(uint result, string operation)
        {
            if (result != 0)
            {
                throw new Win32Exception(
                    unchecked((int)result),
                    operation + " failed with code " + result
                );
            }
        }

        private static IntPtr AddOffset(IntPtr pointer, int offset)
        {
            return new IntPtr(pointer.ToInt64() + offset);
        }

        private static string DecodeSsid(DOT11_SSID ssid)
        {
            if (ssid.SSID == null || ssid.SSIDLength == 0)
            {
                return String.Empty;
            }

            int length = (int)Math.Min(
                ssid.SSIDLength,
                (uint)ssid.SSID.Length
            );

            return Encoding.UTF8.GetString(ssid.SSID, 0, length);
        }

        private static string FormatBssid(byte[] bytes)
        {
            if (bytes == null || bytes.Length == 0)
            {
                return String.Empty;
            }

            string[] parts = new string[bytes.Length];

            for (int index = 0; index < bytes.Length; index++)
            {
                parts[index] = bytes[index].ToString("x2");
            }

            return String.Join(":", parts);
        }

        private static IntPtr OpenClient()
        {
            uint negotiatedVersion;
            IntPtr clientHandle;

            uint result = NativeMethods.WlanOpenHandle(
                NativeMethods.ClientVersion,
                IntPtr.Zero,
                out negotiatedVersion,
                out clientHandle
            );

            ThrowIfError(result, "WlanOpenHandle");
            return clientHandle;
        }

        public static InterfaceSnapshot[] GetInterfaces()
        {
            IntPtr clientHandle = IntPtr.Zero;
            IntPtr listPointer = IntPtr.Zero;

            try
            {
                clientHandle = OpenClient();

                uint result = NativeMethods.WlanEnumInterfaces(
                    clientHandle,
                    IntPtr.Zero,
                    out listPointer
                );

                ThrowIfError(result, "WlanEnumInterfaces");

                int count = Marshal.ReadInt32(listPointer, 0);
                int itemOffset = 8;
                int itemSize = Marshal.SizeOf(typeof(WLAN_INTERFACE_INFO));

                List<InterfaceSnapshot> snapshots =
                    new List<InterfaceSnapshot>();

                for (int index = 0; index < count; index++)
                {
                    IntPtr itemPointer = AddOffset(
                        listPointer,
                        itemOffset + (index * itemSize)
                    );

                    WLAN_INTERFACE_INFO item =
                        (WLAN_INTERFACE_INFO)Marshal.PtrToStructure(
                            itemPointer,
                            typeof(WLAN_INTERFACE_INFO)
                        );

                    snapshots.Add(
                        new InterfaceSnapshot
                        {
                            InterfaceGuid = item.InterfaceGuid,
                            Description = item.InterfaceDescription,
                            StateCode = item.InterfaceState
                        }
                    );
                }

                return snapshots.ToArray();
            }
            finally
            {
                if (listPointer != IntPtr.Zero)
                {
                    NativeMethods.WlanFreeMemory(listPointer);
                }

                if (clientHandle != IntPtr.Zero)
                {
                    NativeMethods.WlanCloseHandle(
                        clientHandle,
                        IntPtr.Zero
                    );
                }
            }
        }

        public static ConnectionSnapshot GetCurrentConnection(
            Guid interfaceGuid
        )
        {
            IntPtr clientHandle = IntPtr.Zero;
            IntPtr dataPointer = IntPtr.Zero;

            try
            {
                clientHandle = OpenClient();

                uint dataSize;
                int opcodeValueType;

                uint result = NativeMethods.WlanQueryInterface(
                    clientHandle,
                    ref interfaceGuid,
                    NativeMethods.CurrentConnectionOpcode,
                    IntPtr.Zero,
                    out dataSize,
                    out dataPointer,
                    out opcodeValueType
                );

                ThrowIfError(result, "WlanQueryInterface");

                WLAN_CONNECTION_ATTRIBUTES connection =
                    (WLAN_CONNECTION_ATTRIBUTES)Marshal.PtrToStructure(
                        dataPointer,
                        typeof(WLAN_CONNECTION_ATTRIBUTES)
                    );

                return new ConnectionSnapshot
                {
                    InterfaceGuid = interfaceGuid,
                    InterfaceStateCode = connection.InterfaceState,
                    ConnectionModeCode = connection.ConnectionMode,
                    ProfileName = connection.ProfileName,
                    Ssid = DecodeSsid(connection.Association.Dot11Ssid),
                    Bssid = FormatBssid(
                        connection.Association.Dot11Bssid
                    ),
                    SignalQuality =
                        connection.Association.SignalQuality,
                    RxRate = connection.Association.RxRate,
                    TxRate = connection.Association.TxRate,
                    SecurityEnabled =
                        connection.Security.SecurityEnabled
                };
            }
            finally
            {
                if (dataPointer != IntPtr.Zero)
                {
                    NativeMethods.WlanFreeMemory(dataPointer);
                }

                if (clientHandle != IntPtr.Zero)
                {
                    NativeMethods.WlanCloseHandle(
                        clientHandle,
                        IntPtr.Zero
                    );
                }
            }
        }

        public static AvailableNetworkSnapshot[] GetAvailableNetworks(
            Guid interfaceGuid
        )
        {
            IntPtr clientHandle = IntPtr.Zero;
            IntPtr listPointer = IntPtr.Zero;

            try
            {
                clientHandle = OpenClient();

                uint result =
                    NativeMethods.WlanGetAvailableNetworkList(
                        clientHandle,
                        ref interfaceGuid,
                        0,
                        IntPtr.Zero,
                        out listPointer
                    );

                ThrowIfError(
                    result,
                    "WlanGetAvailableNetworkList"
                );

                int count = Marshal.ReadInt32(listPointer, 0);
                int itemOffset = 8;

                int itemSize = Marshal.SizeOf(
                    typeof(WLAN_AVAILABLE_NETWORK)
                );

                List<AvailableNetworkSnapshot> snapshots =
                    new List<AvailableNetworkSnapshot>();

                for (int index = 0; index < count; index++)
                {
                    IntPtr itemPointer = AddOffset(
                        listPointer,
                        itemOffset + (index * itemSize)
                    );

                    WLAN_AVAILABLE_NETWORK item =
                        (WLAN_AVAILABLE_NETWORK)Marshal.PtrToStructure(
                            itemPointer,
                            typeof(WLAN_AVAILABLE_NETWORK)
                        );

                    snapshots.Add(
                        new AvailableNetworkSnapshot
                        {
                            ProfileName = item.ProfileName,
                            Ssid = DecodeSsid(item.Dot11Ssid),
                            BssTypeCode = item.Dot11BssType,
                            BssidCount = item.BssidCount,
                            Connectable = item.NetworkConnectable,
                            NotConnectableReason =
                                item.NotConnectableReason,
                            SignalQuality = item.SignalQuality,
                            SecurityEnabled =
                                item.SecurityEnabled,
                            AuthenticationAlgorithm =
                                item.AuthenticationAlgorithm,
                            CipherAlgorithm =
                                item.CipherAlgorithm,
                            Flags = item.Flags
                        }
                    );
                }

                return snapshots.ToArray();
            }
            finally
            {
                if (listPointer != IntPtr.Zero)
                {
                    NativeMethods.WlanFreeMemory(listPointer);
                }

                if (clientHandle != IntPtr.Zero)
                {
                    NativeMethods.WlanCloseHandle(
                        clientHandle,
                        IntPtr.Zero
                    );
                }
            }
        }
    }
}
"@

function New-PrintSwitchNativeWifiResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [bool]$Success,

        [Parameter()]
        [AllowNull()]
        [object]$Data,

        [Parameter()]
        [string]$Visibility = "NOT_EVALUATED",

        [Parameter()]
        [string]$ConnectionOrigin = "UNKNOWN",

        [Parameter()]
        [int]$ErrorCode = 0,

        [Parameter()]
        [string]$ErrorMessage = ""
    )

    [pscustomobject]@{
        Component           = "NativeWifiAdapter"
        Version             = $script:PrintSwitchNativeWifiAdapterVersion
        Operation           = $Operation
        Success             = $Success
        TimestampUtc        = [DateTime]::UtcNow.ToString("o")
        MutationPerformed   = $false
        ScanRequested       = $false
        ConnectionRequested = $false
        Visibility          = $Visibility
        ConnectionOrigin    = $ConnectionOrigin
        ErrorCode           = $ErrorCode
        ErrorMessage        = $ErrorMessage
        Data                = $Data
    }
}

function Initialize-PrintSwitchNativeWifiAdapter {
    [CmdletBinding()]
    param()

    $ExistingType = ([System.Management.Automation.PSTypeName]$script:PrintSwitchNativeWifiInteropType).Type

    if ($null -eq $ExistingType) {
        Add-Type `
            -TypeDefinition $script:PrintSwitchNativeWifiInteropSource `
            -Language CSharp `
            -ErrorAction Stop
    }

    $ResolvedType = ([System.Management.Automation.PSTypeName]$script:PrintSwitchNativeWifiInteropType).Type

    if ($null -eq $ResolvedType) {
        throw "No se pudo inicializar el interop Native Wi-Fi."
    }

    $true
}

function ConvertTo-PrintSwitchNativeWifiState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$StateCode
    )

    switch ($StateCode) {
        0 { "NOT_READY" }
        1 { "CONNECTED" }
        2 { "AD_HOC_FORMED" }
        3 { "DISCONNECTING" }
        4 { "DISCONNECTED" }
        5 { "ASSOCIATING" }
        6 { "DISCOVERING" }
        7 { "AUTHENTICATING" }
        default { "UNKNOWN" }
    }
}

function Get-PrintSwitchNativeWifiInterfaces {
    [CmdletBinding()]
    param()

    try {
        $null = Initialize-PrintSwitchNativeWifiAdapter

        $Interfaces = @(
            [PrintSwitch.NativeWifi.Reader]::GetInterfaces() |
                ForEach-Object {
                    [pscustomobject]@{
                        InterfaceGuid = $_.InterfaceGuid
                        Description   = $_.Description
                        StateCode     = $_.StateCode
                        State         = ConvertTo-PrintSwitchNativeWifiState `
                            -StateCode $_.StateCode
                    }
                }
        )

        New-PrintSwitchNativeWifiResult `
            -Operation "ENUM_INTERFACES" `
            -Success $true `
            -Data $Interfaces
    }
    catch {
        New-PrintSwitchNativeWifiResult `
            -Operation "ENUM_INTERFACES" `
            -Success $false `
            -Data @() `
            -ErrorCode $_.Exception.HResult `
            -ErrorMessage $_.Exception.Message
    }
}

function Resolve-PrintSwitchNativeWifiInterface {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$InterfaceGuid = "",

        [Parameter()]
        [string]$InterfaceDescription = ""
    )

    $InterfaceResult = Get-PrintSwitchNativeWifiInterfaces

    if (-not $InterfaceResult.Success) {
        return $null
    }

    $Interfaces = @($InterfaceResult.Data)

    if (-not [string]::IsNullOrWhiteSpace($InterfaceGuid)) {
        return @(
            $Interfaces |
                Where-Object {
                    $_.InterfaceGuid.ToString() -eq $InterfaceGuid
                }
        ) | Select-Object -First 1
    }

    if (-not [string]::IsNullOrWhiteSpace($InterfaceDescription)) {
        return @(
            $Interfaces |
                Where-Object {
                    $_.Description -eq $InterfaceDescription
                }
        ) | Select-Object -First 1
    }

    $Connected = @(
        $Interfaces |
            Where-Object {
                $_.State -eq "CONNECTED"
            }
    ) | Select-Object -First 1

    if ($null -ne $Connected) {
        return $Connected
    }

    @($Interfaces) | Select-Object -First 1
}

function Get-PrintSwitchNativeWifiConnection {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$InterfaceGuid = "",

        [Parameter()]
        [string]$InterfaceDescription = ""
    )

    try {
        $Interface = Resolve-PrintSwitchNativeWifiInterface `
            -InterfaceGuid $InterfaceGuid `
            -InterfaceDescription $InterfaceDescription

        if ($null -eq $Interface) {
            return New-PrintSwitchNativeWifiResult `
                -Operation "CURRENT_CONNECTION" `
                -Success $false `
                -Data $null `
                -ErrorCode 1 `
                -ErrorMessage "No se encontró una interfaz WLAN."
        }

        $Snapshot = [PrintSwitch.NativeWifi.Reader]::GetCurrentConnection(
            [guid]$Interface.InterfaceGuid
        )

        $Data = [pscustomobject]@{
            InterfaceGuid     = $Snapshot.InterfaceGuid
            InterfaceState    = ConvertTo-PrintSwitchNativeWifiState `
                -StateCode $Snapshot.InterfaceStateCode
            InterfaceStateCode = $Snapshot.InterfaceStateCode
            ConnectionModeCode = $Snapshot.ConnectionModeCode
            ProfileName       = $Snapshot.ProfileName
            Ssid              = $Snapshot.Ssid
            Bssid             = $Snapshot.Bssid
            SignalQuality     = $Snapshot.SignalQuality
            RxRate            = $Snapshot.RxRate
            TxRate            = $Snapshot.TxRate
            SecurityEnabled   = $Snapshot.SecurityEnabled
        }

        New-PrintSwitchNativeWifiResult `
            -Operation "CURRENT_CONNECTION" `
            -Success $true `
            -Data $Data `
            -ConnectionOrigin "UNKNOWN"
    }
    catch {
        New-PrintSwitchNativeWifiResult `
            -Operation "CURRENT_CONNECTION" `
            -Success $false `
            -Data $null `
            -ErrorCode $_.Exception.HResult `
            -ErrorMessage $_.Exception.Message
    }
}

function Get-PrintSwitchNativeWifiVisibilitySnapshot {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TargetSsid = "",

        [Parameter()]
        [string]$InterfaceGuid = "",

        [Parameter()]
        [string]$InterfaceDescription = ""
    )

    try {
        $Interface = Resolve-PrintSwitchNativeWifiInterface `
            -InterfaceGuid $InterfaceGuid `
            -InterfaceDescription $InterfaceDescription

        if ($null -eq $Interface) {
            return New-PrintSwitchNativeWifiResult `
                -Operation "CACHED_NETWORK_SNAPSHOT" `
                -Success $false `
                -Data @() `
                -Visibility "UNKNOWN" `
                -ErrorCode 1 `
                -ErrorMessage "No se encontró una interfaz WLAN."
        }

        $Networks = @(
            [PrintSwitch.NativeWifi.Reader]::GetAvailableNetworks(
                [guid]$Interface.InterfaceGuid
            ) |
                ForEach-Object {
                    [pscustomobject]@{
                        ProfileName            = $_.ProfileName
                        Ssid                   = $_.Ssid
                        BssTypeCode            = $_.BssTypeCode
                        BssidCount             = $_.BssidCount
                        Connectable            = $_.Connectable
                        NotConnectableReason   = $_.NotConnectableReason
                        SignalQuality          = $_.SignalQuality
                        SecurityEnabled        = $_.SecurityEnabled
                        AuthenticationAlgorithm = $_.AuthenticationAlgorithm
                        CipherAlgorithm        = $_.CipherAlgorithm
                        Flags                  = $_.Flags
                    }
                }
        )

        $Visibility = "NOT_EVALUATED"

        if (-not [string]::IsNullOrWhiteSpace($TargetSsid)) {
            $TargetVisible = @(
                $Networks |
                    Where-Object {
                        $_.Ssid -eq $TargetSsid
                    }
            ).Count -gt 0

            if ($TargetVisible) {
                $Visibility = "VISIBLE"
            }
            else {
                # No hubo WlanScan ni scan_complete correlacionado.
                # Por contrato, la ausencia sólo puede clasificarse UNKNOWN.
                $Visibility = "UNKNOWN"
            }
        }

        $Data = [pscustomobject]@{
            InterfaceGuid = $Interface.InterfaceGuid
            Description   = $Interface.Description
            SnapshotKind  = "WINDOWS_CACHED_AVAILABLE_NETWORK_LIST"
            FreshScan     = $false
            NetworkCount  = $Networks.Count
            Networks      = $Networks
        }

        New-PrintSwitchNativeWifiResult `
            -Operation "CACHED_NETWORK_SNAPSHOT" `
            -Success $true `
            -Data $Data `
            -Visibility $Visibility `
            -ConnectionOrigin "UNKNOWN"
    }
    catch {
        New-PrintSwitchNativeWifiResult `
            -Operation "CACHED_NETWORK_SNAPSHOT" `
            -Success $false `
            -Data @() `
            -Visibility "UNKNOWN" `
            -ErrorCode $_.Exception.HResult `
            -ErrorMessage $_.Exception.Message
    }
}

function Test-PrintSwitchNativeWifiResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Result
    )

    $RequiredProperties = @(
        "Component",
        "Version",
        "Operation",
        "Success",
        "TimestampUtc",
        "MutationPerformed",
        "ScanRequested",
        "ConnectionRequested",
        "Visibility",
        "ConnectionOrigin",
        "ErrorCode",
        "ErrorMessage",
        "Data"
    )

    foreach ($PropertyName in $RequiredProperties) {
        if ($Result.PSObject.Properties.Name -notcontains $PropertyName) {
            return $false
        }
    }

    if ($Result.Component -ne "NativeWifiAdapter") {
        return $false
    }

    if ($Result.Visibility -notin @(
        "NOT_EVALUATED",
        "VISIBLE",
        "NOT_VISIBLE_CONFIRMED",
        "SCAN_PENDING",
        "UNKNOWN"
    )) {
        return $false
    }

    if ($Result.ConnectionOrigin -notin @(
        "USER_EXPLICIT",
        "PRINTSWITCH_EXPLICIT",
        "WINDOWS_FAILOVER",
        "WINDOWS_AUTORESTORE",
        "UNKNOWN"
    )) {
        return $false
    }

    if ($Result.MutationPerformed) {
        return $false
    }

    if ($Result.ScanRequested) {
        return $false
    }

    if ($Result.ConnectionRequested) {
        return $false
    }

    $true
}

function Get-PrintSwitchNativeWifiAdapterCapability {
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        Component               = "NativeWifiAdapter"
        Version                 = $script:PrintSwitchNativeWifiAdapterVersion
        ReadOnly                = $true
        SupportsInterfaceQuery  = $true
        SupportsConnectionQuery = $true
        SupportsCachedNetworks  = $true
        SupportsExplicitScan    = $false
        SupportsNotifications   = $false
        SupportsConnect         = $false
        SupportsDisconnect      = $false
        UsesNetsh               = $false
    }
}
