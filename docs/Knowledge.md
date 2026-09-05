# PrintSwitch — Base de conocimiento

**Documento:** KB-001
**Versión:** 0.1
**Estado:** En desarrollo
**Última actualización:** 2026-08-17
**Relacionado con:** `Methodology.md`

---

## 1. Propósito

Este documento concentra el conocimiento técnico validado durante el desarrollo experimental de PrintSwitch.

Su contenido describe lo que actualmente sabemos sobre el comportamiento de Windows, la cola de impresión, la conectividad de red y la impresora utilizada en el entorno de referencia.

Las afirmaciones deben interpretarse según las categorías definidas en `Methodology.md`.

---

## 2. Problema de origen

El entorno de prueba dispone de varias redes Wi-Fi.

La computadora puede encontrarse conectada a una red utilizada normalmente para acceso a Internet mientras que la impresora pertenece a otra red Wi-Fi.

En el entorno experimental:

```text
PC
│
├── Red de uso habitual
│
│   └── Sin acceso directo a la impresora
│
└── suarezcores
    │
    └── Epson L365
```

La impresión requiere actualmente que la computadora tenga conectividad con la red donde se encuentra la impresora.

**Clasificación:** `[OBSERVADO]`

---

## 3. Impresora del entorno de referencia

La impresora utilizada durante las pruebas es:

```text
Modelo: Epson L365 Series
Nombre de red observado: EPSONE2EB06
MAC observada: 64:EB:8C:E2:EB:06
IP observada: 192.168.1.108
SSID: suarezcores
```

La dirección `192.168.1.108` fue observada como asignación DHCP.

Actualmente no debe considerarse una propiedad permanente de la impresora.

**Clasificación:** `[OBSERVADO]`

---

## 4. Comportamiento de la cola de impresión

### 4.1 Creación del trabajo

Cuando una aplicación solicita imprimir, Windows crea un trabajo en la cola de impresión incluso cuando la computadora no posee en ese momento conectividad con la impresora.

**Clasificación:** `[OBSERVADO]`

---

### 4.2 Persistencia

Durante las pruebas, un trabajo que no pudo ser enviado a la Epson L365 permaneció en la cola.

El controlador informó que no podía enviar el trabajo de impresión.

El documento no necesitó ser creado nuevamente.

**Clasificación:** `[OBSERVADO]`

---

### 4.3 Múltiples trabajos

Se realizó una prueba con tres documentos pendientes:

* dos documentos generados desde Microsoft Word;
* un documento generado desde Bloc de notas.

Los tres permanecieron simultáneamente en la cola mientras la computadora estaba conectada a una red sin acceso a la Epson.

**Clasificación:** `[OBSERVADO]`

---

### 4.4 Recuperación de la impresión

Al cambiar manualmente la computadora a `suarezcores`, los trabajos pendientes comenzaron a imprimirse sin necesidad de volver a solicitar la impresión desde las aplicaciones originales.

La cola se vació progresivamente.

**Clasificación:** `[OBSERVADO]`

---

## 5. Consecuencia para la arquitectura

Las pruebas indican que PrintSwitch no necesita interceptar Word, Bloc de notas u otras aplicaciones para conocer la intención de imprimir.

La cola de impresión de Windows constituye un punto común desde el cual pueden detectarse trabajos originados por aplicaciones diferentes.

**Clasificación:** `[INFERIDO]`

Por este motivo se adopta inicialmente la siguiente decisión:

> PrintSwitch observará la infraestructura de impresión de Windows en lugar de implementar integraciones específicas para cada aplicación.

**Clasificación:** `[DECISIÓN]`

---

## 6. Conectividad local de la Epson

Durante una interrupción del acceso a Internet de la red `suarezcores`, el router Wi-Fi continuó operativo.

En ese escenario fue posible acceder mediante navegador al servidor HTTP incorporado en la Epson utilizando:

```text
192.168.1.108
```

La página de administración de la impresora respondió correctamente.

**Clasificación:** `[OBSERVADO]`

---

## 7. LAN e Internet

Durante el escenario anterior se observó simultáneamente:

```text
Acceso a Internet              NO DISPONIBLE

Red Wi-Fi local                DISPONIBLE

Acceso HTTP a Epson L365       DISPONIBLE

Epson Connect Services         DISCONNECTED
```

Esto demuestra que el acceso al servidor HTTP local de la impresora no requiere que la red disponga de conectividad a Internet.

**Clasificación:** `[OBSERVADO]`

---

## 8. Impresión sin Internet

Todavía no se realizó una prueba controlada que confirme que un trabajo de Windows pueda completar todo el proceso de impresión mientras la LAN permanece operativa pero la conexión WAN está desconectada.

Por lo tanto:

> La impresión local probablemente pueda funcionar sin Internet siempre que exista conectividad IP entre Windows y la impresora.

**Clasificación:** `[HIPÓTESIS]`

### Prueba pendiente

Comparar:

```text
ESCENARIO A

LAN:       disponible
Internet:  disponible
Impresión: ?
```

contra:

```text
ESCENARIO B

LAN:       disponible
Internet:  no disponible
Impresión: ?
```

**Clasificación:** `[PENDIENTE]`

---

## 9. Epson iPrint

Durante la interrupción de Internet, Epson iPrint en Android permaneció intentando establecer conexión mientras el servidor HTTP local de la impresora continuaba accesible mediante IP.

Este comportamiento fue observado, pero todavía no permite determinar qué dependencia concreta estaba esperando la aplicación.

No debe concluirse todavía que Epson iPrint requiera necesariamente Internet para toda operación de impresión.

**Clasificación:** `[OBSERVADO]`

---

## 10. Dirección IP e identidad de la impresora

La dirección IP no debe considerarse inicialmente como la identidad permanente de una impresora.

En el entorno actual conocemos:

```text
Impresora:
    Epson L365

MAC:
    64:EB:8C:E2:EB:06

Hostname observado:
    EPSONE2EB06

Última IP conocida:
    192.168.1.108

Red:
    suarezcores
```

Una reserva DHCP permitiría mantener estable la dirección IP, pero PrintSwitch no deberá exigir que el usuario tenga acceso administrativo al router.

**Clasificación:** `[DECISIÓN]`

---

## 11. DHCP dinámico

PrintSwitch deberá contemplar instalaciones donde la impresora pueda recibir direcciones diferentes mediante DHCP.

Conceptualmente:

```text
Identidad de impresora
        │
        ├── nombre
        ├── información de Windows
        ├── MAC
        ├── hostname
        └── última IP conocida
                 │
                 ▼
        descubrimiento/verificación
                 │
                 ▼
           IP actualmente válida
```

Los mecanismos concretos de descubrimiento todavía deben ser investigados y probados.

**Clasificación:** `[PENDIENTE]`

---

## 12. Compatibilidad con otros fabricantes

La arquitectura trabaja sobre componentes de Windows que no son exclusivos de Epson.

Sin embargo, las pruebas realizadas hasta el momento corresponden a una Epson L365.

Por lo tanto:

```text
Epson L365       VALIDADA PARCIALMENTE
HP               NO VALIDADA
Canon            NO VALIDADA
Brother          NO VALIDADA
Otros            NO VALIDADOS
```

La compatibilidad general con otras impresoras permanece como hipótesis hasta realizar pruebas específicas.

**Clasificación:** `[PENDIENTE]`

---

## 13. Arquitectura conceptual actual

El conocimiento obtenido permite plantear provisionalmente:

```text
Aplicación
    │
    ▼
Sistema de impresión de Windows
    │
    ▼
Cola / Spooler
    │
    ▼
PrintSwitch detecta actividad
    │
    ▼
Determina la red requerida
    │
    ▼
Verifica conectividad
    │
    ▼
Gestiona el cambio de red
    │
    ▼
Windows / controlador continúa el trabajo
    │
    ▼
Impresora
```

Esta arquitectura todavía no representa una implementación terminada.

**Clasificación:** `[INFERIDO]`

---

## 14. Próximas validaciones

Quedan pendientes, entre otras:

1. Impresión mediante LAN sin acceso a Internet.
2. Descubrimiento de una impresora cuya IP haya cambiado por DHCP.
3. Cambio automático hacia `suarezcores`.
4. Recuperación automática del trabajo después del cambio.
5. Retorno seguro a la red original.
6. Comportamiento con múltiples trabajos.
7. Comportamiento cuando la impresora está apagada.
8. Comportamiento cuando el SSID requerido no está disponible.
9. Validación con una impresora HP.
10. Determinación de qué información de configuración debe almacenar PrintSwitch.

---

## 15. Conclusión actual

La evidencia obtenida permite sostener que la cola de impresión de Windows puede utilizarse como punto de observación para detectar trabajos pendientes y que, en el entorno probado, dichos trabajos pueden recuperarse cuando se restablece la conectividad con la Epson L365.

Todavía no se ha demostrado que este comportamiento sea universal para todas las impresoras, controladores o configuraciones de red.

PrintSwitch continuará desarrollándose diferenciando explícitamente los comportamientos observados de las hipótesis pendientes de validación.
## 16. Principio de evidencia positiva

PrintSwitch no deberá inferir el estado físico de una impresora a partir de una única señal negativa de conectividad.

Ejemplos:

- un ping fallido no demuestra que la impresora esté apagada;
- un puerto TCP inaccesible no demuestra que la impresora esté apagada;
- un trabajo en estado de error no demuestra que la impresora esté apagada;
- estar conectado a una red diferente no permite determinar el estado físico de la impresora.

En cambio, una evidencia positiva de comunicación permite realizar inferencias más fuertes.

Ejemplos:

```text
Dispositivo identificado en la red
        ↓
evidencia de presencia

Servicio HTTP responde
        ↓
dispositivo activo

Servicio de impresión responde
        ↓
subsistema de red de la impresora activo

---

> **Nota de evolución documental — corte Alpha (27/08/2026)**
>
> Las secciones anteriores corresponden al conocimiento acumulado durante
> las primeras etapas de investigación de PrintSwitch.
>
> Se conservan como registro histórico porque contienen observaciones,
> hipótesis y conclusiones que permitieron construir la arquitectura actual.
>
> A partir de este punto se documenta el conocimiento consolidado durante
> el cierre del Alpha.
>
> Ante una contradicción, las secciones posteriores a este corte representan
> el estado vigente del proyecto.

# Conocimiento consolidado — Alpha

## 17. El SSID actual no determina por sí solo la alcanzabilidad

La red Wi-Fi actualmente conectada no permite determinar por sí sola si una
impresora puede ser alcanzada.

Un equipo puede tener simultáneamente:

```text
Ethernet
Wi-Fi
VPN
interfaces virtuales
otras rutas
```

Por lo tanto:

```text
SSID actual != camino efectivo hacia la impresora
```

La decisión debe considerar las interfaces y rutas disponibles.

---

## 18. Pueden existir múltiples caminos válidos

Durante las pruebas Alpha se observó un escenario donde Ethernet y Wi-Fi
pertenecían simultáneamente a la misma red:

```text
192.168.1.0/24
```

Ambas interfaces podían alcanzar:

```text
Epson L365
192.168.1.108
TCP 9100
```

El resultado fue clasificado como:

```text
MULTIPLE_REACHABLE_PATHS
```

Esto demuestra que la existencia de más de un camino no constituye por sí
misma un error.

La política correcta es:

```text
si al menos un camino válido alcanza la impresora
    NO_ACTION
```

---

## 19. Un camino candidato no implica una impresora alcanzable

Una interfaz puede pertenecer a la misma subred que la impresora y, sin
embargo, el dispositivo puede no responder.

Ejemplo validado:

```text
Ethernet: 192.168.1.109
Impresora: 192.168.1.108
Red:       192.168.1.0/24
```

con la impresora apagada.

Existe un camino de red candidato, pero:

```text
TCP 9100 = no alcanzable
```

Por lo tanto deben distinguirse dos conceptos:

```text
CandidatePath
ReachablePath
```

---

## 20. Impresora no alcanzable no significa red incorrecta

Durante las pruebas con la Epson apagada se confirmó que:

```text
impresora no responde
```

no implica automáticamente:

```text
Wi-Fi incorrecto
```

Si existe una interfaz local coherente con la red de destino, pero el
dispositivo no responde, cambiar de Wi-Fi puede ser una intervención inútil
o incluso perjudicial.

La clasificación utilizada fue:

```text
EXISTING_PATH_PRINTER_UNREACHABLE
```

con decisión:

```text
NO_SWITCH_PRINTER_UNREACHABLE
```

---

## 21. Autorizar recuperación no equivale a ejecutar un cambio

El parámetro:

```text
-EnableRecovery
```

en `QueueWatcher.ps1` significa:

```text
el sistema tiene permiso para ejecutar una recuperación si la evidencia
la justifica
```

No significa:

```text
cambiar siempre de Wi-Fi al detectar un trabajo
```

La autorización global y la decisión contextual son conceptos distintos.

---

## 22. La no intervención también es un resultado correcto

Durante una prueba real se mantuvo una videoconferencia activa en Jabber
mientras:

```text
Wi-Fi = Claro640
Ethernet disponible
Epson apagada
RecoveryEnabled = True
```

PrintSwitch detectó el trabajo y analizó el contexto.

El resultado fue:

```text
SwitchAuthorized = False
SwitchExecuted   = False
```

La conectividad existente permaneció sin cambios.

Esto valida que el sistema puede decidir correctamente no intervenir incluso
cuando tiene permiso para hacerlo.

---

## 23. Ethernet debe preservarse

La política Alpha establece:

```text
PrintSwitch no modifica Ethernet
```

Antes y después de una recuperación se registra:

```text
EthernetPresentBefore
EthernetPresentAfter
EthernetPreserved
```

Si existían interfaces Ethernet activas antes de una recuperación, deben
permanecer activas después.

Las pruebas de simulación de preservación Ethernet finalizaron:

```text
4/4 PASS
```

---

## 24. La visibilidad de una red Wi-Fi es temporal

La salida de:

```text
netsh wlan show networks
```

puede variar entre consultas cercanas en el tiempo.

Por ello, una ausencia instantánea del SSID objetivo no debe interpretarse
inmediatamente como ausencia definitiva.

`WiFiCandidateEvaluator.ps1` y `NetworkManager.ps1` utilizan reintentos
controlados para reducir falsos negativos de visibilidad.

---

## 25. Cambiar de SSID no confirma la recuperación

Una transición como:

```text
Claro640
   |
   v
suarezcores
```

sólo demuestra que Windows cambió de red Wi-Fi.

No demuestra todavía que la impresora pueda recibir el trabajo.

Por ello el Alpha incorpora `RecoveryValidator.ps1`, que verifica después del
cambio:

```text
ruta
+
TCP 9100
```

durante una ventana temporal.

La recuperación sólo se considera confirmada cuando existe conectividad real
con el servicio de impresión.

---

## 26. La recuperación completa fue validada físicamente

En la primera prueba End-to-End completa del Alpha:

```text
Ethernet desconectado
Wi-Fi inicial = Claro640
Epson encendida
SSID objetivo = suarezcores
QueueWatcher -EnableRecovery
```

se produjo la siguiente secuencia:

```text
trabajo detectado
        |
        v
sin camino actual hacia la impresora
        |
        v
SSID objetivo conocido y visible
        |
        v
SWITCH_WIFI_FOR_PRINTER
        |
        v
Claro640 -> suarezcores
        |
        v
RecoveryValidator
        |
        v
TCP 9100 alcanzable
        |
        v
CONTEXTUAL_RECOVERY_SUCCESS
```

La recuperación fue confirmada aproximadamente a los:

```text
1496 ms
```

El resultado final incluyó:

```text
NetworkSwitchVerified = True
RecoveryConfirmed     = True
RecoverySucceeded     = True
SwitchAuthorized      = True
SwitchExecuted        = True
```

y la página física fue impresa correctamente.

Este ensayo constituye el primer End-to-End Contextual Recovery exitoso de
PrintSwitch Alpha.

---

## 27. El happy path también atraviesa el orquestador

Después de validar la recuperación completa se realizó una prueba con:

```text
Epson encendida
Ethernet desconectado
Wi-Fi ya conectado a suarezcores
RecoveryEnabled = True
```

El trabajo fue detectado y procesado por el mismo orquestador.

`InterfacePathAnalyzer` encontró:

```text
UNIQUE_REACHABLE_PATH
```

y el resultado fue:

```text
EXISTING_REACHABLE_PATH
NO_ACTION
SwitchAuthorized = False
SwitchExecuted   = False
```

El trabajo se imprimió normalmente.

Esto confirma que habilitar recuperación no introduce cambios cuando el
sistema ya funciona.

---

## 28. Estado de validaciones previamente pendientes

Varias cuestiones consideradas pendientes durante etapas anteriores quedaron
resueltas durante el Alpha.

| Tema | Estado Alpha |
|---|---|
| Detectar trabajos de impresión | Validado |
| Analizar conectividad antes de actuar | Validado |
| Distinguir Ethernet y Wi-Fi | Validado |
| Detectar múltiples caminos válidos | Validado |
| Evitar cambio si ya existe camino funcional | Validado |
| Evitar cambio si la impresora está apagada pero existe camino local | Validado |
| Preservar Ethernet | Validado |
| Evaluar SSID objetivo | Validado |
| Ejecutar cambio Wi-Fi autorizado | Validado |
| Verificar cambio de SSID | Validado |
| Verificar recuperación real después del cambio | Validado |
| Imprimir físicamente después de recuperación | Validado |
| Mantener no intervención con aplicación activa | Validado |
| Soporte genérico para múltiples fabricantes | Pendiente |
| Retorno automático al SSID anterior | Pendiente |
| Descubrimiento automático de impresoras | Pendiente |
| Gestión multi-impresora | Pendiente |

---

## 29. Evolución de los componentes

El conocimiento experimental derivó en componentes con responsabilidades
separadas.

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

Esta separación permite observar y probar cada fase de manera independiente.

---

## 30. ContextualRecoveryTest queda como antecedente experimental

`ContextualRecoveryTest.ps1` fue utilizado durante la evolución inicial de la
recuperación contextual.

Posteriormente apareció:

```text
PrintRecoveryOrchestrator.ps1
```

como implementación operacional integrada.

El archivo experimental se conserva como evidencia histórica, pero
`QueueWatcher.ps1` ya no depende de él.

---

## 31. QueueWatcher delega la recuperación

`QueueWatcher.ps1` tiene como responsabilidad principal:

```text
observar la cola
detectar nuevos trabajos
delegar la recuperación
```

La política operativa no debe estar duplicada dentro del watcher.

La recuperación se delega a:

```text
PrintRecoveryOrchestrator.ps1
```

Esto reduce divergencias entre decisiones y centraliza el flujo operacional.

---

## 32. Los contratos estructurados son parte de la arquitectura

Los componentes críticos devuelven objetos estructurados en lugar de depender
únicamente de texto de consola.

El contrato de `PrintRecoveryOrchestrator` fue normalizado para incluir en
todas sus ramas:

```text
Component
Version
PrinterName
TargetIP
TargetSSID
```

además de los campos específicos de cada resultado.

Esto permite:

```text
logging
pruebas
integración
diagnóstico
automatización futura
```

sin depender de parsear mensajes humanos.

---

## 33. Arquitectura de conocimiento vigente

El modelo actual puede resumirse como:

```text
trabajo de impresión
        |
        v
¿existe un camino alcanzable?
        |
   +----+----+
   |         |
  sí         no
   |         |
NO_ACTION    v
         ¿existe camino local candidato
         pero impresora no responde?
              |
         +----+----+
         |         |
        sí         no
         |         |
    NO_SWITCH      v
               evaluar Wi-Fi
                    |
                    v
              decidir cambio
                    |
                    v
                 ejecutar
                    |
                    v
                 validar
```

---

## 34. Qué demuestra el Alpha

El Alpha demuestra en el entorno probado que PrintSwitch puede:

```text
detectar un trabajo
analizar interfaces
analizar rutas
distinguir caminos candidatos de caminos alcanzables
preservar Ethernet
evitar cambios innecesarios
decidir un cambio Wi-Fi
ejecutarlo
verificarlo
esperar recuperación real
permitir la impresión física
```

---

## 35. Qué no demuestra todavía el Alpha

El Alpha no permite afirmar todavía que PrintSwitch sea universal.

No se ha validado suficientemente:

```text
otras marcas de impresoras
otros protocolos de impresión
otros sistemas operativos
múltiples impresoras simultáneas
múltiples adaptadores Wi-Fi
entornos corporativos complejos
VPN complejas
retorno automático al estado previo
descubrimiento automático general
```

Estas áreas requieren evidencia adicional.

---

## 36. Evolución del principio de evidencia positiva

Durante el desarrollo se consolidó una regla central:

```text
no modificar conectividad basándose solamente en ausencia o error
```

La intervención debe apoyarse en evidencia positiva de que:

```text
1. no existe un camino funcional actual
2. el problema puede resolverse mediante Wi-Fi
3. existe un SSID objetivo conocido y disponible
4. el cambio está autorizado
```

Después de actuar, se requiere nueva evidencia positiva:

```text
la conectividad con la impresora fue recuperada
```

---

## 37. Conclusión de conocimiento Alpha

El aprendizaje principal del Alpha puede resumirse así:

> **PrintSwitch no debe perseguir redes; debe perseguir conectividad útil.**

El SSID es solamente una de las variables del problema.

La unidad real de decisión es:

```text
trabajo
+
destino
+
interfaces
+
rutas
+
alcanzabilidad
+
contexto
+
política
```

y cualquier cambio debe ser la consecuencia de esa evaluación, no el punto
de partida.

---

# Actualización de conocimiento — Septiembre 2026

> **Estado documental**
>
> Todo el contenido anterior se conserva como conocimiento histórico obtenido
> durante las etapas previas de PrintSwitch-Windows.
>
> Las conclusiones Alpha continúan siendo válidas dentro del contexto en que
> fueron obtenidas, pero algunas fueron posteriormente refinadas mediante
> nueva evidencia experimental.
>
> Esta sección documenta el conocimiento vigente al checkpoint:
>
> ```text
> commit 55316dd
> FEAT: consolida recovery operacional y diagnostico opcional
> ```

---

## 38. La cola es el punto de entrada operacional

Una de las conclusiones más importantes posteriores al Alpha es que
PrintSwitch no debe comenzar identificando una impresora mediante una IP.

El objeto que Windows realmente utiliza para entregar un trabajo es:

```text
la cola de impresión
```

A partir de ella pueden descubrirse:

```text
driver
puerto
monitor
protocolo
destino
transporte
```

Por ello, la secuencia conceptual pasa a ser:

```text
trabajo
   |
   v
cola Windows
   |
   v
endpoint
   |
   v
alcanzabilidad
```

La IP puede formar parte del endpoint, pero no constituye por sí sola la
identidad operacional de la impresora.

---

## 39. Una impresora puede exponer múltiples endpoints

La investigación con una segunda impresora mostró que un mismo equipo puede
estar representado en Windows mediante más de una cola.

Ejemplo observado:

```text
Brother HL-1210W series
Brother HL-1210W series USB
```

Estas colas utilizan mecanismos diferentes.

La primera puede utilizar un endpoint de red.

La segunda utiliza un endpoint USB.

Esto demuestra que:

```text
impresora física
```

y:

```text
cola Windows
```

no son necesariamente equivalentes uno a uno.

La correlación entre múltiples colas y un mismo dispositivo físico es una
capacidad diferente del descubrimiento operacional básico.

---

## 40. Endpoint no significa necesariamente TCP

Durante Alpha, la mayoría de las pruebas se realizaron sobre una impresora de
red.

Eso podía inducir a representar la alcanzabilidad principalmente mediante:

```text
IP + puerto TCP
```

La aparición de una cola USB obliga a generalizar el concepto.

Un endpoint puede requerir distintas estrategias:

```text
NETWORK
   |
   +--> reachability de servicio

USB
   |
   +--> presencia del dispositivo

otros transportes
   |
   +--> estrategia específica
```

Por lo tanto, la arquitectura debe seleccionar la estrategia de reachability
a partir del endpoint y no asumir una única técnica para todas las colas.

---

## 41. La Epson L365 utiliza operacionalmente LPR TCP 515

Las pruebas Alpha utilizaron con éxito:

```text
TCP 9100
```

como señal de disponibilidad de la Epson L365.

Ese resultado continúa siendo válido dentro de aquellas pruebas.

Sin embargo, la inspección posterior del puerto EpsonNet configurado para la
cola:

```text
L365 Series(Red)
```

demostró que el mecanismo operacional configurado es:

```text
Protocol     = LPR
Destination  = 192.168.1.108
TcpPort      = 515
QueueName    = ENPQueue
```

La lección general es:

> Un servicio que responde en una impresora no necesariamente es el servicio
> utilizado por la cola que está intentando imprimir.

Por ello, los tests de liveness generales pueden seguir siendo útiles para
diagnóstico, pero no deben sustituir al endpoint configurado cuando se toma
una decisión operacional.

---

## 42. TCP 9100 sigue siendo útil, pero deja de ser una verdad global

La evolución endpoint-aware no invalida TCP 9100.

Lo reubica.

Puede utilizarse como:

```text
probe diagnóstico
señal de liveness
evidencia adicional
```

cuando el dispositivo lo ofrece.

No debe utilizarse automáticamente como:

```text
puerto operacional de cualquier impresora de red
```

La regla vigente es:

```text
protocolo y puerto operacional
        =
endpoint descubierto para la cola
```

---

## 43. REACHABLE, UNREACHABLE y UNKNOWN no son equivalentes

La normalización de reachability utiliza:

```text
REACHABLE
UNREACHABLE
UNKNOWN
```

Esta separación evita decisiones peligrosas.

### REACHABLE

Existe evidencia positiva de que el endpoint está disponible.

### UNREACHABLE

La estrategia correspondiente pudo ejecutarse y no obtuvo reachability.

### UNKNOWN

No existe evidencia suficiente para afirmar ninguna de las dos anteriores.

Una consecuencia importante es:

> UNKNOWN no constituye autorización para cambiar la red.

La ausencia de conocimiento debe conducir a comportamiento seguro, no a una
acción más agresiva.

---

## 44. La ausencia de una impresora USB no justifica recovery Wi-Fi

Una cola USB requiere una estrategia distinta de una cola de red.

Si el dispositivo USB está presente:

```text
USB = REACHABLE
```

no existe razón para modificar Wi-Fi.

Si el dispositivo USB no está presente:

```text
USB = UNREACHABLE
```

tampoco existe evidencia suficiente para concluir que un cambio de Wi-Fi
resolverá el problema.

Por ello:

```text
USB conectado
    -> NO_ACTION

USB desconectado
    -> NO_WIFI_ACTION
```

La ausencia de un endpoint local no debe reinterpretarse automáticamente como
un problema de conectividad inalámbrica.

---

## 45. Discovery y Policy responden preguntas diferentes

Durante las primeras etapas, `config/printers.json` combinaba información de
naturaleza distinta.

La evolución permitió separar dos preguntas.

### Discovery

```text
¿Qué existe?
```

Incluye información obtenida desde Windows, Registry, PnP y el subsistema de
impresión.

Por ejemplo:

```text
cola
driver
puerto
monitor
transporte
protocolo
destino
identidad USB
```

### Policy

```text
¿Qué está autorizado a hacer PrintSwitch?
```

Ejemplo:

```text
si la Epson necesita recuperación Wi-Fi,
puede utilizar el SSID suarezcores
```

La conclusión es:

> La existencia de una impresora debe descubrirse automáticamente; la
> intención del usuario no debe confundirse con inventario de hardware.

---

## 46. Una cola sin policy sigue siendo una cola válida

La ausencia de entrada en:

```text
config/policy.json
```

no significa:

```text
impresora desconocida
impresora inválida
error de configuración
```

Significa únicamente:

```text
no existe una autorización especial de recuperación para esa cola
```

Esto permite que PrintSwitch analice impresoras normales sin exigir un perfil
manual previo.

La policy sólo adquiere relevancia cuando una acción potencial necesita
autorización.

---

## 47. OperationalTargetIP separa evidencia y operación

La introducción de:

```text
OperationalTargetIP
OperationalTcpPort
```

permitió separar dos conceptos.

### Evidencia de discovery

Describe el endpoint observado realmente en Windows.

### Destino operacional

Describe el destino utilizado por los analizadores durante una ejecución.

Si se proporciona explícitamente:

```text
-TargetIP
```

ese valor tiene precedencia operacional.

Si no existe override:

```text
OperationalTargetIP
    =
destino resuelto del endpoint
```

Esto permite realizar pruebas controladas sin falsificar ni alterar la
información descubierta.

---

## 48. -Execute es permiso, no orden

La semántica de:

```text
-Execute
```

quedó confirmada experimentalmente.

No significa:

```text
cambiar Wi-Fi
```

Significa:

```text
permitir que se ejecute una acción
si el motor concluye que es necesaria
```

Si ya existe un camino funcional, incluso con `-Execute`:

```text
SwitchAuthorized = False
SwitchExecuted   = False
```

La decisión contextual continúa teniendo prioridad sobre el permiso global de
ejecución.

---

## 49. Ethernet debe preservarse y también auditarse correctamente

PrintSwitch no modifica Ethernet durante una recuperación Wi-Fi.

Además, el resultado de preservación debe representar correctamente el estado
inicial.

La semántica vigente es:

```text
Ethernet no existía antes
    -> NOT_APPLICABLE

Ethernet existía y continúa disponible
    -> PRESERVED

Ethernet existía y dejó de estar disponible
    -> FAILED
```

Esto evita falsos negativos de preservación.

No tener una interfaz Ethernet activa al iniciar no puede interpretarse como
un fallo del sistema al intentar preservarla.

---

## 50. ConnectivityAnalyzer es diagnóstico, no autoridad operacional

`ConnectivityAnalyzer.ps1` sigue teniendo valor para:

```text
diagnóstico
telemetría
observabilidad
comparación de señales
```

Sin embargo, ya no forma parte de los criterios obligatorios que determinan si
una recuperación fue exitosa.

El éxito operacional depende de:

```text
NetworkSwitchVerified
        +
RecoveryValidator.RecoveryConfirmed
        +
RouteAfter.TargetReachable
```

Esto fue comprobado realizando una recuperación completa con
`ConnectivityAnalyzer.ps1` temporalmente ausente.

Resultado observado:

```text
ConnectivityAfter   = NOT_AVAILABLE
RecoverySucceeded   = True
FinalClassification = CONTEXTUAL_RECOVERY_SUCCESS
```

La lección general es:

> Un componente de observabilidad no debe convertirse innecesariamente en una
> dependencia del proceso que observa.

---

## 51. RecoveryValidator debe validar el servicio operacional

La recuperación no termina cuando Windows informa que cambió de SSID.

El sistema debe comprobar que el endpoint volvió a ser alcanzable.

Para la Epson actualmente validada:

```text
192.168.1.108:515
```

La secuencia correcta es:

```text
cambio Wi-Fi
     |
     v
verificación del SSID
     |
     v
espera de recuperación
     |
     v
probe del endpoint operacional
     |
     v
revalidación de ruta
```

Esto evita declarar éxito únicamente porque la interfaz inalámbrica cambió de
red.

---

## 52. La recuperación Epson endpoint-aware confirmó la abstracción

Se validó físicamente el escenario:

```text
Ethernet desconectado
Wi-Fi inicial = Claro640
Epson encendida
SSID suarezcores visible
Endpoint Epson = 192.168.1.108:515
```

El endpoint era inicialmente:

```text
UNREACHABLE
```

PrintSwitch determinó que no existía un camino funcional y que la policy
autorizaba recuperación mediante `suarezcores`.

Se ejecutó:

```text
Claro640
   |
   v
suarezcores
```

Posteriormente:

```text
RecoveryValidator = confirmado
RouteAfter.TargetReachable = True
RecoverySucceeded = True
```

y la clasificación final fue:

```text
CONTEXTUAL_RECOVERY_SUCCESS
```

Esto demuestra que la abstracción endpoint-aware no es únicamente conceptual.

Fue utilizada en una recuperación física real.

---

## 53. No intervenir sigue siendo un resultado exitoso

También se validó el escenario:

```text
Ethernet activo
Wi-Fi = Claro640
Epson alcanzable mediante Ethernet
```

El endpoint:

```text
192.168.1.108:515
```

era alcanzable por Ethernet.

PrintSwitch detectó un camino funcional y terminó con:

```text
EXISTING_REACHABLE_PATH
```

sin modificar Wi-Fi.

Este comportamiento se mantuvo incluso cuando el Orchestrator recibió:

```text
-Execute
```

Esto reafirma una idea central del proyecto:

> Resolver correctamente un problema puede significar decidir que no existe
> ninguna acción que realizar.

---

## 54. El modelo debe aceptar fabricantes distintos sin excepciones

La evolución actual prepara la arquitectura para una validación importante.

El objetivo no es agregar:

```text
if Epson ...
if Brother ...
if HP ...
```

El objetivo es que cada cola se normalice mediante:

```text
QueueContext
      |
      v
Endpoint
      |
      v
ReachabilityStrategy
```

y que el resto del motor opere sobre esa representación común.

Una segunda marca de impresora será útil precisamente para detectar qué partes
de la arquitectura son realmente genéricas y cuáles continúan dependiendo de
supuestos derivados de la Epson.

---

## 55. Conocimiento vigente al checkpoint

Al cierre de Septiembre 2026 se consideran respaldadas por evidencia las
siguientes afirmaciones:

```text
[OK] la cola Windows es el objeto operacional primario

[OK] un endpoint debe derivarse de la configuración real de la cola

[OK] un endpoint puede ser NETWORK o USB

[OK] NETWORK y USB necesitan estrategias de reachability diferentes

[OK] la Epson L365 utiliza LPR / TCP 515 en su cola configurada

[OK] TCP 9100 puede ser diagnóstico sin ser el puerto operacional

[OK] UNKNOWN debe producir comportamiento seguro

[OK] una cola puede existir sin policy

[OK] Discovery y Policy representan información diferente

[OK] -Execute autoriza pero no fuerza acciones

[OK] una recuperación debe validar el endpoint después del cambio

[OK] ConnectivityAnalyzer puede estar ausente sin invalidar el recovery

[OK] Ethernet debe preservarse y auditarse con semántica explícita

[OK] una ruta funcional existente evita cambios Wi-Fi
```

El checkpoint de referencia es:

```text
commit 55316dd
FEAT: consolida recovery operacional y diagnostico opcional
```

La próxima etapa debe aportar evidencia nueva mediante una segunda impresora y
no simplemente extender las conclusiones obtenidas con Epson.


---

# Actualización de conocimiento — Validación multimarca, integración y auditoría pre-Punto 6 — Septiembre 2026

> **Alcance**
>
> Esta sección incorpora exclusivamente conocimiento obtenido después del
> checkpoint:
>
> ```text
> 55316dd
> FEAT: consolida recovery operacional y diagnostico opcional
> ```
>
> No reemplaza las conclusiones anteriores.
>
> Las amplía mediante evidencia obtenida durante:
>
> ```text
> Punto 3 — validación Brother
> Punto 4 — consolidación Discovery + Policy
> Punto 5 — integración QueueWatcher
> auditoría técnica pre-Punto 6
> ```
>
> Los checkpoints posteriores relevantes son:
>
> ```text
> bbe5c4c
> FEAT: integra QueueWatcher con discovery y recovery operacional
>
> 4730803
> REFACTOR: desacopla diagnostico de configuracion legacy
> ```

---

## 56. Una segunda marca confirmó que la abstracción no era accidentalmente Epson-specific

La Brother permitió responder una pregunta que permanecía abierta en el
checkpoint anterior.

La arquitectura desarrollada inicialmente alrededor de la Epson podía ser:

```text
realmente genérica
```

o simplemente:

```text
una generalización aparente construida sobre supuestos Epson
```

La Brother presentó características diferentes:

```text
dos colas para un mismo dispositivo físico

endpoint NETWORK basado en HOSTNAME

endpoint USB

LPR

identidad USB

resolución dinámica del destino de red
```

y aun así pudo representarse mediante:

```text
QueueContext
      |
      v
Endpoint
      |
      v
ReachabilityStrategy
```

sin agregar lógica:

```text
if Brother ...
```

Esto constituye evidencia de que la abstracción utilizada por PrintSwitch
trasciende al primer fabricante empleado durante el desarrollo.

---

## 57. El nombre comercial del equipo no es necesariamente la identidad operacional

El dispositivo físico utilizado para la segunda validación pertenece
comercialmente a la familia:

```text
Brother HL-1212W
```

Sin embargo Windows y el driver exponen:

```text
Brother HL-1210W series
```

La diferencia no impidió operar correctamente.

Esto refuerza que PrintSwitch no debe intentar reconstruir la identidad del
producto a partir de nombres comerciales externos.

La identidad operacional relevante es la que Windows expone mediante:

```text
QueueName
DriverName
PortName
```

y posteriormente normaliza mediante `QueueContext`.

La lección es:

> El sistema debe trabajar con la representación operacional que realmente
> utiliza el sistema de impresión y no con una identidad comercial inferida.

---

## 58. Un dispositivo físico puede tener varias identidades operacionales válidas

La Brother produjo simultáneamente:

```text
Brother HL-1210W series
Brother HL-1210W series USB
```

Ambas colas corresponden al mismo equipo físico.

Sin embargo representan endpoints diferentes:

```text
NETWORK
```

y:

```text
USB
```

Por lo tanto:

```text
dispositivo físico
    !=
cola
```

y también:

```text
dispositivo físico
    !=
endpoint único
```

La unidad sobre la cual PrintSwitch puede tomar decisiones continúa siendo la
cola seleccionada y su endpoint.

Esto evita intentar fusionar automáticamente dos caminos que Windows presenta
como mecanismos operacionales distintos.

---

## 59. Un hostname configurado es evidencia válida de destino

La Brother Network utiliza:

```text
ConfiguredDestination = BRWC48E8F7B140F
AddressType           = HOSTNAME
Protocol              = LPR
TcpPort               = 515
```

La dirección operacional no se encontraba almacenada como IPv4 literal en la
cola.

Cuando el contexto de red permitió resolver el hostname:

```text
BRWC48E8F7B140F
        |
        v
192.168.100.12
```

el servicio:

```text
192.168.100.12:515
```

respondió correctamente.

Esto demuestra:

> Una dirección IP literal no es requisito para que PrintSwitch pueda
> representar un endpoint de red.

La información puede evolucionar desde:

```text
destino configurado
        |
        v
resolución
        |
        v
destino operacional
```

La dirección resuelta pertenece al contexto operacional actual y no debe
confundirse necesariamente con la identidad persistente del endpoint.

---

## 60. Fallar al resolver un hostname no demuestra que la impresora esté caída

Se observó físicamente que:

```text
BRWC48E8F7B140F
```

podía no resolverse desde determinado contexto de red.

En esa situación no existía evidencia suficiente para ejecutar el probe TCP.

La clasificación correcta fue:

```text
ReachabilityState = UNKNOWN
ProbeResult       = DESTINATION_RESOLUTION_FAILED
```

No:

```text
UNREACHABLE
```

Posteriormente, desde un contexto donde el hostname volvió a resolverse, la
impresora respondió correctamente.

Esto aporta evidencia experimental adicional a la distinción ya establecida:

```text
UNKNOWN
   !=
UNREACHABLE
```

y permite formular una regla más específica:

> La imposibilidad de obtener el destino operacional es un fallo de evidencia,
> no una demostración de indisponibilidad del servicio final.

---

## 61. La incertidumbre debe degradar capacidad de acción

Cuando la Brother Network produjo:

```text
DESTINATION_RESOLUTION_FAILED
```

el Orchestrator terminó con:

```text
SwitchDecision =
NO_ACTION_INSUFFICIENT_ENDPOINT_EVIDENCE

SwitchAuthorized = False
SwitchExecuted   = False

FinalClassification =
NETWORK_DESTINATION_UNRESOLVED
```

La red Wi-Fi permaneció sin cambios.

Esto amplía el principio de evidencia positiva:

```text
menos evidencia
      |
      v
menos capacidad para justificar una intervención
```

y no:

```text
menos evidencia
      |
      v
más libertad para probar acciones
```

La incertidumbre debe degradar el sistema hacia estados conservadores.

---

## 62. USB requiere semántica propia y no una simulación del modelo IP

La Brother USB fue descubierta como:

```text
TransportType         = USB
Protocol              = USB
ConfiguredDestination = USB001
AddressType           = DEVICE
ReachabilityStrategy  = USB_PRESENCE
```

No fue necesario fabricar valores artificiales para:

```text
IP
TCP
SSID
```

El endpoint pudo describirse correctamente utilizando propiedades propias de
su transporte.

Esto confirma:

> La abstracción común debe normalizar diferencias, no borrarlas.

Un endpoint genérico no significa que todos los transportes deban fingir ser
TCP/IP.

---

## 63. La existencia de una cola USB no demuestra la presencia física del dispositivo

Con la Brother USB desconectada, Windows conservó:

```text
Brother HL-1210W series USB
```

como cola instalada.

Sin embargo:

```text
USB_PRESENCE
```

produjo:

```text
Reachable         = False
ReachabilityState = UNREACHABLE
ProbeResult       = USB_DEVICE_NOT_PRESENT
```

Por lo tanto:

```text
cola instalada
    !=
dispositivo presente
```

Esto es equivalente conceptualmente a otros casos donde configuración y
realidad operacional deben mantenerse separadas.

La cola constituye evidencia de configuración.

La estrategia de reachability aporta evidencia de disponibilidad actual.

---

## 64. Un endpoint USB inaccesible no autoriza recuperación Wi-Fi

La ausencia física de la Brother USB produjo:

```text
USB_ENDPOINT_UNREACHABLE
```

pero:

```text
SwitchDecision   = NO_WIFI_ACTION
SwitchAuthorized = False
SwitchExecuted   = False
```

Esto valida físicamente una conclusión que previamente era principalmente
arquitectónica:

> La estrategia de recuperación debe estar condicionada por el transporte del
> endpoint.

El razonamiento:

```text
impresora inaccesible
        |
        v
cambiar Wi-Fi
```

es incorrecto.

La secuencia correcta comienza por:

```text
endpoint inaccesible
        |
        v
¿qué transporte utiliza?
        |
        v
¿qué tipo de recuperación tiene sentido para ese transporte?
```

---

## 65. Discovery puede reemplazar inventario manual sin convertirse en Policy

Durante el Punto 4 `PrinterDiscovery` pasó a ser la fuente operacional para
conocer las colas existentes.

Esto permitió eliminar de QueueWatcher la dependencia de:

```text
config/printers.json
```

para seleccionar impresoras.

La información:

```text
qué cola existe
qué driver utiliza
qué puerto utiliza
qué endpoint representa
```

puede derivarse de Windows.

Sin embargo esto no elimina la necesidad de Policy.

Windows puede decir:

```text
esta cola existe
```

pero no necesariamente:

```text
PrintSwitch está autorizado a cambiar de red para recuperarla
```

Por lo tanto:

```text
Discovery elimina inventario redundante
```

sin implicar:

```text
Discovery reemplaza intención del usuario
```

---

## 66. Descubrir automáticamente no significa seleccionar arbitrariamente

QueueWatcher puede recibir:

```text
-PrinterName
```

y seleccionar la cola correspondiente dentro de los `QueueContext`
descubiertos.

También puede operar de forma directa cuando existe una única cola física
candidata.

Sin embargo, si existen múltiples candidatas y no hay información suficiente
para seleccionar una, el sistema no debe elegir silenciosamente.

La lección es:

> Automatizar descubrimiento no justifica ocultar ambigüedad.

Una selección automática sólo es segura cuando la evidencia disponible produce
una elección no ambigua.

---

## 67. QueueWatcher no necesita conocer cómo se descubrió técnicamente el endpoint

Después de la integración del Punto 4, QueueWatcher consume:

```text
QueueContext
```

en lugar de reconstruir información de impresora por su cuenta.

Esto permite que la cola pueda representar:

```text
Epson / IPv4
Brother / hostname
Brother / USB
```

sin que QueueWatcher necesite implementar reglas específicas para cada caso.

La lección general es:

> Un consumidor debe depender del contrato normalizado y no repetir la lógica
> que produjo ese contrato.

Esto reduce duplicación y evita divergencias entre componentes.

---

## 68. Recovery habilitado significa permiso y no obligación

El Punto 5 permitió comprobar esta propiedad desde QueueWatcher y no solamente
desde pruebas aisladas del Orchestrator.

Con:

```text
-EnableRecovery
```

y la Epson ya alcanzable mediante:

```text
suarezcores
```

el sistema produjo:

```text
EXISTING_REACHABLE_PATH

SwitchDecision   = NO_ACTION
SwitchAuthorized = False
SwitchExecuted   = False
```

Por lo tanto:

```text
EnableRecovery
      |
      v
puede actuar si la evidencia lo justifica
```

y no:

```text
EnableRecovery
      |
      v
debe cambiar la red
```

Esta diferencia es esencial para que el modo operacional pueda permanecer
habilitado sin provocar modificaciones innecesarias.

---

## 69. El trabajo de impresión puede ser el estímulo real del recovery completo

Se validó la secuencia:

```text
Wi-Fi = Claro640
Ethernet desconectado
Epson encendida
suarezcores visible
Recovery habilitado
```

Un trabajo real ingresó a:

```text
L365 Series(Red)
```

QueueWatcher lo detectó.

El endpoint:

```text
192.168.1.108:515
```

no era alcanzable desde la situación inicial.

El pipeline terminó ejecutando:

```text
Claro640
   |
   v
suarezcores
```

y posteriormente confirmó:

```text
NetworkSwitchVerified       = True
RecoveryValidationConfirmed = True
RecoverySucceeded           = True
RecoveryConfirmed           = True
SwitchExecuted              = True
FinalClassification         = CONTEXTUAL_RECOVERY_SUCCESS
```

La importancia de esta prueba es que no se ejecutó solamente un componente
aislado.

Se validó:

```text
evento real
   |
   v
QueueWatcher
   |
   v
Orchestrator
   |
   v
decisión
   |
   v
NetworkManager
   |
   v
RecoveryValidator
```

---

## 70. El éxito del recovery requiere comprobar el efecto buscado

Después del cambio:

```text
Claro640 -> suarezcores
```

el sistema no consideró suficiente observar que Windows estuviera conectado al
SSID nuevo.

También se verificó:

```text
192.168.1.108:515
```

y externamente:

```text
TcpTestSucceeded = True
```

Esto refuerza una regla previamente establecida:

> La acción ejecutada y el objetivo alcanzado son hechos diferentes.

En términos generales:

```text
acción realizada
    !=
problema resuelto
```

El éxito debe asociarse a la recuperación del recurso operacional que motivó
la intervención.

---

## 71. El happy path integrado es tan importante como el recovery

También se ejecutó:

```text
Wi-Fi = suarezcores
Ethernet desconectado
Epson encendida
Recovery habilitado
```

El trabajo ingresó a la cola y QueueWatcher ejecutó el pipeline.

El endpoint ya era alcanzable.

El resultado fue:

```text
UNIQUE_REACHABLE_PATH
EXISTING_REACHABLE_PATH
NO_ACTION
```

sin modificar Wi-Fi.

Esta prueba demuestra que integrar más componentes no alteró el principio de
mínima intervención.

El pipeline completo puede ejecutarse y concluir correctamente:

```text
no hacer nada
```

---

## 72. ConnectivityAnalyzer estaba duplicando conocimiento que ya pertenecía al pipeline

La auditoría previa al Punto 6 detectó que `ConnectivityAnalyzer` todavía
utilizaba conceptos de una arquitectura anterior.

Entre ellos:

```text
printers.json
RequiredSSID
NETWORK_MISMATCH
TCP 9100
TCP 80
```

El problema no era que esas ideas hubieran sido incorrectas cuando fueron
introducidas.

El problema era que el sistema había evolucionado.

El endpoint operacional ya podía obtenerse mediante:

```text
PrinterEndpointResolver
```

y la autorización de recovery pertenecía a:

```text
Policy
```

Por lo tanto ConnectivityAnalyzer estaba comenzando a duplicar
responsabilidades de otras capas.

La auditoría confirma una lección de mantenimiento:

> Una dependencia correcta en una versión puede convertirse en deuda
> arquitectónica cuando aparece una fuente de verdad mejor.

---

## 73. Un componente diagnóstico debe recibir el objeto que diagnostica

`ConnectivityAnalyzer v0.6` dejó de descubrir por sí mismo:

```text
IP
SSID requerido
puerto supuesto
```

Su contrato pasó a recibir:

```text
PrinterName
TargetIP
TcpPort
```

La información operacional llega desde capas anteriores.

Esto produce:

```text
Resolver
   |
   v
endpoint operacional
   |
   v
ConnectivityAnalyzer
   |
   v
diagnóstico
```

en lugar de:

```text
Resolver ------------------+
                           |
config manual -> Analyzer  |
                           |
dos interpretaciones ------+
del mismo destino
```

La lección es:

> Si una capa ya resolvió una identidad operacional, las capas posteriores
> deberían consumir ese resultado salvo que tengan una responsabilidad
> explícita de revalidarlo.

---

## 74. ICMP es evidencia auxiliar cuando el servicio real es TCP

`ConnectivityAnalyzer v0.6` conserva Ping como información diagnóstica.

Sin embargo la clasificación operacional se apoya en:

```text
TargetIP:TcpPort
```

recibido.

Para Epson:

```text
192.168.1.108:515
```

y para Brother Network:

```text
192.168.100.12:515
```

ambos produjeron:

```text
OperationalTcpSucceeded = True
Classification          = PRINTER_REACHABLE
```

La lección es:

> Alcanzar un host y alcanzar el servicio que PrintSwitch necesita son
> afirmaciones distintas.

ICMP puede aportar contexto.

No debe sustituir la prueba del endpoint operacional.

---

## 75. El puerto operacional tampoco debe ser una constante global

Durante etapas anteriores se utilizaron puertos como:

```text
9100
80
515
```

en distintos contextos.

La evolución endpoint-aware demuestra que el puerto correcto debe ser una
propiedad del endpoint.

Por lo tanto:

```text
TcpPort = 515
```

es correcto para las colas LPR actualmente observadas, pero no constituye una
verdad universal sobre impresoras.

La regla general es:

```text
endpoint
   |
   +--> protocolo
   |
   +--> destino
   |
   +--> puerto
```

y no:

```text
impresora
   |
   v
usar siempre puerto X
```

---

## 76. La auditoría cruzada debe formar parte del desarrollo antes de ampliar funcionalidades

Antes del Punto 6 se revisaron:

```text
dependencias
configuraciones
invocaciones
contratos
referencias legacy
parsers
```

Esta revisión encontró la dependencia residual de ConnectivityAnalyzer.

El hallazgo apareció antes de comenzar las pruebas excepcionales.

Esto demuestra el valor de realizar auditorías entre etapas arquitectónicas.

Una prueba funcional puede responder:

```text
¿funciona este escenario?
```

pero una auditoría de dependencias puede responder:

```text
¿funciona por la arquitectura que creemos tener?
```

Ambas preguntas son necesarias.

---

## 77. El core moderno ya no necesita `printers.json` como fuente operacional

Después de la auditoría, el pipeline moderno queda basado en:

```text
Windows
PrinterDiscovery
PrinterEndpointResolver
PrinterEndpointReachability
policy.json
```

`printers.json` permanece en el repositorio porque existen:

```text
herramientas legacy
herramientas experimentales
historia del proyecto
```

que todavía pueden referenciarlo.

Esto no contradice el diseño vigente.

La lección es:

> Eliminar una dependencia del core no obliga a borrar inmediatamente todos los
> artefactos históricos que alguna vez la utilizaron.

Lo importante es distinguir claramente:

```text
operacional vigente
```

de:

```text
legacy / experimental
```

---

## 78. La compatibilidad con una segunda impresora no equivale todavía a universalidad

La validación Brother aumenta considerablemente la evidencia de generalidad.

Ahora existen casos comprobados de:

```text
dos fabricantes
IPv4
hostname
NETWORK
USB
LPR
USB_PRESENCE
```

Sin embargo esto no demuestra todavía compatibilidad universal con:

```text
todos los monitores de puerto
todos los protocolos
WSD
IPP
RAW
impresoras compartidas
otros drivers propietarios
múltiples interfaces simultáneas
```

La conclusión correcta es:

```text
la arquitectura mostró capacidad de generalización
```

y no:

```text
la arquitectura ya soporta cualquier impresora
```

Mantener esta diferencia evita transformar evidencia limitada en una promesa
arquitectónica excesiva.

---

## 79. Una beta debe construirse sobre regresiones y no sólo sobre happy paths acumulados

Después de los Puntos 1 a 5 existe evidencia suficiente para considerar cercana
una primera beta.

Sin embargo el siguiente paso no debe ser inmediatamente la UI.

Antes deben probarse situaciones donde las premisas habituales fallen.

Entre ellas pueden aparecer:

```text
red inesperada
endpoint ambiguo
hostname no resoluble
múltiples caminos
interfaces cambiantes
dispositivo ausente
información parcial
contradicciones entre fuentes
```

El objetivo del Punto 6 será descubrir qué ocurre cuando la realidad no
coincide con el camino utilizado durante el desarrollo.

La lección metodológica es:

> Una arquitectura no está suficientemente probada porque todos sus escenarios
> diseñados funcionen.
>
> También debe observarse qué hace cuando las condiciones dejan de parecerse a
> aquellas con las que fue construida.

---

## 80. Los casos excepcionales deben diseñarse antes de ejecutarse

Para evitar adaptar la interpretación después de conocer el resultado, cada
prueba del Punto 6 deberá definir previamente:

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

La configuración inicial debe incluir explícitamente cuando corresponda:

```text
Wi-Fi inicial
Ethernet
Epson
Brother
USB
estado de alimentación
SSID visibles
Recovery habilitado o deshabilitado
```

Esto permite comparar:

```text
lo que creíamos que debía ocurrir
```

contra:

```text
lo que realmente ocurrió
```

sin reconstruir retrospectivamente la hipótesis.

---

## 81. La configuración inicial es parte de la evidencia experimental

Durante las pruebas físicas se comprobó que pequeñas diferencias de contexto
cambian radicalmente el significado del resultado.

Por ejemplo:

```text
Wi-Fi = Claro640
```

no es información suficiente si no se conoce además:

```text
Ethernet
impresora encendida
USB
SSID disponibles
endpoint esperado
modo Execute/Recovery
```

Por lo tanto, desde el Punto 6 la configuración inicial no debe considerarse
una nota auxiliar.

Debe formar parte del registro de evidencia de cada prueba.

La regla metodológica pasa a ser:

> Ningún resultado físico debe interpretarse sin registrar previamente el
> estado relevante del entorno.

---

## 82. La tercera red Wi-Fi permite introducir variabilidad controlada

El entorno físico disponible actualmente permite trabajar al menos con:

```text
suarezcores
Claro640
Suarez
```

Estas redes no deben utilizarse solamente como caminos hacia diferentes
impresoras.

También pueden servir para construir condiciones deliberadamente extrañas y
comprobar cómo reacciona el sistema ante cambios de contexto.

Esto permite diseñar casos donde:

```text
la red actual no es la esperada

un hostname deja de resolverse

un endpoint pertenece a otra subred

una red candidata existe pero no conduce al recurso

la conectividad general y la conectividad de impresión divergen
```

La existencia de varias redes controlables convierte el entorno doméstico de
prueba en un pequeño laboratorio de regresión de conectividad.

---

## 83. El principio de evidencia positiva evoluciona hacia degradación por evidencia

Hasta ahora una regla central fue:

```text
actuar únicamente con evidencia positiva suficiente
```

Las pruebas recientes permiten formular una evolución futura:

```text
evidencia completa y coherente
        |
        v
decisión normal

evidencia parcial
        |
        v
capacidad reducida

evidencia contradictoria
        |
        v
no asumir certeza

evidencia insuficiente
        |
        v
estado seguro
```

Esta idea todavía no constituye una nueva capa implementada.

Se registra como dirección arquitectónica para una segunda etapa posterior al
roadmap actual.

En el futuro podrá evaluarse una capa capaz de preguntarse:

```text
¿la evidencia que Windows y los demás componentes me entregan
es suficiente, coherente y no contradictoria para ejecutar
esta política de forma segura?
```

Hasta entonces debe preservarse el comportamiento conservador ya implementado
para los estados de incertidumbre conocidos.

---

## 84. La fuente principal puede ser confiable sin considerarse infalible

Windows continúa siendo la principal fuente operacional para:

```text
colas
drivers
puertos
interfaces
rutas
estado de red
```

Sin embargo el diseño futuro no debería convertir:

```text
Windows dijo X
```

en:

```text
X necesariamente representa toda la realidad
```

Pueden existir situaciones donde una fuente:

```text
no responda
devuelva información vacía
entregue información parcial
mantenga estado obsoleto
se contradiga con evidencia activa
```

La arquitectura actual ya posee parte del comportamiento necesario mediante:

```text
UNKNOWN
falta de autorización
no intervención
validación posterior
```

Una futura capa de calidad de evidencia podrá formalizar este razonamiento de
manera transversal.

Esta mejora queda explícitamente fuera del alcance inmediato del Punto 6.

---

## 85. Conocimiento vigente al inicio del Punto 6

Después de completar los Puntos 3, 4 y 5 y la auditoría posterior, se consideran
respaldadas por evidencia las siguientes afirmaciones:

```text
[OK] la arquitectura funciona con más de un fabricante

[OK] el nombre comercial no tiene que coincidir con QueueName

[OK] un mismo dispositivo físico puede exponer múltiples colas

[OK] múltiples colas pueden representar transportes diferentes

[OK] NETWORK puede utilizar IPv4 literal

[OK] NETWORK puede utilizar hostname

[OK] un hostname puede resolverse dinámicamente a una IPv4 operacional

[OK] fallo de resolución de hostname produce UNKNOWN y no UNREACHABLE

[OK] UNKNOWN no autoriza intervención

[OK] USB requiere una estrategia de reachability propia

[OK] una cola USB puede existir aunque el dispositivo físico esté ausente

[OK] USB_DEVICE_NOT_PRESENT no justifica recovery Wi-Fi

[OK] PrinterDiscovery puede reemplazar inventario manual de colas

[OK] Discovery no reemplaza Policy

[OK] QueueWatcher consume QueueContext en lugar de reconstruir endpoints

[OK] selección automática no debe ocultar ambigüedad

[OK] EnableRecovery es permiso y no obligación

[OK] un trabajo real puede disparar el recovery completo

[OK] el recovery real Claro640 -> suarezcores fue validado físicamente

[OK] el endpoint Epson 192.168.1.108:515 fue recuperado y revalidado

[OK] el happy path integrado no modifica Wi-Fi innecesariamente

[OK] ConnectivityAnalyzer es consumidor del endpoint y no su descubridor

[OK] ConnectivityAnalyzer ya no necesita policy de SSID

[OK] ICMP es evidencia auxiliar y no sustituto del servicio operacional

[OK] TcpPort debe provenir del endpoint y no de una constante global

[OK] printers.json dejó de ser fuente operacional del core moderno

[OK] los artefactos legacy pueden conservarse sin gobernar el core

[OK] una auditoría de dependencias puede descubrir deuda que las pruebas
     funcionales no muestran

[OK] la arquitectura mostró generalización, pero todavía no universalidad

[OK] el Punto 6 debe probar escenarios adversos antes de iniciar la UI

[OK] la configuración inicial debe formar parte explícita de cada prueba
```

El baseline de código para comenzar las regresiones es:

```text
4730803
REFACTOR: desacopla diagnostico de configuracion legacy
```

A partir de este punto el objetivo deja de ser demostrar nuevamente que el
camino normal funciona.

El objetivo pasa a ser buscar deliberadamente situaciones capaces de romper,
confundir o contradecir los supuestos de la arquitectura antes de construir la
primera beta orientada a usuario.