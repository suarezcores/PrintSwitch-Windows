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