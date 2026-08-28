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