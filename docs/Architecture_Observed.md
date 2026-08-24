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