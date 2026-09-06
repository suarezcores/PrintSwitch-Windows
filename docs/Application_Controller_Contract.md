# PrintSwitch — ApplicationController Contract

## Estado

```text
Proyecto    : PrintSwitch-Windows
Etapa       : Punto 7
Subetapa    : P7-A2
Documento   : Contrato ApplicationController
Estado      : DRAFT DE ARQUITECTURA
Baseline    : core-p6-validated
Commit base : 3e557d2
```

Este documento define la frontera entre:

```text
Application / UI
```

y:

```text
PrintSwitch Core
```

antes de implementar la primera interfaz gráfica.

El objetivo es impedir que la UI conozca o replique detalles internos del Core.

---

## 1. Principio fundamental

La arquitectura objetivo es:

```text
UI
 |
 v
ApplicationController
 |
 v
PrintSwitch Core
 |
 v
Windows
```

La UI no debe invocar directamente:

```text
NetworkManager
ConnectivityPolicy
SwitchDecision
RecoveryValidator
RouteAnalyzer
InterfacePathAnalyzer
```

ni reconstruir sus decisiones.

La UI debe solicitar operaciones al:

```text
ApplicationController
```

y representar los resultados estructurados que éste entregue.

---

## 2. Responsabilidad del ApplicationController

El ApplicationController será responsable de:

```text
lifecycle de la aplicación

inicio y detención del monitor

consulta del estado general

consulta de impresoras descubiertas

consulta del QueueContext

consulta del endpoint

consulta de reachability

habilitación y deshabilitación de recovery

exposición de la última decisión

exposición del último recovery

exposición del último error

acceso a logs

adaptación de resultados del Core

aislamiento de componentes mutadores
```

No será responsable de decidir:

```text
qué ruta utilizar

si una impresora está reachable

si debe cambiarse Wi-Fi

qué SSID es seguro

si el recovery fue exitoso

qué endpoint corresponde a una cola
```

Estas decisiones continúan perteneciendo al Core.

---

## 3. Separación Commands / Queries

El Controller debe separar explícitamente:

```text
QUERY
```

de:

```text
COMMAND
```

### Queries

Una query:

```text
consulta estado
no modifica Windows
no ejecuta recovery
no cambia Wi-Fi
```

Ejemplos:

```text
GetStatus
GetPrinters
GetQueueContext
GetEndpoint
GetReachability
GetLastDecision
GetLastRecovery
GetLogs
```

### Commands

Un command puede modificar:

```text
estado interno de PrintSwitch
```

o indirectamente:

```text
estado de Windows
```

Ejemplos:

```text
StartMonitoring
StopMonitoring
EnableRecovery
DisableRecovery
```

La ejecución efectiva de un cambio Wi-Fi permanece encapsulada dentro del
pipeline de recovery.

---

## 4. Operaciones públicas previstas

La API interna inicial del Controller queda definida como:

```text
StartMonitoring
StopMonitoring

GetStatus

GetPrinters
GetQueueContext
GetEndpoint
GetReachability

EnableRecovery
DisableRecovery

GetLastDecision
GetLastRecovery
GetLastError

GetLogs
```

No se expone inicialmente:

```text
ConnectToSSID
ExecuteNetworkSwitch
RunNetworkManager
ForceRecovery
```

La UI no debe poseer una operación:

```text
cambiar Wi-Fi ahora
```

que saltee el motor de decisión.

---

## 5. StartMonitoring

### Intención

Iniciar la observación de trabajos de impresión.

### Tipo

```text
COMMAND
```

### Entrada inicial

```text
PrinterName : opcional
```

### Responsabilidad interna

Debe iniciar o coordinar:

```text
QueueWatcher
```

sin que la UI conozca cómo se ejecuta el loop interno.

### Resultado esperado

```text
ControllerResult
```

con estado equivalente a:

```text
Operation      = StartMonitoring
Success        = True / False
Classification = MONITORING_STARTED
                 ALREADY_RUNNING
                 START_FAILED
```

---

## 6. StopMonitoring

### Intención

Detener limpiamente la observación.

### Tipo

```text
COMMAND
```

### Resultado esperado

```text
Operation      = StopMonitoring
Classification = MONITORING_STOPPED
                 ALREADY_STOPPED
                 STOP_FAILED
```

La primera beta debe poder cerrarse sin dejar procesos o loops huérfanos.

---

## 7. GetStatus

### Intención

Entregar una fotografía estructurada del estado de PrintSwitch.

### Tipo

```text
QUERY
```

### Contrato inicial

```text
ApplicationState
MonitoringState
RecoveryEnabled
CurrentQueue
CurrentEndpoint
CurrentReachability
CurrentSSID
LastDecision
LastRecovery
LastError
Timestamp
```

Ejemplo conceptual:

```text
ApplicationState   = RUNNING
MonitoringState    = WATCHING
RecoveryEnabled    = True
CurrentQueue       = L365 Series(Red)
CurrentEndpoint    = 192.168.1.108:515
CurrentReachability= UNREACHABLE
CurrentSSID        = Claro640
LastDecision       = EVALUATE_WIFI_RECOVERY
LastRecovery       = CONTEXTUAL_RECOVERY_SUCCESS
LastError          = null
```

---

## 8. ApplicationState

Los estados iniciales previstos son:

```text
STOPPED
STARTING
RUNNING
STOPPING
FAULTED
```

No representan estado de una impresora.

Representan exclusivamente el lifecycle de:

```text
PrintSwitch Application
```

---

## 9. MonitoringState

El estado del monitor se mantiene separado de ApplicationState.

Valores previstos:

```text
NOT_STARTED
WATCHING
JOB_DETECTED
PROCESSING
STOPPED
FAULTED
```

Esto permite que una aplicación continúe:

```text
RUNNING
```

aunque el monitor esté:

```text
STOPPED
```

---

## 10. GetPrinters

### Tipo

```text
QUERY
```

### Fuente autoritativa

```text
PrinterDiscovery
```

La UI no debe ejecutar su propio:

```text
Get-Printer
```

ni mantener un inventario paralelo.

### Resultado

Colección de:

```text
QueueContext
```

con propiedades equivalentes a:

```text
QueueName
DriverName
PortName
DiscoveryStatus
TransportType
Protocol
ConfiguredDestination
AddressType
TcpPort
ServiceQueue
ReachabilityStrategy
DiscoverySource
Confidence
OperationalMinimumSatisfied
MissingRequirements
```

---

## 11. GetQueueContext

### Tipo

```text
QUERY
```

### Entrada

```text
PrinterName
```

### Resultado

Un:

```text
QueueContext
```

o una clasificación equivalente a:

```text
QUEUE_FOUND
QUEUE_NOT_FOUND
QUEUE_AMBIGUOUS
DISCOVERY_INCOMPLETE
```

---

## 12. GetEndpoint

### Tipo

```text
QUERY
```

### Fuente

```text
PrinterEndpointResolver
```

### Resultado

Debe exponer el contrato de endpoint sin reinterpretarlo.

Campos esperados:

```text
QueueName
TransportType
Protocol
ConfiguredDestination
AddressType
TcpPort
ServiceQueue
ReachabilityStrategy
```

Posibles clasificaciones:

```text
ENDPOINT_RESOLVED
ENDPOINT_INCOMPLETE
ENDPOINT_UNSUPPORTED
ENDPOINT_UNKNOWN
```

---

## 13. GetReachability

### Tipo

```text
QUERY
```

### Fuente

```text
PrinterEndpointReachability
PrinterServiceProbe
```

según la estrategia del endpoint.

### Resultado conceptual

```text
EndpointState
Strategy
Target
Service
Evidence
Timestamp
```

Estados mínimos:

```text
REACHABLE
UNREACHABLE
UNKNOWN
```

Nunca deberá inferirse:

```text
REACHABLE
```

únicamente porque:

```text
PrinterStatus = Normal
```

o:

```text
PingSucceeded = True
```

La estrategia operacional continúa siendo la autoridad.

---

## 14. EnableRecovery

### Tipo

```text
COMMAND
```

### Efecto

Modificar únicamente la autorización de PrintSwitch para ejecutar recovery.

Debe producir:

```text
RecoveryEnabled = True
```

No debe provocar automáticamente:

```text
cambio Wi-Fi
```

Por tanto:

```text
EnableRecovery
```

significa:

```text
permitir recovery cuando el Core determine que corresponde
```

y no:

```text
ejecutar recovery ahora
```

---

## 15. DisableRecovery

### Tipo

```text
COMMAND
```

### Efecto

```text
RecoveryEnabled = False
```

El monitor puede continuar funcionando.

Debe seguir permitiendo:

```text
detección
discovery
diagnóstico
observabilidad
```

pero no:

```text
NetworkManager mutation
```

como consecuencia automática de un trabajo.

---

## 16. GetLastDecision

### Tipo

```text
QUERY
```

Debe devolver la última decisión relevante producida por el Core.

Ejemplos:

```text
EXISTING_REACHABLE_PATH

EVALUATE_WIFI_RECOVERY

SWITCH_WIFI_FOR_PRINTER

SWITCH_NOT_SAFE

NO_ACTION
```

El Controller no debe traducir esas clasificaciones a nuevas decisiones.

Puede agregar una representación amigable posteriormente para UI, pero el valor
original debe conservarse.

---

## 17. GetLastRecovery

### Tipo

```text
QUERY
```

Debe representar la última secuencia de recovery conocida.

Campos candidatos:

```text
Attempted
SwitchAuthorized
SwitchExecuted
TargetSSID
SwitchVerified
RecoverySucceeded
FinalClassification
Timestamp
```

Ejemplo:

```text
Attempted           = True
SwitchAuthorized    = True
SwitchExecuted      = True
TargetSSID          = suarezcores
SwitchVerified      = True
RecoverySucceeded   = True
FinalClassification = CONTEXTUAL_RECOVERY_SUCCESS
```

---

## 18. GetLastError

### Tipo

```text
QUERY
```

Debe diferenciar:

```text
error técnico
```

de:

```text
resultado negativo válido
```

Ejemplo:

```text
UNREACHABLE
```

no es necesariamente un error.

Puede ser un estado legítimo del endpoint.

El contrato debe reservar error para situaciones equivalentes a:

```text
SCRIPT_FAILURE
INVALID_CONTRACT
UNEXPECTED_EXCEPTION
CONTROLLER_FAILURE
```

---

## 19. GetLogs

### Tipo

```text
QUERY
```

### Fuente

```text
Logger
```

La primera implementación puede limitarse a:

```text
ruta de log
últimos eventos
último evento relevante
```

La UI no necesita interpretar directamente todos los archivos internos.

---

## 20. ControllerResult

Todas las operaciones públicas del Controller deberán devolver un envelope
estructurado común.

Contrato propuesto:

```text
Component
ContractVersion
Operation
Success
Classification
Timestamp
Data
Error
```

Ejemplo:

```text
Component       = ApplicationController
ContractVersion = 1
Operation       = GetStatus
Success         = True
Classification  = STATUS_AVAILABLE
Timestamp       = ...
Data            = ...
Error           = null
```

---

## 21. Error contract

Cuando una operación falle:

```text
Success = False
```

y:

```text
Error
```

deberá ser un objeto estructurado.

Contrato inicial:

```text
Code
Message
SourceComponent
ExceptionType
```

Ejemplo:

```text
Code            = DISCOVERY_FAILED
Message         = No fue posible obtener PrinterDiscovery
SourceComponent = PrinterDiscovery
ExceptionType   = RuntimeException
```

La UI podrá mostrar:

```text
Message
```

pero conservará:

```text
Code
```

para diagnóstico.

---

## 22. Data contract

La propiedad:

```text
Data
```

de `ControllerResult` puede contener diferentes contratos según la operación.

Ejemplos:

```text
GetStatus
    -> ApplicationStatus

GetPrinters
    -> QueueContext[]

GetEndpoint
    -> Endpoint

GetReachability
    -> EndpointReachability

GetLastRecovery
    -> RecoveryResult
```

El Controller no debe convertir estos datos a texto antes de entregarlos.

---

## 23. Adaptación de Write-Host

El inventario P7-A1 mostró que varios componentes:

```text
devuelven PSCustomObject
```

pero además producen:

```text
Write-Host
```

en cantidades significativas.

La primera beta no requiere refactorizar inmediatamente todos esos componentes.

El Controller podrá utilizar una capa adaptadora que:

```text
invoque el componente

preserve el success output estructurado

suprima o capture Information Stream

normalice errores

devuelva ControllerResult
```

En PowerShell moderno:

```text
Write-Host
```

utiliza:

```text
Information Stream
```

por lo que puede aislarse durante la integración sin alterar el contrato de
objetos del Core.

---

## 24. Componentes candidatos a consumo estructurado directo

El inventario P7-A1 identificó como candidatos particularmente limpios:

```text
PrinterEndpointResolver.ps1

PrinterEndpointReachability.ps1

PrinterServiceProbe.ps1
```

Características observadas:

```text
PSCustomObject = True
Write-Host     = 0
no mutación de Windows
```

Estos componentes pueden actuar como referencia para futuros contratos internos.

---

## 25. Componentes que requieren adaptador de salida

Entre los componentes que producen resultados estructurados pero utilizan
`Write-Host` se encuentran:

```text
PrinterDiscovery

InterfacePathAnalyzer

RouteAnalyzer

ConnectivityPolicy

WiFiCandidateEvaluator

SwitchDecision

RecoveryValidator

ConnectivityAnalyzer
```

No deben refactorizarse todos como requisito de entrada al Punto 7.

Inicialmente serán consumidos mediante:

```text
ApplicationController
        |
        v
Output Adapter
        |
        v
Core Component
```

---

## 26. Orchestrators

Los dos coordinadores principales son:

```text
QueueWatcher
PrintRecoveryOrchestrator
```

### QueueWatcher

Responsabilidad:

```text
lifecycle de observación

detección de trabajos

delegación a recovery
```

### PrintRecoveryOrchestrator

Responsabilidad:

```text
componer la decisión operacional completa
```

El Controller no debe replicar ninguno de esos pipelines.

---

## 27. NetworkManager como mutador protegido

`NetworkManager` es el componente que ejecuta cambios reales sobre Windows.

La frontera obligatoria es:

```text
UI
 |
 v
ApplicationController
 |
 v
Core Decision Pipeline
 |
 v
NetworkManager
 |
 v
Windows
```

Queda explícitamente prohibido diseñar:

```text
UI
 |
 v
NetworkManager
```

de forma directa.

---

## 28. Recovery manual forzado queda fuera de la primera beta

No se incluye inicialmente una operación pública:

```text
ForceRecovery
```

porque permitiría evitar:

```text
ConnectivityPolicy
WiFiCandidateEvaluator
SwitchDecision
```

Si en el futuro se incorpora una herramienta manual de recuperación deberá
considerarse:

```text
modo avanzado
```

o:

```text
diagnóstico
```

con una semántica distinta de la operación automática normal.

---

## 29. Estado persistente mínimo del Controller

El Controller deberá mantener únicamente estado de aplicación necesario.

Modelo inicial:

```text
ApplicationState

MonitoringState

RecoveryEnabled

SelectedPrinter

CurrentQueueContext

CurrentEndpoint

CurrentReachability

CurrentSSID

LastDecision

LastRecovery

LastError

StartedAt

LastUpdatedAt
```

No debe duplicar:

```text
tabla de rutas Windows

inventario completo de interfaces

inventario paralelo de impresoras
```

si esa información puede obtenerse del Core.

---

## 30. Fuente autoritativa y caché

El Controller puede mantener una caché para UI.

Pero debe diferenciar:

```text
cached view
```

de:

```text
source of truth
```

Ejemplo:

```text
CurrentEndpoint
```

puede almacenarse temporalmente para presentar estado.

Sin embargo, la fuente autoritativa continúa siendo:

```text
PrinterEndpointResolver
```

cuando sea necesario actualizarlo.

---

## 31. Timestamp obligatorio

Todo resultado expuesto a UI debe incluir:

```text
Timestamp
```

Esto será especialmente importante porque P6 demostró que varias observaciones
de Windows poseen comportamiento temporal.

La UI debe poder distinguir:

```text
estado actual
```

de:

```text
último estado conocido
```

---

## 32. Estado UNKNOWN debe conservarse

La UI no debe convertir:

```text
UNKNOWN
```

en:

```text
OFFLINE
```

ni en:

```text
ERROR
```

El Controller debe preservar las clasificaciones semánticas del Core.

Ejemplo:

```text
EndpointState = UNKNOWN
```

puede presentarse visualmente como:

```text
Estado no determinado
```

pero el valor estructurado continúa siendo:

```text
UNKNOWN
```

---

## 33. Seguridad de comandos

Toda operación que pueda producir una mutación debe seguir:

```text
UI command
    |
    v
Controller validation
    |
    v
Core decision
    |
    v
authorized mutation
```

La UI no deberá recibir referencias directas a funciones que:

```text
cambien Wi-Fi
eliminen jobs
modifiquen rutas
reinicien servicios
```

sin una capa explícita de control.

---

## 34. Política de errores

El Controller deberá:

```text
capturar errores de integración

preservar clasificación del Core

no transformar resultados legítimos en excepciones

no ocultar excepciones inesperadas

registrar errores mediante Logger
```

Ejemplo:

```text
EndpointState = UNREACHABLE
```

es un resultado.

No debe convertirse automáticamente en:

```text
Controller failure
```

---

## 35. Política de logging

El Controller deberá generar eventos propios para:

```text
controller started

controller stopped

monitoring started

monitoring stopped

recovery enabled

recovery disabled

job event received

decision received

recovery received

controller error
```

Sin duplicar necesariamente todos los logs internos del Core.

---

## 36. Contrato de lifecycle

Secuencia de inicio:

```text
Application
    |
    v
ApplicationController created
    |
    v
ApplicationState = STARTING
    |
    v
dependencies validated
    |
    v
ApplicationState = RUNNING
```

Secuencia de monitor:

```text
StartMonitoring
    |
    v
QueueWatcher
    |
    v
MonitoringState = WATCHING
```

Secuencia de cierre:

```text
StopMonitoring
    |
    v
QueueWatcher stopped
    |
    v
MonitoringState = STOPPED
    |
    v
ApplicationState = STOPPING
    |
    v
ApplicationState = STOPPED
```

---

## 37. Eventos internos previstos

La primera versión podrá utilizar eventos o callbacks equivalentes a:

```text
ApplicationStateChanged

MonitoringStateChanged

PrinterContextChanged

EndpointStateChanged

JobDetected

DecisionCompleted

RecoveryStarted

RecoveryCompleted

ErrorOccurred
```

La implementación concreta se definirá durante P7-A3/P7-A4.

Este documento sólo fija que la UI no debería depender de polling agresivo si el
Controller puede notificar cambios.

---

## 38. UI contract

La futura UI podrá:

```text
mostrar estado

solicitar iniciar/detener monitor

habilitar/deshabilitar recovery

seleccionar impresora

consultar impresoras

consultar endpoint

consultar logs
```

No podrá decidir directamente:

```text
cómo alcanzar una impresora

qué SSID elegir

si una ruta es suficiente

si un switch es seguro

si una recuperación debe declararse exitosa
```

---

## 39. Criterio de éxito de P7-A2

P7-A2 podrá considerarse completo cuando exista acuerdo sobre:

```text
[ ] frontera UI / Controller

[ ] operaciones públicas

[ ] queries y commands separados

[ ] ControllerResult definido

[ ] ApplicationStatus definido

[ ] error contract definido

[ ] NetworkManager protegido

[ ] QueueWatcher definido como lifecycle

[ ] Orchestrator definido como pipeline interno

[ ] estrategia inicial para Write-Host definida

[ ] UNKNOWN preservado

[ ] lifecycle inicial definido

[ ] no existe lógica UI duplicando Core
```

---

## 40. Próxima etapa

Una vez aprobado este contrato:

```text
P7-A3
```

implementará un primer:

```text
ApplicationController.ps1
```

sin UI gráfica.

La prueba inicial deberá realizarse completamente desde PowerShell y demostrar:

```text
crear Controller

GetStatus

GetPrinters

GetEndpoint

GetReachability

EnableRecovery

DisableRecovery

resultado estructurado

cero cambio Wi-Fi no autorizado
```

Sólo después se integrará:

```text
QueueWatcher
```

y posteriormente:

```text
system tray / UI
```

---

## 41. Contrato arquitectónico final de P7-A2

```text
┌─────────────────────────────────────────┐
│                  UI                     │
│                                         │
│  presentation / user interaction        │
└────────────────────┬────────────────────┘
                     │
                     v
┌─────────────────────────────────────────┐
│        ApplicationController            │
│                                         │
│  lifecycle                              │
│  commands                               │
│  queries                                │
│  state                                  │
│  output adaptation                      │
│  error normalization                    │
└───────────────┬─────────────────────────┘
                │
                v
┌─────────────────────────────────────────┐
│          PrintSwitch Core               │
│                                         │
│ QueueWatcher                            │
│ PrinterDiscovery                        │
│ EndpointResolver                        │
│ EndpointReachability                    │
│ InterfacePathAnalyzer                   │
│ RouteAnalyzer                           │
│ ConnectivityPolicy                      │
│ WiFiCandidateEvaluator                  │
│ SwitchDecision                          │
│ PrintRecoveryOrchestrator               │
│ RecoveryValidator                       │
│ Logger                                  │
└───────────────┬─────────────────────────┘
                │
                v
┌─────────────────────────────────────────┐
│            NetworkManager               │
│                                         │
│        protected mutator boundary       │
└───────────────┬─────────────────────────┘
                │
                v
              Windows
```

Regla final:

> **La UI expresa intención. El Controller coordina. El Core decide.
> NetworkManager ejecuta únicamente una acción autorizada.**