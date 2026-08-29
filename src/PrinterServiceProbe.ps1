# PrinterServiceProbe.ps1
# PrintSwitch-Windows
#
# Objetivo:
#   Realizar un relevamiento READ-ONLY y acotado de servicios
#   habitualmente asociados a impresión.
#
# Importante:
#   - Un puerto abierto NO demuestra que la cola use ese protocolo.
#   - Este componente observa servicios disponibles.
#   - NO modifica red, impresoras, puertos ni configuración.
#   - NO selecciona una ReachabilityStrategy.
#
# Estado:
#   Post-Alpha / experimental.

Set-StrictMode -Version Latest


function Test-PrintSwitchTcpPort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Destination,

        [Parameter(Mandatory)]
        [int] $Port,

        [int] $TimeoutMs = 800
    )

    $client = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $client = [System.Net.Sockets.TcpClient]::new()

        $connectTask =
            $client.ConnectAsync($Destination, $Port)

        $completed =
            $connectTask.Wait($TimeoutMs)

        if (-not $completed) {
            return [PSCustomObject]@{
                Port       = $Port
                Reachable  = $false
                ElapsedMs  = $stopwatch.ElapsedMilliseconds
                Result     = "TIMEOUT"
                Error      = $null
            }
        }

        if ($client.Connected) {
            return [PSCustomObject]@{
                Port       = $Port
                Reachable  = $true
                ElapsedMs  = $stopwatch.ElapsedMilliseconds
                Result     = "TCP_CONNECTED"
                Error      = $null
            }
        }

        return [PSCustomObject]@{
            Port       = $Port
            Reachable  = $false
            ElapsedMs  = $stopwatch.ElapsedMilliseconds
            Result     = "NOT_CONNECTED"
            Error      = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            Port       = $Port
            Reachable  = $false
            ElapsedMs  = $stopwatch.ElapsedMilliseconds
            Result     = "ERROR"
            Error      = $_.Exception.Message
        }
    }
    finally {
        $stopwatch.Stop()

        if ($null -ne $client) {
            $client.Dispose()
        }
    }
}


function Invoke-PrinterServiceProbe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Destination,

        [int] $TimeoutMs = 800
    )

    # Conjunto deliberadamente pequeño.
    #
    # 9100 = RAW / JetDirect-style printing
    # 515  = LPR/LPD
    # 631  = IPP
    # 80   = HTTP management / discovery evidence
    # 443  = HTTPS management / IPP-related evidence
    #
    # 80 y 443 NO son por sí mismos pruebas de impresión.

    $probeDefinitions = @(
        [PSCustomObject]@{
            Port              = 9100
            CandidateService  = "RAW_PRINTING"
            PrintingEvidence  = $true
        },
        [PSCustomObject]@{
            Port              = 515
            CandidateService  = "LPR_LPD"
            PrintingEvidence  = $true
        },
        [PSCustomObject]@{
            Port              = 631
            CandidateService  = "IPP"
            PrintingEvidence  = $true
        },
        [PSCustomObject]@{
            Port              = 80
            CandidateService  = "HTTP"
            PrintingEvidence  = $false
        },
        [PSCustomObject]@{
            Port              = 443
            CandidateService  = "HTTPS"
            PrintingEvidence  = $false
        }
    )
            # ------------------------------------------------------------
    # Resolución explícita del destino
    #
    # ConfiguredDestination puede ser una IP o un nombre.
    # Los probes TCP trabajan sobre una dirección resuelta explícita
    # para mantener separadas:
    #
    #   configuración → resolución → reachability
    #
    # La dirección configurada original se conserva como evidencia.
    # ------------------------------------------------------------

    $resolvedDestination = $null
    $resolutionSource    = "DIRECT_IP"

    $parsedAddress = $null

    if (
        [System.Net.IPAddress]::TryParse(
            $Destination,
            [ref]$parsedAddress
        )
    ) {
        $resolvedDestination = $parsedAddress.IPAddressToString
    }
    else {
        try {
            $resolvedAddresses =
                @(
                    [System.Net.Dns]::GetHostAddresses($Destination) |
                    Where-Object {
                        $_.AddressFamily -eq
                        [System.Net.Sockets.AddressFamily]::InterNetwork
                    }
                )

            if ($resolvedAddresses.Count -gt 0) {
                $resolvedDestination =
                    $resolvedAddresses[0].IPAddressToString

                $resolutionSource = "DOTNET_NAME_RESOLUTION"
            }
        }
        catch {
            $resolvedDestination = $null
            $resolutionSource    = "RESOLUTION_FAILED"
        }
    }

    if ([string]::IsNullOrWhiteSpace($resolvedDestination)) {

        return [PSCustomObject]@{
            Component                 = "PrinterServiceProbe"
            Version                   = "0.2"

            Destination               = $Destination
            ResolvedDestination       = $null
            ResolutionSource          = $resolutionSource
            TimeoutMs                 = $TimeoutMs

            Results                   = @()
            ReachablePrintingServices = @()
            PrintingServiceCount      = 0

            Interpretation =
                "DESTINATION_RESOLUTION_FAILED"

            ImportantNote =
                "The configured destination could not be resolved. No TCP probes were performed."
        }
    }


    $results =
        [System.Collections.Generic.List[object]]::new()


    foreach ($definition in $probeDefinitions) {

        $tcpResult =
            Test-PrintSwitchTcpPort `
                -Destination $resolvedDestination `
                -Port $definition.Port `
                -TimeoutMs $TimeoutMs

        $results.Add(
            [PSCustomObject]@{
                Destination         = $Destination
                ResolvedDestination = $resolvedDestination
                Port                = $definition.Port
                CandidateService    = $definition.CandidateService
                PrintingEvidence    = $definition.PrintingEvidence
                Reachable           = $tcpResult.Reachable
                Result              = $tcpResult.Result
                ElapsedMs           = $tcpResult.ElapsedMs
                Error               = $tcpResult.Error
            }
        )
    }


    $reachablePrintingServices =
        @(
            $results |
            Where-Object {
                $_.Reachable -eq $true -and
                $_.PrintingEvidence -eq $true
            }
        )


    [PSCustomObject]@{
        Component                 = "PrinterServiceProbe"
        Version                   = "0.2"

        Destination               = $Destination
        ResolvedDestination       = $resolvedDestination
        ResolutionSource          = $resolutionSource
        TimeoutMs                 = $TimeoutMs

        Results                   = @($results)

        ReachablePrintingServices =
            @($reachablePrintingServices)

        PrintingServiceCount      =
            $reachablePrintingServices.Count

        Interpretation            =
            if ($reachablePrintingServices.Count -eq 0) {
                "NO_STANDARD_PRINTING_SERVICE_OBSERVED"
            }
            elseif ($reachablePrintingServices.Count -eq 1) {
                "ONE_STANDARD_PRINTING_SERVICE_OBSERVED"
            }
            else {
                "MULTIPLE_STANDARD_PRINTING_SERVICES_OBSERVED"
            }

        ImportantNote =
            "Observed service availability does not prove the protocol configured for the Windows queue."
    }
}