# PrinterEndpointResolver.ps1
# PrintSwitch-Windows
#
# Objetivo:
#   Convertir una cola de impresión Windows en una descripción operacional
#   mínima y normalizada.
#
# Principios:
#   - READ-ONLY.
#   - No modifica impresoras, red, puertos ni registro.
#   - No asume que TCP/9100 sea universal.
#   - Prefiere información declarada por Windows.
#   - Puede inspeccionar el registro de monitores de impresión como evidencia
#     adicional cuando el puerto no expone suficiente información.
#   - No interpreta valores propietarios desconocidos salvo cuando existe
#     evidencia experimental o documental suficiente.
#
# Estado:
#   Post-Alpha / experimental.
#   Todavía NO integrado al core operativo.

Set-StrictMode -Version Latest


function Add-EndpointEvidence {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]] $Evidence,

        [Parameter(Mandatory)]
        [string] $Source,

        [Parameter(Mandatory)]
        [string] $Field,

        [AllowNull()]
        $Value,

        [Parameter(Mandatory)]
        [ValidateSet("OBSERVED", "INFERRED")]
        [string] $Kind
    )

    $Evidence.Add(
        [PSCustomObject]@{
            Source = $Source
            Field  = $Field
            Value  = $Value
            Kind   = $Kind
        }
    )
}


function Find-PrintPortRegistryEntry {
    param(
        [Parameter(Mandatory)]
        [string] $PortName
    )

    $monitorsRoot =
        "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors"

    if (-not (Test-Path -LiteralPath $monitorsRoot)) {
        return $null
    }

    foreach (
        $monitorKey in
        Get-ChildItem -LiteralPath $monitorsRoot -ErrorAction SilentlyContinue
    ) {

        $portsRoot =
            Join-Path $monitorKey.PSPath "Ports"

        if (-not (Test-Path -LiteralPath $portsRoot)) {
            continue
        }

        $candidate =
            Join-Path $portsRoot $PortName

        if (-not (Test-Path -LiteralPath $candidate)) {
            continue
        }

        try {

            $properties =
                Get-ItemProperty `
                    -LiteralPath $candidate `
                    -ErrorAction Stop

            return [PSCustomObject]@{
                Found        = $true
                MonitorName  = $monitorKey.PSChildName
                RegistryPath = $candidate
                Properties   = $properties
            }
        }
        catch {

            return [PSCustomObject]@{
                Found        = $true
                MonitorName  = $monitorKey.PSChildName
                RegistryPath = $candidate
                Properties   = $null
            }
        }
    }

    return $null
}


function Resolve-EpsonNetPrintPort {
    param(
        [Parameter(Mandatory)]
        $RegistryPort,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]] $Evidence
    )

    # ------------------------------------------------------------
    # Adapter específico para EpsonNet Print Port.
    #
    # Evidencia experimental obtenida en la instalación estudiada:
    #
    #   EpsonNet UI: Impresión LPR
    #       ProtocolID = 1
    #
    #   EpsonNet UI: Impresión Alta-velocidad (RAW)
    #       ProtocolID = 2
    #
    #   Restauración a LPR
    #       ProtocolID = 1
    #
    # Durante la prueba permanecieron estables:
    #   IpAddress
    #   MacAddress
    #   PrinterAddress
    #   PrinterAddressType
    #   QueueName
    #
    # Por lo tanto, para ESTA familia/configuración observada:
    #
    #   ProtocolID 1 -> LPR
    #   ProtocolID 2 -> RAW
    #
    # No se considera todavía una constante universal para todas
    # las versiones históricas o futuras de EpsonNet.
    # ------------------------------------------------------------

    if ($null -eq $RegistryPort) {
        return $null
    }

    if ($RegistryPort.MonitorName -ne "EpsonNet Print Port") {
        return $null
    }

    if ($null -eq $RegistryPort.Properties) {
        return $null
    }

    $propertyNames =
        $RegistryPort.Properties.PSObject.Properties.Name

    if (-not ($propertyNames -contains "ProtocolID")) {
        return $null
    }

    $protocolId =
        [int]$RegistryPort.Properties.ProtocolID

    $queueName = $null

    if (
        $propertyNames -contains "QueueName" -and
        -not [string]::IsNullOrWhiteSpace(
            [string]$RegistryPort.Properties.QueueName
        )
    ) {

        $queueName =
            [string]$RegistryPort.Properties.QueueName
    }


    Add-EndpointEvidence `
        -Evidence $Evidence `
        -Source "EpsonNet Print Port Registry" `
        -Field "ProtocolID" `
        -Value $protocolId `
        -Kind "OBSERVED"


    if ($null -ne $queueName) {

        Add-EndpointEvidence `
            -Evidence $Evidence `
            -Source "EpsonNet Print Port Registry" `
            -Field "QueueName" `
            -Value $queueName `
            -Kind "OBSERVED"
    }


    switch ($protocolId) {

        1 {

            Add-EndpointEvidence `
                -Evidence $Evidence `
                -Source "EpsonNet Experimental Mapping" `
                -Field "NormalizedProtocol" `
                -Value "LPR" `
                -Kind "INFERRED"

            return [PSCustomObject]@{
                Matched              = $true
                ProtocolID           = $protocolId
                Protocol             = "LPR"
                TcpPort              = 515
                ServiceQueue         = $queueName
                ReachabilityStrategy = "LPR_TCP"
                DiscoverySource      = "EPSONNET_PRINT_MONITOR"
                Confidence           = "HIGH"
            }
        }


        2 {

            Add-EndpointEvidence `
                -Evidence $Evidence `
                -Source "EpsonNet Experimental Mapping" `
                -Field "NormalizedProtocol" `
                -Value "RAW" `
                -Kind "INFERRED"

            return [PSCustomObject]@{
                Matched              = $true
                ProtocolID           = $protocolId
                Protocol             = "RAW"
                TcpPort              = 9100
                ServiceQueue         = $queueName
                ReachabilityStrategy = "RAW_TCP"
                DiscoverySource      = "EPSONNET_PRINT_MONITOR"
                Confidence           = "HIGH"
            }
        }


        default {

            Add-EndpointEvidence `
                -Evidence $Evidence `
                -Source "EpsonNet Print Port Registry" `
                -Field "UnmappedProtocolID" `
                -Value $protocolId `
                -Kind "OBSERVED"

            return [PSCustomObject]@{
                Matched              = $true
                ProtocolID           = $protocolId
                Protocol             = "UNKNOWN"
                TcpPort              = $null
                ServiceQueue         = $queueName
                ReachabilityStrategy = "UNKNOWN"
                DiscoverySource      = "EPSONNET_PRINT_MONITOR"
                Confidence           = "MEDIUM"
            }
        }
    }
}


function Resolve-PrintSwitchEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $PrinterName
    )

    $printer =
        Get-Printer `
            -Name $PrinterName `
            -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace($printer.PortName)) {
        throw "La cola '$PrinterName' no informa PortName."
    }

    $port =
        Get-PrinterPort `
            -Name $printer.PortName `
            -ErrorAction Stop


    $evidence =
        [System.Collections.Generic.List[object]]::new()


    Add-EndpointEvidence `
        -Evidence $evidence `
        -Source "Get-Printer" `
        -Field "QueueName" `
        -Value $printer.Name `
        -Kind "OBSERVED"

    Add-EndpointEvidence `
        -Evidence $evidence `
        -Source "Get-Printer" `
        -Field "DriverName" `
        -Value $printer.DriverName `
        -Kind "OBSERVED"

    Add-EndpointEvidence `
        -Evidence $evidence `
        -Source "Get-Printer" `
        -Field "PortName" `
        -Value $printer.PortName `
        -Kind "OBSERVED"

    Add-EndpointEvidence `
        -Evidence $evidence `
        -Source "Get-PrinterPort" `
        -Field "PortMonitor" `
        -Value $port.PortMonitor `
        -Kind "OBSERVED"


    # ------------------------------------------------------------
    # Valores normalizados
    # ------------------------------------------------------------

    $transportType         = "UNKNOWN"
    $protocol              = "UNKNOWN"
    $configuredDestination = $null
    $addressType           = "UNKNOWN"
    $tcpPort               = $null
    $serviceQueue          = $null
    $reachabilityStrategy  = "UNKNOWN"
    $discoverySource       = "WINDOWS_PRINTING"
    $confidence            = "LOW"


    # ------------------------------------------------------------
    # 1. USB
    # ------------------------------------------------------------

    if ($printer.PortName -match '^USB\d+$') {

        $transportType         = "USB"
        $protocol              = "USB"
        $configuredDestination = $printer.PortName
        $addressType           = "DEVICE"
        $reachabilityStrategy  = "USB_PRESENCE"
        $confidence            = "HIGH"


        Add-EndpointEvidence `
            -Evidence $evidence `
            -Source "Get-Printer" `
            -Field "TransportType" `
            -Value "USB" `
            -Kind "INFERRED"
    }


    # ------------------------------------------------------------
    # 2. Puerto que expone PrinterHostAddress
    #
    # Caso esperado:
    # Standard TCP/IP Port / TCPMON
    # ------------------------------------------------------------

    elseif (
        $port.PSObject.Properties.Name -contains "PrinterHostAddress" -and
        -not [string]::IsNullOrWhiteSpace(
            [string]$port.PrinterHostAddress
        )
    ) {

        $transportType         = "NETWORK"
        $configuredDestination =
            [string]$port.PrinterHostAddress

        $discoverySource =
            "WINDOWS_PRINTER_PORT"


        Add-EndpointEvidence `
            -Evidence $evidence `
            -Source "Get-PrinterPort" `
            -Field "PrinterHostAddress" `
            -Value $configuredDestination `
            -Kind "OBSERVED"


        # --------------------------------------------------------
        # Determinar si Windows entregó IP o hostname
        # --------------------------------------------------------

        $parsedAddress = $null

        if (
            [System.Net.IPAddress]::TryParse(
                $configuredDestination,
                [ref]$parsedAddress
            )
        ) {

            if (
                $parsedAddress.AddressFamily -eq
                [System.Net.Sockets.AddressFamily]::InterNetwork
            ) {

                $addressType = "IPV4"
            }

            elseif (
                $parsedAddress.AddressFamily -eq
                [System.Net.Sockets.AddressFamily]::InterNetworkV6
            ) {

                $addressType = "IPV6"
            }
        }

        else {

            $addressType = "HOSTNAME"
        }


        # --------------------------------------------------------
        # Protocolo declarado por Windows
        # --------------------------------------------------------

        $protocolText = ""

        if (
            $port.PSObject.Properties.Name -contains "Protocol"
        ) {

            $protocolText =
                [string]$port.Protocol


            Add-EndpointEvidence `
                -Evidence $evidence `
                -Source "Get-PrinterPort" `
                -Field "Protocol" `
                -Value $protocolText `
                -Kind "OBSERVED"
        }


        if ($protocolText -match 'LPR') {

            $protocol =
                "LPR"

            $reachabilityStrategy =
                "LPR_TCP"


            if (
                $port.PSObject.Properties.Name -contains "PortNumber" -and
                $null -ne $port.PortNumber
            ) {

                $tcpPort =
                    [int]$port.PortNumber
            }


            if (
                $port.PSObject.Properties.Name -contains "LprQueueName" -and
                -not [string]::IsNullOrWhiteSpace(
                    [string]$port.LprQueueName
                )
            ) {

                $serviceQueue =
                    [string]$port.LprQueueName
            }


            $confidence =
                "HIGH"
        }


        elseif ($protocolText -match 'RAW') {

            $protocol =
                "RAW"

            $reachabilityStrategy =
                "RAW_TCP"


            if (
                $port.PSObject.Properties.Name -contains "PortNumber" -and
                $null -ne $port.PortNumber
            ) {

                $tcpPort =
                    [int]$port.PortNumber
            }


            $confidence =
                "HIGH"
        }


        else {

            # Tenemos un destino de red, pero todavía no sabemos
            # qué prueba representa correctamente a esta cola.

            $protocol =
                "UNKNOWN"

            $reachabilityStrategy =
                "UNKNOWN"

            $confidence =
                "MEDIUM"
        }
    }


    # ------------------------------------------------------------
    # 3. Puerto no resuelto mediante propiedades estándar
    #
    # Buscamos una entrada de registro que corresponda EXACTAMENTE
    # con PortName dentro de los Print Monitors instalados.
    #
    # El descubrimiento inicial sigue siendo genérico. Sólo después
    # puede aplicarse un adapter para interpretar campos propietarios.
    # ------------------------------------------------------------

    else {

        $registryPort =
            Find-PrintPortRegistryEntry `
                -PortName $printer.PortName


        if ($null -ne $registryPort) {

            $discoverySource =
                "PRINT_MONITOR_REGISTRY"


            Add-EndpointEvidence `
                -Evidence $evidence `
                -Source "Print Monitor Registry" `
                -Field "MonitorName" `
                -Value $registryPort.MonitorName `
                -Kind "OBSERVED"

            Add-EndpointEvidence `
                -Evidence $evidence `
                -Source "Print Monitor Registry" `
                -Field "RegistryPath" `
                -Value $registryPort.RegistryPath `
                -Kind "OBSERVED"


            if ($null -ne $registryPort.Properties) {

                $registryPropertyNames =
                    $registryPort.Properties.PSObject.Properties.Name


                # ------------------------------------------------
                # 3.1 Destino IP declarado por el Print Monitor
                # ------------------------------------------------

                if (
                    $registryPropertyNames -contains "IpAddress" -and
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$registryPort.Properties.IpAddress
                    )
                ) {

                    $configuredDestination =
                        [string]$registryPort.Properties.IpAddress

                    $transportType =
                        "NETWORK"


                    $parsedAddress = $null

                    if (
                        [System.Net.IPAddress]::TryParse(
                            $configuredDestination,
                            [ref]$parsedAddress
                        )
                    ) {

                        if (
                            $parsedAddress.AddressFamily -eq
                            [System.Net.Sockets.AddressFamily]::InterNetwork
                        ) {

                            $addressType =
                                "IPV4"
                        }

                        elseif (
                            $parsedAddress.AddressFamily -eq
                            [System.Net.Sockets.AddressFamily]::InterNetworkV6
                        ) {

                            $addressType =
                                "IPV6"
                        }
                    }


                    Add-EndpointEvidence `
                        -Evidence $evidence `
                        -Source "Print Monitor Registry" `
                        -Field "IpAddress" `
                        -Value $configuredDestination `
                        -Kind "OBSERVED"


                    # Encontrar una IP no demuestra por sí solo
                    # qué protocolo representa a esta cola.
                    # Este estado puede ser refinado después por
                    # un adapter específico del Print Monitor.

                    $protocol =
                        "UNKNOWN"

                    $reachabilityStrategy =
                        "UNKNOWN"

                    $confidence =
                        "MEDIUM"
                }


                # ------------------------------------------------
                # 3.2 PortNumber genérico si existe
                # ------------------------------------------------

                if (
                    $registryPropertyNames -contains "PortNumber" -and
                    $null -ne $registryPort.Properties.PortNumber
                ) {

                    $tcpPort =
                        [int]$registryPort.Properties.PortNumber


                    Add-EndpointEvidence `
                        -Evidence $evidence `
                        -Source "Print Monitor Registry" `
                        -Field "PortNumber" `
                        -Value $tcpPort `
                        -Kind "OBSERVED"
                }


                # ------------------------------------------------
                # 3.3 Adapter EpsonNet
                #
                # Se aplica DESPUÉS del descubrimiento genérico,
                # para que la interpretación específica refine
                # el endpoint y no sea sobrescrita después.
                # ------------------------------------------------

                $epsonNetEndpoint =
                    Resolve-EpsonNetPrintPort `
                        -RegistryPort $registryPort `
                        -Evidence $evidence


                if (
                    $null -ne $epsonNetEndpoint -and
                    $epsonNetEndpoint.Matched
                ) {

                    $protocol =
                        $epsonNetEndpoint.Protocol

                    $tcpPort =
                        $epsonNetEndpoint.TcpPort

                    $serviceQueue =
                        $epsonNetEndpoint.ServiceQueue

                    $reachabilityStrategy =
                        $epsonNetEndpoint.ReachabilityStrategy

                    $discoverySource =
                        $epsonNetEndpoint.DiscoverySource

                    $confidence =
                        $epsonNetEndpoint.Confidence
                }
            }
        }
    }


    # ------------------------------------------------------------
    # Evaluación de suficiencia operacional
    # ------------------------------------------------------------

    $missingRequirements =
        [System.Collections.Generic.List[string]]::new()


    if ([string]::IsNullOrWhiteSpace($configuredDestination)) {

        $missingRequirements.Add(
            "DESTINATION"
        )
    }


    if ($reachabilityStrategy -eq "UNKNOWN") {

        $missingRequirements.Add(
            "REACHABILITY_STRATEGY"
        )
    }


    if (
        $reachabilityStrategy -in @(
            "RAW_TCP",
            "LPR_TCP"
        ) -and
        $null -eq $tcpPort
    ) {

        $missingRequirements.Add(
            "TCP_PORT"
        )
    }


    $operationalMinimumSatisfied =
        ($missingRequirements.Count -eq 0)


    # ------------------------------------------------------------
    # Salida normalizada
    # ------------------------------------------------------------

    [PSCustomObject]@{
        Component =
            "PrinterEndpointResolver"

        Version =
            "0.2"

        QueueName =
            $printer.Name

        DriverName =
            $printer.DriverName

        PortName =
            $printer.PortName

        PortMonitor =
            $port.PortMonitor

        TransportType =
            $transportType

        Protocol =
            $protocol

        ConfiguredDestination =
            $configuredDestination

        AddressType =
            $addressType

        TcpPort =
            $tcpPort

        ServiceQueue =
            $serviceQueue

        ReachabilityStrategy =
            $reachabilityStrategy

        DiscoverySource =
            $discoverySource

        Confidence =
            $confidence

        OperationalMinimumSatisfied =
            $operationalMinimumSatisfied

        MissingRequirements =
            @($missingRequirements)

        Evidence =
            @($evidence)
    }
}