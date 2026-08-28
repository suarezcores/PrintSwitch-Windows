# PrintSwitch — Alpha Checkpoint

## 1. Estado del proyecto

Estado:

```text
Alpha funcional
```

Fecha de corte:

```text
27/08/2026
```

Este checkpoint registra el primer estado de PrintSwitch en el que el flujo completo de recuperación contextual fue validado con una impresión física real.

Entorno principal de referencia:

```text
Windows
Epson L365
Cola: L365 Series(Red)
IP: 192.168.1.108
Puerto de impresión: TCP 9100
SSID objetivo: suarezcores
```

---

## 2. Objetivo alcanzado

PrintSwitch puede detectar un trabajo de impresión y determinar si es necesario modificar la conectividad Wi-Fi para alcanzar la impresora.

El flujo Alpha validado es:

```text
trabajo detectado
        |
        v
analizar interfaces
        |
        v
analizar caminos y rutas
        |
        v
aplicar política
        |
        v
decidir
        |
        v
actuar sólo si corresponde
        |
        v
validar recuperación
```

El objetivo no es cambiar de red automáticamente.

El objetivo es intervenir únicamente cuando la evidencia indica que el cambio puede resolver el problema.

---

## 3. Arquitectura operativa

La arquitectura integrada al cierre Alpha es:

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

`QueueWatcher.ps1` detecta trabajos y delega la recuperación.

`PrintRecoveryOrchestrator.ps1` concentra la coordinación operativa.

---

## 4. Autorización no equivale a acción

En el watcher:

```text
-EnableRecovery
```

significa:

```text
PrintSwitch tiene permiso para realizar cambios
si el análisis contextual los justifica
```

No significa:

```text
todo trabajo provoca un cambio de Wi-Fi
```

El orquestador mantiene la decisión final.

Por lo tanto:

```text
RecoveryEnabled = True
```

puede terminar correctamente en:

```text
SwitchAuthorized = False
SwitchExecuted   = False
```

---

## 5. Principio de intervención mínima

Si existe al menos un camino funcional hacia la impresora:

```text
ReachablePathCount > 0
```

la política es:

```text
NO_ACTION
```

Esto incluye tanto:

```text
UNIQUE_REACHABLE_PATH
```

como:

```text
MULTIPLE_REACHABLE_PATHS
```

El SSID actual no determina por sí solo si la impresora es alcanzable.

---

## 6. Preservación de Ethernet

La política Alpha establece:

```text
PrintSwitch nunca modifica Ethernet
```

El estado se observa mediante:

```text
EthernetPresentBefore
EthernetPresentAfter
EthernetPreserved
```

Si existía Ethernet activo antes de la recuperación, debe permanecer activo después.

La lógica fue validada mediante:

```text
scripts\Test-EthernetPreservation.ps1
```

Resultado:

```text
4/4 PASS
```

---

## 7. Múltiples caminos alcanzables

Se validó:

```text
Ethernet = 192.168.1.109
Wi-Fi    = 192.168.1.224
Epson    = 192.168.1.108
```

Ethernet y Wi-Fi pertenecían a:

```text
192.168.1.0/24
```

y ambos podían alcanzar:

```text
TCP 9100
```

Resultado:

```text
OverlapDetected = True
MULTIPLE_REACHABLE_PATHS
NO_ACTION
```

No se modificó ninguna interfaz.

---

## 8. Camino Ethernet único

Se validó:

```text
Ethernet = 192.168.1.109
Wi-Fi = Claro640 / 192.168.100.7
Epson = 192.168.1.108
```

La impresora era alcanzable únicamente por Ethernet.

Resultado:

```text
UNIQUE_REACHABLE_PATH
EXISTING_REACHABLE_PATH
NO_ACTION
SwitchAuthorized = False
SwitchExecuted   = False
```

Esto confirmó que PrintSwitch no necesita conectar el Wi-Fi al SSID de la impresora cuando ya existe otro camino válido.

---

## 9. Impresora apagada con camino local existente

Se validó:

```text
Ethernet activo
Wi-Fi = Claro640
Epson apagada
SSID suarezcores visible
RecoveryEnabled = True
```

Existía un camino local candidato hacia:

```text
192.168.1.0/24
```

pero la impresora no respondía en:

```text
TCP 9100
```

Resultado:

```text
CANDIDATE_PATHS_UNREACHABLE
EXISTING_PATH_PRINTER_UNREACHABLE
NO_SWITCH_PRINTER_UNREACHABLE
SwitchAuthorized = False
SwitchExecuted   = False
```

El Wi-Fi permaneció en:

```text
Claro640
```

Una impresora apagada no se interpreta automáticamente como una selección incorrecta de red.

---

## 10. Prueba de no interferencia

El escenario anterior fue probado durante una videoconferencia activa en Jabber.

Condiciones:

```text
Jabber activo
Ethernet disponible
Wi-Fi = Claro640
Epson apagada
RecoveryEnabled = True
```

PrintSwitch detectó el trabajo y realizó el análisis.

Resultado:

```text
SwitchAuthorized = False
SwitchExecuted   = False
```

La conectividad existente permaneció sin cambios.

Esta prueba valida:

```text
Non-interference / contextual preservation
```

---

## 11. Primer End-to-End Contextual Recovery

Condiciones iniciales:

```text
Epson = encendida
Ethernet = desconectado
Wi-Fi inicial = Claro640
SSID objetivo = suarezcores
TargetIP = 192.168.1.108
RecoveryEnabled = True
```

Se inició:

```text
QueueWatcher.ps1 -EnableRecovery
```

y se envió un trabajo pequeño desde Notepad.

Trabajo detectado:

```text
JobId = 7
```

### 11.1 Análisis inicial

No existía un camino actual hacia la impresora.

`RouteAnalyzer` observó:

```text
Wi-Fi = Claro640
IPv4 = 192.168.100.7
Gateway = 192.168.100.1
Target = no alcanzable
```

`ConnectivityPolicy` produjo:

```text
EVALUATE_WIFI_RECOVERY
```

### 11.2 Evaluación Wi-Fi

`WiFiCandidateEvaluator` observó:

```text
CurrentSSID   = Claro640
TargetSSID    = suarezcores
ProfileKnown  = True
TargetVisible = True
```

Resultado:

```text
WIFI_SWITCH_CANDIDATE_AVAILABLE
```

### 11.3 Decisión

`SwitchDecision` produjo:

```text
SWITCH_WIFI_FOR_PRINTER
```

### 11.4 Ejecución

`NetworkManager` produjo:

```text
InitialSSID      = Claro640
TargetSSID       = suarezcores
FinalSSID        = suarezcores
SwitchAuthorized = True
SwitchRequested  = True
CommandIssued    = True
SwitchVerified   = True
ExecutionResult  = NETWORK_SWITCH_VERIFIED
```

### 11.5 Validación

`RecoveryValidator` esperó la recuperación real del servicio.

Aproximadamente a los:

```text
1488 ms
```

TCP 9100 comenzó a responder.

Resultado:

```text
RecoveryValidation = RECOVERY_CONFIRMED_FAST
RecoveryConfirmed  = True
RecoveryElapsedMs  = 1496
```

### 11.6 Estado posterior

`ConnectivityAnalyzer` confirmó:

```text
SSID = suarezcores
Ping = OK
TCP 9100 = OK
HTTP 80 = OK
Classification = PRINTER_REACHABLE
```

`RouteAnalyzer` confirmó:

```text
TARGET_REACHABLE_VIA_WIFI
```

Resultado final:

```text
NetworkSwitchVerified = True
ConnectivityAfter     = PRINTER_REACHABLE
RouteAfter            = TARGET_REACHABLE_VIA_WIFI
RecoverySucceeded     = True
FinalClassification   = CONTEXTUAL_RECOVERY_SUCCESS
RecoveryValidation    = RECOVERY_CONFIRMED_FAST
RecoveryConfirmed     = True
SwitchAuthorized      = True
SwitchExecuted        = True
```

### 11.7 Evidencia física

La página fue impresa correctamente.

Resultado:

```text
PASS
```

Este evento constituye:

```text
PrintSwitch Alpha
primer End-to-End Contextual Recovery exitoso
```

---

## 12. Regresión del happy path

Después del End-to-End se validó:

```text
Epson encendida
Ethernet desconectado
Wi-Fi = suarezcores
RecoveryEnabled = True
```

Trabajo:

```text
JobId = 8
```

El trabajo atravesó `PrintRecoveryOrchestrator`.

Resultado:

```text
UNIQUE_REACHABLE_PATH
EXISTING_REACHABLE_PATH
NO_ACTION
SwitchAuthorized = False
SwitchExecuted   = False
```

La impresión se completó normalmente.

Resultado:

```text
PASS
```

---

## 13. QueueWatcher integrado

`QueueWatcher.ps1` delega actualmente la recuperación en:

```text
PrintRecoveryOrchestrator.ps1
```

El watcher transmite:

```text
PrinterName
TargetIP
TargetSSID
ConfigPath
```

Cuando se utiliza:

```text
-EnableRecovery
```

también habilita:

```text
Execute = True
```

La lógica anterior duplicada de recuperación fue eliminada.

---

## 14. PrintRecoveryOrchestrator

El orquestador operativo:

```text
src\PrintRecoveryOrchestrator.ps1
```

funciona por defecto en:

```text
DRY-RUN
```

y puede ejecutar cambios con:

```text
-Execute
```

Acepta configuración resuelta desde archivo y también parámetros explícitos:

```text
-TargetIP
-TargetSSID
```

Su contrato común incluye:

```text
Component
Version
PrinterName
TargetIP
TargetSSID
```

Versión registrada:

```text
Component = PrintRecoveryOrchestrator
Version   = 0.1
```

---

## 15. Componentes Alpha

Estado de componentes relevantes:

```text
QueueWatcher.ps1                  v0.6
PrintRecoveryOrchestrator.ps1    v0.1
InterfacePathAnalyzer.ps1        v0.2
RouteAnalyzer.ps1                v0.2
ConnectivityPolicy.ps1           v0.1
WiFiCandidateEvaluator.ps1       v0.2
SwitchDecision.ps1               v0.1
NetworkManager.ps1               v0.4
ConnectivityAnalyzer.ps1         v0.5
ConfigValidator.ps1              v0.1
```

`RecoveryValidator.ps1` forma parte del flujo de validación post-switch.

`ContextualRecoveryTest.ps1` se conserva como antecedente experimental y no forma parte del camino operativo de `QueueWatcher`.

---

## 16. Estado de integración

Al cierre Alpha:

```text
QueueWatcher
        |
        v
PrintRecoveryOrchestrator
```

es el camino operativo vigente.

Se eliminaron del watcher las rutas duplicadas de recuperación.

Se verificó la ausencia de referencias operativas obsoletas relacionadas con:

```text
ContextualRecoveryTest
DRY-RUN CONTEXTUAL
EJECUCION CONTEXTUAL
legacy
TODO
FIXME
```

El cierre de integración quedó sincronizado en `main`.

Commit de referencia:

```text
8526d3a
```

---

## 17. Capacidades demostradas

El Alpha demuestra, dentro del entorno probado:

```text
detección de trabajos
análisis de interfaces
análisis de rutas
detección de caminos únicos
detección de caminos múltiples
diferenciación entre camino candidato y alcanzable
preservación Ethernet
intervención mínima
evaluación Wi-Fi
decisión contextual
cambio Wi-Fi autorizado
verificación de SSID
validación TCP post-switch
impresión física después de recuperación
no intervención contextual
```

---

## 18. Limitaciones

El checkpoint no demuestra todavía soporte general para:

```text
otras marcas de impresoras
otros protocolos
múltiples impresoras simultáneas
múltiples adaptadores Wi-Fi
DHCP dinámico generalizado
descubrimiento automático
retorno automático al SSID previo
VPN complejas
entornos corporativos
otros sistemas operativos
```

El entorno principal validado continúa siendo:

```text
Windows
Epson L365
RAW TCP 9100
Claro640
suarezcores
```

---

## 19. Criterio de Alpha alcanzado

PrintSwitch alcanza el checkpoint Alpha porque existe evidencia real de ambos comportamientos fundamentales:

```text
intervención correcta
+
no intervención correcta
```

Se validó que el sistema puede:

```text
detectar
analizar
decidir
actuar
verificar
```

y también:

```text
detectar
analizar
decidir no actuar
preservar el contexto
```

El principio operativo consolidado es:

> **PrintSwitch no debe cambiar de red porque exista un trabajo de impresión. Debe cambiarla únicamente cuando la evidencia indique que la intervención es necesaria, está autorizada y puede recuperar la conectividad útil.**