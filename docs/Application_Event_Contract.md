# PrintSwitch — Application Event Contract

## Estado

```text
Proyecto      : PrintSwitch-Windows
Etapa         : Punto 7
Subetapa      : P7-A5.2
Documento     : Contrato de eventos estructurados
Estado        : DRAFT DE ARQUITECTURA
Controller    : ApplicationController v0.2
Baseline      : f4f9bac
Core seguro   : core-p6-validated / 3e557d2
```

Este documento define cómo los eventos producidos durante la ejecución de
PrintSwitch deben atravesar la frontera:

```text
QueueWatcher
    |
    v
ApplicationController
    |
    v
UI
```

sin depender de:

```text
Write-Host

texto de consola

regex sobre logs

parsing de mensajes humanos
```

---

## 1. Problema observado

Durante P7-A5.1 se ejecutó un trabajo real sobre:

```text
L365 Series(Red)
```

con:

```text
Wi-Fi     = Claro640
Ethernet  = desconectado
Recovery  = deshabilitado desde ApplicationController
```

QueueWatcher detectó correctamente:

```text
JobId       = 9
Documento   = receipt.pdf
Propietario = Suarez
```

y el pipeline produjo:

```text
PolicyDecision      = EVALUATE_WIFI_RECOVERY
WiFiClassification = WIFI_SWITCH_CANDIDATE_AVAILABLE
SwitchDecision      = SWITCH_WIFI_FOR_PRINTER
FinalClassification = SWITCH_NOT_EXECUTED_DRY_RUN
SwitchAuthorized    = True
SwitchExecuted      = False
```

Sin embargo:

```text
ApplicationController.LastDecision = null
ApplicationController.LastRecovery = null
```

y el consumidor externo del background worker recibió:

```text
StructuredCandidates = 0
CapturedCount         = 0
```

La información operacional existe dentro del proceso.

El problema es que no existe todavía un canal estructurado explícito entre el
worker y ApplicationController.

---

## 2. Principio fundamental

La UI nunca debe reconstruir eventos mediante:

```text
Write-Host
```

o frases como:

```text
"NUEVO TRABAJO DETECTADO"

"SWITCH AUTORIZADO"

"Recovery exitoso"

"Esperando trabajos"
```

La arquitectura debe ser:

```text
Core event
    |
    v
PrintSwitchEvent
    |
    v
ApplicationController
    |
    v
UI state / notification
```

El texto humano puede continuar existiendo para:

```text
CLI
diagnóstico
logs
desarrollo
```

pero deja de ser el contrato máquina-a-máquina.

---

## 3. Event envelope

Todo evento expuesto al Controller deberá utilizar una envoltura común.

Contrato inicial:

```text
Component
EventVersion
EventType
Timestamp
Source
PrinterName
CorrelationId
Severity
Data
```

Ejemplo conceptual:

```text
Component     = PrintSwitchEvent
EventVersion  = 1
EventType     = PrintJobDetected
Timestamp     = 2026-09-06T20:41:06
Source        = QueueWatcher
PrinterName   = L365 Series(Red)
CorrelationId = ...
Severity      = INFO
Data          = ...
```

---

## 4. Component

El campo:

```text
Component
```

debe contener:

```text
PrintSwitchEvent
```

Esto diferencia un evento de:

```text
ControllerResult
QueueContext
Endpoint
RecoveryResult
```

aunque todos sean objetos PowerShell estructurados.

---

## 5. EventVersion

La primera versión del contrato será:

```text
EventVersion = 1
```

La versión pertenece al envelope de eventos.

No debe confundirse con:

```text
ApplicationController.Version

QueueWatcher.Version

PrintRecoveryOrchestrator.Version
```

---

## 6. EventType

`EventType` identifica semánticamente qué ocurrió.

Tipos iniciales:

```text
MonitoringStarted

MonitoringStopped

PrintJobDetected

DecisionProduced

RecoveryStarted

RecoveryCompleted

MonitoringFaulted

ErrorOccurred
```

La primera implementación no necesita emitir todos simultáneamente.

El contrato los define desde el comienzo para evitar introducir formatos
incompatibles posteriormente.

---

## 7. Timestamp

Todo evento debe contener:

```text
Timestamp
```

como fecha y hora de creación del evento.

No representa:

```text
hora de consulta de la UI
```

sino:

```text
momento en que PrintSwitch produjo el evento
```

Esto permite diferenciar:

```text
evento ocurrido
```

de:

```text
evento leído posteriormente
```

---

## 8. Source

`Source` identifica qué componente originó el evento.

Valores esperados:

```text
ApplicationController

QueueWatcher

PrintRecoveryOrchestrator

RecoveryValidator

NetworkManager

PrinterDiscovery
```

El Controller puede transportar eventos originados por componentes internos,
pero no debe falsificar su origen.

---

## 9. PrinterName

Cuando el evento pertenece a una cola determinada:

```text
PrinterName
```

debe contener exactamente el nombre de la cola Windows.

Ejemplo:

```text
L365 Series(Red)
```

o:

```text
Brother HL-1210W series
```

Cuando un evento no pertenece a una impresora particular podrá ser:

```text
null
```

---

## 10. CorrelationId

Cada episodio operacional deberá poseer un:

```text
CorrelationId
```

único.

Ejemplo:

```text
0ad5ec8e-...
```

Un mismo trabajo debe conservar el mismo CorrelationId durante:

```text
PrintJobDetected
        |
        v
DecisionProduced
        |
        v
RecoveryStarted
        |
        v
RecoveryCompleted
```

Esto permite reconstruir posteriormente:

```text
qué detección

produjo qué decisión

produjo qué recovery

produjo qué resultado final
```

---

## 11. Creación del CorrelationId

La primera fuente de CorrelationId será:

```text
QueueWatcher
```

cuando detecte un trabajo nuevo.

Secuencia:

```text
nuevo JobId
    |
    v
New-Guid
    |
    v
CorrelationId
    |
    +--> PrintJobDetected
    |
    +--> Orchestrator
    |
    +--> DecisionProduced
    |
    +--> RecoveryCompleted
```

El identificador no debe derivarse únicamente de:

```text
JobId
```

porque Windows puede reutilizar identificadores en diferentes momentos.

---

## 12. Severity

Valores iniciales:

```text
DEBUG
INFO
WARNING
ERROR
```

La severidad describe relevancia para observabilidad.

No reemplaza:

```text
EventType
```

ni:

```text
Classification
```

Ejemplos:

```text
PrintJobDetected
Severity = INFO
```

```text
RecoveryCompleted
FinalClassification = SWITCH_NOT_EXECUTED_DRY_RUN
Severity = INFO
```

```text
ErrorOccurred
Severity = ERROR
```

---

## 13. Data

`Data` contiene el payload específico de cada evento.

Debe permanecer:

```text
estructurado
```

y no convertirse a una cadena antes de atravesar la frontera.

Ejemplo:

```text
Data = PSCustomObject
```

---

## 14. MonitoringStarted

Evento emitido cuando ApplicationController inicia correctamente el worker.

Contrato:

```text
EventType = MonitoringStarted
Source    = ApplicationController
Severity  = INFO
```

Payload:

```text
PrinterName
WorkerId
WorkerName
RecoveryEnabled
StartedAt
```

Este evento pertenece al lifecycle de la aplicación.

No implica que exista todavía un trabajo de impresión.

---

## 15. MonitoringStopped

Evento emitido cuando el worker deja de estar administrado por el Controller.

Payload:

```text
PrinterName
PreviousWorkerId
FinalWorkerState
StoppedAt
```

No debe confundirse con:

```text
PrintJobCompleted
```

La primera beta no necesita todavía modelar el estado completo del spooler como
workflow de documento.

---

## 16. PrintJobDetected

Evento fundamental del watcher.

Debe emitirse cuando QueueWatcher detecta por primera vez un trabajo nuevo.

Contrato:

```text
EventType = PrintJobDetected
Source    = QueueWatcher
Severity  = INFO
```

Payload mínimo:

```text
JobId
DocumentName
Owner
JobStatus
SubmittedTime
QueueName
```

Ejemplo:

```text
JobId        = 9
DocumentName = receipt.pdf
Owner        = Suarez
JobStatus    = Trabajos en cola
QueueName    = L365 Series(Red)
```

---

## 17. Un trabajo debe producir PrintJobDetected una sola vez

QueueWatcher actualmente utiliza memoria de trabajos conocidos.

El contrato de eventos debe conservar esta propiedad.

Un mismo trabajo no debe generar:

```text
PrintJobDetected
PrintJobDetected
PrintJobDetected
```

en cada iteración del watcher.

La regla es:

```text
nuevo JobId observado
        |
        v
emitir una vez
        |
        v
registrar como conocido
```

---

## 18. DecisionProduced

Este evento representa una decisión operacional producida por el Core.

No es una decisión creada por ApplicationController.

Contrato:

```text
EventType = DecisionProduced
Source    = PrintRecoveryOrchestrator
Severity  = INFO
```

Payload candidato:

```text
RouteClassification
PolicyDecision
WiFiClassification
SwitchDecision
ShouldExecuteSwitch
PreserveEthernet
CurrentSSID
TargetSSID
```

---

## 19. DecisionProduced no equivale a mutación

Puede existir:

```text
SwitchDecision = SWITCH_WIFI_FOR_PRINTER
```

sin:

```text
SwitchExecuted = True
```

P7-A5.1 demostró precisamente:

```text
SwitchDecision   = SWITCH_WIFI_FOR_PRINTER
SwitchAuthorized = True
SwitchExecuted   = False
```

en modo dry-run.

La UI debe poder mostrar una decisión sin insinuar que la acción ocurrió.

---

## 20. RecoveryStarted

Evento reservado para el comienzo real de una recuperación.

Debe emitirse únicamente cuando:

```text
la ejecución de recovery fue autorizada
```

y el sistema está por realizar acciones de recuperación.

No debe emitirse en modo dry-run si no comienza una mutación real.

Payload candidato:

```text
TargetSSID
PreviousSSID
Strategy
Authorized
StartedAt
```

---

## 21. RecoveryCompleted

Evento que representa el resultado final del pipeline de recuperación.

Contrato:

```text
EventType = RecoveryCompleted
Source    = PrintRecoveryOrchestrator
```

Payload mínimo:

```text
FinalClassification
SwitchDecision
SwitchAuthorized
SwitchExecuted
RecoverySucceeded
TargetSSID
ConnectivityAfter
CompletedAt
```

---

## 22. RecoveryCompleted también existe sin switch ejecutado

El evento puede representar resultados legítimos como:

```text
EXISTING_REACHABLE_PATH
```

```text
SWITCH_NOT_EXECUTED_DRY_RUN
```

```text
CONTEXTUAL_RECOVERY_SUCCESS
```

```text
NO_SWITCH_PRINTER_UNREACHABLE
```

Por tanto:

```text
RecoveryCompleted
```

significa:

```text
el pipeline terminó
```

y no necesariamente:

```text
se cambió Wi-Fi
```

---

## 23. MonitoringFaulted

Evento emitido cuando el worker deja de funcionar de forma inesperada.

Ejemplos:

```text
background job = Failed

QueueWatcher terminó inesperadamente

worker desapareció

error de inicialización no recuperable
```

Contrato:

```text
EventType = MonitoringFaulted
Severity  = ERROR
```

Payload:

```text
WorkerId
WorkerState
Reason
LastKnownPrinter
```

---

## 24. ErrorOccurred

Evento para fallos técnicos.

Ejemplos:

```text
exception inesperada

contrato inválido

dependencia ausente

fallo de Controller

fallo de worker
```

Payload:

```text
Code
Message
SourceComponent
ExceptionType
```

No debe utilizarse para estados operacionales legítimos como:

```text
UNREACHABLE
```

```text
UNKNOWN
```

```text
SWITCH_NOT_EXECUTED_DRY_RUN
```

---

## 25. Resultado negativo no es error

La arquitectura debe preservar la distinción:

```text
operational result
```

frente a:

```text
technical error
```

Ejemplo:

```text
ReachabilityState = UNREACHABLE
```

puede ser una observación válida.

No debe generar automáticamente:

```text
ErrorOccurred
```

---

## 26. Cola de eventos

ApplicationController deberá mantener inicialmente una colección temporal:

```text
EventBuffer
```

El modelo conceptual:

```text
QueueWatcher
    |
    v
EventBuffer
    |
    +--> GetEvents
    |
    +--> GetLastEvent
    |
    +--> GetStatus
```

La primera implementación no necesita una base de datos.

---

## 27. EventBuffer no es fuente histórica definitiva

`EventBuffer` se utilizará para:

```text
estado reciente

UI

pruebas

diagnóstico inmediato
```

No reemplaza:

```text
Logger
```

ni una futura persistencia histórica.

---

## 28. Tamaño limitado del EventBuffer

El buffer debe ser acotado.

Valor inicial propuesto:

```text
MaximumEvents = 100
```

Cuando se supere:

```text
eliminar evento más antiguo
```

Esto evita crecimiento ilimitado en un agente residente.

---

## 29. Orden del EventBuffer

El buffer debe preservar:

```text
orden temporal de recepción
```

La UI podrá mostrar inicialmente:

```text
evento más reciente primero
```

sin alterar el orden interno almacenado.

---

## 30. GetEvents

Nueva query prevista para ApplicationController.

Contrato:

```text
GetEvents
```

Entrada opcional:

```text
MaxEvents
EventType
PrinterName
CorrelationId
```

Salida:

```text
ControllerResult
```

con:

```text
Data = PrintSwitchEvent[]
```

No produce mutaciones.

---

## 31. GetLastEvent

Nueva query prevista:

```text
GetLastEvent
```

Devuelve:

```text
último evento disponible
```

o:

```text
NO_EVENT_AVAILABLE
```

No debe fallar porque el buffer esté vacío.

---

## 32. GetStatus y eventos

`GetStatus` no debe contener todo el historial.

Sólo deberá exponer referencias resumidas:

```text
LastEvent
LastDecision
LastRecovery
LastError
```

El historial reciente pertenece a:

```text
GetEvents
```

---

## 33. LastDecision

ApplicationController deberá actualizar:

```text
LastDecision
```

cuando reciba:

```text
DecisionProduced
```

La propiedad conservará el objeto estructurado más reciente.

---

## 34. LastRecovery

ApplicationController deberá actualizar:

```text
LastRecovery
```

cuando reciba:

```text
RecoveryCompleted
```

Esto soluciona el gap observado en P7-A5.1, donde el pipeline terminó pero:

```text
LastRecovery = null
```

---

## 35. LastError

ApplicationController deberá actualizar:

```text
LastError
```

únicamente cuando:

```text
ErrorOccurred
```

represente un fallo técnico.

No deberá llenarse por:

```text
UNREACHABLE
```

o:

```text
dry-run
```

---

## 36. Canales humanos y estructurados pueden coexistir

Durante la primera beta se permite:

```text
Write-Host
```

y:

```text
PrintSwitchEvent
```

simultáneamente.

Ejemplo:

```text
QueueWatcher
    |
    +--> Write-Host
    |
    +--> Event Channel
```

Esto permite preservar:

```text
compatibilidad CLI
```

mientras se desarrolla:

```text
ApplicationController / UI
```

---

## 37. No parsear Write-Host

Queda explícitamente prohibido implementar:

```text
if output contains "NUEVO TRABAJO DETECTADO"
```

o:

```text
regex "FinalClassification : ..."
```

como mecanismo de integración.

Esto sería frágil porque:

```text
el texto puede cambiar

el idioma puede cambiar

el formato puede cambiar

los espacios pueden cambiar

la UI quedaría acoplada a diagnóstico humano
```

---

## 38. Canal estructurado inicial

La implementación de P7-A5.3 deberá elegir un mecanismo que permita transportar
objetos desde el worker hacia ApplicationController.

Requisitos:

```text
preservar PSCustomObject

funcionar con background worker

no depender de Write-Host

permitir múltiples eventos

permitir correlación

no bloquear QueueWatcher

permitir cleanup
```

La tecnología concreta se decidirá en P7-A5.3.

---

## 39. Separar Event Contract de transporte

El contrato:

```text
PrintSwitchEvent
```

no debe depender de si el transporte futuro utiliza:

```text
PowerShell Job output

ConcurrentQueue

runspace

event subscription

named pipe

archivo temporal estructurado
```

El transporte puede cambiar.

El contrato semántico debe permanecer.

---

## 40. Evento vs ControllerResult

No son equivalentes.

### ControllerResult

Responde a:

```text
una operación solicitada
```

Ejemplo:

```text
GetStatus
StartMonitoring
StopMonitoring
```

### PrintSwitchEvent

Representa:

```text
algo que ocurrió
```

Ejemplo:

```text
PrintJobDetected
DecisionProduced
RecoveryCompleted
```

Una operación puede producir uno o varios eventos.

---

## 41. EventId

Además de CorrelationId cada evento deberá poseer:

```text
EventId
```

único.

Ejemplo:

```text
EventId = GUID
```

Distinción:

```text
EventId
    identifica un evento

CorrelationId
    identifica un episodio
```

---

## 42. Ejemplo de correlación completa

```text
CorrelationId = ABC123
```

Evento 1:

```text
EventId       = E1
EventType     = PrintJobDetected
CorrelationId = ABC123
```

Evento 2:

```text
EventId       = E2
EventType     = DecisionProduced
CorrelationId = ABC123
```

Evento 3:

```text
EventId       = E3
EventType     = RecoveryCompleted
CorrelationId = ABC123
```

La UI podrá reconstruir:

```text
trabajo
  |
  v
decisión
  |
  v
resultado
```

sin inferencias textuales.

---

## 43. SequenceNumber

Cada evento producido por un mismo Controller podrá poseer:

```text
SequenceNumber
```

incremental.

Ejemplo:

```text
1
2
3
4
...
```

Sirve para:

```text
orden local

debugging

detección de eventos perdidos
```

No sustituye:

```text
Timestamp
```

ni:

```text
EventId
```

---

## 44. Contrato final PrintSwitchEvent v1

La envoltura definitiva propuesta para v1 es:

```text
Component
EventVersion
EventId
SequenceNumber
EventType
Timestamp
Source
PrinterName
CorrelationId
Severity
Data
```

Ejemplo:

```text
Component      = PrintSwitchEvent
EventVersion   = 1
EventId        = <GUID>
SequenceNumber = 27
EventType      = PrintJobDetected
Timestamp      = ...
Source         = QueueWatcher
PrinterName    = L365 Series(Red)
CorrelationId  = <GUID>
Severity       = INFO
Data           = <PSCustomObject>
```

---

## 45. Contrato PrintJobDetected v1

```text
JobId
DocumentName
Owner
JobStatus
SubmittedTime
QueueName
```

Todos los campos representan observaciones del spooler.

Si un campo no está disponible:

```text
null
```

No se inventa un valor.

---

## 46. Contrato DecisionProduced v1

```text
RouteClassification
PolicyDecision
WiFiClassification
SwitchDecision
ShouldExecuteSwitch
PreserveEthernet
CurrentSSID
TargetSSID
```

Debe representar el resultado real producido por el pipeline.

No debe reinterpretarse en ApplicationController.

---

## 47. Contrato RecoveryCompleted v1

```text
FinalClassification
SwitchDecision
SwitchAuthorized
SwitchExecuted
RecoverySucceeded
TargetSSID
ConnectivityAfter
CompletedAt
```

Si alguna propiedad no existe en una rama determinada del pipeline:

```text
null
```

El envelope continúa siendo válido.

---

## 48. Contrato ErrorOccurred v1

```text
Code
Message
SourceComponent
ExceptionType
```

Debe ser compatible conceptualmente con:

```text
ControllerError
```

para evitar duplicar semántica de errores.

---

## 49. Estado de recovery y policy

P7-A5.1 observó simultáneamente:

```text
ApplicationController.RecoveryEnabled = False
```

y:

```text
Printer Policy.WifiRecoveryEnabled = True
```

Estos campos representan dimensiones diferentes.

### Controller RecoveryEnabled

Representa:

```text
permiso operacional de la aplicación
```

### Policy WifiRecoveryEnabled

Representa:

```text
capacidad permitida por policy para esa impresora
```

La ejecución real requiere ambas condiciones pertinentes.

No deben fusionarse en un único booleano sin contexto.

---

## 50. Recovery permission efectiva

Conceptualmente:

```text
EffectiveRecoveryPermission =
    ControllerRecoveryEnabled
    AND
    PolicyAllowsRecovery
    AND
    CoreDecisionAuthorizesAction
```

Este valor podrá exponerse posteriormente a UI.

No pertenece todavía al Event Contract como campo obligatorio.

---

## 51. La UI no controla Policy

La interfaz podrá permitir:

```text
EnableRecovery
DisableRecovery
```

a nivel ApplicationController.

No debe modificar silenciosamente:

```text
policy.json
```

cuando el usuario cambia ese toggle.

Son configuraciones distintas.

---

## 52. Eventos y UI

La primera UI podrá representar eventos como:

```text
20:41  Trabajo detectado
20:41  Epson no alcanzable
20:41  Recovery evaluado
20:41  Cambio a suarezcores sería necesario
20:41  Dry-run: cambio no ejecutado
```

Pero estas frases serán:

```text
representación visual
```

derivada de objetos estructurados.

No serán la fuente de verdad.

---

## 53. Eventos y system tray

El system tray no necesita mostrar todos los eventos.

Podrá utilizar:

```text
LastEvent
```

para decidir si corresponde una notificación visible.

Ejemplos candidatos:

```text
RecoveryCompleted

ErrorOccurred

MonitoringFaulted
```

`PrintJobDetected` puede permanecer inicialmente sólo en el panel/log.

---

## 54. Evento silencioso vs notificación

La existencia de un evento no implica una notificación al usuario.

La futura UI decidirá:

```text
evento
    |
    v
presentation policy
    |
    +--> panel
    +--> tray notification
    +--> log only
```

Esto evita contaminar el Core con decisiones de UX.

---

## 55. Eventos no deben bloquear el Core

La producción de un evento no debe detener:

```text
QueueWatcher
```

si la UI:

```text
no está abierta
```

o:

```text
no consume inmediatamente
```

La capa de eventos debe tolerar consumidores lentos o ausentes.

---

## 56. Fallo del transporte de eventos

Si el transporte de eventos falla:

```text
la lógica Core no debe dejar de funcionar
```

La prioridad continúa siendo:

```text
impresión / decisión / recovery
```

La observabilidad de UI es secundaria frente a la operación.

---

## 57. Compatibilidad CLI

Después de implementar P7-A5.3 deberá seguir siendo posible ejecutar:

```text
QueueWatcher.ps1
```

directamente desde consola.

La introducción del canal de eventos no debe convertir la UI en requisito del
Core.

---

## 58. Compatibilidad con P6

La capa de eventos no debe cambiar:

```text
EndpointResolver

EndpointReachability

RouteAnalyzer

ConnectivityPolicy

WiFiCandidateEvaluator

SwitchDecision

NetworkManager

RecoveryValidator
```

ni sus clasificaciones vigentes.

P7-A5 agrega observabilidad estructurada.

No redefine las decisiones validadas en P6.

---

## 59. Criterio de PASS de P7-A5.2

P7-A5.2 se considera completo cuando queden definidos:

```text
[ ] PrintSwitchEvent envelope

[ ] EventId

[ ] SequenceNumber

[ ] EventType

[ ] Timestamp

[ ] Source

[ ] PrinterName

[ ] CorrelationId

[ ] Severity

[ ] Data

[ ] PrintJobDetected

[ ] DecisionProduced

[ ] RecoveryStarted

[ ] RecoveryCompleted

[ ] MonitoringStarted

[ ] MonitoringStopped

[ ] MonitoringFaulted

[ ] ErrorOccurred

[ ] EventBuffer

[ ] GetEvents

[ ] GetLastEvent

[ ] separación Event / ControllerResult

[ ] prohibición de parsear Write-Host

[ ] compatibilidad CLI

[ ] Core P6 sin redefinir
```

---

## 60. Próxima etapa

La siguiente etapa será:

```text
P7-A5.3 — transporte estructurado de eventos
```

Primero se evaluará qué mecanismo encaja mejor con el worker actual.

La implementación deberá demostrar:

```text
QueueWatcher detecta un job

PrintJobDetected cruza al Controller

DecisionProduced cruza al Controller

RecoveryCompleted cruza al Controller

CorrelationId se conserva

GetEvents devuelve los objetos

GetStatus actualiza LastDecision / LastRecovery

Write-Host puede continuar existiendo

no se parsea texto

no se cambia Wi-Fi sin autorización
```

Sólo después se considerará:

```text
P7-B — System tray / UI
```

---

## 61. Arquitectura objetivo al cierre de P7-A5

```text
┌────────────────────────────────────────────┐
│                    UI                      │
│                                            │
│  state / tray / notifications / history    │
└──────────────────────┬─────────────────────┘
                       │
                       v
┌────────────────────────────────────────────┐
│          ApplicationController             │
│                                            │
│  lifecycle                                 │
│  ControllerResult                          │
│  EventBuffer                               │
│  GetEvents                                 │
│  GetLastEvent                              │
│  LastDecision                              │
│  LastRecovery                              │
│  LastError                                 │
└──────────────────────┬─────────────────────┘
                       │
                       │ PrintSwitchEvent
                       ^
                       │
┌──────────────────────┴─────────────────────┐
│              QueueWatcher                  │
│                                            │
│  PrintJobDetected                          │
│        |                                   │
│        v                                   │
│  PrintRecoveryOrchestrator                 │
│        |                                   │
│        +--> DecisionProduced               │
│        |                                   │
│        +--> RecoveryCompleted              │
│                                            │
│  Write-Host remains diagnostic only        │
└──────────────────────┬─────────────────────┘
                       │
                       v
┌────────────────────────────────────────────┐
│              PrintSwitch Core              │
│                                            │
│      decisiones validadas en Punto 6       │
└────────────────────────────────────────────┘
```

Regla final:

> **El Core produce hechos y decisiones. Los eventos los transportan.
> ApplicationController mantiene estado. La UI solamente representa.**