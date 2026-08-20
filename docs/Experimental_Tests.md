# PrintSwitch — Registro de pruebas experimentales

## 1. Objetivo

Este documento registra las pruebas experimentales realizadas durante el desarrollo de PrintSwitch.

El objetivo no es únicamente conservar resultados, sino documentar:

- qué pregunta intentaba responder cada prueba;
- qué condiciones se establecieron;
- qué variables fueron modificadas;
- qué variables permanecieron constantes;
- qué herramientas se utilizaron;
- qué resultados fueron observados;
- qué conclusiones permite la evidencia;
- qué conclusiones NO permite la evidencia.

PrintSwitch adopta como principio metodológico no atribuir causas que no puedan demostrarse mediante la evidencia disponible.

---

# 2. Metodología general

Las pruebas se realizan modificando, cuando es posible, una sola variable relevante entre experimentos comparables.

Las variables principales consideradas son:

- SSID de la computadora;
- estado físico ON/OFF de la impresora;
- existencia de trabajos en la cola;
- accesibilidad IP;
- respuesta de servicios de red;
- estado informado por Windows;
- progreso del trabajo de impresión.

Se distinguen tres niveles de información:

### [OBSERVADO]

Dato obtenido directamente durante una prueba.

### [INFERIDO]

Conclusión razonable derivada de uno o más datos observados.

### [HIPÓTESIS]

Explicación posible que todavía requiere validación experimental.

Una respuesta negativa de una prueba no deberá interpretarse automáticamente como demostración de una causa.

Por ejemplo:

```text
Ping negativo
    ≠
Impresora apagada
```

Mientras que una respuesta positiva permite establecer evidencia de presencia:

```text
Servicio de la impresora responde
        ↓
Existe un dispositivo activo
capaz de responder en esa capa
```

---

# 3. CA-01 — Red incorrecta + impresora apagada

## Pregunta

¿Qué información proporciona Windows cuando existe un trabajo pendiente, la PC está fuera de la red esperada y la impresora está físicamente apagada?

## Condiciones

```text
PC                  Claro640
Impresora           Epson L365
Estado impresora    OFF
Puerto Windows      EPE2EB06:L365 SERIES
Trabajo pendiente   Sí
Modo                 Observación pasiva
```

## Herramientas

ConnectivityAnalyzer v0.1:

- `netsh wlan show interfaces`
- `Get-Printer`
- `Win32_Printer`
- `Win32_PrintJob`

Todavía no se realizaron pruebas activas de red.

## Resultado

### Red

```text
SSID        : Claro640
Estado      : conectado
Radio       : 802.11ax
```

### Get-Printer

```text
PrinterStatus : Error
JobCount      : 1
```

### Win32_Printer

```text
PrinterStatus         : 1
ExtendedPrinterStatus : 9
DetectedErrorState    : 1
WorkOffline           : False
```

### Trabajo

```text
JobId        : 3
Document     : 0221 _ Noticias, actualidad e información de La Plata, Berisso y Ensenada.
Status       : Error
JobStatus    : Error | Imprimiendo
TotalPages   : 16
PagesPrinted : 0
Size         : 64690152
```

## Observaciones

**[OBSERVADO]**

Windows detectó un error de impresión y conservó el trabajo.

**[OBSERVADO]**

`WorkOffline` permaneció en `False` a pesar de que la impresora estaba físicamente apagada.

## Conclusión

**[INFERIDO]**

Los estados pasivos consultados permiten detectar un problema de impresión, pero no permiten determinar por sí solos el estado físico ON/OFF de la impresora.

---

# 4. CA-02 — Red incorrecta + impresora encendida

## Pregunta

¿Cambian los indicadores pasivos de Windows si se enciende la impresora pero la computadora continúa conectada a una red desde la cual no puede alcanzarla?

## Variable modificada

```text
Epson OFF → Epson ON
```

## Variables mantenidas

```text
SSID              Claro640
Trabajo           mismo trabajo pendiente
Configuración     sin cambios
```

## Resultado

Los principales indicadores permanecieron iguales a CA-01:

```text
PrinterStatus         : Error
JobCount              : 1
PrinterStatus CIM     : 1
ExtendedPrinterStatus : 9
DetectedErrorState    : 1
WorkOffline           : False
JobStatus             : Error | Imprimiendo
PagesPrinted          : 0
```

## Observación

**[OBSERVADO]**

Encender físicamente la Epson no produjo diferencias observables en los indicadores pasivos consultados mientras la PC permaneció en `Claro640`.

## Conclusión

**[INFERIDO]**

Desde este contexto de red, los indicadores pasivos utilizados no permiten distinguir Epson ON de Epson OFF.

Esto no demuestra que ningún mecanismo de Epson o Windows pueda hacerlo. Solamente describe el comportamiento de los mecanismos probados en este escenario.

---

# 5. CA-03 — Cambio a la red de la impresora

## Pregunta

¿Qué ocurre con los estados de Windows y con el trabajo pendiente cuando la PC pasa desde `Claro640` a `suarezcores` con la Epson encendida?

## Variable modificada

```text
SSID:
Claro640 → suarezcores
```

## Condiciones mantenidas

```text
Epson                    ON
Trabajo                  pendiente
Intervención sobre cola  ninguna
```

## Resultado

### Red

```text
SSID : suarezcores
```

### Get-Printer

```text
PrinterStatus : Normal
JobCount      : 1
```

### Win32_Printer

```text
PrinterStatus         : 4
ExtendedPrinterStatus : 2
DetectedErrorState    : 2
WorkOffline           : False
```

### Trabajo

```text
JobId        : 3
Document     : 0221 _ Noticias, actualidad e información de La Plata, Berisso y Ensenada.
Status       : OK
JobStatus    : Imprimiendo
TotalPages   : 14
PagesPrinted : 2
Size         : 55724852
```

## Observaciones

**[OBSERVADO]**

Al conectarse la PC a `suarezcores`, el estado reportado por Windows cambió.

**[OBSERVADO]**

El mismo trabajo que permanecía en error comenzó a progresar sin ser reenviado manualmente.

**[OBSERVADO]**

Se registraron páginas impresas.

## Conclusión

**[INFERIDO]**

La restauración de conectividad hacia la impresora permitió que Windows recuperara automáticamente el trabajo pendiente.

Este comportamiento constituye una propiedad fundamental para PrintSwitch:

> Un trabajo retenido puede sobrevivir al período de inaccesibilidad y continuar cuando la conectividad apropiada es restaurada.

---

# 6. CA-04 — Impresora accesible y pruebas activas

## Pregunta

¿Qué señales positivas pueden obtenerse cuando la PC está en la red apropiada, la Epson está encendida y existe un trabajo activo?

## Condiciones

```text
PC             suarezcores
Epson          ON
IP conocida    192.168.1.108
Trabajo        entrada_rata_blanca.pdf
Páginas        2
```

## Herramientas adicionales

Se incorporaron pruebas activas:

- ICMP mediante `Test-Connection`;
- TCP 9100 mediante `Test-NetConnection`;
- TCP 80 mediante `Test-NetConnection`.

Estas pruebas generan tráfico de diagnóstico pero no modifican configuraciones.

Por este motivo, a partir de esta etapa `ConnectivityAnalyzer` deja de considerarse exclusivamente pasivo y pasa a utilizar el concepto:

```text
DIAGNOSTICO NO INTRUSIVO
```

## Resultado

### Windows

```text
PrinterStatus         : Normal
PrinterStatus CIM     : 4
ExtendedPrinterStatus : 2
DetectedErrorState    : 2
WorkOffline           : False
```

### Trabajo

```text
JobId        : 6
Document     : entrada_rata_blanca.pdf
Status       : OK
JobStatus    : Imprimiendo
TotalPages   : 2
PagesPrinted : 0
Size         : 355580
```

### Conectividad

```text
PingSucceeded    : True
Tcp9100Succeeded : True
Tcp80Succeeded   : True
```

## Observaciones

**[OBSERVADO]**

La dirección `192.168.1.108` respondió mediante ICMP.

**[OBSERVADO]**

El puerto TCP 9100 aceptó conexión.

**[OBSERVADO]**

El puerto TCP 80 aceptó conexión.

**[OBSERVADO]**

Simultáneamente Windows informó la impresora como normal y el trabajo como `Imprimiendo`.

**[OBSERVADO]**

`PagesPrinted` todavía mostraba `0` durante esta captura a pesar de que el trabajo estaba en estado `Imprimiendo`.

## Conclusión

**[INFERIDO]**

La combinación de múltiples evidencias positivas permite establecer con alta confianza que la impresora es alcanzable.

Estado conceptual propuesto:

```text
PRINTER_REACHABLE
```

No se utilizará una única señal como condición exclusiva.

El campo `PagesPrinted` tampoco deberá utilizarse por sí solo como indicador instantáneo de progreso, ya que su actualización puede no coincidir exactamente con el momento físico de impresión.

---

# 7. CA-05 — Misma red + impresora apagada

## Pregunta

¿Qué señales desaparecen cuando la PC permanece en la red correcta pero la impresora es apagada?

Esta prueba busca aislar la variable física ON/OFF sin introducir simultáneamente un cambio de red.

## Procedimiento

Se realizó una impresión con la Epson disponible.

Posteriormente:

1. se esperó;
2. se apagó físicamente la impresora;
3. la PC permaneció conectada a `suarezcores`;
4. se ejecutó nuevamente `ConnectivityAnalyzer.ps1`.

## Variable modificada

```text
Epson ON → Epson OFF
```

## Variables mantenidas

```text
SSID : suarezcores
IP   : 192.168.1.108
```

## Resultado

### Get-Printer

```text
PrinterStatus : Normal
JobCount      : 0
```

### Win32_Printer

```text
PrinterStatus         : 3
ExtendedPrinterStatus : 2
DetectedErrorState    : 0
WorkOffline           : False
```

### Trabajos

```text
No se encontraron trabajos.
```

### Conectividad

```text
PingSucceeded    : False
Tcp9100Succeeded : False
Tcp80Succeeded   : False
```

## Observaciones

**[OBSERVADO]**

La impresora físicamente apagada dejó de responder a las tres pruebas activas realizadas.

**[OBSERVADO]**

`Get-Printer` continuó mostrando:

```text
PrinterStatus : Normal
```

**[OBSERVADO]**

`WorkOffline` continuó mostrando:

```text
False
```

**[OBSERVADO]**

La ausencia física de la impresora en la red no provocó que todos los indicadores pasivos de Windows representaran inmediatamente dicha situación.

## Conclusión

**[INFERIDO]**

El estado informado por Windows no constituye por sí solo una representación confiable del estado físico de la impresora.

Cuando la PC se encuentra en la red esperada pero no existe evidencia positiva de conectividad, PrintSwitch no deberá afirmar automáticamente que la impresora está apagada.

Estado conceptual propuesto:

```text
PRINTER_UNREACHABLE_ON_TARGET_NETWORK
```

Este estado significa:

> La impresora no pudo ser alcanzada mediante las pruebas realizadas desde la red esperada.

No significa necesariamente:

```text
PRINTER_POWERED_OFF
```

---

# 8. Comparación CA-01 / CA-02

Estas dos pruebas permiten analizar qué ocurre cuando cambia únicamente el estado físico de la impresora mientras la PC permanece fuera de la red esperada.

| Evidencia | CA-01 Epson OFF | CA-02 Epson ON |
|---|---|---|
| SSID | Claro640 | Claro640 |
| Get-Printer | Error | Error |
| JobCount | 1 | 1 |
| ExtendedPrinterStatus | 9 | 9 |
| DetectedErrorState | 1 | 1 |
| WorkOffline | False | False |
| JobStatus | Error / Imprimiendo | Error / Imprimiendo |
| PagesPrinted | 0 | 0 |

## Hallazgo principal

**[OBSERVADO]**

Los mecanismos pasivos consultados no mostraron una diferencia útil entre Epson OFF y Epson ON mientras la computadora permaneció en `Claro640`.

**[INFERIDO]**

El contexto de red limita la capacidad de esos mecanismos para proporcionar información sobre el estado real del dispositivo.

---

# 9. Comparación CA-04 / CA-05

Estas pruebas constituyen actualmente el par experimental más limpio para evaluar presencia de red.

| Evidencia | CA-04 Epson ON | CA-05 Epson OFF |
|---|---|---|
| SSID | suarezcores | suarezcores |
| Get-Printer | Normal | Normal |
| WorkOffline | False | False |
| Ping | True | False |
| TCP 9100 | True | False |
| TCP 80 | True | False |
| Trabajo | Imprimiendo | Ninguno |

La variable principal modificada fue el estado físico de la Epson.

## Hallazgo principal

Los indicadores activos de conectividad presentaron una diferencia clara entre ambos escenarios.

Los indicadores pasivos de Windows no reflejaron de manera equivalente dicha diferencia.

Esto refuerza la necesidad de utilizar varias fuentes de evidencia.

---

# 10. Modelo de evidencia resultante

A partir de las pruebas realizadas comienza a surgir la siguiente jerarquía conceptual:

```text
CONTEXTO
   │
   ├── SSID actual
   └── red esperada
          │
          ▼
EVIDENCIA WINDOWS
   │
   ├── PrinterStatus
   ├── ExtendedPrinterStatus
   ├── DetectedErrorState
   ├── WorkOffline
   └── JobStatus
          │
          ▼
EVIDENCIA DE RED
   │
   ├── ICMP
   ├── TCP 9100
   └── TCP 80
          │
          ▼
EVIDENCIA DE PROCESO
   │
   ├── trabajo aceptado
   ├── trabajo imprimiendo
   ├── páginas procesadas
   └── trabajo completado
```

Ninguna capa negativa deberá atribuir automáticamente una causa física.

En cambio, la evidencia positiva permite incrementar progresivamente la confianza sobre la presencia y disponibilidad del dispositivo.

---

# 11. Estados conceptuales propuestos

A partir de las pruebas realizadas se proponen inicialmente los siguientes estados.

## NETWORK_MISMATCH

La computadora no está conectada a la red esperada para alcanzar la impresora.

Este estado no permite determinar si la impresora está encendida o apagada.

---

## PRINTER_REACHABLE

Existe evidencia positiva suficiente de que la impresora puede ser alcanzada.

La evidencia puede incluir varias señales concurrentes:

```text
ICMP positivo
TCP 9100 positivo
TCP 80 positivo
estado Windows compatible
trabajo progresando
```

No todas las señales deberán ser necesariamente obligatorias en futuras implementaciones.

---

## PRINTER_UNREACHABLE_ON_TARGET_NETWORK

La computadora se encuentra en la red esperada pero las comprobaciones realizadas no consiguieron alcanzar la impresora.

Este estado no deberá traducirse automáticamente como:

```text
impresora apagada
```

Entre las posibles causas podrían encontrarse:

- impresora apagada;
- impresora desconectada del Wi-Fi;
- cambio de dirección IP;
- configuración de red modificada;
- servicio no disponible;
- problema de conectividad;
- información almacenada desactualizada.

Estas posibilidades son hipótesis hasta obtener evidencia adicional.

---

## INSUFFICIENT_EVIDENCE

La información disponible no permite realizar una clasificación más precisa.

Este estado se considera válido.

PrintSwitch deberá poder reconocer:

> No tengo evidencia suficiente para determinar la causa.

en lugar de inventar una explicación.

---

# 12. Principios confirmados hasta CA-05

Hasta CA-05 la evidencia permite establecer:

1. Windows puede conservar trabajos cuando la impresora no es alcanzable.

2. Un trabajo pendiente puede recuperarse automáticamente cuando se restaura la conectividad adecuada.

3. `PrinterStatus`, `WorkOffline` y otros estados de Windows no deben interpretarse aisladamente como representación del estado físico real de la impresora.

4. Una respuesta positiva de red constituye evidencia fuerte de presencia.

5. Una respuesta negativa de red demuestra ausencia de respuesta en esa prueba, pero no demuestra automáticamente su causa.

6. La combinación:

```text
ICMP positivo
+
TCP 9100 positivo
+
TCP 80 positivo
+
estado de impresión compatible
```

constituye actualmente una firma experimental fuerte de:

```text
PRINTER_REACHABLE
```

7. El fallo simultáneo de las pruebas activas desde la red esperada justifica:

```text
PRINTER_UNREACHABLE_ON_TARGET_NETWORK
```

pero no permite concluir automáticamente:

```text
PRINTER_POWERED_OFF
```

8. PrintSwitch deberá distinguir al menos:

```text
NETWORK_MISMATCH
PRINTER_REACHABLE
PRINTER_UNREACHABLE_ON_TARGET_NETWORK
INSUFFICIENT_EVIDENCE
```

9. El estado físico de la impresora y la ubicación de red son problemas diferentes y deberán analizarse por separado.

10. PrintSwitch deberá privilegiar evidencia positiva y acumulativa antes que inferencias basadas exclusivamente en ausencia de respuesta.

---

# 13. Descubrimiento futuro

Las pruebas actuales utilizan una dirección conocida:

```text
192.168.1.108
```

Sin embargo, el diseño futuro no deberá asumir que dicha dirección será siempre válida.

Se contempla una estrategia de descubrimiento progresivo:

```text
Información conocida
        ↓
Red esperada
        ↓
IP conocida
        ↓
¿responde?
   ├── SÍ
   │    ↓
   │ continuar diagnóstico
   │
   └── NO
        ↓
buscar candidatos
        ↓
filtrar por evidencia
        ↓
resolver identidad
```

El descubrimiento deberá intentar reducir candidatos antes de realizar verificaciones más profundas.

Ejemplo conceptual:

```text
Dispositivos visibles
        ↓
bloques MAC compatibles
        ↓
candidatos de fabricante
        ↓
MAC completa
hostname
servicios
IP
        ↓
identidad probable
```

Una coincidencia de fabricante no será suficiente para identificar una impresora específica.

---

# 14. Descubrimiento entre múltiples redes

Como capacidad futura y mecanismo de recuperación extrema, PrintSwitch podrá investigar el caso en que la impresora haya dejado de encontrarse en la red almacenada en su perfil.

Conceptualmente:

```text
Red esperada
      ↓
impresora no encontrada
      ↓
descubrimiento local
      ↓
sin resultado
      ↓
CrossNetworkDiscovery
      ↓
redes conocidas disponibles
      ↓
búsqueda progresiva
```

Este mecanismo no deberá formar parte inicialmente del camino normal de impresión.

PrintSwitch tampoco deberá actualizar silenciosamente la red persistente de una impresora únicamente porque encuentre un dispositivo compatible en otra red.

La identidad deberá alcanzar un nivel de confianza suficiente.

---

# 15. Router como evidencia futura

Cuando sea técnicamente posible, el router podrá utilizarse como una fuente adicional de evidencia.

Entre los datos potencialmente útiles se encuentran:

```text
IP asignada
MAC
hostname
concesión DHCP
dispositivo asociado
```

Esta integración deberá ser opcional.

El funcionamiento básico de PrintSwitch no deberá depender de disponer de credenciales administrativas del router.

La presencia de un dispositivo en información proporcionada por el router podrá utilizarse como evidencia de presencia, pero deberá interpretarse según la naturaleza y actualidad de los datos proporcionados por dicho router.

---

# 16. Próximas pruebas

Las siguientes pruebas deberán investigar progresivamente:

- comportamiento de las pruebas activas desde una red incorrecta;
- comportamiento de ARP;
- identificación mediante MAC;
- diferencia entre IP conocida pero dispositivo ausente e IP modificada;
- información disponible mediante el puerto Epson `EPE2EB06:L365 SERIES`;
- descubrimiento dentro de la LAN;
- comportamiento ante DHCP dinámico;
- recuperación de trabajos después de períodos prolongados de inaccesibilidad;
- comportamiento con más de un trabajo simultáneo;
- comportamiento cuando la impresora se apaga durante una impresión;
- comportamiento cuando la conectividad se pierde durante una impresión;
- comportamiento cuando la conectividad vuelve sin intervención del usuario;
- diferencias entre estado del Spooler y estado físico observable;
- futura validación con impresoras de otros fabricantes.

No deberán incorporarse conclusiones fuertes al futuro `DecisionEngine` hasta contar con evidencia experimental suficiente.

---

# 17. Regla metodológica central

PrintSwitch deberá distinguir permanentemente entre:

```text
NO PUEDO ALCANZAR LA IMPRESORA
```

y:

```text
SÉ POR QUÉ NO PUEDO ALCANZAR LA IMPRESORA
```

La primera afirmación puede obtenerse mediante pruebas de conectividad.

La segunda requiere evidencia adicional.

Del mismo modo:

```text
NO RESPONDE
```

no equivale automáticamente a:

```text
ESTÁ APAGADA
```

Mientras que:

```text
RESPONDE
```

sí constituye evidencia positiva de que existe un dispositivo activo capaz de comunicarse mediante la capa probada.

Este principio deberá orientar el diseño de `ConnectivityAnalyzer`, `DecisionEngine`, `PrinterDiscovery` y los futuros mecanismos de recuperación de PrintSwitch.
# 19. Validación de ConnectivityAnalyzer v0.2

## Objetivo

Validar que una misma lógica de clasificación pueda distinguir correctamente tres escenarios distintos sin modificar la red ni la impresora.

## Estados evaluados

### Escenario A — Red incorrecta

```text
PC              Claro640
Epson           ON
SSID esperado   suarezcores
Ping            False
TCP 9100        False
HTTP 80         False

# 20. Validación integrada — QueueWatcher + ConnectivityAnalyzer

## Objetivo

Validar que PrintSwitch pueda ejecutar de manera integrada el siguiente flujo:

```text
trabajo de impresión
        ↓
QueueWatcher
        ↓
detección de evento
        ↓
ConnectivityAnalyzer
        ↓
clasificación
        ↓
decisión propuesta
        ↓
DRY-RUN
```

La prueba no busca todavía modificar la conectividad.

El objetivo es comprobar que los componentes puedan comunicarse correctamente y que la decisión resultante sea coherente con el entorno observado.

---

## Arquitectura probada

```text
Windows / Print Spooler
        ↓
trabajo nuevo
        ↓
QueueWatcher v0.2
        ↓
ConnectivityAnalyzer v0.3.1
        ↓
PSCustomObject
        ↓
Classification
        ↓
switch de decisión
        ↓
acción propuesta
        ↓
DRY-RUN
```

ConnectivityAnalyzer v0.3.1 devuelve un objeto estructurado que QueueWatcher puede consumir directamente.

No resulta necesario interpretar texto de consola para conocer la clasificación.

---

# 20.1 Integración A — NETWORK_MISMATCH

## Pregunta

¿Puede QueueWatcher detectar automáticamente un trabajo y reconocer, mediante ConnectivityAnalyzer, que la PC está conectada a una red diferente de la requerida por la impresora?

## Condiciones

```text
PC                Claro640
SSID requerido    suarezcores
Impresora         L365 Series(Red)
Modo              DRY-RUN
```

El estado físico ON/OFF de la Epson no constituye una variable relevante para esta clasificación.

## Flujo observado

```text
trabajo enviado
      ↓
QueueWatcher detecta trabajo
      ↓
ConnectivityAnalyzer ejecutado
      ↓
SSID actual = Claro640
SSID requerido = suarezcores
      ↓
NETWORK_MISMATCH
```

## Decisión obtenida

```text
ACCION PROPUESTA:
cambiar a 'suarezcores'

DRY-RUN:
NO se modifico la red
```

## Conclusión

**[OBSERVADO]**

QueueWatcher pudo ejecutar ConnectivityAnalyzer y consumir su clasificación.

**[OBSERVADO]**

El programa reconoció correctamente que la PC no estaba conectada a la red esperada.

**[OBSERVADO]**

No se realizó ninguna modificación automática de conectividad.

**[INFERIDO]**

El flujo integrado puede utilizar `NETWORK_MISMATCH` como condición futura para solicitar al componente de administración de red un cambio de SSID.

---

# 20.2 Integración B — PRINTER_REACHABLE

## Pregunta

¿Puede PrintSwitch detectar que no necesita intervenir cuando la PC ya se encuentra en la red correcta y la impresora es alcanzable?

## Condiciones

```text
PC                suarezcores
SSID requerido    suarezcores
Epson             ON
Modo              DRY-RUN
```

Se envió un trabajo real de impresión.

## Evidencia observada

ConnectivityAnalyzer obtuvo:

```text
Ping           True
TCP 9100       True
HTTP 80        True
```

Clasificación:

```text
PRINTER_REACHABLE
```

## Decisión obtenida

```text
ACCION PROPUESTA: ninguna.
La impresora ya resulta alcanzable.
```

El trabajo continuó mediante el subsistema normal de impresión de Windows.

## Conclusión

**[OBSERVADO]**

QueueWatcher detectó correctamente el trabajo.

**[OBSERVADO]**

ConnectivityAnalyzer determinó que la impresora era alcanzable.

**[OBSERVADO]**

QueueWatcher interpretó correctamente `PRINTER_REACHABLE`.

**[OBSERVADO]**

PrintSwitch no propuso una modificación de red innecesaria.

**[DECISIÓN]**

Cuando la impresora ya resulta alcanzable, PrintSwitch deberá evitar modificar la conectividad.

---

# 20.3 Integración C — PRINTER_UNREACHABLE_ON_TARGET_NETWORK

## Pregunta

¿Qué decisión toma PrintSwitch cuando la PC se encuentra en la red esperada pero la impresora no puede ser alcanzada?

## Condiciones

```text
PC                suarezcores
SSID requerido    suarezcores
Epson             OFF
Modo              DRY-RUN
```

Se envió un trabajo de impresión.

## Evidencia observada

ConnectivityAnalyzer obtuvo:

```text
Ping           False
TCP 9100       False
HTTP 80        False
```

Clasificación:

```text
PRINTER_UNREACHABLE_ON_TARGET_NETWORK
```

## Decisión obtenida

```text
ACCION PROPUESTA: no cambiar de red.

La PC ya esta en la red esperada,
pero la impresora no responde.

No se infiere la causa fisica.
```

## Conclusión

**[OBSERVADO]**

PrintSwitch distinguió correctamente entre:

```text
red incorrecta
```

y:

```text
red correcta + impresora no alcanzable
```

**[OBSERVADO]**

No propuso cambiar de red cuando la PC ya se encontraba en `suarezcores`.

**[OBSERVADO]**

No afirmó que la impresora estuviera apagada.

**[DECISIÓN]**

`PRINTER_UNREACHABLE_ON_TARGET_NETWORK` no deberá transformarse automáticamente en una acción de cambio de SSID.

El siguiente paso deberá ser diagnóstico adicional, espera, descubrimiento o interacción con el usuario según la evolución futura del sistema.

---

# 20.4 Matriz integrada validada

| Contexto | Evidencia | Clasificación | Decisión DRY-RUN |
|---|---|---|---|
| Red incorrecta | SSID distinto | NETWORK_MISMATCH | Proponer cambio de red |
| Red correcta + impresora accesible | evidencia positiva | PRINTER_REACHABLE | No hacer nada |
| Red correcta + impresora inaccesible | pruebas negativas | PRINTER_UNREACHABLE_ON_TARGET_NETWORK | No cambiar red / no inferir causa |

---

# 20.5 Hito alcanzado

A partir de estas pruebas PrintSwitch deja de estar compuesto únicamente por herramientas experimentales independientes.

El sistema ya ejecuta un flujo funcional:

```text
ESPERAR
   ↓
DETECTAR
   ↓
ANALIZAR
   ↓
CLASIFICAR
   ↓
DECIDIR
   ↓
INFORMAR
   ↓
VOLVER A ESPERAR
```

Estado actual:

```text
Percibir    ✔
Relevar     ✔
Clasificar  ✔
Decidir     ✔ básico
Actuar      ✘
Verificar   ✘
Recuperar   ✘
```

La próxima etapa del core será comenzar a desarrollar el componente responsable de la administración de red:

```text
NetworkManager
```

Inicialmente deberá operar también en modo no destructivo / DRY-RUN.

# 21. Validación de NetworkManager v0.1

## Objetivo

Validar que PrintSwitch pueda analizar el estado de conectividad Wi-Fi de Windows y determinar si un cambio hacia una red objetivo parece posible, sin modificar todavía ninguna configuración.

NetworkManager v0.1 opera completamente en:

```text
DRY-RUN
```

y responde cuatro preguntas:

```text
¿A qué SSID está conectada la PC?
¿Windows conoce el perfil de la red objetivo?
¿La red objetivo está actualmente visible?
¿El cambio de red parece posible?
```

---

## Arquitectura probada

```text
Windows Wi-Fi
    │
    ├── SSID actual
    ├── perfiles conocidos
    └── redes visibles
          │
          ▼
   NetworkManager v0.1
          │
          ▼
     clasificación
          │
          ▼
   decisión propuesta
          │
          ▼
        DRY-RUN
```

NetworkManager no ejecuta todavía:

```text
netsh wlan connect
```

ni modifica perfiles Wi-Fi.

---

# 21.1 Caso A — Ya conectado a la red objetivo

## Condiciones

```text
SSID actual      suarezcores
SSID objetivo    suarezcores
Perfil conocido  True
Red visible      True
```

## Resultado

```text
ALREADY_ON_TARGET_NETWORK
```

## Decisión

```text
ACCION PROPUESTA: ninguna.
La PC ya esta conectada a 'suarezcores'.
```

## Conclusión

**[OBSERVADO]**

NetworkManager reconoció correctamente que no era necesario realizar ningún cambio de red.

---

# 21.2 Caso B — Cambio disponible

## Condiciones

```text
SSID actual           Claro640
SSID objetivo         suarezcores
Perfil conocido       True
Red visible           True
```

## Resultado

```text
NETWORK_SWITCH_AVAILABLE
```

## Decisión

```text
ACCION PROPUESTA:
Claro640 -> suarezcores

DRY-RUN:
El cambio parece posible, pero NO se ejecutara.
```

## Conclusión

**[OBSERVADO]**

NetworkManager pudo distinguir una situación en la que:

```text
la PC está en otra red
+
Windows conoce el perfil objetivo
+
la red objetivo está visible
```

y clasificó correctamente que un cambio parece disponible.

---

# 21.3 Caso C — Perfil inexistente

Para validar esta rama sin modificar perfiles reales se utilizó temporalmente:

```text
PrintSwitch_Red_Inexistente
```

## Condiciones

```text
SSID actual           Claro640
SSID objetivo         PrintSwitch_Red_Inexistente
Perfil conocido       False
Red visible           False
```

## Resultado

```text
TARGET_PROFILE_NOT_FOUND
```

## Decisión

```text
ACCION PROPUESTA: no conectar.
Windows no posee un perfil Wi-Fi conocido para
'PrintSwitch_Red_Inexistente'.
```

## Conclusión

**[OBSERVADO]**

NetworkManager priorizó correctamente la ausencia de un perfil conocido.

**[DECISIÓN]**

PrintSwitch no deberá intentar conectarse automáticamente a una red para la cual Windows no disponga de un perfil previamente configurado.

---

# 21.4 Caso D — Perfil conocido pero red no visible

Se utilizó:

```text
ESP32_Matriz
```

como caso experimental.

Windows posee un perfil guardado para dicha red, pero durante la prueba el dispositivo que genera ese SSID se encontraba desconectado.

## Condiciones

```text
SSID actual           Claro640
SSID objetivo         ESP32_Matriz
Perfil conocido       True
Red visible           False
```

## Resultado

```text
TARGET_NETWORK_NOT_VISIBLE
```

## Decisión

```text
ACCION PROPUESTA: esperar / informar.
El perfil existe, pero 'ESP32_Matriz'
no aparece entre las redes visibles.
```

## Conclusión

**[OBSERVADO]**

NetworkManager distinguió correctamente entre:

```text
perfil guardado
```

y:

```text
red actualmente disponible
```

**[DECISIÓN]**

La existencia de un perfil no deberá interpretarse como evidencia suficiente de que el SSID puede utilizarse en ese momento.

---

# 21.5 Matriz validada de NetworkManager v0.1

| Estado | Perfil conocido | Red visible | Clasificación |
|---|---:|---:|---|
| Ya conectado al objetivo | Sí | Sí | ALREADY_ON_TARGET_NETWORK |
| Otra red + objetivo disponible | Sí | Sí | NETWORK_SWITCH_AVAILABLE |
| Perfil inexistente | No | No / irrelevante | TARGET_PROFILE_NOT_FOUND |
| Perfil conocido pero no visible | Sí | No | TARGET_NETWORK_NOT_VISIBLE |

---

# 21.6 Árbol de decisión validado

```text
¿SSID actual == SSID objetivo?
        │
   ┌────┴────┐
   │         │
  SÍ        NO
   │         │
   ▼         ▼
ALREADY_   ¿Existe perfil?
ON_TARGET       │
NETWORK     ┌───┴───┐
            │       │
           NO      SÍ
            │       │
            ▼       ▼
        TARGET_   ¿Red visible?
        PROFILE_      │
        NOT_FOUND ┌───┴───┐
                  │       │
                 NO      SÍ
                  │       │
                  ▼       ▼
             TARGET_   NETWORK_
             NETWORK_  SWITCH_
             NOT_      AVAILABLE
             VISIBLE
```

---

# 21.7 Estado del componente

A partir de estas pruebas:

```text
NetworkManager v0.1

Observar red actual       ✔
Detectar perfil conocido  ✔
Detectar red visible      ✔
Clasificar                ✔
Proponer acción           ✔
Cambiar Wi-Fi             ✘
Verificar cambio          ✘
```

La próxima versión deberá investigar el cambio real de red de forma:

```text
aislada
manual
controlada
reversible
```

antes de integrarlo con QueueWatcher y ConnectivityAnalyzer.

---

# 21.8 Próximo objetivo

NetworkManager v0.2 deberá intentar un cambio real solamente cuando:

```text
Classification == NETWORK_SWITCH_AVAILABLE
```

El primer ensayo deberá realizarse de forma aislada, sin que QueueWatcher pueda dispararlo automáticamente.

Una vez validado el cambio real, deberá desarrollarse una etapa posterior de verificación que confirme:

```text
SSID solicitado
      ↓
cambio ejecutado
      ↓
SSID realmente conectado
```

Solo después de validar ambas etapas deberá considerarse la integración completa:

```text
QueueWatcher
      ↓
ConnectivityAnalyzer
      ↓
NETWORK_MISMATCH
      ↓
NetworkManager
      ↓
cambio real
      ↓
verificación
      ↓
ConnectivityAnalyzer nuevamente
      ↓
PRINTER_REACHABLE
```
# 22. Validación de NetworkManager v0.2 y v0.3

## Objetivo

Validar experimentalmente que NetworkManager pueda:

1. solicitar un cambio real de red Wi-Fi;
2. utilizar exclusivamente un perfil previamente conocido por Windows;
3. esperar durante la transición de la interfaz;
4. verificar que el SSID final sea efectivamente el solicitado.

Estas pruebas se realizaron todavía de forma aislada.

QueueWatcher y ConnectivityAnalyzer no participaron en la ejecución del cambio.

---

# 22.1 NetworkManager v0.2 — Primer cambio real

## Condiciones iniciales

```text
SSID inicial       Claro640
SSID objetivo      suarezcores
Perfil conocido    True
Red visible        True
```

NetworkManager clasificó:

```text
NETWORK_SWITCH_AVAILABLE
```

Antes de ejecutar la acción solicitó autorización explícita:

```text
Escriba SI para autorizar el cambio
```

La autorización fue concedida manualmente.

## Acción ejecutada

NetworkManager solicitó a Windows la conexión al perfil:

```text
suarezcores
```

Windows respondió:

```text
La solicitud de conexión se completó correctamente.
```

Durante el cambio se observó una breve interrupción de conectividad, consistente con la transición de la interfaz Wi-Fi entre ambos puntos de acceso.

La PC terminó conectada a:

```text
suarezcores
```

## Conclusión

**[OBSERVADO]**

NetworkManager pudo solicitar exitosamente un cambio real:

```text
Claro640
   ↓
suarezcores
```

**[OBSERVADO]**

El cambio utilizó un perfil Wi-Fi previamente configurado en Windows.

**[OBSERVADO]**

La transición produjo una breve interrupción de conectividad.

**[DECISIÓN]**

La aceptación del comando por parte de Windows no será considerada evidencia suficiente de éxito.

PrintSwitch deberá verificar posteriormente el estado real de la interfaz.

---

# 22.2 NetworkManager v0.3 — Verificación del cambio

## Objetivo

Distinguir entre:

```text
orden de cambio aceptada
```

y:

```text
cambio realmente completado
```

Para ello NetworkManager v0.3 vuelve a consultar el SSID después de solicitar la conexión.

---

## Condiciones

```text
SSID inicial       Claro640
SSID objetivo      suarezcores
Perfil conocido    True
Red visible        True
```

Clasificación inicial:

```text
NETWORK_SWITCH_AVAILABLE
```

El cambio fue autorizado manualmente.

Windows aceptó la solicitud.

---

## Comportamiento durante la transición

NetworkManager consultó repetidamente el estado de la interfaz.

Se obtuvo:

```text
Intento 1/10 - SSID detectado:
Intento 2/10 - SSID detectado:
Intento 3/10 - SSID detectado:
Intento 4/10 - SSID detectado: suarezcores
```

Durante los primeros intentos la interfaz se encontraba en transición y no reportó un SSID asociado.

En el cuarto intento Windows informó:

```text
suarezcores
```

---

## Resultado

```text
SSID inicial       : Claro640
SSID solicitado    : suarezcores
SSID final         : suarezcores
SwitchRequested    : True
CommandIssued      : True
SwitchVerified     : True
```

Resultado lógico:

```text
NETWORK_SWITCH_VERIFIED
```

Además se verificó externamente que la PC había quedado efectivamente conectada a `suarezcores`.

---

## Conclusión

**[OBSERVADO]**

La transición Wi-Fi no es instantánea.

**[OBSERVADO]**

Durante varios segundos Windows puede no reportar ningún SSID mientras cambia de asociación.

**[OBSERVADO]**

NetworkManager toleró correctamente ese estado transitorio.

**[OBSERVADO]**

El componente verificó el cambio únicamente cuando:

```text
FinalSSID == TargetSSID
```

**[DECISIÓN]**

PrintSwitch deberá distinguir siempre:

```text
CommandIssued
```

de:

```text
SwitchVerified
```

Una orden enviada no implica necesariamente una transición exitosa.

---

# 22.3 Observación adicional — visibilidad Wi-Fi transitoria

Durante una ejecución previa, NetworkManager obtuvo:

```text
TargetProfileKnown   : True
TargetNetworkVisible : False
```

para `suarezcores`.

El componente respondió correctamente:

```text
TARGET_NETWORK_NOT_VISIBLE
```

y no intentó modificar la conectividad.

Una consulta posterior de Windows mediante:

```text
netsh wlan show networks mode=bssid
```

mostró nuevamente `suarezcores` disponible.

Una nueva ejecución de NetworkManager también la detectó correctamente.

## Conclusión

**[OBSERVADO]**

La lista de redes Wi-Fi visibles puede presentar estados transitorios.

**[INFERIDO]**

Una única consulta negativa no debería considerarse necesariamente evidencia suficiente de indisponibilidad persistente.

**[DECISIÓN FUTURA]**

Antes de declarar:

```text
TARGET_NETWORK_NOT_VISIBLE
```

NetworkManager podrá realizar varios intentos de descubrimiento separados por una espera breve.

Esta mejora deberá implementarse antes o durante la maduración del componente.

---

# 22.4 Estado alcanzado

```text
NetworkManager

Detectar SSID actual           ✔
Detectar perfil conocido       ✔
Detectar red visible           ✔
Clasificar                     ✔
Proponer cambio                ✔
Solicitar autorización         ✔
Ejecutar cambio real           ✔
Esperar transición             ✔
Verificar SSID final           ✔
```

NetworkManager ya posee las capacidades mínimas necesarias para comenzar una integración controlada con el core de PrintSwitch.

---

# 22.5 Próximo hito

El siguiente experimento deberá integrar:

```text
QueueWatcher
      ↓
trabajo detectado
      ↓
ConnectivityAnalyzer
      ↓
NETWORK_MISMATCH
      ↓
NetworkManager
      ↓
NETWORK_SWITCH_AVAILABLE
      ↓
cambio Wi-Fi
      ↓
SwitchVerified
      ↓
ConnectivityAnalyzer
      ↓
PRINTER_REACHABLE
```

El éxito del cambio de red no será suficiente para considerar resuelto el problema.

PrintSwitch deberá comprobar posteriormente que la impresora se volvió realmente alcanzable.

Por lo tanto:

```text
cambiar de red
       ≠
impresión recuperada
```

El criterio de recuperación será evidencia posterior de conectividad con el destino de impresión.