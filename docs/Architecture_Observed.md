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