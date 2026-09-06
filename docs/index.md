# PrintSwitch

## Estado actual

PrintSwitch se encuentra en estado:

```text
Alpha funcional
```

Fecha de corte documental:

```text
27/08/2026
```

El proyecto ya completó una primera validación End-to-End real de recuperación contextual de conectividad para impresión en Windows.

El escenario de referencia utiliza:

```text
Windows
Epson L365
IP 192.168.1.108
TCP 9100
SSID objetivo suarezcores
```

---

## Qué hace PrintSwitch

PrintSwitch observa trabajos de impresión y analiza si la impresora puede ser alcanzada mediante la conectividad existente.

El objetivo no es cambiar de Wi-Fi por detectar una impresora.

El objetivo es:

```text
detectar
   |
analizar
   |
decidir
   |
intervenir sólo si corresponde
   |
verificar
```

La arquitectura Alpha intenta conservar el estado actual siempre que exista un camino válido hacia la impresora.

---

## Arquitectura Alpha

El flujo operativo actual es:

```text
Windows Print Queue
        |
        v
QueueWatcher
        |
        v
PrintRecoveryOrchestrator
        |
        +--> InterfacePathAnalyzer
        +--> RouteAnalyzer
        +--> ConnectivityPolicy
        +--> WiFiCandidateEvaluator
        +--> SwitchDecision
        +--> NetworkManager
        +--> RecoveryValidator
        +--> ConnectivityAnalyzer
```

Cada componente mantiene una responsabilidad acotada.

---

## Capacidades validadas

Durante el Alpha se validó:

```text
detección de trabajos de impresión
análisis de interfaces IPv4
análisis de rutas
distinción Ethernet / Wi-Fi
detección de múltiples caminos alcanzables
preservación de Ethernet
política de intervención mínima
evaluación de SSID objetivo
cambio Wi-Fi autorizado
verificación del cambio
validación posterior mediante TCP 9100
impresión física después de recuperación
no intervención cuando el cambio no está justificado
```

---

## Primer End-to-End Contextual Recovery

La primera recuperación completa validada comenzó con:

```text
Epson encendida
Ethernet desconectado
Wi-Fi = Claro640
SSID objetivo = suarezcores
```

PrintSwitch detectó un trabajo y ejecutó:

```text
sin camino actual hacia la impresora
        |
        v
EVALUATE_WIFI_RECOVERY
        |
        v
WIFI_SWITCH_CANDIDATE_AVAILABLE
        |
        v
SWITCH_WIFI_FOR_PRINTER
        |
        v
Claro640 -> suarezcores
        |
        v
NETWORK_SWITCH_VERIFIED
        |
        v
RECOVERY_CONFIRMED_FAST
        |
        v
CONTEXTUAL_RECOVERY_SUCCESS
```

La conectividad TCP 9100 quedó confirmada aproximadamente a los:

```text
1496 ms
```

La página física fue impresa correctamente.

Este ensayo constituye el primer:

```text
PrintSwitch Alpha
End-to-End Contextual Recovery exitoso
```

---

## Intervención mínima

Una propiedad central del Alpha es que:

```text
RecoveryEnabled = True
```

no significa:

```text
cambiar siempre de Wi-Fi
```

La recuperación habilitada representa permiso para actuar si la evidencia lo justifica.

Si ya existe un camino válido:

```text
EXISTING_REACHABLE_PATH
NO_ACTION
```

Si existe un camino local candidato pero la impresora no responde:

```text
EXISTING_PATH_PRINTER_UNREACHABLE
NO_SWITCH_PRINTER_UNREACHABLE
```

---

## Preservación de Ethernet

PrintSwitch Alpha adopta la regla:

```text
Ethernet nunca es modificado por PrintSwitch
```

La recuperación Wi-Fi debe preservar cualquier Ethernet activo existente.

Esta política fue validada mediante pruebas específicas de preservación:

```text
4/4 PASS
```

---

## No interferencia contextual

También se validó un escenario real con:

```text
Jabber activo
Ethernet disponible
Wi-Fi = Claro640
Epson apagada
RecoveryEnabled = True
```

PrintSwitch detectó el trabajo pero decidió:

```text
SwitchAuthorized = False
SwitchExecuted   = False
```

La conectividad existente no fue modificada.

---

## Documentación

La documentación conserva dos capas:

```text
documentación histórica
        |
        v
corte documental Alpha
        |
        v
documentación vigente
```

Las secciones históricas no se eliminan ni reescriben.

Esto permite reconstruir cómo evolucionaron:

```text
hipótesis
pruebas
arquitectura
decisiones
roadmap
metodología
```

Ante una contradicción entre contenido previo y contenido posterior al corte Alpha, el contenido posterior representa el estado vigente.

---

## Documentos principales

### Estado Alpha

`Alpha_Checkpoint.md`

Resume el estado funcional alcanzado al cierre del Alpha.

### Metodología

`Methodology.md`

Documenta la metodología de investigación, validación incremental, intervención mínima y preservación contextual.

### Base de conocimiento

`Knowledge.md`

Consolida observaciones, inferencias y conocimiento técnico obtenido durante las pruebas.

### Arquitectura observada

`Architecture_Observed.md`

Describe la evolución arquitectónica y la arquitectura Alpha implementada.

### Pruebas experimentales

`Experimental_Tests.md`

Mantiene el registro cronológico de experimentos y validaciones.

### Roadmap

`Roadmap.md`

Concilia los objetivos históricos con el cierre Alpha y define la dirección Post-Alpha.

### Arquitectura de impresión Windows

`Windows_Printing_Architecture.md`

Documenta aspectos de la arquitectura de impresión de Windows relevantes para PrintSwitch.

---

## Limitaciones actuales

El Alpha fue validado principalmente con:

```text
Windows
Epson L365
RAW TCP 9100
redes Claro640 / suarezcores
```

Todavía requieren validación adicional:

```text
otras marcas de impresoras
otros protocolos
múltiples impresoras
múltiples adaptadores Wi-Fi
DHCP dinámico generalizado
descubrimiento automático de impresoras
retorno contextual a la red previa
VPN complejas
entornos corporativos
otros sistemas operativos
```

---

## Dirección Post-Alpha

La siguiente etapa prioriza:

```text
regresiones
        |
        v
segunda impresora
        |
        v
PrinterDiscovery
        |
        v
identidad dinámica
        |
        v
abstracción de protocolos
        |
        v
multi-impresora
```

La generalización debe realizarse a partir de evidencia experimental y no de supuestos.

---

## Principio de ingeniería

La regla central de PrintSwitch puede resumirse como:

> **Observar antes de inferir, medir antes de decidir, decidir antes de actuar y verificar después de actuar.**

Y para cualquier modificación de conectividad:

> **Si la evidencia disponible no justifica el cambio, la acción preferida es no intervenir.**


---

# Estado vigente — Septiembre 2026

> **Nota de versión**
>
> Todo el contenido anterior de este documento se conserva como referencia
> histórica de las etapas Alpha y Post-Alpha de PrintSwitch-Windows.
>
> Las descripciones anteriores representan correctamente el estado que tenía
> el proyecto cuando fueron escritas, pero no deben interpretarse como una
> descripción completa de la arquitectura operacional vigente.
>
> El estado actual documentado toma como referencia:
>
> ```text
> commit 55316dd
> FEAT: consolida recovery operacional y diagnostico opcional
> ```

---

## Evolución desde Alpha

El Alpha demostró que PrintSwitch podía:

```text
detectar un trabajo
        |
        v
analizar conectividad
        |
        v
evitar cambios innecesarios
        |
        v
decidir una recuperación Wi-Fi
        |
        v
ejecutarla
        |
        v
verificar recuperación
        |
        v
permitir la impresión
```

La etapa posterior refinó la unidad sobre la que se realiza esa decisión.

La arquitectura ya no parte de:

```text
impresora
+
IP
+
TCP 9100
```

como modelo operacional general.

El flujo vigente parte de la cola Windows:

```text
Trabajo
   |
   v
Cola Windows
   |
   v
QueueContext
   |
   v
Endpoint
   |
   v
Reachability
   |
   v
Paths
   |
   v
Policy
   |
   v
Acción mínima
```

---

## Endpoint-aware

PrintSwitch incorpora actualmente una capa de resolución de endpoint.

Esto permite distinguir, entre otros casos:

```text
NETWORK / RAW
NETWORK / LPR
NETWORK / IPP
USB
```

sin exigir que todos los dispositivos utilicen la misma estrategia de
reachability.

La cola Windows constituye el objeto operacional inicial.

El endpoint define cómo debe evaluarse su disponibilidad.

---

## Epson L365 — evidencia vigente

La Epson L365 continúa siendo la principal impresora utilizada para validar el
recovery físico.

La investigación posterior al Alpha determinó que la cola:

```text
L365 Series(Red)
```

utiliza operacionalmente:

```text
Transport    = NETWORK
Protocol     = LPR
Destination  = 192.168.1.108
TcpPort      = 515
QueueName    = ENPQueue
```

Por ello:

```text
192.168.1.108:515
```

es actualmente el endpoint utilizado para validar la recuperación operacional
de esa cola.

TCP 9100 continúa siendo una señal diagnóstica válida en los experimentos
donde fue utilizado, pero ya no constituye una suposición global del motor.

---

## Recovery físico validado

Se volvió a validar el escenario real:

```text
Ethernet desconectado
Wi-Fi inicial = Claro640
Epson encendida
suarezcores visible y conocido
```

El endpoint:

```text
192.168.1.108:515
```

era inicialmente inalcanzable.

PrintSwitch evaluó el contexto, determinó que correspondía recuperación Wi-Fi
y realizó:

```text
Claro640
   |
   v
suarezcores
```

Posteriormente se confirmó el servicio LPR / TCP 515 y la ruta resultante.

El resultado final fue:

```text
RecoverySucceeded     = True
FinalClassification   = CONTEXTUAL_RECOVERY_SUCCESS
```

---

## No intervención cuando existe un camino funcional

También se validó el escenario donde:

```text
Ethernet
   |
   v
Epson alcanzable

Wi-Fi
   |
   v
Claro640
```

Aunque se ejecutó el Orchestrator con permiso para realizar acciones reales,
el sistema detectó que el endpoint ya era alcanzable mediante Ethernet.

Resultado:

```text
SwitchAuthorized   = False
SwitchExecuted     = False
FinalClassification = EXISTING_REACHABLE_PATH
```

Esto confirma que:

```text
-Execute
```

significa permiso para actuar si es necesario y no una orden de cambiar Wi-Fi.

---

## Discovery y Policy

La arquitectura vigente separa:

```text
DISCOVERY
```

de:

```text
POLICY
```

Discovery responde:

```text
¿Qué existe y cómo está configurado?
```

Policy responde:

```text
¿Qué está autorizado a hacer PrintSwitch?
```

El inventario puede construirse desde:

```text
Windows
Registry
PnP
Spooler
```

mediante:

```text
PrinterDiscovery.ps1
```

y representarse temporalmente en:

```text
config/discovery.json
```

como snapshot regenerable.

La intención persistente se almacena separadamente en:

```text
config/policy.json
```

El archivo:

```text
config/printers.json
```

se conserva por compatibilidad con componentes anteriores y no representa el
modelo arquitectónico objetivo.

---

## ConnectivityAnalyzer

`ConnectivityAnalyzer.ps1` continúa disponible como herramienta diagnóstica.

Ya no constituye una dependencia obligatoria del recovery operacional.

Una recuperación completa fue validada con el componente temporalmente
ausente:

```text
ConnectivityAfter   = NOT_AVAILABLE
RecoverySucceeded   = True
FinalClassification = CONTEXTUAL_RECOVERY_SUCCESS
```

La autoridad operacional corresponde actualmente a la combinación de:

```text
NetworkSwitchVerified
RecoveryValidator.RecoveryConfirmed
RouteAfter.TargetReachable
```

---

## Preservación Ethernet

PrintSwitch continúa manteniendo como regla:

> **Una recuperación Wi-Fi no debe modificar Ethernet.**

La auditoría distingue actualmente:

```text
NOT_APPLICABLE
PRESERVED
FAILED
```

según exista o no Ethernet activa antes de la recuperación y según su estado
posterior.

---

## Documentación por versiones

A partir de este checkpoint se adopta explícitamente la siguiente política
documental:

```text
documentación existente
        |
        v
se conserva como versión histórica
        |
        v
no se reescribe retroactivamente
        |
        v
se agrega una nueva sección fechada
        |
        v
la nueva sección describe el estado vigente
```

Por lo tanto, una afirmación histórica puede diferir de una conclusión
posterior sin que la primera sea eliminada.

Ejemplo:

```text
Alpha
    TCP 9100 utilizado como señal operacional y de liveness

Septiembre 2026
    endpoint real Epson identificado como LPR / TCP 515
```

Ambas afirmaciones pertenecen a momentos distintos del desarrollo.

---

## Documentos vigentes de referencia

Para comprender el estado de Septiembre 2026 deben consultarse especialmente:

```text
Architecture_Observed.md
Knowledge.md
Roadmap.md
```

Las nuevas secciones fechadas al final de esos documentos describen la
evolución posterior al contenido histórico.

`Alpha_Checkpoint.md` continúa siendo deliberadamente una fotografía del Alpha
y no debe actualizarse para simular el comportamiento actual.

`Experimental_Tests.md` conserva la evidencia experimental cronológica y no
debe corregirse retroactivamente cuando una hipótesis o mecanismo fue
posteriormente refinado.

---

## Roadmap vigente

El estado actual es:

```text
[COMPLETADO] 1. Cierre endpoint-aware

[COMPLETADO] 2. Consolidación de inconsistencias

[SIGUIENTE]   3. Validación Brother

[PENDIENTE]   4. Consolidar Discovery + Policy

[PENDIENTE]   5. Integración QueueWatcher

[PENDIENTE]   6. Regresiones y casos raros

[POSTERIOR]   7. Aplicación / UI

[FUTURO]      8. Multi-impresora / otros fabricantes
```

La siguiente etapa funcional utiliza:

```text
Brother HL-1212W
```

como segunda impresora física de validación.

Windows expone actualmente colas de red y USB asociadas a ese dispositivo.

El objetivo no será agregar excepciones específicas para Brother.

El objetivo será comprobar si:

```text
QueueContext
      |
      v
Endpoint
      |
      v
ReachabilityStrategy
```

permite interpretar correctamente ambos transportes utilizando el mismo motor
general.

---

## Principio vigente

La regla histórica:

> **Observar antes de inferir, medir antes de decidir, decidir antes de actuar y verificar después de actuar.**

continúa plenamente vigente.

La evolución endpoint-aware agrega una precisión:

> **No preguntar primero en qué red debería estar la impresora. Preguntar
> primero cómo intenta alcanzarla realmente la cola que recibió el trabajo.**

Y se mantiene la regla de seguridad:

> **Si la evidencia disponible no justifica el cambio, la acción preferida es no intervenir.**

---

# Estado vigente — Cierre de Puntos 3 a 5 y entrada al Punto 6 — Septiembre 2026

> **Nota de actualización**
>
> Esta sección reemplaza únicamente la interpretación del estado vigente.
>
> Todo el contenido anterior permanece preservado como registro histórico de
> Alpha, Post-Alpha y de los checkpoints previos de Septiembre 2026.
>
> El baseline actual del proyecto es:
>
> ```text
> commit 4730803
> REFACTOR: desacopla diagnostico de configuracion legacy
> ```

---

## Estado actual del proyecto

PrintSwitch se encuentra actualmente en:

```text
Puntos 1 a 5
    COMPLETADOS

Auditoría pre-Punto 6
    COMPLETADA

Punto 6
    ACTUAL
```

La fase vigente ya no consiste principalmente en construir la arquitectura
base.

La arquitectura se encuentra:

```text
integrada
validada físicamente
probada con dos fabricantes
probada con NETWORK y USB
auditada
versionada
```

El siguiente objetivo es someterla a escenarios adversos y poco habituales
antes de iniciar el desarrollo de una interfaz de usuario.

---

## Roadmap vigente

```text
[COMPLETADO] 1. Cierre endpoint-aware

[COMPLETADO] 2. Consolidación de inconsistencias

[COMPLETADO] 3. Validación Brother

[COMPLETADO] 4. Consolidar Discovery + Policy

[COMPLETADO] 5. Integración QueueWatcher

[ACTUAL]      6. Regresiones y casos excepcionales

[POSTERIOR]   7. Aplicación / UI

[FUTURO]      8. Multi-impresora / otros fabricantes

[FUTURO 2]    Evaluación transversal de calidad de evidencia
```

---

## Arquitectura operacional vigente

La arquitectura actual parte de la cola real utilizada por Windows.

```text
Windows Print Queue
        |
        v
QueueWatcher
        |
        v
PrinterDiscovery
        |
        v
QueueContext
        |
        v
PrinterEndpointResolver
        |
        v
PrinterEndpointReachability
        |
        v
PrintRecoveryOrchestrator
        |
        +--> InterfacePathAnalyzer
        |
        +--> RouteAnalyzer
        |
        +--> ConnectivityPolicy
        |
        +--> WiFiCandidateEvaluator
        |
        +--> SwitchDecision
        |
        +--> NetworkManager
        |
        +--> RecoveryValidator
        |
        +--> ConnectivityAnalyzer
               |
               +--> diagnóstico endpoint-aware opcional
```

La decisión ya no parte del modelo histórico:

```text
impresora
+
IP manual
+
TCP 9100
```

sino de:

```text
trabajo
   |
   v
cola
   |
   v
endpoint
   |
   v
reachability
   |
   v
caminos
   |
   v
policy
   |
   v
acción mínima
```

---

## Separación de responsabilidades

La arquitectura vigente distingue:

```text
OBSERVAR
    Windows Print Queue
    QueueWatcher
    PrinterDiscovery

DESCRIBIR EL DESTINO
    PrinterEndpointResolver

COMPROBAR ENDPOINT
    PrinterEndpointReachability

ANALIZAR CAMINOS
    InterfacePathAnalyzer
    RouteAnalyzer

AUTORIZAR
    ConnectivityPolicy

EVALUAR ALTERNATIVAS
    WiFiCandidateEvaluator

DECIDIR
    SwitchDecision

ACTUAR
    NetworkManager

VALIDAR
    RecoveryValidator

DIAGNOSTICAR
    ConnectivityAnalyzer
```

La regla general es:

> Ninguna capa debe reconstruir innecesariamente información que ya fue
> resuelta por otra capa responsable de producirla.

---

## Epson L365 — evidencia vigente

La Epson continúa siendo el principal dispositivo utilizado para validar
recovery Wi-Fi.

Su cola de red es:

```text
L365 Series(Red)
```

y el endpoint operacional configurado actualmente por Windows es:

```text
TransportType         = NETWORK
Protocol              = LPR
ConfiguredDestination = 192.168.1.108
TcpPort               = 515
ServiceQueue          = ENPQueue
ReachabilityStrategy  = LPR_TCP
```

Por lo tanto:

```text
192.168.1.108:515
```

es el servicio operacional utilizado por la cola.

El histórico Alpha conserva referencias a:

```text
TCP 9100
```

porque ese puerto fue utilizado correctamente como señal diagnóstica durante
esa etapa.

La interpretación vigente es:

```text
TCP 9100
    puede aportar evidencia diagnóstica

TCP 515
    es el servicio operacional de la cola Epson actualmente configurada
```

---

## Brother HL-1212W — segunda impresora validada

La segunda impresora física utilizada para comprobar generalización es:

```text
Brother HL-1212W
```

Windows y el software Brother la exponen mediante la familia:

```text
Brother HL-1210W series
```

y actualmente existen dos colas relevantes:

```text
Brother HL-1210W series
Brother HL-1210W series USB
```

Estas representan dos endpoints distintos.

---

## Brother Network

La cola de red fue descubierta como:

```text
TransportType         = NETWORK
Protocol              = LPR
ConfiguredDestination = BRWC48E8F7B140F
AddressType           = HOSTNAME
TcpPort               = 515
ServiceQueue          = BINARY_P1
ReachabilityStrategy  = LPR_TCP
```

En el contexto donde la impresora está disponible:

```text
BRWC48E8F7B140F
        |
        v
192.168.100.12
```

y:

```text
192.168.100.12:515
```

responde correctamente.

Esto valida un endpoint NETWORK basado en hostname sin agregar reglas
específicas para Brother.

---

## Brother USB

La segunda cola Brother fue descubierta como:

```text
TransportType         = USB
Protocol              = USB
ConfiguredDestination = USB001
AddressType           = DEVICE
ReachabilityStrategy  = USB_PRESENCE
```

Con USB conectado:

```text
REACHABLE
USB_DEVICE_PRESENT
USB_ENDPOINT_REACHABLE
```

Con USB desconectado:

```text
UNREACHABLE
USB_DEVICE_NOT_PRESENT
USB_ENDPOINT_UNREACHABLE
```

En ambos escenarios:

```text
SwitchDecision   = NO_WIFI_ACTION
SwitchAuthorized = False
SwitchExecuted   = False
```

La ausencia de un endpoint USB no se interpreta como un problema recuperable
mediante Wi-Fi.

---

## Generalización validada hasta el momento

La misma arquitectura puede representar actualmente:

```text
Epson
    NETWORK
    IPV4
    LPR / TCP 515

Brother
    NETWORK
    HOSTNAME
    LPR / TCP 515

Brother
    USB
    DEVICE
    USB_PRESENCE
```

No se introdujeron reglas:

```text
if Epson ...
if Brother ...
```

La abstracción común permanece:

```text
QueueContext
      |
      v
Endpoint
      |
      v
ReachabilityStrategy
```

Esto constituye evidencia real de generalización.

No constituye todavía evidencia de universalidad.

---

## UNKNOWN y degradación segura

Durante la validación Brother se comprobó un caso donde:

```text
ConfiguredDestination = BRWC48E8F7B140F
```

no podía resolverse desde determinado contexto Wi-Fi.

La clasificación fue:

```text
ReachabilityState = UNKNOWN
ProbeResult       = DESTINATION_RESOLUTION_FAILED
```

El sistema produjo:

```text
NO_ACTION_INSUFFICIENT_ENDPOINT_EVIDENCE
NETWORK_DESTINATION_UNRESOLVED
```

sin modificar Wi-Fi.

Esto confirma:

```text
UNKNOWN
   !=
UNREACHABLE
```

y:

```text
falta de evidencia
   !=
autorización para intervenir
```

---

## Discovery y Policy

La arquitectura distingue explícitamente:

```text
DISCOVERY
```

de:

```text
POLICY
```

### Discovery

Responde:

```text
¿Qué existe?
¿Cómo intenta Windows alcanzarlo?
```

Se construye principalmente mediante:

```text
Windows
PrinterDiscovery
PrinterEndpointResolver
PrinterEndpointReachability
```

### Policy

Responde:

```text
¿Qué está autorizado a hacer PrintSwitch?
```

y se mantiene en:

```text
config/policy.json
```

Por ejemplo:

```text
la Epson existe y utiliza 192.168.1.108:515
        |
        v
DISCOVERY
```

mientras:

```text
PrintSwitch puede intentar recovery mediante suarezcores
        |
        v
POLICY
```

---

## Estado de `printers.json`

`config/printers.json` se conserva en el repositorio como artefacto histórico y
para herramientas legacy o experimentales.

Ya no constituye la fuente operacional del core moderno.

La selección de colas y resolución de endpoints se obtiene desde Windows.

La distinción vigente es:

```text
CORE MODERNO

Windows
PrinterDiscovery
PrinterEndpointResolver
PrinterEndpointReachability
policy.json
```

frente a:

```text
LEGACY / EXPERIMENTAL

printers.json
ConfigValidator
ProfileAnalyzer
PerformanceAnalyzer
ContextualRecoveryTest
```

---

## QueueWatcher integrado

QueueWatcher obtiene actualmente las colas mediante:

```text
PrinterDiscovery
```

y consume objetos:

```text
QueueContext
```

Ya no utiliza `printers.json` como inventario operacional.

Cuando existen varias colas, la selección puede realizarse explícitamente con:

```text
-PrinterName
```

La ambigüedad no debe resolverse mediante una elección silenciosa y arbitraria.

El checkpoint de esta integración es:

```text
bbe5c4c
FEAT: integra QueueWatcher con discovery y recovery operacional
```

---

## Recovery físico desde un trabajo real

Se validó el escenario:

```text
Wi-Fi inicial = Claro640
Ethernet      = desconectado
Epson         = encendida
SSID objetivo = suarezcores
Endpoint      = 192.168.1.108:515
Recovery      = habilitado
```

Un trabajo real ingresó en:

```text
L365 Series(Red)
```

QueueWatcher detectó el trabajo y delegó el análisis.

El sistema determinó que no existía un camino funcional y ejecutó:

```text
Claro640
   |
   v
suarezcores
```

Posteriormente:

```text
NetworkSwitchVerified       = True
RecoveryValidationConfirmed = True
RecoverySucceeded           = True
SwitchExecuted              = True
FinalClassification         = CONTEXTUAL_RECOVERY_SUCCESS
```

El endpoint:

```text
192.168.1.108:515
```

quedó nuevamente alcanzable.

---

## No intervención cuando el endpoint ya es alcanzable

También se validó:

```text
Wi-Fi inicial = suarezcores
Ethernet      = desconectado
Epson         = encendida
Recovery      = habilitado
```

El endpoint ya estaba disponible.

Resultado:

```text
UNIQUE_REACHABLE_PATH
EXISTING_REACHABLE_PATH
NO_ACTION

SwitchAuthorized = False
SwitchExecuted   = False
```

Esto confirma:

```text
Recovery habilitado
        !=
acción obligatoria
```

---

## ConnectivityAnalyzer v0.6

La auditoría previa al Punto 6 detectó que `ConnectivityAnalyzer v0.5`
continuaba dependiendo de conceptos legacy:

```text
printers.json
RequiredSSID
NETWORK_MISMATCH
TCP 9100
TCP 80
```

La versión vigente es:

```text
ConnectivityAnalyzer v0.6
```

y recibe:

```text
PrinterName
TargetIP
TcpPort
```

Su responsabilidad es:

```text
diagnosticar el endpoint recibido
```

y no:

```text
descubrirlo
decidir policy
comparar SSID
asumir puertos globales
```

ICMP permanece como evidencia auxiliar.

La evidencia operacional principal es:

```text
TargetIP:TcpPort
```

---

## Regresión posterior a la auditoría

El nuevo contrato se validó con dos dispositivos de red.

### Epson

```text
TargetIP = 192.168.1.108
TcpPort  = 515

OperationalTcpSucceeded = True
Classification          = PRINTER_REACHABLE
```

### Brother

```text
ConfiguredDestination = BRWC48E8F7B140F
ResolvedDestination   = 192.168.100.12
TcpPort               = 515

OperationalTcpSucceeded = True
Classification          = PRINTER_REACHABLE
```

El checkpoint correspondiente es:

```text
4730803
REFACTOR: desacopla diagnostico de configuracion legacy
```

---

## Baseline del Punto 6

Todas las próximas regresiones parten de:

```text
4730803
```

Este baseline representa:

```text
Puntos 1–5 completados
Epson validada
Brother Network validada
Brother USB validada
IPv4 validado
HOSTNAME validado
LPR validado
USB_PRESENCE validado
Discovery integrado
Policy separada
QueueWatcher integrado
recovery físico real
no intervención real
ConnectivityAnalyzer endpoint-aware
auditoría de dependencias completada
```

---

## Punto 6 — Regresiones y casos excepcionales

La fase vigente busca intentar romper o confundir deliberadamente los supuestos
del sistema.

La primera batería planificada incluye:

```text
P6-01
Endpoint accesible por camino alternativo

P6-02
Hostname conocido pero no resoluble

P6-03
Red objetivo visible pero endpoint no recuperado

P6-04
Cambio de contexto durante una evaluación

P6-05
Múltiples colas y selección ambigua

P6-06
Información parcial o contradictoria
```

Cada prueba debe registrar antes de ejecutarse:

```text
Test ID
Objetivo
Configuración inicial
Hipótesis
Resultado esperado
Acción
Resultado obtenido
Check real
Observaciones
Corrección necesaria
Regresión posterior
```

---

## Configuración inicial como parte de la evidencia

A partir del Punto 6 toda prueba física deberá declarar explícitamente, cuando
corresponda:

```text
Wi-Fi actual
SSID actual
Ethernet
Epson ON/OFF
Brother ON/OFF
USB conectado/desconectado
SSID visibles
Recovery habilitado/deshabilitado
cola utilizada
endpoint esperado
```

No deberá reconstruirse posteriormente de memoria.

---

## Entorno de pruebas disponible

El entorno controlable dispone actualmente de:

```text
Claro640
suarezcores
Suarez
```

además de:

```text
Epson L365

Brother HL-1212W
    |
    +--> Network
    |
    +--> USB
```

Esto permite producir escenarios con:

```text
cambios de SSID
Ethernet presente o ausente
impresoras ON/OFF
USB conectado/desconectado
hostname resoluble/no resoluble
red objetivo presente/ausente
caminos alternativos
```

sin modificar todavía la arquitectura para fabricar situaciones artificiales.

---

## Gate hacia la primera beta

La primera UI no comienza automáticamente después del Punto 5.

El gate vigente es:

```text
Puntos 1–5 completados
        +
Punto 6 ejecutado y estabilizado
        |
        v
arquitectura suficientemente estable
        |
        v
Punto 7
Aplicación / UI
```

La idea es evitar construir una interfaz sobre contratos que todavía puedan
cambiar durante la batería adversa.

---

## Documentos vigentes de referencia

Para comprender el estado actual deben consultarse principalmente:

```text
Architecture_Observed.md
Knowledge.md
Roadmap.md
Methodology.md
```

`Alpha_Checkpoint.md` continúa siendo deliberadamente una fotografía histórica
del Alpha.

`Experimental_Tests.md` conserva la cronología experimental y no debe
reescribirse retroactivamente cuando una conclusión posterior refine una etapa
anterior.

---

## Principios vigentes

Se mantienen las reglas históricas:

> **Observar antes de inferir, medir antes de decidir, decidir antes de actuar
> y verificar después de actuar.**

> **Si la evidencia disponible no justifica el cambio, la acción preferida es
> no intervenir.**

La evolución endpoint-aware agrega:

> **No preguntar primero en qué red debería estar la impresora. Preguntar
> primero cómo intenta alcanzarla realmente la cola que recibió el trabajo.**

Y la auditoría reciente agrega una cuarta precisión:

> **Una capa diagnóstica debe consumir el endpoint operacional ya resuelto y no
> reconstruir una segunda versión de la misma realidad mediante configuración
> legacy.**

---

## Próxima acción

La próxima acción del proyecto no es:

```text
agregar UI
```

ni:

```text
agregar más fabricantes
```

ni:

```text
expandir funcionalidades
```

La secuencia actual es:

```text
cerrar actualización documental
        |
        v
formalizar metodología del Punto 6
        |
        v
preparar registro experimental
        |
        v
ejecutar P6-01
        |
        v
analizar resultado
        |
        v
continuar batería adversa
```

El objetivo inmediato es comprobar cuánto resiste la arquitectura actual antes
de convertirla en una primera beta orientada a usuario.


---

# Estado vigente — Cierre del Punto 6 — Septiembre 2026

> Esta sección representa el estado actual de PrintSwitch.
>
> El contenido anterior se conserva como registro histórico de la evolución
> del proyecto.

## Punto 6 completado

La fase de regresiones y casos excepcionales quedó cerrada.

Resultado consolidado:

```text
P6-01   PASS
P6-02   PASS
P6-03   INCONCLUSIVE / SAFE BEHAVIOR
P6-04   PASS
P6-05   PASS
P6-06   PASS
P6-R01  PASS
```

La batería confirmó que el Core endpoint-aware puede:

```text
detectar trabajos

descubrir colas Windows

resolver endpoints reales

trabajar con IPv4 y hostname

distinguir NETWORK y USB

analizar caminos y rutas

preservar conectividad existente

ejecutar recovery cuando corresponde

no intervenir cuando no corresponde

revalidar el servicio operacional después de actuar

degradar de manera segura ante evidencia insuficiente
```

---

## Dos fabricantes físicamente validados

El entorno experimental ya incluye:

```text
Epson L365
Brother HL-1210W
```

### Epson L365

```text
TransportType         = NETWORK
Protocol              = LPR
ConfiguredDestination = 192.168.1.108
AddressType           = IPV4
TcpPort               = 515
ServiceQueue          = ENPQueue
ReachabilityStrategy  = LPR_TCP
```

### Brother HL-1210W

```text
TransportType         = NETWORK
Protocol              = LPR
ConfiguredDestination = BRWC48E8F7B140F
AddressType           = HOSTNAME
ResolvedAddress       = 192.168.100.12
TcpPort               = 515
ServiceQueue          = BINARY_P1
ReachabilityStrategy  = LPR_TCP
```

También se observó una cola USB Brother con una estrategia diferente de
reachability.

Esto respalda una arquitectura general basada en endpoints sin declarar
todavía compatibilidad universal.

---

## Principio operacional vigente

PrintSwitch ya no intenta responder simplemente:

```text
¿la impresora está disponible?
```

La pregunta real es:

```text
¿el servicio operacional asociado a esta cola
es alcanzable desde el contexto de red actual?
```

Si no lo es:

```text
¿existe una intervención conocida,
justificada,
segura
y autorizada
capaz de mejorar ese estado?
```

Y después de actuar:

```text
¿el servicio operacional fue realmente recuperado?
```

---

## Arquitectura vigente

```text
Print Job
    |
    v
Windows Queue
    |
    v
QueueWatcher
    |
    v
QueueContext
    |
    v
Endpoint Resolver
    |
    v
Reachability
    |
    v
Network Context
    |
    v
Policy
    |
    v
Decision
    |
    +---- NO ACTION
    |
    +---- SAFE NO-OP
    |
    +---- RECOVERY
              |
              v
         NetworkManager
              |
              v
         RecoveryValidator
```

`ConnectivityAnalyzer` permanece como diagnóstico complementario y no como
autoridad operacional.

---

## Hallazgos diferidos a Beta 2

La campaña P6 no detectó una falla estructural del Core que requiera
reconstrucción.

Sí dejó áreas de hardening:

```text
estabilización del discovery Wi-Fi

temporización del stack WLAN de Windows

scan / rescan

eventos frente a polling

Native Wi-Fi API

múltiples gateways

métricas y rutas alternativas

Ethernet + Wi-Fi

topologías controladas

fault injection
```

Para esa etapa se incorpora como recurso experimental:

```text
Suarez
```

una red Movistar independiente y administrable.

Debe distinguirse completamente de:

```text
suarezcores
```

que pertenece a otra infraestructura del laboratorio.

---

## Roadmap actual

```text
[COMPLETADO] 1. Cierre endpoint-aware

[COMPLETADO] 2. Consolidación de inconsistencias

[COMPLETADO] 3. Validación Brother

[COMPLETADO] 4. Consolidar Discovery + Policy

[COMPLETADO] 5. Integración QueueWatcher

[COMPLETADO] 6. Regresiones y casos raros

[SIGUIENTE]   7. Aplicación / UI — primera beta

[POSTERIOR]   Beta 2 — hardening Windows y topologías

[POSTERIOR]   8. Multi-impresora / otros fabricantes

[FUTURO]      Calidad y coherencia de evidencia
```

---

## Próximo hito — Primera beta

El siguiente trabajo funcional es:

```text
PUNTO 7
APLICACIÓN / UI
```

La primera beta deberá transformar el Core validado en una aplicación
utilizable sin duplicar su lógica.

Dirección prevista:

```text
PrintSwitch
    |
    +--> agente residente
    |
    +--> QueueWatcher
    |
    +--> system tray
    |
    +--> panel de estado
    |
    +--> configuración mínima
    |
    +--> logs
```

La regla para esta etapa es:

> **La interfaz debe exponer y controlar el Core validado, no reimplementarlo.**

El objetivo inmediato deja de ser demostrar nuevamente el mecanismo de
recovery.

El objetivo pasa a ser convertirlo en una primera experiencia de producto
reproducible y observable.