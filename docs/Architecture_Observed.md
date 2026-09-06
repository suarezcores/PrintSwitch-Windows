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


---

# Actualización de arquitectura — Cierre de Puntos 3 a 5 y auditoría pre-Punto 6 — Septiembre 2026

> **Estado documental**
>
> Esta sección continúa la actualización arquitectónica iniciada en Septiembre
> de 2026.
>
> Todo el contenido anterior se conserva como registro histórico de las etapas
> en las que fue escrito.
>
> En particular, las descripciones Alpha basadas en TCP 9100, configuración
> manual mediante `printers.json` y componentes experimentales anteriores no se
> reescriben retroactivamente.
>
> Esta nueva sección documenta el estado alcanzado después de:
>
> ```text
> Punto 3 — Validación Brother
> Punto 4 — Consolidación Discovery + Policy
> Punto 5 — Integración QueueWatcher
> Auditoría técnica pre-Punto 6
> ```
>
> Los checkpoints principales de código correspondientes a esta evolución son:
>
> ```text
> bbe5c4c
> FEAT: integra QueueWatcher con discovery y recovery operacional
>
> 4730803
> REFACTOR: desacopla diagnostico de configuracion legacy
> ```

---

## 57. Validación de una segunda impresora

El Punto 3 utilizó una segunda impresora física para comprobar si la
arquitectura endpoint-aware podía operar fuera del caso Epson.

El equipo físico posee identificación comercial:

```text
Brother HL-1212W
```

mientras que Windows, el driver y el software Brother exponen la familia
mediante:

```text
Brother HL-1210W series
```

Esta diferencia de nomenclatura no fue tratada mediante una excepción de
fabricante.

PrintSwitch operó sobre las colas que Windows expone realmente.

Se observaron:

```text
Brother HL-1210W series
Brother HL-1210W series USB
```

Estas dos colas representan mecanismos de acceso distintos al mismo equipo
físico.

La primera utiliza un endpoint de red.

La segunda utiliza un endpoint USB.

La validación permitió comprobar una idea importante:

> La unidad operacional de PrintSwitch no debe ser el nombre comercial escrito
> en la carcasa del dispositivo sino la cola de impresión y el endpoint que
> Windows utiliza realmente.

---

## 58. Brother Network

La cola de red fue descubierta como:

```text
QueueName             = Brother HL-1210W series
DriverName            = Brother HL-1210W series
PortName              = BRWC48E8F7B140F
TransportType         = NETWORK
Protocol              = LPR
ConfiguredDestination = BRWC48E8F7B140F
AddressType           = HOSTNAME
TcpPort               = 515
ServiceQueue          = BINARY_P1
ReachabilityStrategy  = LPR_TCP
DiscoverySource       = WINDOWS_PRINTER_PORT
Confidence            = HIGH
```

La información anterior fue obtenida desde la configuración real que Windows
mantiene para la cola.

No fue necesario introducir manualmente:

```text
IP de la Brother
puerto de impresión
protocolo
```

en el core operacional.

### 58.1. Resolución del hostname

En la red donde la impresora estaba disponible, Windows resolvió:

```text
BRWC48E8F7B140F
        |
        v
192.168.100.12
```

El endpoint operacional respondió correctamente mediante:

```text
TCP 515
```

y la prueba produjo:

```text
ReachabilityState = REACHABLE
ProbeResult       = TCP_CONNECTION_SUCCEEDED
```

### 58.2. Consecuencia arquitectónica

La validación demuestra que un endpoint de red no necesita estar representado
mediante una dirección IPv4 literal.

La arquitectura puede operar sobre:

```text
hostname
   |
   v
resolución
   |
   v
dirección operacional
   |
   v
servicio TCP
```

sin incorporar una condición específica para Brother.

Esto amplía el modelo previamente validado con la Epson:

```text
Epson
ConfiguredDestination = IPv4

Brother
ConfiguredDestination = HOSTNAME
```

ambos interpretados mediante el mismo modelo general de endpoint.

---

## 59. Brother USB

La segunda cola Brother permitió validar un transporte completamente diferente
de los endpoints de red.

La cola fue descubierta como:

```text
QueueName             = Brother HL-1210W series USB
DriverName            = Brother HL-1210W series
PortName              = USB001
TransportType         = USB
Protocol              = USB
ConfiguredDestination = USB001
AddressType           = DEVICE
ReachabilityStrategy  = USB_PRESENCE
DiscoverySource       = WINDOWS_PRINTING
Confidence            = HIGH
```

No existe en este caso:

```text
TargetIP
TcpPort
SSID requerido
```

porque esas propiedades no pertenecen al transporte utilizado por la cola.

### 59.1. USB conectado

Con el cable USB conectado y el dispositivo encendido, la estrategia
`USB_PRESENCE` produjo:

```text
ResolvedDestination =
USBPRINT\BROTHERHL-1210W_SERIES\...\USB001

Reachable         = True
ReachabilityState = REACHABLE
ProbeResult       = USB_DEVICE_PRESENT
```

El Orchestrator reconoció que se encontraba ante un endpoint USB y no ejecutó
análisis IP ni recuperación Wi-Fi.

Resultado:

```text
SwitchDecision      = NO_WIFI_ACTION
SwitchAuthorized    = False
SwitchExecuted      = False
FinalClassification = USB_ENDPOINT_REACHABLE
```

### 59.2. USB desconectado

Después de retirar físicamente el cable USB, la misma cola continuó existiendo
en Windows.

Sin embargo, la estrategia de reachability produjo:

```text
Reachable         = False
ReachabilityState = UNREACHABLE
ProbeResult       = USB_DEVICE_NOT_PRESENT
```

El Orchestrator volvió a evitar cualquier intento de recuperación inalámbrica.

Resultado:

```text
SwitchDecision      = NO_WIFI_ACTION
SwitchAuthorized    = False
SwitchExecuted      = False
FinalClassification = USB_ENDPOINT_UNREACHABLE
```

### 59.3. Consecuencia arquitectónica

La ausencia de una impresora USB no constituye evidencia de un problema de red.

Por lo tanto:

```text
USB conectado
      |
      v
endpoint disponible
      |
      v
NO_WIFI_ACTION
```

y:

```text
USB desconectado
      |
      v
endpoint local no disponible
      |
      v
NO_WIFI_ACTION
```

La estrategia de recuperación debe depender del transporte observado y no de
una regla global aplicada indiscriminadamente a cualquier cola.

---

## 60. UNKNOWN continúa siendo un estado seguro

Durante la validación Brother se observó un escenario donde la cola de red
utilizaba:

```text
BRWC48E8F7B140F
```

pero el hostname no podía resolverse desde otra red Wi-Fi.

El endpoint no podía considerarse:

```text
REACHABLE
```

pero tampoco existía evidencia suficiente para afirmar:

```text
UNREACHABLE
```

La clasificación obtenida fue:

```text
ReachabilityState = UNKNOWN
ProbeResult       = DESTINATION_RESOLUTION_FAILED
```

El Orchestrator respondió:

```text
SwitchDecision =
NO_ACTION_INSUFFICIENT_ENDPOINT_EVIDENCE

SwitchAuthorized = False
SwitchExecuted   = False

FinalClassification =
NETWORK_DESTINATION_UNRESOLVED
```

La red Wi-Fi no fue modificada.

Posteriormente, al regresar al contexto donde Windows podía resolver el
hostname, el mismo endpoint volvió a producir:

```text
ResolvedDestination = 192.168.100.12
ReachabilityState   = REACHABLE
ProbeResult         = TCP_CONNECTION_SUCCEEDED
```

Esto confirma experimentalmente:

```text
UNKNOWN
   !=
UNREACHABLE
```

y también:

```text
falta de evidencia
   !=
autorización para intervenir
```

La arquitectura debe degradarse hacia un comportamiento seguro cuando el
conocimiento disponible no alcanza para justificar una acción.

---

## 61. Punto 3 cerrado — abstracción multimarca y multitransporte

La validación Brother permitió utilizar el mismo modelo con tres endpoints
diferentes:

```text
Epson L365
    |
    +--> NETWORK
         IPV4
         LPR / TCP 515


Brother HL-1210W series
    |
    +--> NETWORK
         HOSTNAME
         LPR / TCP 515


Brother HL-1210W series USB
    |
    +--> USB
         DEVICE
         USB_PRESENCE
```

No fue necesario implementar:

```text
if Epson ...
if Brother ...
```

La abstracción efectiva continúa siendo:

```text
QueueContext
      |
      v
Endpoint
      |
      v
ReachabilityStrategy
```

Esto permite que las diferencias reales aparezcan como propiedades del
endpoint y no como excepciones codificadas por fabricante.

El Punto 3 se considera completado.

---

## 62. Punto 4 — Discovery pasa a ser la fuente operacional de colas

Durante el Punto 4 se revisó la relación entre:

```text
Discovery
Policy
configuración legacy
QueueWatcher
```

El objetivo fue eliminar duplicaciones entre lo que Windows conoce sobre las
colas y lo que PrintSwitch mantenía manualmente en archivos de configuración.

`PrinterDiscovery.ps1` produce actualmente objetos:

```text
QueueContext
```

utilizando información observada desde Windows y delegando la interpretación
del endpoint a:

```text
PrinterEndpointResolver.ps1
```

El `QueueContext` normalizado contiene, entre otros:

```text
QueueName
DriverName
PortName
Default
PrinterStatus
WorkOffline
JobCount
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
EndpointEvidence
```

La presencia de una cola y su endpoint dejan de definirse mediante inventario
manual.

La secuencia operacional pasa a ser:

```text
Windows
   |
   v
PrinterDiscovery
   |
   v
QueueContext
   |
   v
PrinterEndpointResolver
```

---

## 63. QueueWatcher integrado con PrinterDiscovery

`QueueWatcher.ps1` evolucionó para utilizar:

```text
Windows
   |
   v
PrinterDiscovery
   |
   v
QueueContext
```

como fuente operacional de las colas físicas.

El watcher ya no utiliza:

```text
ConfigValidator
config/printers.json
```

para determinar qué impresora debe observar.

Cuando el usuario especifica:

```text
-PrinterName
```

QueueWatcher busca esa cola dentro del discovery realizado sobre Windows.

Si sólo existe una cola física candidata, puede seleccionarse directamente.

Si existen varias y el usuario no indicó cuál observar, el sistema evita
elegir arbitrariamente.

La regla resultante es:

> Descubrir automáticamente no significa adivinar silenciosamente cuando la
> selección es ambigua.

El cambio quedó integrado en:

```text
QueueWatcher v0.7
```

y consolidado posteriormente mediante el checkpoint:

```text
bbe5c4c
FEAT: integra QueueWatcher con discovery y recovery operacional
```

---

## 64. Separación consolidada entre Discovery y Policy

Después del Punto 4 la arquitectura diferencia explícitamente dos preguntas.

### 64.1. Discovery

```text
¿Qué existe?
¿Cómo intenta Windows alcanzarlo?
```

Esta información proviene principalmente de:

```text
Windows Printing
PrinterDiscovery
PrinterEndpointResolver
PrinterEndpointReachability
```

Incluye:

```text
cola
driver
puerto
monitor
transporte
protocolo
destino
puerto TCP
servicio LPR
identidad USB
```

### 64.2. Policy

```text
¿Qué está autorizado a hacer PrintSwitch?
```

Esta información pertenece a:

```text
config/policy.json
```

Por ejemplo:

```text
la Epson existe
        |
        v
DISCOVERY
```

mientras:

```text
si necesita recuperación Wi-Fi
puede utilizar suarezcores
        |
        v
POLICY
```

La existencia de un dispositivo no debe confundirse con la intención del
usuario respecto de qué acciones pueden ejecutarse.

---

## 65. Estado de `printers.json` después del Punto 4

Durante las primeras etapas:

```text
config/printers.json
```

combinaba información de distinta naturaleza:

```text
identidad
IP
SSID
configuración
```

Después de la evolución Discovery + Policy, este archivo deja de ser la fuente
operacional del core moderno.

Se conserva porque forma parte del desarrollo histórico y todavía puede ser
utilizado por herramientas legacy o experimentales.

La arquitectura distingue:

```text
CORE MODERNO

Windows
PrinterDiscovery
PrinterEndpointResolver
PrinterEndpointReachability
policy.json
```

de:

```text
LEGACY / EXPERIMENTAL

printers.json
ConfigValidator
ProfileAnalyzer
PerformanceAnalyzer
ContextualRecoveryTest
```

La presencia de `printers.json` en el repositorio no significa que represente
la fuente de verdad del pipeline operacional vigente.

---

## 66. Punto 5 — QueueWatcher completa el camino operacional

El Punto 5 integró la detección real de trabajos con el pipeline endpoint-aware.

El flujo completo queda:

```text
trabajo de impresión
        |
        v
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
PrintRecoveryOrchestrator
        |
        v
PrinterEndpointResolver
        |
        v
PrinterEndpointReachability
        |
        v
InterfacePathAnalyzer
        |
        v
RouteAnalyzer
        |
        v
ConnectivityPolicy
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
resultado operacional
```

`ConnectivityAnalyzer` participa como diagnóstico adicional y no como autoridad
sobre el resultado de la recuperación.

---

## 67. Recovery real iniciado por un trabajo de impresión

Se validó físicamente:

```text
Wi-Fi inicial = Claro640
Ethernet      = desconectado
Epson L365    = encendida
SSID objetivo = suarezcores
Endpoint      = 192.168.1.108:515
Recovery      = habilitado
```

QueueWatcher se ejecutó mediante:

```text
-PrinterName "L365 Series(Red)"
-EnableRecovery
```

Un trabajo real ingresó a la cola.

QueueWatcher detectó el trabajo y delegó la recuperación al Orchestrator.

Inicialmente:

```text
192.168.1.108:515
        |
        v
UNREACHABLE
```

No existía un camino funcional hacia el endpoint.

La policy permitió evaluar recuperación Wi-Fi.

La secuencia observada fue:

```text
EVALUATE_WIFI_RECOVERY
        |
        v
WIFI_SWITCH_CANDIDATE_AVAILABLE
        |
        v
SWITCH_WIFI_FOR_PRINTER
```

`NetworkManager` ejecutó:

```text
Claro640
   |
   v
suarezcores
```

y verificó:

```text
InitialSSID    = Claro640
FinalSSID      = suarezcores
SwitchVerified = True
```

Posteriormente `RecoveryValidator` confirmó nuevamente el endpoint operacional:

```text
192.168.1.108:515
```

El resultado final incluyó:

```text
NetworkSwitchVerified        = True
RecoveryValidationConfirmed  = True
RouteAfter                   = TARGET_REACHABLE_VIA_WIFI
RecoverySucceeded            = True
RecoveryConfirmed            = True
SwitchExecuted               = True
FinalClassification          = CONTEXTUAL_RECOVERY_SUCCESS
```

Finalmente, una comprobación externa confirmó:

```text
RemotePort       = 515
TcpTestSucceeded = True
```

La PC quedó conectada a:

```text
suarezcores
```

Este escenario demuestra la integración real:

```text
trabajo
   |
   v
detección
   |
   v
discovery
   |
   v
endpoint
   |
   v
decisión
   |
   v
acción
   |
   v
validación
```

sin intervención manual entre etapas.

---

## 68. No intervención con recovery habilitado

Se ejecutó también la contraprueba:

```text
Wi-Fi inicial = suarezcores
Ethernet      = desconectado
Epson L365    = encendida
Endpoint      = 192.168.1.108:515
Recovery      = habilitado
```

Un trabajo real fue detectado por QueueWatcher y atravesó nuevamente el
Orchestrator.

La diferencia fue que el endpoint ya era alcanzable.

El análisis produjo:

```text
UNIQUE_REACHABLE_PATH
```

y el resultado operacional fue:

```text
EXISTING_REACHABLE_PATH
```

con:

```text
SwitchDecision   = NO_ACTION
SwitchAuthorized = False
SwitchExecuted   = False
```

La red Wi-Fi permaneció sin cambios.

Esta prueba confirma una propiedad central:

> `-EnableRecovery` otorga permiso para actuar cuando corresponda.
>
> No constituye una orden de modificar conectividad.

Por lo tanto:

```text
permiso
   !=
acción obligatoria
```

La decisión continúa subordinada a la evidencia.

---

## 69. Cierre del Punto 5

Los dos experimentos anteriores validan las dos ramas fundamentales del flujo
integrado.

### 69.1. Intervención necesaria

```text
trabajo real
   |
   v
endpoint inaccesible
   |
   v
no existe camino funcional
   |
   v
policy permite recuperación
   |
   v
cambio Wi-Fi
   |
   v
endpoint recuperado
   |
   v
CONTEXTUAL_RECOVERY_SUCCESS
```

### 69.2. Intervención innecesaria

```text
trabajo real
   |
   v
endpoint alcanzable
   |
   v
camino funcional existente
   |
   v
NO_ACTION
```

El Punto 5 se considera completado.

El checkpoint correspondiente es:

```text
bbe5c4c
FEAT: integra QueueWatcher con discovery y recovery operacional
```

---

## 70. Auditoría técnica previa al Punto 6

Antes de comenzar la batería de regresión y casos excepcionales se realizó una
auditoría específica del sistema.

El objetivo fue comprobar que la arquitectura declarada coincidiera con las
dependencias reales del código.

Se revisaron:

```text
componentes
configuraciones
dependencias
consumidores
contratos
versiones
referencias legacy
fuentes de verdad
parser
integraciones
```

La auditoría permitió descubrir una dependencia residual importante.

---

## 71. Hallazgo — ConnectivityAnalyzer continuaba dependiendo de configuración legacy

`ConnectivityAnalyzer v0.5` todavía cargaba:

```text
config/printers.json
```

y obtenía desde allí:

```text
PrinterName
PrinterIP
RequiredSSID
```

Además realizaba pruebas generales sobre:

```text
ICMP
TCP 9100
TCP 80
```

y podía producir:

```text
NETWORK_MISMATCH
```

comparando el SSID actual con el SSID configurado.

Este modelo pertenecía correctamente a una etapa anterior del proyecto.

Sin embargo, después de introducir:

```text
PrinterDiscovery
PrinterEndpointResolver
OperationalTargetIP
OperationalTcpPort
```

esa dependencia se volvió redundante y conceptualmente incorrecta.

El Analyzer estaba intentando redescubrir mediante configuración manual un
endpoint que el pipeline operacional ya conocía.

---

## 72. ConnectivityAnalyzer v0.6

La auditoría produjo:

```text
ConnectivityAnalyzer v0.6
```

El nuevo contrato de entrada es:

```text
PrinterName
TargetIP
TcpPort
```

El Analyzer ya no:

```text
carga printers.json
descubre el endpoint
decide policy
decide si el SSID actual es correcto
asume TCP 9100
asume TCP 80
```

La evidencia operacional primaria pasa a ser:

```text
TargetIP:TcpPort
```

ICMP puede conservarse únicamente como evidencia diagnóstica auxiliar.

La clasificación principal queda:

```text
PRINTER_REACHABLE
PRINTER_UNREACHABLE
```

según el servicio TCP operacional recibido por el componente.

La responsabilidad queda reducida a:

> Diagnosticar conectividad hacia un endpoint que ya fue resuelto por otra
> capa.

---

## 73. Diagnóstico no equivale a descubrimiento

La nueva separación establece:

```text
PrinterEndpointResolver
        |
        v
define endpoint
```

mientras:

```text
ConnectivityAnalyzer
        |
        v
diagnostica endpoint recibido
```

Por lo tanto:

```text
Discovery
   !=
Diagnosis
```

El Orchestrator pasó a invocar al Analyzer mediante:

```text
-PrinterName $PrinterName
-TargetIP    $OperationalTargetIP
-TcpPort     $OperationalTcpPort
```

`ConfigPath` fue eliminado del contrato del Orchestrator porque dejó de ser
necesario para el pipeline operacional moderno.

`ContextualRecoveryTest.ps1`, aunque se conserva como herramienta experimental,
también fue adaptado para obtener su endpoint mediante:

```text
PrinterEndpointResolver
```

y dejar de asumir:

```text
TCP 515
```

de forma fija.

---

## 74. Regresión del diagnóstico endpoint-aware

Después del refactor se realizaron dos comprobaciones físicas.

### 74.1. Epson L365

El Resolver produjo:

```text
QueueName             = L365 Series(Red)
TransportType         = NETWORK
Protocol              = LPR
ConfiguredDestination = 192.168.1.108
TcpPort               = 515
ReachabilityStrategy  = LPR_TCP
```

`ConnectivityAnalyzer v0.6` recibió:

```text
TargetIP = 192.168.1.108
TcpPort  = 515
```

y obtuvo:

```text
PingSucceeded           = True
OperationalTcpSucceeded = True
Classification          = PRINTER_REACHABLE
```

### 74.2. Brother Network

El Resolver produjo:

```text
QueueName             = Brother HL-1210W series
TransportType         = NETWORK
Protocol              = LPR
ConfiguredDestination = BRWC48E8F7B140F
AddressType           = HOSTNAME
TcpPort               = 515
ServiceQueue          = BINARY_P1
```

La resolución del hostname produjo:

```text
192.168.100.12
```

`ConnectivityAnalyzer v0.6` recibió:

```text
TargetIP = 192.168.100.12
TcpPort  = 515
```

y obtuvo:

```text
PingSucceeded           = True
OperationalTcpSucceeded = True
Classification          = PRINTER_REACHABLE
```

La segunda prueba es especialmente relevante porque confirma que el nuevo
contrato no fue construido como una excepción para Epson.

---

## 75. Limpieza final del core moderno

Después del refactor se realizó una inspección final.

No quedaron referencias operacionales a:

```text
RequiredSSID
NETWORK_MISMATCH
Tcp9100
Tcp80
TcpPort 515 hardcodeado
```

dentro de `ConnectivityAnalyzer`.

También se eliminó:

```text
ConfigPath
```

del contrato de `PrintRecoveryOrchestrator`.

En el core moderno, `printers.json` ya no constituye una dependencia
operacional.

La única referencia explícita conservada en QueueWatcher es documental:

```text
elimina la dependencia operacional de config/printers.json
```

Las herramientas históricas que aún utilizan ese archivo permanecen
preservadas como parte de etapas anteriores del proyecto.

Todos los scripts PowerShell de:

```text
src
scripts
```

fueron sometidos al parser y no presentaron errores sintácticos.

---

## 76. Arquitectura operacional vigente antes del Punto 6

La arquitectura consolidada puede representarse como:

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

Las responsabilidades quedan distribuidas así:

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

EVALUAR ALTERNATIVA
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

La regla general continúa siendo:

> Ninguna capa debe asumir una responsabilidad que ya pertenece a otra.

---

## 77. Estado del roadmap al cierre documental pre-Punto 6

El roadmap arquitectónico queda:

```text
[COMPLETADO] 1. Cierre endpoint-aware

[COMPLETADO] 2. Consolidación de inconsistencias

[COMPLETADO] 3. Validación Brother

[COMPLETADO] 4. Consolidar Discovery + Policy

[COMPLETADO] 5. Integración QueueWatcher

[ACTUAL]      6. Regresiones y casos excepcionales

[POSTERIOR]   7. Aplicación / UI

[FUTURO]      8. Multi-impresora / otros fabricantes
```

El Punto 6 no tiene como objetivo principal agregar funcionalidades nuevas.

Su objetivo será someter la arquitectura existente a condiciones:

```text
inusuales
ambiguas
contradictorias
degradadas
adversas
```

para intentar detectar supuestos todavía ocultos.

---

## 78. Baseline de regresión para el Punto 6

El checkpoint de referencia queda establecido en:

```text
commit 4730803
REFACTOR: desacopla diagnostico de configuracion legacy
```

Este baseline representa:

```text
Puntos 1 a 5 completados
        +
validación Epson
        +
validación Brother Network
        +
validación Brother USB
        +
Discovery integrado
        +
Policy separada
        +
QueueWatcher integrado
        +
recovery físico disparado por trabajo
        +
no intervención física validada
        +
auditoría de dependencias
        +
ConnectivityAnalyzer endpoint-aware
```

Cualquier modificación producida durante el Punto 6 deberá poder compararse
contra este estado.

La función del baseline es permitir distinguir:

```text
comportamiento ya validado
        |
        v
regresión introducida
```

de:

```text
supuesto arquitectónico previamente no descubierto
        |
        v
nuevo conocimiento
```

---

## 79. Criterio de entrada al Punto 6

Antes de ejecutar la primera prueba del Punto 6 deberán existir:

```text
arquitectura actual documentada
conocimiento actual documentado
roadmap actualizado
metodología de prueba definida
matriz de escenarios preparada
baseline Git identificado
```

Cada prueba deberá declarar explícitamente:

```text
Test ID

Objetivo

Configuración inicial
    Wi-Fi
    Ethernet
    Epson
    Brother
    USB
    SSID visibles
    Recovery

Hipótesis

Resultado esperado

Acción o estímulo

Resultado obtenido

Check real
    PASS
    FAIL

Observaciones

Corrección necesaria

Regresión posterior
```

La configuración física y de red deberá registrarse antes de ejecutar el caso,
no reconstruirse posteriormente de memoria.

---

## 80. Estado arquitectónico al inicio de la fase de regresión

A partir de este punto PrintSwitch deja de estar principalmente en una etapa de
construcción de arquitectura base.

El estado puede representarse como:

```text
arquitectura
    |
    v
integrada
    |
    v
validada con dos fabricantes
    |
    v
auditada
    |
    v
checkpoint
    |
    v
testing adverso
```

El objetivo inmediato pasa de:

```text
¿podemos construir este flujo?
```

a:

```text
¿qué sucede cuando sometemos este flujo
a situaciones que no fueron utilizadas
para diseñarlo?
```

El Punto 6 deberá responder esa pregunta antes de iniciar el desarrollo de una
interfaz de usuario o declarar una primera beta funcional.

---

# Actualización arquitectónica — Cierre del Punto 6 — Septiembre 2026

> **Estado documental**
>
> Esta sección describe la arquitectura observada y validada después de la
> campaña experimental del Punto 6.
>
> El contenido anterior se conserva como registro histórico de las etapas
> Alpha, Post-Alpha y de preparación de la fase de regresión.
>
> La evidencia detallada de las pruebas se encuentra en:
>
> ```text
> Experimental_Tests.md
> ```
>
> Las conclusiones conceptuales derivadas de esa evidencia se consolidan en:
>
> ```text
> Knowledge.md
> ```

---

## 81. Arquitectura operativa observada después de P6

La arquitectura vigente puede representarse como:

```text
Windows Print Queue
        |
        v
QueueWatcher
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
ReachabilityStrategy
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
               diagnóstico opcional
```

El cambio respecto de etapas anteriores es que la recuperación ya no comienza
desde una asociación rígida:

```text
PrinterName
+
IP
+
SSID
```

sino desde:

```text
Queue
   |
   v
Endpoint
   |
   v
Operational Reachability
```

---

## 82. QueueContext es la representación operacional primaria de una cola

`PrinterDiscovery.ps1` construye actualmente objetos:

```text
QueueContext
```

que concentran información como:

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

Esta estructura permite que `QueueWatcher` seleccione una cola real y delegue
la decisión posterior sin depender de `config/printers.json` como fuente
operacional.

La cola continúa siendo el objeto que recibe el trabajo.

El endpoint representa cómo esa cola intenta alcanzar el dispositivo.

---

## 83. Endpoint y dispositivo físico permanecen desacoplados

P6 confirmó que una misma impresora física puede estar representada mediante
más de una cola.

Ejemplo Brother:

```text
Brother HL-1210W series
    |
    +--> NETWORK
         LPR
         HOSTNAME
         TCP 515

Brother HL-1210W series USB
    |
    +--> USB
         DEVICE
         USB_PRESENCE
```

Por tanto:

```text
PhysicalPrinter
```

no debe identificarse automáticamente con:

```text
Queue
```

ni con:

```text
Endpoint
```

La arquitectura mantiene esas entidades separadas.

---

## 84. ReachabilityStrategy pertenece al endpoint

La estrategia utilizada para comprobar disponibilidad depende del tipo de
endpoint.

Actualmente se observaron:

```text
NETWORK
    |
    +--> LPR_TCP

USB
    |
    +--> USB_PRESENCE
```

Esto evita aplicar universalmente:

```text
Ping
```

o:

```text
TCP 9100
```

a todas las colas.

La arquitectura actual selecciona la técnica de reachability a partir del
endpoint descubierto.

---

## 85. QueueState, ResolutionState y EndpointState son capas independientes

P6 produjo evidencia de que estas tres dimensiones pueden diferir
simultáneamente.

Ejemplo observado con Brother apagada:

```text
QueueState      = Normal
ResolutionState = RESOLVED
EndpointState   = UNREACHABLE
```

Por tanto, la arquitectura efectiva debe preservar:

```text
QueueState
    |
    +--> Windows Printing

ResolutionState
    |
    +--> Name Resolution

EndpointState
    |
    +--> ReachabilityStrategy
```

sin colapsarlas prematuramente en un único booleano.

---

## 86. El estado administrativo de Windows no es autoridad de liveness

P6-04 mostró:

```text
Epson OFF
PrinterStatus = Normal
WorkOffline   = False
TCP515        = False
```

y posteriormente:

```text
Epson ON
PrinterStatus = Normal
WorkOffline   = False
TCP515        = True
```

Por tanto, la arquitectura no debe utilizar:

```text
PrinterStatus
```

como sustituto de:

```text
EndpointReachability
```

Los estados Windows permanecen disponibles como contexto y observabilidad.

La autoridad operacional corresponde al endpoint.

---

## 87. ICMP queda fuera de la ruta de autoridad operacional

Tanto Epson como Brother produjeron escenarios:

```text
PingSucceeded    = False
TcpTestSucceeded = True
```

mientras el servicio de impresión estaba disponible.

Por tanto:

```text
ICMP
```

puede continuar formando parte de herramientas diagnósticas, pero no debe
gobernar la decisión principal de reachability.

La arquitectura vigente sigue:

```text
Endpoint
    |
    v
Operational Service Probe
```

---

## 88. Name Resolution no equivale a disponibilidad

La cola Brother utiliza:

```text
ConfiguredDestination = BRWC48E8F7B140F
AddressType           = HOSTNAME
```

El nombre puede continuar resolviendo:

```text
BRWC48E8F7B140F
    |
    v
192.168.100.12
```

aunque la impresora esté apagada.

Por tanto:

```text
Resolution success
```

es una fase intermedia de discovery y normalización.

No constituye evidencia suficiente de disponibilidad operacional.

La secuencia observada es:

```text
ConfiguredDestination
        |
        v
Address Resolution
        |
        v
Operational Address
        |
        v
Service Reachability
```

---

## 89. NetworkContext forma parte de la interpretación de reachability

P6-R01 validó simultáneamente:

```text
Epson   PhysicalState = ON
Brother PhysicalState = ON
```

desde:

```text
Wi-Fi    = Claro640
Ethernet = desconectado
```

con:

```text
Epson   = UNREACHABLE
Brother = REACHABLE
```

Por tanto, la arquitectura debe interpretar reachability como una relación:

```text
Source Context
      +
Endpoint
      +
Service
      +
Route
```

y no como una propiedad persistente del dispositivo.

---

## 90. RouteAnalyzer e InterfacePathAnalyzer responden preguntas diferentes

P6-02 volvió a mostrar un escenario donde Windows disponía de una ruta:

```text
0.0.0.0/0
via 192.168.100.1
```

hacia el destino Epson, pero:

```text
TCP515 = False
```

Esto produjo:

```text
ROUTED_PATH_ONLY
```

y:

```text
TARGET_ROUTE_EXISTS_BUT_UNREACHABLE
```

Por tanto:

```text
RouteAnalyzer
```

responde aproximadamente:

```text
¿qué ruta utilizaría Windows?
```

mientras:

```text
InterfacePathAnalyzer
```

y las sondas operacionales responden:

```text
¿existe realmente un camino funcional?
```

La arquitectura mantiene ambas dimensiones separadas.

---

## 91. La recuperación se ejecuta sólo después de descartar caminos funcionales

P6-01 y P6-02 validaron ambas ramas de decisión.

### Camino existente

```text
Ethernet
    |
    v
Epson 192.168.1.108:515
```

Resultado:

```text
EXISTING_REACHABLE_PATH
NO_ACTION
SwitchAuthorized = False
SwitchExecuted   = False
```

### Camino inexistente

```text
Wi-Fi = Claro640
Ethernet = desconectado
Endpoint Epson = UNREACHABLE
```

Resultado:

```text
EVALUATE_WIFI_RECOVERY
        |
        v
WIFI_SWITCH_CANDIDATE_AVAILABLE
        |
        v
SWITCH_WIFI_FOR_PRINTER
```

La arquitectura preserva primero lo que ya funciona.

---

## 92. SwitchDecision continúa siendo una barrera explícita de seguridad

La policy puede solicitar:

```text
EVALUATE_WIFI_RECOVERY
```

sin que eso implique automáticamente:

```text
ejecutar cambio Wi-Fi
```

`SwitchDecision` continúa evaluando si existe evidencia suficiente para
autorizar una acción.

P6-03 produjo:

```text
TARGET_WIFI_NOT_VISIBLE
```

y el resultado fue:

```text
SWITCH_NOT_SAFE
ShouldExecuteSwitch = False
```

La arquitectura demuestra así una separación clara entre:

```text
necesidad potencial de recovery
```

y:

```text
autorización final de ejecución
```

---

## 93. NetworkManager ejecuta, pero no decide la necesidad del cambio

`NetworkManager.ps1` permanece responsable de:

```text
solicitar conexión al SSID
verificar cambio de red
devolver resultado estructurado
```

pero la decisión de actuar debe haber sido tomada previamente por:

```text
SwitchDecision
```

Esto mantiene:

```text
Decision
```

separada de:

```text
Execution
```

y evita que la capa que modifica el sistema determine por sí misma cuándo debe
hacerlo.

---

## 94. RecoveryValidator valida el objetivo y no sólo la acción

La recuperación no finaliza cuando:

```text
SSID actual = TargetSSID
```

P6-02 volvió a confirmar la secuencia:

```text
Network switch
      |
      v
SwitchVerified
      |
      v
RecoveryValidator
      |
      v
Endpoint operational probe
      |
      v
RecoveryConfirmed
```

Esto separa:

```text
ActionSucceeded
```

de:

```text
GoalSucceeded
```

La arquitectura no considera suficiente que Windows confirme el cambio de
SSID.

Debe recuperarse el servicio de impresión.

---

## 95. ConnectivityAnalyzer permanece fuera del camino crítico

`ConnectivityAnalyzer.ps1` continúa disponible como herramienta diagnóstica y
de observabilidad.

No constituye autoridad operacional ni dependencia necesaria para realizar
recovery.

La arquitectura vigente puede representarse como:

```text
Operational Pipeline
        |
        +--> Endpoint Reachability
        +--> InterfacePathAnalyzer
        +--> RouteAnalyzer
        +--> Policy
        +--> Decision
        +--> NetworkManager
        +--> RecoveryValidator

ConnectivityAnalyzer
        |
        +--> observabilidad adicional
```

Esto reduce acoplamiento y evita que un componente explicativo se convierta
innecesariamente en condición de funcionamiento.

---

## 96. Discovery y Policy permanecen separados

La separación consolidada continúa siendo:

```text
Discovery
    |
    +--> qué existe
    +--> cómo está configurado
    +--> qué endpoint usa la cola

Policy
    |
    +--> qué está autorizado
    +--> qué red puede utilizarse
    +--> cuándo puede intervenir PrintSwitch
```

P6 no produjo evidencia que justifique volver a mezclar ambas responsabilidades.

Una cola válida puede existir sin policy.

Una policy no redefine el endpoint real de Windows.

---

## 97. El Core moderno ya no depende operacionalmente de printers.json

La evolución previa al Punto 6 eliminó la dependencia operacional de:

```text
config/printers.json
```

en el core moderno.

La fuente operacional actual es:

```text
Windows
    |
    v
PrinterDiscovery
    |
    v
QueueContext
    |
    v
Endpoint
```

Los archivos legacy pueden continuar existiendo para herramientas anteriores o
compatibilidad documental.

No constituyen el modelo objetivo del pipeline moderno.

---

## 98. El modelo multi-fabricante ya tiene evidencia física

Antes de P6, la generalización multimarca era principalmente una dirección de
diseño.

Después de P6 existen pruebas reales con:

```text
Epson L365
Brother HL-1210W
```

La Brother validó:

```text
HOSTNAME
LPR
TCP 515
```

y sus colas también permitieron observar:

```text
USB
USB_PRESENCE
```

sin incorporar ramas específicas por fabricante.

La arquitectura genérica queda respaldada experimentalmente.

---

## 99. Generalización no equivale a universalidad

P6 demuestra que la abstracción funciona con más de un fabricante.

No demuestra todavía:

```text
todos los fabricantes
todos los monitores de puerto
todos los protocolos
IPP
WSD
SMB
Bluetooth
impresoras corporativas
VPN complejas
múltiples adaptadores Wi-Fi
```

Por tanto, la arquitectura debe continuar permitiendo nuevas estrategias sin
declarar compatibilidad universal prematuramente.

---

## 100. La evidencia insuficiente degrada capacidad de acción

Una conclusión transversal de P6 es:

```text
evidence insufficient
        |
        v
action capability decreases
```

y no:

```text
evidence insufficient
        |
        v
inferir valor probable
        |
        v
actuar
```

El comportamiento observado en P6-03 fue:

```text
SSID objetivo no confirmado
        |
        v
SWITCH_NOT_SAFE
        |
        v
NO NETWORK CHANGE
```

Esto constituye una propiedad arquitectónica de seguridad.

---

## 101. El discovery Wi-Fi presenta una frontera temporal con Windows

P6 identificó una limitación fuera del Core de decisión.

Una red conocida puede:

```text
no aparecer
```

en una consulta y posteriormente:

```text
aparecer
```

sin cambios físicos.

Esto indica que:

```text
netsh wlan show networks
```

no debe considerarse necesariamente un snapshot físico instantáneo y completo.

La arquitectura actual se mantiene conservadora.

El hardening de discovery queda diferido.

---

## 102. Beta 2 incorpora una capa de hardening de plataforma

La etapa Beta 2 deberá estudiar:

```text
Wi-Fi discovery stabilization
scan timing
eventos WLAN
polling
cache
doble muestreo
SCAN_PENDING
NOT_VISIBLE_CONFIRMED
UNKNOWN
```

También utilizará una topología experimental adicional:

```text
Suarez
```

como red Movistar completamente independiente y administrable.

Su función será permitir fault injection y diseño de topologías sin modificar
los principios del Core ya validados.

---

## 103. El laboratorio de red futuro queda explícitamente separado

La infraestructura experimental queda conceptualmente:

```text
Claro640
    |
    +--> router Claro independiente
         administración restringida

Suarez
    |
    +--> router Movistar independiente
         administración disponible
         posibilidad Ethernet

suarezcores
    |
    +--> TP-Link
         entorno asociado a Epson
         única topología del laboratorio con bridge relevante
```

Importante:

```text
Suarez != suarezcores
```

No existe relación topológica implícita entre ambas.

El parecido del nombre no tiene significado arquitectónico.

---

## 104. La arquitectura futura deberá evaluar topología, no nombres de red

Las pruebas Beta 2 podrán introducir:

```text
múltiples gateways
rutas alternativas
métricas
Ethernet + Wi-Fi
subredes iguales en infraestructuras distintas
destinos con rutas engañosas
gateway disponible pero endpoint inaccesible
SSID visible pero camino no funcional
```

Estas pruebas deberán utilizar:

```text
direccionamiento
rutas
interfaces
gateways
reachability
```

como evidencia.

Nunca:

```text
parecido entre nombres de SSID
```

---

## 105. Arquitectura observada consolidada

Después de P6, el flujo puede resumirse como:

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
Endpoint Contract
    |
    +--> TransportType
    +--> Protocol
    +--> AddressType
    +--> Destination
    +--> Service
    +--> ReachabilityStrategy
    |
    v
Evidence Acquisition
    |
    +--> Queue State
    +--> Resolution State
    +--> Interface State
    +--> Route State
    +--> Endpoint State
    |
    v
Network Context Analysis
    |
    v
Policy
    |
    v
Switch Decision
    |
    +---- NO ACTION
    |
    +---- SAFE NO-OP
    |
    +---- EXECUTE RECOVERY
              |
              v
         NetworkManager
              |
              v
         SwitchVerified
              |
              v
         RecoveryValidator
              |
              v
         Endpoint Revalidated
              |
              v
         Final Result
```

La regla de diseño central continúa siendo:

> **La intervención es la consecuencia de evidencia suficiente, no el punto de
> partida del análisis.**

---

## 106. Estado arquitectónico después del Punto 6

A cierre de P6 se consideran respaldadas por evidencia:

```text
[OK] QueueWatcher integrado con PrinterDiscovery

[OK] QueueContext como contrato operacional

[OK] Endpoint derivado de la cola Windows

[OK] NETWORK y USB representados mediante estrategias diferentes

[OK] IPV4 y HOSTNAME observados físicamente

[OK] Epson L365 validada con LPR / TCP 515

[OK] Brother validada con LPR / TCP 515 y hostname

[OK] estado Windows separado de endpoint reachability

[OK] resolución de hostname separada de endpoint reachability

[OK] route existence separada de reachability

[OK] ICMP mantenido como evidencia auxiliar

[OK] recovery condicionado a ausencia de camino funcional

[OK] no intervención cuando existe un camino funcional

[OK] SwitchDecision como barrera de seguridad

[OK] RecoveryValidator como validación de objetivo

[OK] ConnectivityAnalyzer fuera del camino crítico

[OK] comportamiento conservador ante evidencia insuficiente

[OK] regresión multi-printer superada
```

No se observó durante P6 una falla arquitectónica que requiera reconstruir el
Core.

Los hallazgos pendientes corresponden principalmente a:

```text
hardening de integración con Windows
```

y:

```text
topologías más complejas
```

que se reservan para Beta 2.

El Core endpoint-aware queda suficientemente estable para avanzar al siguiente
punto del Roadmap.