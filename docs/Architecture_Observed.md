# PrintSwitch — Arquitectura observada

**Documento:** ARC-001
**Versión:** 0.1
**Estado:** En desarrollo
**Última actualización:** 2026-08-17
**Relacionado con:** `Methodology.md`, `Knowledge.md`

---

## 1. Objetivo

Este documento describe la arquitectura observada durante las pruebas iniciales de PrintSwitch.

No representa todavía la arquitectura definitiva del software.

Su propósito es identificar los componentes que participan realmente en una impresión y determinar en qué punto puede intervenir PrintSwitch.

---

## 2. Entorno experimental

El entorno utilizado durante las pruebas contiene varias redes Wi-Fi.

La computadora puede estar conectada a una red diferente de aquella donde se encuentra la impresora.

El escenario principal observado fue:

```text
                    ┌─────────────────┐
                    │      PC         │
                    │    Windows      │
                    └────────┬────────┘
                             │
                       Wi-Fi actual
                             │
                    ┌────────▼────────┐
                    │    Claro640     │
                    └─────────────────┘

                       SIN ACCESO
                            X
                            │
                    ┌───────▼─────────┐
                    │   suarezcores   │
                    │     Router      │
                    └───────┬─────────┘
                            │
                            │ LAN
                            ▼
                    ┌─────────────────┐
                    │   Epson L365    │
                    │ 192.168.1.108   │
                    └─────────────────┘
```

En este estado la computadora puede generar trabajos de impresión, pero no posee conectividad con la impresora.

---

## 3. Flujo observado de un trabajo

Durante las pruebas se observó el siguiente comportamiento:

```text
Aplicación
   │
   │ solicitud de impresión
   ▼
Windows
   │
   ▼
Cola de impresión
   │
   │ trabajo registrado
   ▼
Controlador / sistema de impresión
   │
   ▼
Intento de comunicación
   │
   X
Impresora inaccesible
```

El fallo de comunicación no provoca necesariamente la desaparición del trabajo.

El trabajo permanece disponible en la cola.

**Clasificación:** `[OBSERVADO]`

---

## 4. Recuperación observada

Cuando la computadora cambia posteriormente a la red `suarezcores`:

```text
PC
 │
 │ cambio de Wi-Fi
 ▼
suarezcores
 │
 │ conectividad LAN
 ▼
Epson L365
```

el sistema de impresión puede continuar procesando los trabajos pendientes.

Durante las pruebas no fue necesario regresar a Word o Bloc de notas para solicitar nuevamente la impresión.

**Clasificación:** `[OBSERVADO]`

---

## 5. Punto de observación para PrintSwitch

Las aplicaciones que originaron los documentos fueron diferentes.

Sin embargo, los trabajos terminaron siendo visibles desde una infraestructura común de Windows.

Por lo tanto, el punto inicial elegido para PrintSwitch será:

```text
                 Aplicaciones
                /      |      \
               /       |       \
            Word    Bloc     Otras
               \       |       /
                \      |      /
                 ▼     ▼     ▼

             COLA DE WINDOWS
                    │
                    │
              PrintSwitch
```

PrintSwitch no necesita inicialmente conocer qué aplicación creó el documento.

Necesita detectar la existencia y estado del trabajo.

**Clasificación:** `[DECISIÓN]`

---

## 6. Separación entre cola y conectividad

Las pruebas muestran dos problemas diferentes:

### Capa de impresión

Determina si existen trabajos pendientes.

```text
¿Hay trabajo?
     │
    SÍ
     ▼
Existe intención de imprimir
```

### Capa de red

Determina si existe un camino hacia la impresora.

```text
¿Impresora accesible?
        │
      NO
        ▼
Debe resolverse conectividad
```

PrintSwitch deberá mantener separadas ambas responsabilidades.

**Clasificación:** `[DECISIÓN]`

---

## 7. Arquitectura conceptual de PrintSwitch

A partir de las observaciones actuales se propone provisionalmente:

```text
┌──────────────────────┐
│     QueueWatcher     │
│                      │
│ Observa trabajos     │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ ConnectivityAnalyzer │
│                      │
│ ¿La impresora está   │
│ disponible?          │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│    NetworkManager    │
│                      │
│ Determina / cambia   │
│ la red necesaria     │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│    PrinterMonitor    │
│                      │
│ Verifica recuperación│
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│        Logger        │
│                      │
│ Registra decisiones  │
│ y resultados         │
└──────────────────────┘
```

Los nombres representan responsabilidades conceptuales.

No implican todavía clases, procesos, servicios o archivos definitivos.

**Clasificación:** `[INFERIDO]`

---

## 8. Principio de independencia del fabricante

QueueWatcher deberá operar sobre la infraestructura de impresión de Windows siempre que sea posible.

La lógica central no deberá depender directamente de Epson.

Los componentes específicos de un fabricante deberán quedar aislados cuando sean necesarios.

Ejemplo:

```text
                PrintSwitch Core
                      │
            ┌─────────┴─────────┐
            │                   │
      Windows Spooler      Connectivity
                                │
                   ┌────────────┼────────────┐
                   │            │            │
                 Epson          HP         Otros
              (si requiere) (si requiere) (si requiere)
```

La independencia efectiva respecto de otros fabricantes todavía debe validarse experimentalmente.

**Clasificación:** `[DECISIÓN]` + `[PENDIENTE]`

---

## 9. Identidad y ubicación

PrintSwitch deberá diferenciar:

```text
IDENTIDAD DE IMPRESORA
        ≠
UBICACIÓN IP ACTUAL
```

Una dirección IP obtenida mediante DHCP puede cambiar.

Por ello, una futura configuración podrá contener múltiples atributos:

```text
PrinterProfile
│
├── WindowsPrinter
├── RequiredSSID
├── MAC
├── Hostname
├── LastKnownIP
└── IPMode
```

`LastKnownIP` deberá tratarse como información potencialmente variable.

El mecanismo definitivo de descubrimiento todavía no está definido.

**Clasificación:** `[DECISIÓN]` + `[PENDIENTE]`

---

## 10. Internet y LAN

La arquitectura debe distinguir explícitamente:

```text
                INTERNET
                    │
             servicios externos
                    │
          ─────────────────────
                    │
                   WAN
                    │
              ┌─────▼─────┐
              │  Router   │
              └─────┬─────┘
                    │
                   LAN
              ┌─────▼─────┐
              │ Impresora │
              └───────────┘
```

Se ha comprobado acceso HTTP local a la Epson L365 durante una interrupción de Internet.

Todavía está pendiente comprobar mediante un experimento controlado que la impresión completa se realiza sin WAN.

---

## 11. Principio de intervención mínima

PrintSwitch no deberá reemplazar innecesariamente funciones que Windows ya realiza correctamente.

Si Windows:

* conserva el trabajo;
* administra la cola;
* reintenta la comunicación;
* continúa la impresión cuando vuelve la conectividad;

PrintSwitch deberá concentrarse en resolver la condición que Windows no puede resolver por sí mismo:

> proporcionar temporalmente la conectividad de red necesaria.

**Clasificación:** `[DECISIÓN]`

---

## 12. Flujo objetivo provisional

El comportamiento buscado actualmente es:

```text
Trabajo aparece
       │
       ▼
QueueWatcher
       │
       ▼
¿Impresora accesible?
       │
   ┌───┴────┐
   │        │
  SÍ       NO
   │        │
   │        ▼
   │   identificar red
   │        │
   │        ▼
   │   cambiar conexión
   │        │
   │        ▼
   │   verificar impresora
   │        │
   └────────┤
            ▼
      Windows continúa
       la impresión
            │
            ▼
       trabajo termina
            │
            ▼
    retorno controlado
     a la red original
```

Este flujo constituye actualmente una arquitectura objetivo y deberá validarse mediante implementación incremental.

---

## 13. Próximo paso de ingeniería

La siguiente etapa experimental será pasar de un observador pasivo de la cola a un prototipo capaz de:

1. detectar un nuevo trabajo;
2. identificar la impresora correspondiente;
3. registrar la red actual;
4. determinar que la impresora no es accesible;
5. decidir qué red requiere;
6. realizar el cambio de red de forma controlada;
7. verificar la recuperación;
8. registrar el resultado.

La restauración automática de la red original deberá implementarse después de validar de forma segura el cambio hacia la red de impresión.


# Evolución de la arquitectura observada

## 1. Alcance arquitectónico actual

La implementación validada de PrintSwitch puede representarse actualmente como:

```text
                    ┌─────────────────────┐
                    │   printers.json     │
                    │   configuración     │
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │  ConfigValidator    │
                    │ valida configuración│
                    └─────────┬───────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────┐
│                    QueueWatcher                       │
│                                                       │
│  observa subsistema de impresión                     │
│  detecta trabajos                                    │
│  coordina diagnóstico y recuperación                 │
└───────────────┬───────────────────────┬───────────────┘
                │                       │
                ▼                       ▼
┌────────────────────────┐   ┌──────────────────────────┐
│ ConnectivityAnalyzer   │   │     NetworkManager       │
│                        │   │                          │
│ SSID                   │   │ identifica SSID         │
│ estado Windows         │   │ verifica perfil         │
│ ICMP                   │   │ verifica red visible    │
│ FastTcp                │   │ solicita cambio Wi-Fi   │
│ clasificación          │   │ verifica resultado      │
└────────────────────────┘   └──────────────────────────┘
                │                       │
                └───────────┬───────────┘
                            │
                            ▼
                  ┌─────────────────────┐
                  │       Logger        │
                  │                     │
                  │ registro persistente│
                  │ de eventos          │
                  └─────────────────────┘
```

Esta arquitectura corresponde al core actualmente implementado y probado.

---

# 2. QueueWatcher como coordinador

QueueWatcher no debe asumir progresivamente todas las responsabilidades del sistema.

Su función principal es:

```text
observar
   ↓
detectar
   ↓
consultar
   ↓
coordinar
   ↓
registrar
```

Ejemplo actual:

```text
PRINT_JOB_DETECTED
        ↓
ConnectivityAnalyzer
        ↓
NETWORK_MISMATCH
        ↓
NetworkManager
        ↓
NETWORK_SWITCH_VERIFIED
        ↓
ConnectivityAnalyzer
        ↓
PRINTER_REACHABLE
        ↓
RECOVERY_SUCCESS
```

Esto permite modificar internamente un componente sin alterar necesariamente los demás.

La sustitución de `Test-NetConnection` por `FastTcp` en ConnectivityAnalyzer v0.5 constituye una validación práctica de este desacoplamiento.

---

# 3. ConnectivityAnalyzer

Responsabilidad actual:

> Determinar el contexto de conectividad de una impresora sin modificar la configuración de red.

Actualmente utiliza información procedente de:

```text
SSID actual
Get-Printer
Win32_Printer
Win32_PrintJob
ICMP
TCP 9100
TCP 80
```

A partir de estas evidencias produce clasificaciones estructuradas.

Entre ellas:

```text
PRINTER_REACHABLE
NETWORK_MISMATCH
PRINTER_UNREACHABLE_ON_TARGET_NETWORK
```

ConnectivityAnalyzer debe continuar siendo:

```text
diagnóstico
```

y no:

```text
acción
```

La modificación de interfaces o redes corresponde a otros componentes.

---

# 4. NetworkManager

Responsabilidad actual:

> Ejecutar y verificar una modificación de conectividad previamente autorizada.

Actualmente la estrategia implementada es:

```text
Wi-Fi Target Switching
```

El componente puede:

```text
detectar SSID actual
verificar perfil Wi-Fi conocido
verificar visibilidad de red
solicitar conexión
verificar SSID final
devolver resultado estructurado
```

NetworkManager no decide por sí mismo que una impresora requiere un cambio de red.

La decisión surge del flujo coordinado por QueueWatcher a partir del diagnóstico.

---

# 5. ConfigValidator

Responsabilidad:

> Impedir que PrintSwitch comience a operar sobre una configuración estructuralmente inválida.

Actualmente valida, entre otros casos:

```text
archivo inexistente
JSON inválido
IP inválida
SSID ausente
nombre de impresora duplicado
```

Principio arquitectónico:

```text
configuración inválida
        ↓
fallar antes de operar
```

y no:

```text
configuración inválida
        ↓
intentar recuperación de red
        ↓
fallar durante la operación
```

---

# 6. Logger

Responsabilidad:

> Mantener trazabilidad persistente de las decisiones y resultados relevantes.

Ejemplos:

```text
PRINTSWITCH_STARTED
CONFIG_VALID
PRINTSWITCH_READY
PRINT_JOB_DETECTED
NETWORK_MISMATCH
NETWORK_SWITCH_VERIFIED
RECOVERY_SUCCESS
RECOVERY_FAILED
```

El Logger permite distinguir entre:

```text
lo que el sistema intentó
lo que Windows informó
lo que la red permitió
lo que finalmente fue verificado
```

---

# 7. Principio arquitectónico emergente

Las pruebas realizadas muestran que el problema general no debe modelarse simplemente como:

```text
impresora
   ↓
SSID obligatorio
```

La abstracción futura más apropiada es:

```text
impresora
   ↓
destino de conectividad
   ↓
rutas disponibles
   ↓
estrategia necesaria
```

Por lo tanto:

> El SSID requerido es actualmente una propiedad de la estrategia implementada, no necesariamente una propiedad universal de toda impresora soportada por PrintSwitch.

---

# 8. Principio de mínima intervención

Antes de modificar una interfaz, una futura versión debería responder:

```text
¿existe ya un camino válido hacia la impresora?
```

Si la respuesta es:

```text
SÍ
```

la acción preferida deberá ser:

```text
NO MODIFICAR CONECTIVIDAD
```

Solo cuando no exista una ruta válida deberá evaluarse una intervención.

---

# 9. Arquitectura futura propuesta

Los siguientes componentes representan evolución arquitectónica y NO funcionalidad actualmente implementada.

```text
                Windows Printing Subsystem
                          │
                          ▼
                 ┌──────────────────┐
                 │ PrinterDiscovery │
                 └────────┬─────────┘
                          │
                          ▼
                 Printer / Destination
                          │
                          ▼
              ┌────────────────────────┐
              │ ConnectivityAnalyzer   │
              └────────────┬───────────┘
                           │
                           ▼
                ¿destino alcanzable?
                    │             │
                   SÍ            NO
                    │             │
                    ▼             ▼
                NO ACTION    Route / Interface
                               Awareness
                                   │
                                   ▼
                           Strategy Selection
                                   │
                   ┌───────────────┼───────────────┐
                   ▼               ▼               ▼
                Wi-Fi          Ethernet        futuras
                Switch         coexistencia    estrategias
```

---

# 10. PrinterDiscovery — componente futuro

Responsabilidad propuesta:

> Descubrir y describir las impresoras que Windows ya conoce.

Posibles fuentes:

```text
Get-Printer
Win32_Printer
configuración de puertos
impresora predeterminada
drivers instalados
monitores de puerto
```

Salida conceptual:

```text
PrinterProfile
    Name
    Driver
    Port
    Destination
    Default
    ProtocolHint
```

No deberá suponerse que todos estos datos estarán disponibles para todas las impresoras.

---

# 11. Route / Interface Awareness — componente futuro

Responsabilidad propuesta:

> Determinar qué interfaces y rutas existentes pueden alcanzar el destino sin alterar innecesariamente la conectividad.

Escenario motivador:

```text
Ethernet conectado
        +
Wi-Fi conectado
```

Si Ethernet mantiene:

```text
Internet
Jabber
VPN
servicios generales
```

y Wi-Fi puede utilizarse para alcanzar la impresora, PrintSwitch debería poder aprovechar esa coexistencia.

Más importante aún:

```text
si Ethernet ya alcanza la impresora
```

PrintSwitch no debería cambiar Wi-Fi solamente porque exista un `requiredSSID`.

---

# 12. Strategy Selection — evolución futura

La arquitectura deberá permitir seleccionar estrategias según el destino observado.

Ejemplos posibles:

```text
RAW / TCP 9100
IPP / IPPS
LPR
WSD
monitores propietarios
```

Esto evita codificar una falsa equivalencia:

```text
impresora de red = puerto 9100
```

La Epson L365 constituye actualmente el entorno experimental validado, no una definición universal del comportamiento de todas las impresoras.

---

# 13. Compatibilidad multimarca

Las futuras pruebas con:

```text
HP
Lexmark
otras impresoras de red
```

deberán utilizarse para descubrir diferencias reales.

Principio:

```text
no diseñar excepciones por marca anticipadamente
```

Primero:

```text
observar
medir
identificar protocolo / puerto
documentar
```

Después:

```text
generalizar cuando exista evidencia
```

---

# 14. Separación entre conectividad e impresión

PrintSwitch debe distinguir dos dominios:

```text
CONECTIVIDAD
¿Windows posee un camino utilizable hacia la impresora?
```

y:

```text
ESTADO DE IMPRESORA
¿la impresora puede físicamente completar el trabajo?
```

Ejemplos de problemas que pueden quedar fuera de la responsabilidad de conectividad:

```text
sin tinta
sin papel
cabezal obstruido
error mecánico
impresora pausada
problema de driver
```

Una recuperación puede considerarse exitosa cuando PrintSwitch restablece y verifica el camino de conectividad que le corresponde, aunque posteriormente la impresora presente un problema propio.

---

# 15. Dirección arquitectónica

La evolución deseada puede resumirse como:

```text
PrintSwitch inicial
        =
cambio automático de Wi-Fi

             ↓

PrintSwitch evolucionado
        =
orquestador de conectividad
para impresión en Windows
```

El core existente constituye la primera estrategia funcional de esa arquitectura más amplia.
---

> **Nota de evolución documental — corte Alpha (27/08/2026)**
>
> Las secciones anteriores documentan la arquitectura observada y propuesta
> durante las etapas iniciales del proyecto.
>
> Se conservan como registro histórico porque muestran cómo evolucionaron
> las hipótesis, las pruebas y las decisiones técnicas.
>
> A partir de este punto se documenta la arquitectura efectivamente
> implementada y validada durante el cierre del Alpha.
>
> Ante una contradicción, las secciones posteriores a este corte representan
> el estado arquitectónico vigente.

# Arquitectura Alpha implementada — 27/08/2026

## 16. Cambio de estado arquitectónico

Durante las primeras etapas, PrintSwitch fue una combinación de scripts de
diagnóstico, observación de cola y experimentos de conectividad.

En el Alpha, esas capacidades quedaron integradas en un flujo operativo
completo.

La arquitectura dejó de ser:

```text
QueueWatcher
    |
    +--> ConnectivityAnalyzer
    |
    +--> NetworkManager
```

para evolucionar hacia:

```text
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

El cambio principal consiste en separar:

```text
detección
análisis
política
decisión
ejecución
validación
```

---

## 17. QueueWatcher como punto de entrada

`QueueWatcher.ps1` continúa siendo el componente que observa la cola de
impresión.

Su responsabilidad actual es:

```text
detectar nuevo trabajo
        |
        v
identificar impresora
        |
        v
delegar recuperación
```

La lógica de recuperación ya no se implementa dentro del watcher.

Cuando detecta un trabajo, construye los parámetros necesarios y llama a:

```text
PrintRecoveryOrchestrator.ps1
```

Esto elimina la duplicación de política entre el observador y el sistema de
recuperación.

---

## 18. PrintRecoveryOrchestrator

`PrintRecoveryOrchestrator.ps1` es el coordinador operativo de la recuperación
Alpha.

Recibe:

```text
PrinterName
TargetIP
TargetSSID
ConfigPath
```

y opcionalmente:

```text
-Execute
```

Sin `-Execute` funciona como:

```text
DRY-RUN
```

Con `-Execute` puede autorizar componentes que realizan cambios reales.

El orquestador no asume que un trabajo de impresión requiere automáticamente
un cambio de red.

Primero analiza el contexto.

---

## 19. Resolución de configuración

El orquestador puede obtener:

```text
TargetIP
TargetSSID
```

desde:

```text
config\printers.json
```

pero también acepta valores explícitos.

Esto permite mantener la configuración actual basada en archivo y, al mismo
tiempo, preparar la arquitectura para pruebas futuras con múltiples
impresoras.

La impresora Alpha de referencia es:

```text
L365 Series(Red)
IP: 192.168.1.108
SSID objetivo: suarezcores
```

---

## 20. InterfacePathAnalyzer

`InterfacePathAnalyzer.ps1` analiza las interfaces IPv4 activas y determina
qué caminos locales podrían alcanzar la red de destino.

Evalúa, entre otros elementos:

```text
interfaz
dirección IPv4
prefijo
subred
relación con TargetIP
TCP 9100 ligado a interfaz
```

El objetivo es distinguir:

```text
camino candidato
```

de:

```text
camino realmente alcanzable
```

---

## 21. Clasificaciones de caminos

Las clasificaciones principales observadas en el Alpha son:

```text
UNIQUE_REACHABLE_PATH
MULTIPLE_REACHABLE_PATHS
CANDIDATE_PATHS_UNREACHABLE
```

### UNIQUE_REACHABLE_PATH

Existe exactamente un camino validado hacia el servicio de impresión.

Ejemplo:

```text
Ethernet 192.168.1.109
        |
        v
Epson 192.168.1.108:9100
```

### MULTIPLE_REACHABLE_PATHS

Más de una interfaz puede alcanzar la impresora.

Ejemplo validado:

```text
Ethernet 192.168.1.109
Wi-Fi   192.168.1.224

ambas:
192.168.1.0/24
```

### CANDIDATE_PATHS_UNREACHABLE

Existe una interfaz compatible con la red de destino, pero el servicio no
responde.

Ejemplo:

```text
Ethernet en 192.168.1.0/24
Epson apagada
TCP 9100 no responde
```

---

## 22. Solapamiento Ethernet + Wi-Fi

Se validó un escenario donde Ethernet y Wi-Fi pertenecían simultáneamente a:

```text
192.168.1.0/24
```

y ambos podían alcanzar:

```text
192.168.1.108:9100
```

El resultado fue:

```text
MULTIPLE_REACHABLE_PATHS
```

La arquitectura no considera este solapamiento como motivo automático para
intervenir.

La regla operativa es:

```text
ReachablePathCount > 0
        |
        v
NO_ACTION
```

---

## 23. RouteAnalyzer

`RouteAnalyzer.ps1` observa cómo Windows intenta alcanzar el destino.

Analiza:

```text
ruta hacia TargetIP
interfaz preferida
dirección local
gateway
alcanzabilidad
```

Entre las clasificaciones observadas se encuentran:

```text
TARGET_REACHABLE_VIA_ETHERNET
TARGET_REACHABLE_VIA_WIFI
```

El análisis de ruta complementa el análisis de interfaces, pero no lo
reemplaza.

---

## 24. ConnectivityPolicy

`ConnectivityPolicy.ps1` decide si corresponde:

```text
NO_ACTION
```

o:

```text
EVALUATE_WIFI_RECOVERY
```

La política Alpha evita iniciar recuperación Wi-Fi cuando ya existe un camino
funcional hacia la impresora.

Su función no es ejecutar acciones sino determinar si el contexto justifica
seguir evaluando una intervención.

---

## 25. WiFiCandidateEvaluator

`WiFiCandidateEvaluator.ps1` evalúa si el SSID objetivo constituye una
alternativa válida.

Comprueba:

```text
adaptador Wi-Fi
SSID actual
perfil conocido
SSID objetivo visible
```

La visibilidad del SSID se trata como un dato temporal.

Por ello se incorporaron reintentos antes de concluir que una red no está
disponible.

Una clasificación observada es:

```text
WIFI_SWITCH_CANDIDATE_AVAILABLE
```

---

## 26. SwitchDecision

`SwitchDecision.ps1` transforma la evidencia recolectada en una decisión
explícita.

Una decisión validada es:

```text
SWITCH_WIFI_FOR_PRINTER
```

La existencia de esta decisión no implica por sí sola que se ejecute el
cambio.

Debe existir además autorización de ejecución.

---

## 27. Autorización y ejecución son independientes

La arquitectura separa:

```text
decidir
```

de:

```text
ejecutar
```

En `QueueWatcher.ps1`:

```text
-EnableRecovery
```

otorga permiso global para que el orquestador ejecute una recuperación si la
política y la evidencia la justifican.

En el orquestador:

```text
-Execute
```

habilita las acciones reales.

Por lo tanto:

```text
RecoveryEnabled = True
```

no significa:

```text
SwitchExecuted = True
```

---

## 28. NetworkManager

`NetworkManager.ps1` es el componente encargado del cambio Wi-Fi real.

La ejecución sólo ocurre cuando está explícitamente autorizada.

Utiliza:

```text
netsh wlan connect
```

y posteriormente verifica que el SSID final sea el solicitado.

Su salida estructurada incluye:

```text
InitialSSID
TargetSSID
FinalSSID
SwitchAuthorized
SwitchRequested
CommandIssued
SwitchVerified
ExecutionResult
```

Un resultado validado fue:

```text
NETWORK_SWITCH_VERIFIED
```

---

## 29. Preservación de Ethernet

PrintSwitch Alpha adopta una regla explícita:

```text
Ethernet nunca es modificado por PrintSwitch
```

Antes y después de una recuperación se registra:

```text
EthernetPresentBefore
EthernetPresentAfter
EthernetPreserved
```

La semántica vigente es:

```text
si Ethernet estaba activo antes
    debe continuar activo después
```

Si no existía Ethernet activo antes, el sistema no afirma falsamente que
hubo preservación de una interfaz inexistente.

---

## 30. RecoveryValidator

Verificar únicamente el SSID final no alcanza para confirmar una recuperación.

Después del cambio, `RecoveryValidator.ps1` realiza polling sobre:

```text
ruta
TCP 9100
```

hasta:

```text
confirmar recuperación
```

o:

```text
agotar la ventana temporal
```

Una recuperación real sólo se confirma cuando el servicio de impresión vuelve
a estar alcanzable.

---

## 31. ConnectivityAnalyzer optimizado

`ConnectivityAnalyzer.ps1` se utiliza para describir el estado de
conectividad.

Comprueba:

```text
SSID
estado de impresora
ping
TCP 9100
HTTP 80
```

Durante la evolución Alpha se reemplazó una dependencia lenta de
`Test-NetConnection` por pruebas TCP más directas.

Esto redujo significativamente el tiempo de diagnóstico y permitió usar el
análisis dentro del flujo operativo.

Una clasificación observada es:

```text
PRINTER_REACHABLE
```

---

## 32. Principio de intervención mínima implementado

La arquitectura Alpha prioriza no alterar conectividad cuando ya existe una
solución válida.

Flujo simplificado:

```text
¿hay camino alcanzable?
        |
   +----+----+
   |         |
  sí         no
   |         |
NO_ACTION    continuar análisis
```

Esto impide usar el SSID actual como único criterio de decisión.

---

## 33. Impresora apagada con camino existente

Se validó el escenario:

```text
Ethernet activo
Wi-Fi = Claro640
Epson apagada
SSID suarezcores visible
RecoveryEnabled = True
```

Aunque la impresora no respondía, existía un camino local candidato por
Ethernet hacia la red de destino.

El sistema produjo:

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

Esto evita interpretar una impresora apagada como un problema de selección de
red.

---

## 34. Prueba de no interferencia con Jabber

El escenario anterior fue reproducido mientras existía una videoconferencia
activa en Jabber.

Contexto:

```text
Jabber activo
Ethernet disponible
Wi-Fi = Claro640
Epson apagada
RecoveryEnabled = True
```

PrintSwitch detectó el trabajo de impresión, realizó el análisis y decidió no
modificar la red.

Resultado:

```text
SwitchAuthorized = False
SwitchExecuted   = False
```

La prueba valida una propiedad arquitectónica importante:

```text
la capacidad de recuperación puede estar habilitada
sin que ello implique interferencia automática
con conectividad utilizada por otras aplicaciones
```

---

## 35. Primer End-to-End Contextual Recovery exitoso

El Alpha fue validado con un escenario real completo.

Estado inicial:

```text
Epson encendida
Ethernet desconectado
Wi-Fi = Claro640
SSID objetivo = suarezcores
```

Se ejecutó:

```text
QueueWatcher.ps1 -EnableRecovery
```

y se envió un trabajo pequeño desde Notepad.

El flujo observado fue:

```text
QueueWatcher
    |
    v
JobId 7 detectado
    |
    v
PrintRecoveryOrchestrator
    |
    v
sin camino actual hacia Epson
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
NetworkManager
    |
    v
Claro640 -> suarezcores
    |
    v
NETWORK_SWITCH_VERIFIED
    |
    v
RecoveryValidator
    |
    v
TCP 9100 alcanzable
    |
    v
RECOVERY_CONFIRMED_FAST
    |
    v
CONTEXTUAL_RECOVERY_SUCCESS
```

La recuperación fue confirmada aproximadamente a los:

```text
1496 ms
```

Los campos finales incluyeron:

```text
NetworkSwitchVerified = True
ConnectivityAfter     = PRINTER_REACHABLE
RouteAfter            = TARGET_REACHABLE_VIA_WIFI
RecoverySucceeded     = True
RecoveryConfirmed     = True
SwitchAuthorized      = True
SwitchExecuted        = True
```

La página física fue impresa correctamente.

Este escenario constituye el primer:

```text
PrintSwitch Alpha
End-to-End Contextual Recovery exitoso
```

---

## 36. Regresión del happy path

Después del End-to-End se probó:

```text
Epson encendida
Ethernet desconectado
Wi-Fi ya conectado a suarezcores
RecoveryEnabled = True
```

Se detectó:

```text
JobId 8
```

El trabajo atravesó el mismo orquestador operativo.

`InterfacePathAnalyzer` detectó:

```text
UNIQUE_REACHABLE_PATH
```

El resultado fue:

```text
EXISTING_REACHABLE_PATH
NO_ACTION
SwitchAuthorized = False
SwitchExecuted   = False
```

El trabajo se imprimió correctamente.

Esto confirma que el orquestador permanece en el camino operativo incluso
cuando no necesita realizar ninguna recuperación.

---

## 37. Contrato uniforme del orquestador

Las diferentes ramas de salida de `PrintRecoveryOrchestrator.ps1` fueron
normalizadas.

Todas incluyen:

```text
Component
Version
PrinterName
TargetIP
TargetSSID
```

El componente declara:

```text
Component = PrintRecoveryOrchestrator
Version   = 0.1
```

A estos campos se agregan los resultados específicos de cada rama.

Esto facilita:

```text
logging
pruebas automáticas
diagnóstico
integración futura
```

---

## 38. Arquitectura resultante

La arquitectura operativa Alpha puede representarse así:

```text
Windows Print Queue
        |
        v
QueueWatcher
        |
        v
PrintRecoveryOrchestrator
        |
        +-----------------------------+
        |                             |
        v                             v
InterfacePathAnalyzer           RouteAnalyzer
        |                             |
        +--------------+--------------+
                       |
                       v
               ConnectivityPolicy
                       |
                       v
              ¿requiere recuperación?
                  |           |
                 no           sí
                  |           |
                  v           v
              NO_ACTION   WiFiCandidateEvaluator
                              |
                              v
                        SwitchDecision
                              |
                              v
                        NetworkManager
                              |
                              v
                       RecoveryValidator
                              |
                              v
                     ConnectivityAnalyzer
                              |
                              v
                         resultado final
```

La idea central es:

```text
observar
   |
analizar
   |
decidir
   |
actuar sólo si corresponde
   |
verificar
```

---

## 39. Límites de la arquitectura Alpha

La arquitectura actual fue validada principalmente con:

```text
Windows
Epson L365
TCP 9100
SSID suarezcores
redes Claro640 / suarezcores
```

Todavía no puede considerarse validado:

```text
descubrimiento genérico de impresoras
múltiples impresoras simultáneas
otras marcas
otros protocolos
retorno automático al SSID anterior
múltiples adaptadores Wi-Fi
VPN complejas
entornos corporativos
otros sistemas operativos
```

Estos límites no invalidan el Alpha.

Definen el alcance real de la evidencia obtenida hasta este punto.

---

# Actualización de arquitectura — Septiembre 2026

> **Estado documental**
>
> Todo el contenido anterior de este documento se conserva como registro
> histórico de las etapas previas de PrintSwitch-Windows.
>
> Las descripciones anteriores de la arquitectura Alpha, sus componentes,
> dependencias, protocolos y criterios de validación representan el estado
> real del proyecto en esas etapas, pero no deben interpretarse como la
> arquitectura operacional vigente.
>
> Esta sección documenta la evolución posterior y toma como referencia el
> estado del proyecto alcanzado en el commit:
>
> ```text
> 55316dd
> FEAT: consolida recovery operacional y diagnostico opcional
> ```

---

## 40. Cambio de unidad operacional

Durante el Alpha, gran parte del análisis podía representarse mediante una
relación relativamente directa:

```text
impresora
   |
   v
dirección IP
   |
   v
alcanzabilidad
```

La investigación posterior mostró que esta representación era insuficiente.

Windows no entrega simplemente un trabajo a una dirección IP.

La unidad operacional real comienza en la cola de impresión y continúa hacia
el endpoint configurado para esa cola.

La arquitectura vigente se representa conceptualmente como:

```text
Trabajo de impresión
        |
        v
Cola Windows
        |
        v
QueueContext
        |
        v
Endpoint lógico
        |
        v
Transporte / protocolo
        |
        v
Reachability
        |
        v
Paths disponibles
        |
        v
Policy
        |
        v
Acción mínima necesaria
```

Por lo tanto, PrintSwitch deja de considerar una IP fija como identidad
suficiente de una impresora.

La cola Windows pasa a ser el objeto operacional primario desde el cual se
descubre el destino real.

---

## 41. Separación entre cola, endpoint y dispositivo físico

La arquitectura vigente distingue tres conceptos que anteriormente podían
aparecer mezclados.

### Cola Windows

Representa el objeto al que Windows entrega el trabajo.

Ejemplos observados:

```text
L365 Series(Red)

Brother HL-1210W series

Brother HL-1210W series USB
```

### Endpoint

Representa el mecanismo mediante el cual una cola intenta alcanzar su destino.

Puede ser:

```text
USB
RAW / TCP
LPR
IPP
WSD
protocolo propietario
```

El endpoint contiene la información operacional necesaria para seleccionar
una estrategia de reachability.

### Dispositivo físico

Representa la impresora física real.

La correlación entre diferentes colas y un mismo dispositivo físico es una
capacidad futura y no es necesaria para resolver todos los casos actuales.

Por ello:

```text
QueueContext
      |
      v
Endpoint
```

es obligatorio para la operación actual, mientras que:

```text
PrinterIdentity
```

es una capa opcional que podrá incorporarse cuando sea necesario correlacionar
múltiples endpoints pertenecientes al mismo hardware.

---

## 42. PrinterEndpointResolver

`PrinterEndpointResolver.ps1` introduce una capa explícita entre la cola
Windows y los analizadores de conectividad.

Su responsabilidad es responder:

```text
¿Cómo intenta imprimir realmente esta cola?
```

El resolver no decide si debe cambiarse una red.

Tampoco decide si la impresora está disponible.

Su función es normalizar la información observada en Windows y producir un
endpoint operacional.

Entre los campos relevantes se encuentran conceptualmente:

```text
Transport
Protocol
Destination
DestinationType
TcpPort
QueueName
ReachabilityStrategy
DiscoverySource
Confidence
```

Esto permite que los componentes posteriores trabajen sobre una
representación común independientemente del fabricante.

---

## 43. Evidencia Epson: LPR TCP 515

La evolución endpoint-aware permitió identificar una diferencia importante
respecto de la arquitectura Alpha.

Durante Alpha:

```text
TCP 9100
```

fue utilizado exitosamente como evidencia de liveness de la Epson L365.

Ese resultado sigue siendo válido como evidencia experimental histórica.

Sin embargo, la inspección posterior del puerto configurado por EpsonNet
demostró que la cola:

```text
L365 Series(Red)
```

utiliza operacionalmente:

```text
Transport       = NETWORK
Protocol        = LPR
Destination     = 192.168.1.108
TcpPort         = 515
QueueName       = ENPQueue
Reachability    = LPR_TCP
```

Por lo tanto:

```text
TCP 9100
```

no debe considerarse universalmente equivalente al servicio de impresión
configurado por una cola.

Puede continuar utilizándose como señal diagnóstica cuando corresponda, pero
la decisión operacional debe utilizar el endpoint descubierto.

---

## 44. PrinterEndpointReachability

`PrinterEndpointReachability.ps1` evalúa la disponibilidad utilizando la
estrategia definida por el endpoint.

El contrato normalizado utiliza tres estados:

```text
REACHABLE
UNREACHABLE
UNKNOWN
```

La distinción es importante.

```text
REACHABLE
```

indica evidencia positiva de disponibilidad.

```text
UNREACHABLE
```

indica que el endpoint pudo ser evaluado pero no respondió según la estrategia
correspondiente.

```text
UNKNOWN
```

indica que no existe evidencia suficiente para realizar una afirmación segura.

La arquitectura evita convertir automáticamente `UNKNOWN` en una autorización
para modificar conectividad.

---

## 45. Reachability dependiente del transporte

La estrategia de reachability ya no debe asumir que toda impresora es un host
TCP.

Para endpoints de red pueden utilizarse:

```text
destino resuelto
+
puerto operacional
```

Por ejemplo:

```text
192.168.1.108:515
```

para la Epson L365 configurada mediante LPR.

Para USB, la estrategia es diferente.

La presencia del dispositivo puede verificarse mediante la identidad PnP
asociada a la cola.

Por lo tanto:

```text
NETWORK
   |
   +--> reachability de servicio

USB
   |
   +--> presencia del dispositivo
```

son estrategias diferentes dentro del mismo modelo de endpoint.

---

## 46. OperationalTargetIP y OperationalTcpPort

El Orchestrator separa actualmente el destino configurado o descubierto del
destino operacional utilizado durante el análisis.

Los campos centrales son:

```text
OperationalTargetIP
OperationalTcpPort
```

Para una cola de red normal, estos valores provienen del endpoint resuelto.

Cuando existe un `TargetIP` explícito proporcionado al Orchestrator, ese valor
tiene precedencia como destino operacional.

La precedencia validada es:

```text
TargetIP explícito
        |
        +--> sí --> OperationalTargetIP = TargetIP
        |
        +--> no --> OperationalTargetIP = destino resuelto del endpoint
```

El puerto operacional continúa derivándose del endpoint:

```text
OperationalTcpPort = Endpoint.TcpPort
```

Esto permite mantener separadas:

```text
evidencia de discovery
```

y:

```text
decisión operacional
```

sin alterar retroactivamente lo observado en la configuración de Windows.

---

## 47. InterfacePathAnalyzer y RouteAnalyzer endpoint-aware

`InterfacePathAnalyzer.ps1` y `RouteAnalyzer.ps1` dejaron de depender
operacionalmente de un TCP 9100 implícito.

Ambos pueden recibir:

```text
OperationalTargetIP
OperationalTcpPort
```

y analizar el servicio correspondiente al endpoint real.

Esto permite distinguir entre:

```text
camino existente y alcanzable
camino existente pero servicio no alcanzable
ruta disponible sin camino directo
múltiples caminos alcanzables
```

sin asumir un protocolo de impresión único.

Una propiedad de seguridad se mantiene:

> Si existe un camino válido y alcanzable hacia el endpoint, PrintSwitch no
> debe modificar la conectividad.

---

## 48. Separación entre Discovery y Policy

La arquitectura actual separa dos tipos de información que anteriormente
convivían en `config/printers.json`.

### Discovery

Describe lo que Windows y el sistema permiten observar.

Ejemplos:

```text
nombre de cola
driver
puerto
monitor
transporte
protocolo
destino
puerto TCP
identidad USB
```

`PrinterDiscovery.ps1` construye esta información automáticamente.

El archivo:

```text
config/discovery.json
```

puede utilizarse como snapshot o cache regenerable.

No constituye la fuente primaria de verdad.

### Policy

Describe intención del usuario o autorización de comportamiento.

Ejemplo:

```text
la cola Epson puede utilizar suarezcores
como red de recuperación Wi-Fi
```

Esta información pertenece a:

```text
config/policy.json
```

La separación conceptual es:

```text
Discovery
   =
lo que existe

Policy
   =
lo que PrintSwitch está autorizado a hacer
```

La ausencia de una policy para una cola no significa que la cola sea
desconocida ni inválida.

Significa que no existe una autorización especial asociada a ella.

---

## 49. Estado de config/printers.json

`config/printers.json` se conserva temporalmente por compatibilidad con
componentes Alpha.

No representa el modelo arquitectónico objetivo.

Su función actual es legacy y no debe utilizarse para concluir que una cola
necesita un perfil PrintSwitch para ser descubierta.

La transición es:

```text
ANTES

config/printers.json
        |
        +--> identidad
        +--> IP
        +--> SSID requerido


ACTUAL

Windows / Registry / PnP
        |
        v
PrinterDiscovery
        |
        v
QueueContext / Endpoint


config/policy.json
        |
        v
autorización de recuperación
```

La eliminación definitiva de `printers.json` sólo deberá realizarse cuando
ningún componente vigente dependa de él.

---

## 50. ConnectivityAnalyzer pasa a diagnóstico opcional

Durante Alpha, `ConnectivityAnalyzer.ps1` formaba parte del flujo utilizado
para caracterizar el estado de conectividad.

En la arquitectura vigente continúa siendo útil como fuente diagnóstica y de
telemetría, pero dejó de ser una autoridad obligatoria para determinar el
éxito operacional de una recuperación.

El Orchestrator puede completar una recuperación incluso si
`ConnectivityAnalyzer.ps1` no está disponible.

Los estados diagnósticos contemplados incluyen:

```text
clasificación real del analyzer
NOT_AVAILABLE
NO_RESULT
DIAGNOSTIC_ERROR
```

Ninguno de estos estados reemplaza la validación operacional del endpoint.

El éxito de recovery se determina mediante evidencia operacional:

```text
NetworkSwitchVerified
        +
RecoveryValidator.RecoveryConfirmed
        +
RouteAfter.TargetReachable
```

Esto fue validado experimentalmente ejecutando una recuperación completa con
`ConnectivityAnalyzer.ps1` temporalmente ausente.

El resultado fue:

```text
ConnectivityAfter   = NOT_AVAILABLE
RecoverySucceeded   = True
FinalClassification = CONTEXTUAL_RECOVERY_SUCCESS
```

Por lo tanto:

> Un diagnóstico auxiliar puede enriquecer la observabilidad sin convertirse
> en una dependencia del mecanismo que intenta observar.

---

## 51. Semántica explícita de preservación Ethernet

La preservación de Ethernet continúa siendo una propiedad de seguridad del
sistema.

PrintSwitch no modifica interfaces Ethernet durante una recuperación Wi-Fi.

La semántica de validación fue refinada para distinguir tres situaciones:

```text
No existía Ethernet activa antes
    EthernetPreserved = null
    EthernetPreservationStatus = NOT_APPLICABLE

Existía Ethernet activa y continúa activa
    EthernetPreserved = True
    EthernetPreservationStatus = PRESERVED

Existía Ethernet activa y dejó de estar disponible
    EthernetPreserved = False
    EthernetPreservationStatus = FAILED
```

Esto evita interpretar:

```text
no había Ethernet
```

como:

```text
falló la preservación de Ethernet
```

---

## 52. Contrato de -Execute

El parámetro:

```text
-Execute
```

no significa:

```text
forzar cambio de Wi-Fi
```

Significa:

```text
autorizar acciones reales si el motor determina que son necesarias
```

Por ello, incluso con `-Execute`, si el endpoint ya es alcanzable:

```text
SwitchAuthorized = False
SwitchExecuted   = False
```

La existencia de permiso para actuar no reemplaza la decisión contextual.

---

## 53. Recuperación endpoint-aware validada

La recuperación completa fue nuevamente validada utilizando el endpoint real
de la Epson.

Condiciones iniciales:

```text
Ethernet desconectado
Wi-Fi = Claro640
Epson L365 encendida
suarezcores conocido y visible
Endpoint = 192.168.1.108:515
```

Estado inicial:

```text
EndpointReachability = UNREACHABLE
InterfacePathAnalyzer = ROUTED_PATH_ONLY
RouteAnalyzer = TARGET_ROUTE_EXISTS_BUT_UNREACHABLE
```

La policy autorizó evaluar recuperación Wi-Fi.

El flujo continuó:

```text
WiFiCandidateEvaluator
        |
        v
SwitchDecision
        |
        v
SWITCH_WIFI_FOR_PRINTER
        |
        v
NetworkManager
        |
        v
Claro640 -> suarezcores
        |
        v
RecoveryValidator
        |
        v
192.168.1.108:515 alcanzable
```

Resultado:

```text
NetworkSwitchVerified = True
RecoverySucceeded     = True
FinalClassification   = CONTEXTUAL_RECOVERY_SUCCESS
```

La prueba demuestra que la recuperación ya no depende del TCP 9100 utilizado
como señal durante Alpha.

Utiliza el endpoint operacional descubierto para la cola.

---

## 54. Regresión de camino Ethernet existente

También se validó el caso:

```text
Ethernet = 192.168.1.109
Wi-Fi = Claro640
Epson = encendida
Endpoint = 192.168.1.108:515
```

El endpoint era alcanzable mediante Ethernet.

El sistema clasificó:

```text
UNIQUE_REACHABLE_PATH
```

y finalizó:

```text
FinalClassification = EXISTING_REACHABLE_PATH
SwitchAuthorized     = False
SwitchExecuted       = False
```

La misma conducta se mantuvo incluso ejecutando el Orchestrator con:

```text
-Execute
```

Esto valida nuevamente el principio:

> Una ruta funcional existente tiene prioridad sobre cualquier recuperación
> mediante cambio de Wi-Fi.

---

## 55. Arquitectura operacional vigente

Al cierre de este checkpoint, la arquitectura puede representarse así:

```text
Windows / Registry / PnP / Spooler
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
             Endpoint
                |
                v
  PrinterEndpointReachability
                |
                v
      +-------------------+
      |                   |
      v                   v
InterfacePathAnalyzer  RouteAnalyzer
      |                   |
      +---------+---------+
                |
                v
        ¿ya es alcanzable?
          |            |
         sí            no
          |            |
          v            v
      NO_ACTION   RecoveryPolicy
                       |
                       v
              ¿Wi-Fi autorizado?
                  |         |
                 no        sí
                  |         |
                  v         v
            NO_WIFI_ACTION
                            |
                            v
                 WiFiCandidateEvaluator
                            |
                            v
                      SwitchDecision
                            |
                            v
                      NetworkManager
                            |
                            v
                    RecoveryValidator
                            |
                            v
                       RouteAfter
                            |
                            v
                   resultado operacional

ConnectivityAnalyzer
        |
        +--> diagnóstico opcional
```

La regla central continúa siendo intervención mínima.

La diferencia respecto del Alpha es que ahora esa decisión se construye sobre
la cola y su endpoint real, no sobre una asociación rígida entre impresora,
IP y TCP 9100.

---

## 56. Estado del checkpoint — Septiembre 2026

A la fecha de este checkpoint se consideran alcanzados:

```text
[OK] resolución de endpoint por cola
[OK] reachability dependiente del transporte
[OK] Epson L365 identificada operacionalmente como LPR / TCP 515
[OK] analizadores de caminos endpoint-aware
[OK] separación entre discovery y policy
[OK] policy opcional
[OK] TargetIP explícito con precedencia operacional
[OK] OperationalTargetIP / OperationalTcpPort
[OK] semántica Ethernet PRESERVED / FAILED / NOT_APPLICABLE
[OK] ConnectivityAnalyzer convertido en diagnóstico opcional
[OK] recovery Epson real Claro640 -> suarezcores mediante LPR / 515
[OK] regresión de no intervención cuando Ethernet ya alcanza la Epson
```

El estado de referencia del código es:

```text
commit 55316dd
FEAT: consolida recovery operacional y diagnostico opcional
```

El siguiente objetivo formal es validar una segunda impresora dentro del mismo
modelo arquitectónico, sin introducir excepciones específicas por fabricante.

La candidata de validación es:

```text
Brother HL-1212W
```

expuesta actualmente en Windows mediante colas de red y USB.

Esa validación pertenece a la etapa siguiente y no se considera completada en
este checkpoint.