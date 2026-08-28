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