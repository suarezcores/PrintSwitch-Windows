# PrinterEndpointReachability.ps1
# PrintSwitch-Windows
#
# Objetivo:
#   Evaluar la alcanzabilidad operacional de un endpoint normalizado
#   producido por PrinterEndpointResolver.
#
# Principios:
#   - READ-ONLY.
#   - No modifica impresoras, red, rutas ni configuración.
#   - La estrategia de reachability proviene del endpoint.
#   - No asume TCP/9100 como protocolo universal.
#   - Los hostnames se resuelven explícitamente antes del probe TCP.
#   - Las pruebas TCP tienen timeout acotado.
#   - Una estrategia no implementada devuelve UNKNOWN; no se adivina.
#
# Estado:
#   Post-Alpha / experimental.
#   Todavía NO integrado al core operativo.

Set-StrictMode -Version Latest


function Resolve-PrintSwitchNetworkDestination {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Destination
    )

    $parsedAddress = $null

    if (
        [System.Net.IPAddress]::TryParse(
            $Destination,
            [ref]$parsedAddress
        )
    ) {

        return [PSCustomObject]@{
            Success             = $true
            ConfiguredDestination = $Destination
            ResolvedDestination = $parsedAddress.IPAddressToString
            ResolutionSource    = "DIRECT_IP"
            Error               = $null
        }
    }


    try {

        $addresses =
            [System.Net.Dns]::GetHostAddresses($Destination) |
            Where-Object {
                $_.AddressFamily -eq
                [System.Net.Sockets.AddressFamily]::InterNetwork
            }

        $resolved =
            $addresses |
            Select-Object -First 1

        if ($null -eq $resolved) {

            return [PSCustomObject]@{
                Success               = $false
                ConfiguredDestination = $Destination
                ResolvedDestination   = $null
                ResolutionSource      = "DOTNET_NAME_RESOLUTION"
                Error                 = "NO_IPV4_ADDRESS"
            }
        }


        return [PSCustomObject]@{
            Success               = $true
            ConfiguredDestination = $Destination
            ResolvedDestination   = $resolved.IPAddressToString
            ResolutionSource      = "DOTNET_NAME_RESOLUTION"
            Error                 = $null
        }
    }

    catch {

        return [PSCustomObject]@{
            Success               = $false
            ConfiguredDestination = $Destination
            ResolvedDestination   = $null
            ResolutionSource      = "DOTNET_NAME_RESOLUTION"
            Error                 = $_.Exception.Message
        }
    }
}


function Test-PrintSwitchEndpointTcp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $IPAddress,

        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int] $Port,

        [ValidateRange(100, 10000)]
        [int] $TimeoutMs = 1500
    )

    $client =
        [System.Net.Sockets.TcpClient]::new()

    $stopwatch =
        [System.Diagnostics.Stopwatch]::StartNew()

    try {

        $task =
            $client.ConnectAsync(
                $IPAddress,
                $Port
            )

        $completed =
            $task.Wait($TimeoutMs)

        $stopwatch.Stop()


        if (
            $completed -and
            $client.Connected
        ) {

            return [PSCustomObject]@{
                Reachable = $true
                ElapsedMs = $stopwatch.ElapsedMilliseconds
                Result    = "TCP_CONNECTION_SUCCEEDED"
                Error     = $null
            }
        }


        return [PSCustomObject]@{
            Reachable = $false
            ElapsedMs = $stopwatch.ElapsedMilliseconds
            Result    = "TCP_CONNECTION_TIMEOUT"
            Error     = $null
        }
    }

    catch {

        $stopwatch.Stop()

        return [PSCustomObject]@{
            Reachable = $false
            ElapsedMs = $stopwatch.ElapsedMilliseconds
            Result    = "TCP_CONNECTION_FAILED"
            Error     = $_.Exception.Message
        }
    }

    finally {

        $client.Dispose()
    }
}


function Test-PrintSwitchEndpointReachability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Endpoint,

        [ValidateRange(100, 10000)]
        [int] $TimeoutMs = 1500
    )


    # ------------------------------------------------------------
    # Validación mínima del contrato recibido
    # ------------------------------------------------------------

    $requiredProperties = @(
        "QueueName",
        "TransportType",
        "ConfiguredDestination",
        "ReachabilityStrategy"
    )


    foreach ($propertyName in $requiredProperties) {

        if (
            -not (
                $Endpoint.PSObject.Properties.Name -contains
                $propertyName
            )
        ) {

            throw (
                "El endpoint no contiene la propiedad requerida '{0}'." -f
                $propertyName
            )
        }
    }


    # ------------------------------------------------------------
    # Estrategias TCP
    # ------------------------------------------------------------

    if (
        $Endpoint.ReachabilityStrategy -in @(
            "LPR_TCP",
            "RAW_TCP"
        )
    ) {

        if (
            -not (
                $Endpoint.PSObject.Properties.Name -contains
                "TcpPort"
            ) -or
            $null -eq $Endpoint.TcpPort
        ) {

            return [PSCustomObject]@{
                Component             = "PrinterEndpointReachability"
                Version               = "0.3"

                QueueName             = $Endpoint.QueueName
                TransportType         = $Endpoint.TransportType
                ReachabilityStrategy  = $Endpoint.ReachabilityStrategy

                ConfiguredDestination = $Endpoint.ConfiguredDestination
                ResolvedDestination   = $null
                ResolutionSource      = $null

                TcpPort               = $null

                Reachable             = $false
                ReachabilityState     = "UNKNOWN"

                ProbeResult           = "TCP_PORT_MISSING"
                ElapsedMs             = $null
                Error                 = $null
            }
        }


        $resolution =
            Resolve-PrintSwitchNetworkDestination `
                -Destination $Endpoint.ConfiguredDestination


                if (-not $resolution.Success) {

            return [PSCustomObject]@{
                Component             = "PrinterEndpointReachability"
                Version               = "0.3"

                QueueName             = $Endpoint.QueueName
                TransportType         = $Endpoint.TransportType
                ReachabilityStrategy  = $Endpoint.ReachabilityStrategy

                ConfiguredDestination = $Endpoint.ConfiguredDestination
                ResolvedDestination   = $null
                ResolutionSource      = $resolution.ResolutionSource

                TcpPort               = [int]$Endpoint.TcpPort

                Reachable             = $false
                ReachabilityState     = "UNKNOWN"

                ProbeResult           = "DESTINATION_RESOLUTION_FAILED"
                ElapsedMs             = $null

                Error =
                    $resolution.Error
            }
        }


        $tcpResult =
            Test-PrintSwitchEndpointTcp `
                -IPAddress $resolution.ResolvedDestination `
                -Port ([int]$Endpoint.TcpPort) `
                -TimeoutMs $TimeoutMs


        $state =
            if ($tcpResult.Reachable) {
                "REACHABLE"
            }
            else {
                "UNREACHABLE"
            }


        return [PSCustomObject]@{
            Component             = "PrinterEndpointReachability"
            Version               = "0.3"

            QueueName             = $Endpoint.QueueName
            TransportType         = $Endpoint.TransportType
            ReachabilityStrategy  = $Endpoint.ReachabilityStrategy

            ConfiguredDestination = $Endpoint.ConfiguredDestination
            ResolvedDestination   = $resolution.ResolvedDestination
            ResolutionSource      = $resolution.ResolutionSource

            TcpPort               = [int]$Endpoint.TcpPort

            Reachable             = $tcpResult.Reachable
            ReachabilityState     = $state

            ProbeResult           = $tcpResult.Result
            ElapsedMs             = $tcpResult.ElapsedMs
            Error                 = $tcpResult.Error
        }
    }


    # ------------------------------------------------------------
    # USB
    #
    # Todavía NO usamos PrinterStatus ni existencia de USB001 como
    # prueba de presencia física.
    #
    # Necesitamos correlacionar cola/driver/PnP de manera fiable.
    # ------------------------------------------------------------

        elseif (
        $Endpoint.ReachabilityStrategy -eq
        "USB_PRESENCE"
    ) {

        $QueueRegistryPath =
            "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers\$($Endpoint.QueueName)"

        $PnPDataPath =
            Join-Path $QueueRegistryPath "PnPData"

        if (-not (Test-Path $PnPDataPath)) {

            return [PSCustomObject]@{
                Component             = "PrinterEndpointReachability"
                Version               = "0.3"

                QueueName             = $Endpoint.QueueName
                TransportType         = $Endpoint.TransportType
                ReachabilityStrategy  = $Endpoint.ReachabilityStrategy

                ConfiguredDestination = $Endpoint.ConfiguredDestination
                ResolvedDestination   = $null
                ResolutionSource      = $null

                TcpPort               = $null

                Reachable             = $false
                ReachabilityState     = "UNKNOWN"

                ProbeResult           = "USB_DEVICE_IDENTITY_UNAVAILABLE"
                ElapsedMs             = $null

                Error                 =
                    "La cola USB no posee una clave PnPData utilizable."
            }
        }

        try {

            $PnPData =
                Get-ItemProperty `
                    -Path $PnPDataPath `
                    -ErrorAction Stop

            $DeviceInstanceId =
                $PnPData.DeviceInstanceId

            if ([string]::IsNullOrWhiteSpace($DeviceInstanceId)) {

                return [PSCustomObject]@{
                    Component             = "PrinterEndpointReachability"
                    Version               = "0.3"

                    QueueName             = $Endpoint.QueueName
                    TransportType         = $Endpoint.TransportType
                    ReachabilityStrategy  = $Endpoint.ReachabilityStrategy

                    ConfiguredDestination = $Endpoint.ConfiguredDestination
                    ResolvedDestination   = $null
                    ResolutionSource      = $null

                    TcpPort               = $null

                    Reachable             = $false
                    ReachabilityState     = "UNKNOWN"

                    ProbeResult           = "USB_DEVICE_IDENTITY_UNAVAILABLE"
                    ElapsedMs             = $null

                    Error                 =
                        "PnPData existe, pero DeviceInstanceId no esta disponible."
                }
            }

            try {

                $PnPDevice =
                    Get-PnpDevice `
                        -PresentOnly `
                        -InstanceId $DeviceInstanceId `
                        -ErrorAction Stop

                return [PSCustomObject]@{
                    Component             = "PrinterEndpointReachability"
                    Version               = "0.3"

                    QueueName             = $Endpoint.QueueName
                    TransportType         = $Endpoint.TransportType
                    ReachabilityStrategy  = $Endpoint.ReachabilityStrategy

                    ConfiguredDestination = $Endpoint.ConfiguredDestination
                    ResolvedDestination   = $DeviceInstanceId
                    ResolutionSource      = "WINDOWS_PNP_DEVICE_INSTANCE"

                    TcpPort               = $null

                    Reachable             = $true
                    ReachabilityState     = "REACHABLE"

                    ProbeResult           = "USB_DEVICE_PRESENT"
                    ElapsedMs             = $null

                    Error                 = $null
                }
            }
            catch {

                $FullyQualifiedErrorId =
                    $_.FullyQualifiedErrorId

                if (
                    $FullyQualifiedErrorId -match
                    "CmdletizationQuery_NotFound"
                ) {

                    return [PSCustomObject]@{
                        Component             = "PrinterEndpointReachability"
                        Version               = "0.3"

                        QueueName             = $Endpoint.QueueName
                        TransportType         = $Endpoint.TransportType
                        ReachabilityStrategy  = $Endpoint.ReachabilityStrategy

                        ConfiguredDestination = $Endpoint.ConfiguredDestination
                        ResolvedDestination   = $DeviceInstanceId
                        ResolutionSource      = "WINDOWS_PNP_DEVICE_INSTANCE"

                        TcpPort               = $null

                        Reachable             = $false
                        ReachabilityState     = "UNREACHABLE"

                        ProbeResult           = "USB_DEVICE_NOT_PRESENT"
                        ElapsedMs             = $null

                        Error                 =
                            "El dispositivo USB conocido no esta presente actualmente."
                    }
                }

                return [PSCustomObject]@{
                    Component             = "PrinterEndpointReachability"
                    Version               = "0.3"

                    QueueName             = $Endpoint.QueueName
                    TransportType         = $Endpoint.TransportType
                    ReachabilityStrategy  = $Endpoint.ReachabilityStrategy

                    ConfiguredDestination = $Endpoint.ConfiguredDestination
                    ResolvedDestination   = $DeviceInstanceId
                    ResolutionSource      = "WINDOWS_PNP_DEVICE_INSTANCE"

                    TcpPort               = $null

                    Reachable             = $false
                    ReachabilityState     = "UNKNOWN"

                    ProbeResult           = "USB_PRESENCE_CHECK_FAILED"
                    ElapsedMs             = $null

                    Error                 = $_.Exception.Message
                }
            }
        }
        catch {

            return [PSCustomObject]@{
                Component             = "PrinterEndpointReachability"
                Version               = "0.3"

                QueueName             = $Endpoint.QueueName
                TransportType         = $Endpoint.TransportType
                ReachabilityStrategy  = $Endpoint.ReachabilityStrategy

                ConfiguredDestination = $Endpoint.ConfiguredDestination
                ResolvedDestination   = $null
                ResolutionSource      = $null

                TcpPort               = $null

                Reachable             = $false
                ReachabilityState     = "UNKNOWN"

                ProbeResult           = "USB_DEVICE_IDENTITY_UNAVAILABLE"
                ElapsedMs             = $null

                Error                 = $_.Exception.Message
            }
        }
    }


    # ------------------------------------------------------------
    # Estrategia desconocida
    # ------------------------------------------------------------

    else {

        return [PSCustomObject]@{
            Component             = "PrinterEndpointReachability"
            Version               = "0.3"

            QueueName             = $Endpoint.QueueName
            TransportType         = $Endpoint.TransportType
            ReachabilityStrategy  = $Endpoint.ReachabilityStrategy

            ConfiguredDestination = $Endpoint.ConfiguredDestination
            ResolvedDestination   = $null
            ResolutionSource      = $null

            TcpPort               = $null

            Reachable             = $false
            ReachabilityState     = "UNKNOWN"

            ProbeResult           = "UNSUPPORTED_REACHABILITY_STRATEGY"
            ElapsedMs             = $null

            Error =
                "La estrategia '$($Endpoint.ReachabilityStrategy)' no esta implementada."
        }
    }
}
