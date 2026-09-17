# Metodología de ingeniería

## 1. Propósito

PrintSwitch se desarrolla mediante una metodología basada en evidencia experimental.

La documentación debe diferenciar claramente los comportamientos observados, los datos medidos, las conclusiones inferidas, las hipótesis pendientes y las decisiones de ingeniería.

El objetivo es evitar que una suposición sea presentada como un hecho comprobado.

---

## 2. Principio general

El flujo de trabajo del proyecto será:

```text
Observación
    ↓
Experimento
    ↓
Evidencia
    ↓
Conclusión
    ↓
Decisión de ingeniería
    ↓
Implementación
```

El código deberá construirse sobre conocimiento previamente documentado siempre que sea posible.

---

> **Nota de evolución documental — corte Alpha (27/08/2026)**
>
> Las secciones anteriores corresponden a la formulación inicial de la
> metodología de PrintSwitch.
>
> Se conservan como registro histórico y no se reemplazan, ya que reflejan
> los principios con los que comenzó la investigación.
>
> Con el crecimiento del proyecto, las pruebas reales y la incorporación de
> componentes de análisis, decisión, ejecución y validación permitieron
> formalizar una metodología de ingeniería más completa.
>
> Las secciones siguientes documentan esa metodología consolidada durante
> el desarrollo del Alpha.
>
> Lo anterior debe interpretarse como **metodología inicial histórica**;
> lo posterior a este punto representa la **metodología vigente del Alpha**.

# Metodología consolidada — Alpha

## 3. Ciclo experimental

El desarrollo de PrintSwitch sigue un ciclo incremental:

```text
observar
   |
medir
   |
formular hipótesis
   |
realizar cambio mínimo
   |
probar
   |
comparar resultado
   |
documentar
   |
integrar
```

La implementación no debe preceder a la comprensión del problema cuando
existe una forma razonable de observarlo experimentalmente.

---

## 4. Separación entre observado, inferido e hipotético

Toda investigación debe distinguir explícitamente entre:

```text
[OBSERVADO]
dato medido o comportamiento reproducido

[INFERIDO]
conclusión razonable derivada de evidencias

[HIPÓTESIS]
explicación todavía no validada
```

Esta separación evita convertir una interpretación provisional en una regla
arquitectónica.

---

## 5. Una variable por vez

Cuando sea posible, cada experimento debe modificar una sola condición.

Ejemplo:

```text
misma impresora
mismo trabajo
mismo equipo

cambiar solamente:
Wi-Fi
```

Esto permite atribuir el resultado a una causa con mayor confianza.

---

## 6. Casos positivos y negativos

Una capacidad no se considera suficientemente comprendida únicamente porque
funciona en el escenario esperado.

Se deben probar al menos:

```text
caso positivo
+
caso negativo
```

Ejemplo:

```text
impresora alcanzable
+
impresora no alcanzable
```

o:

```text
SSID visible
+
SSID no visible
```

---

## 7. Intervención mínima

El sistema debe preferir conservar el estado actual cuando ya existe una
solución válida.

Regla:

```text
camino válido existente
        |
        v
NO_ACTION
```

La intervención debe justificarse mediante evidencia.

---

## 8. Dry-run antes de ejecución

Las decisiones nuevas deben validarse inicialmente sin modificar el entorno.

Secuencia preferida:

```text
detectar
analizar
clasificar
mostrar decisión
```

y sólo después:

```text
autorizar ejecución
```

Esto permite validar la política antes de conceder capacidad de cambio real.

---

## 9. Separación de responsabilidades

Cada componente debe resolver un problema acotado.

La arquitectura Alpha separa:

```text
detección
análisis
política
decisión
ejecución
validación
```

Evitar lógica duplicada reduce divergencias entre comportamiento experimental
y comportamiento operativo.

---

## 10. No confiar en una única señal

Una señal aislada no debe utilizarse como prueba universal.

Ejemplos:

```text
SSID actual
estado de cola
ping
estado del driver
```

pueden aportar evidencia, pero no describen por sí solos toda la situación.

La decisión debe basarse en un conjunto coherente de observaciones.

---

## 11. Evidencia temporal

Algunos estados de red cambian rápidamente.

Por lo tanto, la metodología debe considerar:

```text
reintentos
ventanas de tiempo
polling controlado
verificación posterior
```

cuando la evidencia pueda ser transitoria.

---

## 12. Preservación del contexto

La solución no debe analizar únicamente su objetivo inmediato.

Debe considerar qué otras funciones puede estar sosteniendo la conectividad
existente.

Ejemplo:

```text
Ethernet
   |
   +--> Internet
   +--> Jabber
   +--> VPN
   +--> servicios locales
```

Por ello, PrintSwitch no modifica Ethernet durante la recuperación Alpha.

---

## 13. Validación física

Cuando el objetivo final es producir una impresión, una clasificación lógica
no sustituye completamente la evidencia física.

La validación más fuerte disponible es:

```text
trabajo detectado
      |
recuperación
      |
impresión física realizada
```

---

## 14. Separar conectividad de estado de impresora

Una impresora no accesible no implica automáticamente que la red sea
incorrecta.

Debe distinguirse:

```text
no existe camino hacia la red
```

de:

```text
existe camino
pero la impresora no responde
```

Esta distinción evita cambios de conectividad innecesarios.

---

## 15. Optimizar después de comprender

La optimización de latencia debe realizarse después de identificar el cuello
de botella.

Secuencia:

```text
medir
   |
identificar demora
   |
crear alternativa
   |
comparar
   |
validar
```

No se debe sacrificar observabilidad o corrección únicamente para reducir
tiempo de ejecución.

---

## 16. Integración progresiva

Una capacidad experimental debe integrarse al core sólo después de validar:

```text
caso positivo
caso negativo
efectos colaterales
contrato de salida
```

La integración debe reducir duplicación y mantener una única fuente de
decisión cuando sea posible.

---

## 17. Limpieza posterior a la integración

Después de integrar una capacidad se deben eliminar:

```text
rutas duplicadas
código experimental innecesario en producción
mensajes obsoletos
referencias legacy
```

sin eliminar archivos históricos que sigan siendo útiles como evidencia del
proceso experimental.

---

## 18. Documentar evolución, no reescribir el pasado

Los documentos de PrintSwitch conservan hipótesis y diseños anteriores.

Cuando una idea queda superada:

```text
contenido histórico
      |
      v
nota de corte
      |
      v
estado vigente
```

Esto permite reconstruir cómo evolucionó el razonamiento técnico.

---

## 19. Generalizar sólo con evidencia

Una solución validada con Epson L365 no debe considerarse automáticamente
universal.

La generalización debe esperar pruebas con:

```text
otros fabricantes
otros puertos
otros protocolos
otras topologías
```

Las reglas específicas del entorno experimental deben permanecer explícitas.

---

## 20. Principio metodológico consolidado

La metodología Alpha puede resumirse como:

> **Observar antes de inferir, medir antes de decidir, decidir antes de actuar
> y verificar después de actuar.**

Y ante una intervención de conectividad:

> **Si la evidencia disponible no justifica el cambio, la acción preferida
> es no intervenir.**

---

# Actualización metodológica — Preparación del Punto 6 — Septiembre 2026

> **Estado documental**
>
> Todo el contenido anterior se conserva como metodología histórica y
> consolidada del Alpha.
>
> La presente sección documenta la metodología vigente para la etapa posterior
> a los Puntos 1 a 5 y para la ejecución del Punto 6.
>
> El baseline técnico de referencia es:
>
> ```text
> 4730803
> REFACTOR: desacopla diagnostico de configuracion legacy
> ```
>
> La arquitectura llega a esta fase después de haber validado:
>
> ```text
> Epson Network
> Brother Network
> Brother USB
> IPv4
> HOSTNAME
> LPR
> USB_PRESENCE
> QueueWatcher integrado
> recovery físico
> no intervención
> auditoría de dependencias
> ```

---

## 21. Cambio de objetivo metodológico

Hasta el cierre del Punto 5, gran parte del trabajo experimental respondía a:

```text
¿podemos construir esta capacidad?
```

A partir del Punto 6 la pregunta principal cambia a:

```text
¿qué ocurre cuando intentamos romper,
confundir o contradecir
los supuestos de esa capacidad?
```

Por lo tanto, la metodología pasa de una etapa predominantemente de:

```text
construcción
+
validación positiva
```

a otra de:

```text
regresión
+
testing adverso
+
búsqueda de supuestos ocultos
```

El objetivo no es provocar fallos arbitrariamente.

El objetivo es descubrir:

```text
qué hipótesis implícitas existen
qué información falta en casos poco frecuentes
qué clasificaciones pueden ser ambiguas
qué acciones podrían ser inseguras
qué capacidades ya validadas podrían romperse
```

antes de comenzar la primera UI.

---

## 22. Una prueba adversa debe diseñarse antes de ejecutarse

Cada prueba del Punto 6 debe existir primero como diseño.

No debe ocurrir:

```text
ejecutar algo raro
        |
        v
mirar qué pasó
        |
        v
inventar después qué esperábamos
```

La secuencia correcta es:

```text
definir escenario
        |
        v
registrar configuración inicial
        |
        v
formular hipótesis
        |
        v
definir resultado esperado
        |
        v
ejecutar
        |
        v
registrar resultado real
        |
        v
comparar
```

Esto evita adaptar retrospectivamente la interpretación al resultado obtenido.

---

## 23. Estructura obligatoria de cada prueba

Cada prueba deberá documentarse con el siguiente contrato mínimo:

```text
Test ID

Nombre

Objetivo

Configuración inicial

Hipótesis

Resultado esperado

Acción / estímulo

Resultado obtenido

Check real

Observaciones

Hallazgo

Corrección necesaria

Regresión posterior
```

El identificador seguirá inicialmente el formato:

```text
P6-01
P6-02
P6-03
...
```

Los casos derivados podrán utilizar:

```text
P6-03A
P6-03B
```

cuando representen variaciones controladas del mismo escenario.

---

## 24. La configuración inicial forma parte de la evidencia

La configuración física y de red debe registrarse antes de cada experimento.

No se considera información auxiliar.

Forma parte de la evidencia necesaria para interpretar el resultado.

Cuando corresponda se registrará:

```text
Wi-Fi actual
SSID actual
Ethernet conectado/desconectado
Epson ON/OFF
Brother ON/OFF
USB conectado/desconectado
SSID visibles
Recovery habilitado/deshabilitado
cola utilizada
endpoint esperado
```

También podrán registrarse:

```text
IP local
gateway
resolución DNS/hostname
rutas relevantes
estado de adaptadores
```

si el caso lo requiere.

---

## 25. La configuración inicial debe expresarse de forma explícita

Toda instrucción de prueba deberá comenzar con una sección equivalente a:

```text
CONFIGURACIÓN INICIAL

Wi-Fi       : PRIMARY_INTERNET_SSID
Ethernet    : desconectado
Epson       : encendida
Brother     : encendida
USB Brother : desconectado
Recovery    : habilitado
SSID visibles:
    PRIMARY_INTERNET_SSID
    PRINTER_NETWORK_SSID
    Suarez
```

No debe utilizarse solamente:

```text
usar la configuración habitual
```

o:

```text
dejar todo como estaba
```

porque esas expresiones no producen evidencia reproducible.

---

## 26. Una variable relevante por vez cuando sea posible

La metodología histórica de modificar una sola variable continúa vigente.

En los casos adversos esto es especialmente importante.

Ejemplo incorrecto:

```text
cambiar Wi-Fi
apagar impresora
desconectar Ethernet
retirar USB
```

en una misma prueba sin necesidad.

Ejemplo preferido:

```text
estado inicial conocido
        |
        v
desaparece solamente el hostname resoluble
```

o:

```text
estado inicial conocido
        |
        v
se desconecta solamente USB
```

Si el escenario requiere múltiples cambios simultáneos, esto deberá declararse
explícitamente como parte del objetivo.

---

## 27. Hipótesis y resultado esperado no son lo mismo

La hipótesis describe la explicación o comportamiento que creemos que el
sistema debería seguir.

Ejemplo:

```text
si el endpoint ya es alcanzable por Ethernet,
PrintSwitch debería preservar ese camino
```

El resultado esperado debe ser más concreto:

```text
SwitchDecision   = NO_ACTION
SwitchAuthorized = False
SwitchExecuted   = False
```

Esta distinción permite comparar:

```text
idea conceptual
```

contra:

```text
salida verificable
```

---

## 28. Clasificación formal del resultado

Cada prueba deberá finalizar con una clasificación explícita.

Estados iniciales:

```text
PASS
FAIL
INCONCLUSO
```

### PASS

Se utiliza cuando:

```text
el comportamiento observado coincide con el esperado
y no aparece una regresión adicional relevante
```

### FAIL

Se utiliza cuando:

```text
el comportamiento observado contradice el resultado esperado
o revela una acción insegura
o rompe una capacidad previamente validada
```

### INCONCLUSO

Se utiliza cuando:

```text
la evidencia obtenida no permite decidir
si el sistema se comportó correctamente
```

`INCONCLUSO` no debe convertirse artificialmente en `PASS`.

---

## 29. Un FAIL es un resultado útil

Durante el Punto 6 un `FAIL` no significa que la batería haya fracasado.

Puede significar exactamente lo contrario:

```text
la prueba encontró un supuesto oculto
```

La secuencia esperada es:

```text
FAIL
  |
  v
describir evidencia
  |
  v
aislar causa
  |
  v
definir corrección mínima
  |
  v
implementar
  |
  v
repetir prueba
  |
  v
ejecutar regresiones
```

El objetivo no es maximizar la cantidad de `PASS`.

El objetivo es maximizar la comprensión antes de la beta.

---

## 30. No corregir durante la primera observación

Cuando una prueba revela un comportamiento inesperado, la primera prioridad es
preservar evidencia.

No debe ocurrir:

```text
resultado extraño
      |
      v
editar código inmediatamente
      |
      v
perder el estado original
```

La secuencia preferida será:

```text
resultado extraño
      |
      v
registrar salida
      |
      v
registrar configuración
      |
      v
confirmar reproducibilidad
      |
      v
analizar
      |
      v
recién después modificar
```

---

## 31. Evidencia cruda y conclusión deben permanecer separadas

La evidencia puede incluir:

```text
salida PowerShell
JSON
estado de interfaces
resolución de hostname
logs
git status
resultado estructurado
```

La conclusión es una interpretación posterior.

Por ejemplo:

```text
[OBSERVADO]
DESTINATION_RESOLUTION_FAILED
```

no equivale automáticamente a:

```text
[CONCLUSIÓN]
la impresora está apagada
```

La conclusión deberá limitarse a lo que la evidencia soporta.

---

## 32. La terminal no debe ser la única fuente de evidencia

Cuando una salida sea extensa debe persistirse en:

```text
docs/evidence/
```

o en otro archivo explícitamente destinado a evidencia.

Ejemplo:

```text
docs/evidence/P6-02-hostname-unresolved.txt
```

Esto evita:

```text
salida truncada
selección incompleta
pérdida del contexto de terminal
```

y permite reutilizar la evidencia para documentación y regresiones posteriores.

---

## 33. Convención sugerida para evidencia del Punto 6

Los archivos podrán seguir:

```text
P6-01-<descripcion>.txt
P6-02-<descripcion>.txt
P6-03-<descripcion>.txt
```

Cuando existan varias capturas de un mismo test:

```text
P6-03A-before.txt
P6-03A-after.txt
```

o:

```text
P6-03A-environment.txt
P6-03A-result.txt
```

La prioridad es que el nombre permita asociar rápidamente la evidencia con el
test correspondiente.

---

## 34. El estado Git forma parte del control experimental

Antes de una batería importante deberá registrarse:

```text
git status --short
git log -1 --oneline
```

El objetivo es conocer exactamente:

```text
qué código se está probando
```

y:

```text
si existen modificaciones locales
```

El baseline inicial del Punto 6 es:

```text
4730803
REFACTOR: desacopla diagnostico de configuracion legacy
```

Las modificaciones documentales posteriores no alteran el comportamiento
funcional del core.

---

## 35. Separar checkpoint funcional de checkpoint documental

Un commit documental puede modificar:

```text
Architecture_Observed.md
Knowledge.md
Roadmap.md
Methodology.md
index.md
```

sin cambiar el comportamiento del sistema.

Por lo tanto debe distinguirse:

```text
baseline funcional
```

de:

```text
checkpoint documental
```

El baseline funcional del Punto 6 continúa siendo conceptualmente el código
validado en:

```text
4730803
```

aunque posteriormente exista un commit adicional exclusivamente documental.

---

## 36. Regresión después de cada corrección funcional

Si una prueba del Punto 6 requiere modificar código, no alcanza con repetir
solamente el caso que falló.

Debe ejecutarse también una regresión mínima sobre capacidades relevantes.

El conjunto mínimo podrá incluir según el cambio:

```text
Epson Network alcanzable

Brother Network alcanzable

Brother USB conectado

Brother USB desconectado

recovery PRIMARY_INTERNET_SSID -> PRINTER_NETWORK_SSID

no intervención con camino funcional
```

No todas las pruebas necesitan ejecutarse después de cada modificación pequeña.

La selección debe depender de qué componentes fueron afectados.

---

## 37. Regresión dirigida por dependencia

Si se modifica:

```text
PrinterEndpointResolver
```

deben priorizarse casos:

```text
Epson
Brother Network
Brother USB
```

Si se modifica:

```text
PrinterEndpointReachability
```

deben repetirse casos de:

```text
NETWORK
USB
UNKNOWN
```

Si se modifica:

```text
SwitchDecision
NetworkManager
RecoveryValidator
```

deben priorizarse:

```text
recovery real
no intervención
validación posterior
```

La regresión debe seguir la arquitectura afectada.

---

## 38. No introducir excepciones por fabricante como reacción inmediata

Si una prueba con Brother, Epson u otra impresora falla, la primera respuesta
no debe ser:

```text
if Brother ...
```

o:

```text
if Epson ...
```

Primero debe preguntarse:

```text
¿qué propiedad operacional diferencia realmente este caso?
```

Ejemplos válidos:

```text
TransportType
Protocol
AddressType
ReachabilityStrategy
PortMonitor
```

La generalización debe continuar basada en capacidades observables.

---

## 39. Validar transporte antes de seleccionar recuperación

Un endpoint inaccesible no implica automáticamente un problema Wi-Fi.

Antes de considerar recuperación debe conocerse:

```text
TransportType
```

Ejemplo:

```text
USB
    |
    v
USB_DEVICE_NOT_PRESENT
    |
    v
NO_WIFI_ACTION
```

y:

```text
NETWORK
    |
    v
sin camino funcional
    |
    v
evaluar Policy
```

Esta regla deberá comprobarse también en los casos excepcionales.

---

## 40. UNKNOWN debe conservar semántica propia

Durante el Punto 6 se mantendrá explícitamente:

```text
REACHABLE
UNREACHABLE
UNKNOWN
```

como estados diferentes.

No debe utilizarse:

```text
if not reachable -> unreachable
```

sin demostrar que existe evidencia suficiente.

Los casos de:

```text
hostname no resoluble
información incompleta
fallo de discovery
```

pueden requerir `UNKNOWN`.

---

## 41. La falta de evidencia reduce capacidad de acción

La regla metodológica vigente es:

```text
evidencia suficiente
       |
       v
evaluar acción
```

mientras:

```text
evidencia insuficiente
       |
       v
reducir capacidad de intervenir
```

No debe utilizarse:

```text
no sé qué pasa
       |
       v
probar un cambio de red
```

como estrategia operacional normal.

---

## 42. Diferenciar fallo del sistema y fallo del entorno

Un test puede fallar porque:

```text
el software tomó una decisión incorrecta
```

o porque:

```text
el escenario físico no quedó configurado como se esperaba
```

Antes de declarar `FAIL` deberá verificarse la configuración inicial.

Ejemplos:

```text
SSID que debía estar visible realmente no estaba visible

impresora que debía estar encendida estaba apagada

Ethernet quedó conectado

USB permaneció conectado
```

Un entorno mal preparado puede invalidar el experimento.

---

## 43. Verificación previa obligatoria del entorno

Antes de pruebas relevantes deberá comprobarse cuando corresponda:

```text
netsh wlan show interfaces

netsh wlan show networks mode=bssid

Get-NetAdapter

Get-Printer

Get-PrinterPort
```

No es necesario ejecutar siempre todos los comandos.

Debe elegirse la verificación mínima que demuestre que las precondiciones son
reales.

---

## 44. Verificación posterior obligatoria cuando existe acción

Si el sistema ejecuta un cambio, el test debe comprobar el estado posterior.

Ejemplos:

```text
Wi-Fi final

endpoint final

ruta final

USB final

resultado de RecoveryValidator
```

La acción reportada por el sistema no constituye por sí sola evidencia
suficiente.

---

## 45. Acción y efecto deben documentarse por separado

Toda prueba que ejecute una modificación deberá distinguir:

```text
acción ejecutada
```

de:

```text
efecto conseguido
```

Ejemplo:

```text
SwitchExecuted = True
```

responde:

```text
¿se intentó / ejecutó el cambio?
```

mientras:

```text
RecoveryConfirmed = True
```

responde:

```text
¿el cambio solucionó el problema?
```

Ambos datos cumplen funciones diferentes.

---

## 46. Evitar dependencias diagnósticas accidentales

La auditoría previa al Punto 6 mostró que un componente diagnóstico puede
convertirse accidentalmente en una dependencia del core.

Por ello se deberá revisar periódicamente:

```text
quién produce una información

quién la consume

quién toma decisiones

quién sólo observa
```

Un componente de diagnóstico no debe redefinir:

```text
Discovery
Policy
Decision
```

sin necesidad explícita.

---

## 47. Una fuente de verdad por responsabilidad

La arquitectura debería aproximarse a:

```text
Windows / Discovery
    -> qué existe

EndpointResolver
    -> cómo se alcanza

Policy
    -> qué está autorizado

SwitchDecision
    -> qué hacer

NetworkManager
    -> ejecutar

RecoveryValidator
    -> confirmar

ConnectivityAnalyzer
    -> diagnosticar
```

Cuando dos componentes intenten definir la misma información deberán revisarse
las responsabilidades antes de continuar.

---

## 48. La tercera red permite testing de topologías y no sólo conectividad

El entorno dispone de:

```text
PRIMARY_INTERNET_SSID
PRINTER_NETWORK_SSID
Suarez
```

Estas redes pueden utilizarse para construir escenarios controlados donde:

```text
la red actual cambia

el hostname deja de resolver

el endpoint no pertenece a la red seleccionada

una red candidata existe pero no recupera el recurso
```

La red adicional no debe utilizarse para introducir caos simultáneo.

Debe emplearse como variable experimental controlada.

---

## 49. Diseño inicial de la batería del Punto 6

La batería inicial contiene:

```text
P6-01
Endpoint accesible por camino alternativo

P6-02
Hostname conocido pero no resoluble

P6-03
Red objetivo visible pero endpoint no recuperado

P6-04
Cambio de contexto durante una evaluación

P6-05
Múltiples colas y selección ambigua

P6-06
Información parcial o contradictoria
```

El orden puede ampliarse pero no debe modificarse sin documentar el motivo.

---

## 50. P6-01 — Camino alternativo existente

Pregunta:

```text
¿Qué ocurre si el Wi-Fi actual no parece ser
la red de la impresora,
pero ya existe otro camino funcional?
```

Hipótesis:

```text
PrintSwitch debe preservar el camino existente
y no cambiar Wi-Fi
```

La variable principal será:

```text
Ethernet
```

Este caso funciona además como regresión del principio:

```text
endpoint alcanzable
        |
        v
NO_ACTION
```

---

## 51. P6-02 — Hostname no resoluble

Pregunta:

```text
¿Qué ocurre cuando la cola posee un hostname válido
pero el contexto actual no permite resolverlo?
```

Caso de referencia:

```text
Brother HL-1210W series
ConfiguredDestination = BRWC48E8F7B140F
```

Hipótesis:

```text
Resolution failure
      |
      v
UNKNOWN
      |
      v
NO_ACTION_INSUFFICIENT_ENDPOINT_EVIDENCE
```

El objetivo será confirmar que la incertidumbre no se transforme en
autorización de recovery.

---

## 52. P6-03 — SSID disponible pero endpoint no recuperado

Pregunta:

```text
¿Qué ocurre si la red candidata existe
pero el recurso buscado no queda disponible?
```

La hipótesis es:

```text
SSID conectado correctamente
       !=
Recovery confirmado
```

La prueba deberá verificar que:

```text
NetworkSwitchVerified = True
```

no sea suficiente para producir:

```text
RecoverySucceeded = True
```

si el endpoint continúa inaccesible.

---

## 53. P6-04 — Cambio de contexto durante la evaluación

Pregunta:

```text
¿Qué sucede si una condición cambia
después de haber sido observada
pero antes de la validación final?
```

Sólo deberá modificarse una condición.

Ejemplos candidatos:

```text
impresora se apaga

SSID desaparece

USB se desconecta

hostname deja de resolver
```

La hipótesis general es:

```text
la validación posterior debe detectar
que la evidencia anterior ya no representa
el estado final
```

---

## 54. P6-05 — Selección ambigua de cola

Pregunta:

```text
¿Qué ocurre cuando existen varias colas físicas
y no se especifica cuál debe observarse?
```

El entorno actual contiene al menos:

```text
Epson Network
Brother Network
Brother USB
```

La hipótesis es:

```text
ambigüedad
    |
    v
no seleccionar arbitrariamente
```

La respuesta segura podrá ser:

```text
requerir PrinterName
```

o una clasificación equivalente que evite ejecutar recovery sobre una cola
incorrecta.

---

## 55. P6-06 — Evidencia parcial o contradictoria

Pregunta:

```text
¿Qué hace PrintSwitch cuando distintas señales
no representan exactamente el mismo estado?
```

Escenarios posibles:

```text
cola existe pero dispositivo USB no está presente

PrinterStatus = Normal pero endpoint no responde

hostname configurado pero no resoluble

red visible pero recurso no disponible
```

El objetivo inicial no es implementar una nueva capa de confianza.

Es observar:

```text
qué evidencia llega

qué componente la interpreta

qué clasificación produce

si el comportamiento sigue siendo seguro
```

---

## 56. Las pruebas derivadas deben conservar trazabilidad

Si P6-03 produce un hallazgo adicional, se podrá crear:

```text
P6-03A
P6-03B
```

Cada prueba derivada deberá registrar:

```text
de qué test nace
qué variable adicional modifica
qué nueva pregunta responde
```

No se debe perder la relación con el caso original.

---

## 57. Criterio de cierre de cada test

Un test se considera cerrado cuando contiene:

```text
diseño previo
configuración inicial
evidencia
resultado real
clasificación
conclusión
```

Si produjo un `FAIL`, además deberá existir:

```text
análisis de causa
corrección
retest
regresión
```

antes de marcarlo como cerrado.

---

## 58. Criterio de cierre del Punto 6

El Punto 6 podrá cerrarse cuando:

```text
todos los tests planificados hayan sido ejecutados

las evidencias estén preservadas

los FAIL hayan sido entendidos

las correcciones necesarias hayan sido aplicadas

las pruebas afectadas hayan sido repetidas

las regresiones relevantes continúen pasando

no existan fallos críticos sin explicación
```

No se exige que la arquitectura soporte cualquier escenario imaginable.

Sí se exige conocer claramente sus límites antes de promoverla hacia una beta.

---

## 59. Gate metodológico hacia la UI

La metodología establece el siguiente gate:

```text
arquitectura integrada
        |
        v
auditoría
        |
        v
testing adverso
        |
        v
regresiones
        |
        v
contratos estables
        |
        v
UI / beta
```

Por lo tanto:

```text
UI
```

no debe convertirse en una nueva fuente de decisiones.

La interfaz deberá consumir contratos ya estabilizados por el core.

---

## 60. Calidad de evidencia como etapa futura

Durante la preparación del Punto 6 apareció una pregunta transversal:

```text
¿Qué ocurre si la fuente principal
está incompleta, obsoleta o se contradice
con otra evidencia?
```

Esta pregunta es válida y relevante.

Sin embargo no debe introducirse una nueva arquitectura transversal durante el
Punto 6 sin necesidad demostrada.

Se registra como etapa futura:

```text
evaluación de calidad de evidencia
```

capaz potencialmente de distinguir:

```text
evidencia suficiente

evidencia parcial

evidencia contradictoria

evidencia insuficiente
```

El Punto 6 puede aportar los casos reales necesarios para diseñarla después.

---

## 61. Principio metodológico vigente

La metodología actual puede resumirse como:

> **Observar antes de inferir, medir antes de decidir, decidir antes de actuar
> y verificar después de actuar.**

A esto se agrega:

> **Diseñar la prueba antes de ejecutarla, registrar la configuración antes de
> modificarla y comparar el resultado real contra una hipótesis explícita.**

Y ante incertidumbre:

> **Menos evidencia debe producir menos capacidad para intervenir, no mayor
> libertad para probar acciones.**

Finalmente:

> **Un FAIL reproducible y comprendido es más valioso para la ingeniería que un
> PASS obtenido en un escenario que no desafía ninguna premisa.**

---

# Actualización metodológica — Cierre del Punto 6 — Septiembre 2026

> Esta sección actualiza la metodología después de ejecutar la campaña
> experimental del Punto 6.
>
> Las secciones anteriores conservan el diseño pre-P6 y permanecen como
> registro histórico.
>
> Las reglas siguientes representan la metodología vigente para avanzar hacia
> la primera beta.

---

## 62. Una campaña experimental puede modificar su diseño sin invalidarse

El Punto 6 confirmó que una batería de pruebas no debe ejecutarse como una lista
rígida únicamente porque fue diseñada con anterioridad.

Durante la campaña aparecieron observaciones no previstas inicialmente.

Ejemplo:

```text
Epson físicamente apagada
+
Windows PrinterStatus = Normal
```

La observación produjo una hipótesis más útil que parte del caso originalmente
planificado.

La metodología correcta fue:

```text
observar
    |
    v
reconocer desviación
    |
    v
documentar
    |
    v
formular nueva hipótesis
    |
    v
convertirla en prueba controlada
```

Por tanto:

> **Modificar una prueba a partir de evidencia nueva no constituye pérdida de
> rigor si la modificación queda documentada y la nueva hipótesis se valida de
> manera explícita.**

---

## 63. El estado físico requerido debe declararse explícitamente

P6 mostró que una condición física aparentemente obvia puede introducir una
ambigüedad importante.

A partir de ahora, toda prueba donde el resultado dependa del dispositivo
deberá indicar explícitamente:

```text
ESTADO FÍSICO REQUERIDO

EPSON   = ENCENDIDA / APAGADA
BROTHER = ENCENDIDA / APAGADA
ETHERNET = CONECTADO / DESCONECTADO
Wi-Fi    = SSID requerido
```

No debe asumirse que el operador recuerda el estado anterior.

La precondición física debe formar parte de la ficha experimental.

---

## 64. Una precondición declarada debe verificarse antes de interpretar el resultado

La ficha de prueba no constituye evidencia suficiente de que las condiciones
realmente estén presentes.

Cuando sea posible se verificará:

```text
SSID actual
estado de Ethernet
cola seleccionada
endpoint esperado
ruta
jobs pendientes
```

El estado físico que no pueda consultarse programáticamente deberá confirmarse
por el operador.

La regla es:

```text
precondición diseñada
        !=
precondición observada
```

hasta que exista evidencia de su cumplimiento.

---

## 65. Un resultado inesperado debe clasificarse antes de repetir la prueba

P6-03 mostró que repetir inmediatamente un caso puede reproducir una limitación
de observación y no aportar nueva evidencia.

Ante un resultado inesperado se debe preguntar primero:

```text
¿falló el Core?

¿falló una precondición?

¿falló la adquisición de evidencia?

¿cambió el entorno?

¿la prueba no alcanzó la condición que pretendía evaluar?
```

Sólo después se decide:

```text
repetir

adaptar

clasificar INCONCLUSIVE

abrir hallazgo futuro
```

---

## 66. INCONCLUSIVE no equivale a FAIL

Una prueba puede no alcanzar el escenario necesario para evaluar la hipótesis.

P6-03 produjo:

```text
Wi-Fi candidata no confirmada
        |
        v
switch no autorizado
```

La prueba original buscaba analizar:

```text
switch exitoso
+
recovery posterior fallido
```

Ese estado nunca se alcanzó.

Por tanto:

```text
resultado de hipótesis = INCONCLUSIVE
```

y no:

```text
FAIL
```

Sin embargo, la misma ejecución aportó evidencia sobre otro comportamiento:

```text
evidencia insuficiente
        |
        v
no intervención
```

que sí pudo clasificarse como:

```text
SAFE BEHAVIOR CONFIRMED
```

---

## 67. Una prueba puede generar más de un hallazgo independiente

El resultado primario de una prueba no debe ocultar observaciones secundarias
relevantes.

Ejemplo P6-04:

```text
objetivo principal
    -> comparar estado físico y reachability

hallazgo adicional
    -> Ping=False con TCP515=True
```

Ambos resultados deben documentarse de forma separada.

Esto evita perder conocimiento únicamente porque no pertenecía a la pregunta
original.

---

## 68. Las fuentes de evidencia deben asociarse a preguntas concretas

P6 consolidó una regla metodológica:

```text
pregunta
    |
    v
fuente adecuada
```

Ejemplos:

```text
¿existe la cola?
    -> Windows Printing

¿cómo llega la cola al dispositivo?
    -> Endpoint Resolver

¿resuelve el nombre?
    -> Name Resolution

¿responde el servicio?
    -> Operational Probe

¿qué camino elegiría Windows?
    -> Routing

¿está permitido cambiar Wi-Fi?
    -> Policy
```

No debe utilizarse una fuente simplemente porque devuelve información sobre la
impresora.

Debe utilizarse porque responde a la pregunta que se está evaluando.

---

## 69. Las fuentes pueden ser simultáneamente correctas y diferentes

P6-06 mostró:

```text
QueueState      = Normal
ResolutionState = RESOLVED
EndpointState   = UNREACHABLE
```

La metodología no debe considerar automáticamente que alguna fuente está
equivocada.

Primero debe comprobar:

```text
qué dimensión describe cada una
```

Por tanto, ante evidencia aparentemente contradictoria:

```text
no reconciliar inmediatamente
no elegir una fuente arbitrariamente
no forzar un booleano global
```

Primero se conserva la evidencia por dimensión.

---

## 70. La prueba operacional debe utilizar el servicio real

El mecanismo utilizado para validar disponibilidad debe corresponder al
servicio que utiliza la cola.

Para las colas LPR observadas:

```text
TCP 515
```

es una evidencia más pertinente que:

```text
Ping
TCP 9100 genérico
HTTP
```

La metodología general queda:

```text
descubrir servicio
        |
        v
probar servicio
        |
        v
clasificar
```

y no:

```text
elegir una sonda genérica
        |
        v
inferir disponibilidad
```

---

## 71. Las regresiones deben ejecutarse al final de una campaña

P6-R01 confirmó la utilidad de cerrar una batería con una regresión transversal.

La finalidad es comprobar que los hallazgos obtenidos durante los casos
excepcionales no dejaron incoherencias en los caminos ya validados.

La secuencia recomendada queda:

```text
casos normales
    |
    v
casos negativos
    |
    v
casos raros
    |
    v
hallazgos
    |
    v
regresión final
```

Una campaña no debe cerrarse únicamente porque todos los casos individuales
fueron ejecutados.

---

## 72. El Core no debe modificarse durante una batería salvo que exista evidencia suficiente

Durante P6 aparecieron posibles optimizaciones:

```text
esperas Wi-Fi
doble scan
temporización de discovery
```

No se incorporaron inmediatamente.

La razón metodológica es evitar:

```text
cambiar el objeto bajo prueba
```

durante la misma campaña que intenta evaluarlo.

Una modificación inmediata se justifica únicamente si:

```text
existe defecto claro
+
el defecto bloquea la campaña
+
la corrección es necesaria para continuar
```

Las optimizaciones no bloqueantes pueden diferirse.

---

## 73. Los hallazgos no bloqueantes deben convertirse en backlog explícito

P6 identificó una frontera temporal en el discovery Wi-Fi de Windows.

No se ignoró ni se corrigió improvisadamente.

Se clasificó como:

```text
Beta 2
Hardening Wi-Fi
```

La metodología para estos casos será:

```text
hallazgo
    |
    v
impacto actual
    |
    +--> bloqueante
    |       -> tratar ahora
    |
    +--> no bloqueante
            -> documentar
            -> asignar etapa futura
```

Esto mantiene foco sin perder conocimiento.

---

## 74. El parecido nominal no constituye evidencia técnica

La disponibilidad de las redes:

```text
Suarez
PRINTER_NETWORK_SSID
```

introduce un ejemplo útil.

El parecido de sus nombres no implica:

```text
misma red
mismo router
misma topología
relación de bridge
```

Las futuras pruebas deberán describir las redes mediante:

```text
router
subred
gateway
interfaz
ruta
bridge
reachability
```

y nunca inferir relaciones por el SSID.

---

## 75. Beta 2 utilizará fault injection controlado

La red `ALTERNATE_INTERNET_SSID` queda reservada como recurso para una etapa posterior de
hardening.

Su valor metodológico consiste en permitir controlar variables como:

```text
gateway
Ethernet
Wi-Fi
rutas
métricas
subred
conectividad parcial
```

La finalidad será introducir fallos deliberados y reproducibles.

Cada fault injection deberá declarar:

```text
estado inicial
variable modificada
hipótesis
resultado esperado
resultado obtenido
restauración del entorno
```

---

## 76. El gate metodológico hacia la UI quedó superado

La UI estaba condicionada a que el motor demostrara:

```text
detección
discovery
reachability
decisión
acción
validación
no intervención
regresión
```

P6 permitió completar ese gate.

Por tanto:

```text
Punto 7 = habilitado
```

La metodología cambia ahora parcialmente de foco.

Hasta P6 la pregunta dominante fue:

```text
¿funciona correctamente el Core?
```

En Punto 7 se agrega:

```text
¿puede utilizarse el Core de forma reproducible,
observable y segura como aplicación?
```

---

## 77. La UI deberá validarse como integración y no como nueva lógica

La primera beta deberá demostrar que la interfaz:

```text
consume
```

el Core.

No que:

```text
lo reimplementa
```

Toda decisión importante observada desde UI deberá poder correlacionarse con un
resultado estructurado del motor.

Por tanto, una prueba de UI deberá registrar:

```text
acción del usuario
evento recibido
resultado del Core
estado presentado
acción física real si corresponde
```

---

## 78. Las pruebas de Punto 7 deben conservar el mismo modelo de ficha

El formato experimental utilizado en P6 continuará en la primera beta.

Cada prueba deberá incluir:

```text
ID

nombre

objetivo

estado inicial

estado físico requerido

hipótesis

acción

resultado esperado

resultado obtenido

check real

hallazgo

conclusión
```

Esto mantiene continuidad metodológica entre:

```text
Core
```

y:

```text
Application Layer
```

---

## 79. La experiencia de usuario también debe producir evidencia

En Punto 7 no bastará con comprobar:

```text
la ventana abre
```

o:

```text
el icono aparece
```

Será necesario verificar relaciones como:

```text
Core detecta evento
        |
        v
UI lo representa correctamente
```

y:

```text
usuario cambia setting
        |
        v
Application Controller
        |
        v
Core recibe configuración correcta
```

La UI se evaluará como parte del sistema.

---

## 80. La primera beta debe preservar regresiones del Core

Cada milestone importante de UI deberá incluir al menos:

```text
happy path

no intervention

recovery real

cierre limpio
```

La existencia de interfaz no debe degradar las capacidades que ya estaban
validadas desde terminal.

El criterio es:

```text
nuevo capability
+
no regression
```

---

## 81. Principio metodológico vigente después de P6

La regla histórica permanece:

> **Observar antes de inferir, medir antes de decidir, decidir antes de actuar y
> verificar después de actuar.**

P6 agrega varias precisiones:

> **Una fuente debe utilizarse para la pregunta que realmente puede responder.**

> **Un resultado inesperado debe clasificarse antes de corregirse.**

> **INCONCLUSIVE no equivale a FAIL.**

> **La evidencia insuficiente debe reducir capacidad de intervención.**

> **Una optimización no bloqueante puede diferirse sin invalidar el Core.**

> **Toda nueva capa debe demostrar que preserva las regresiones anteriores.**

Con estas reglas, la metodología queda preparada para iniciar el Punto 7 y la
primera beta de PrintSwitch.

---

# 82. Actualización 2026-09-16 — Metodología vigente después de LAB‑01–LAB‑05D

## 82.1. Propósito de esta actualización

Esta sección registra la evolución metodológica producida por la serie experimental Native Wi‑Fi.

No reemplaza los métodos documentados anteriormente.

Las reglas previas permanecen como evidencia de:

- cómo se investigaba el sistema en cada etapa;
- qué incertidumbres estaban abiertas;
- qué nivel de instrumentación estaba disponible;
- qué criterios justificaron nuevas pruebas;
- cómo evolucionó el estándar de evidencia de PrintSwitch.

Cuando una práctica anterior haya quedado incompleta, debe conservarse como antecedente y complementarse con esta actualización.

El contrato técnico resultante se encuentra en:

[Contrato de comportamiento Native Wi‑Fi para Beta 1](Native_WiFi_Beta1_Contract.md)

---

# 83. Estado de la metodología anterior

| Regla metodológica anterior | Estado actual | Aclaración |
| --- | --- | --- |
| Utilizar evidencia positiva antes de autorizar una acción. | Vigente | La evidencia positiva debe corresponder exactamente a la afirmación que se desea sostener. |
| No observado no equivale a inexistente. | Vigente | Deben registrarse frescura, fuente y alcance de la observación. |
| Separar Discovery, Policy, NetworkManager y Validator. | Vigente y ampliada | Se incorpora `NativeWifiAdapter` como frontera técnica sin decisiones de negocio. |
| Conservar estados grises. | Vigente | Se añaden estados asíncronos, atribución causal y timeouts explícitos. |
| Utilizar pruebas controladas y evidencia TXT. | Vigente | Las pruebas deben incluir contrato experimental, línea temporal y actor de cada acción. |
| Un resultado `PASS` valida el comportamiento probado. | Vigente con límite | No permite generalizar a condiciones que el laboratorio no controló. |
| La correlación temporal ayuda a explicar una transición. | Vigente con límite | Correlación temporal no demuestra por sí sola causalidad. |
| Native Wi‑Fi podía estudiarse posteriormente como hardening. | Superado para Beta 1 | Los laboratorios justificaron su adopción productiva inmediata y aislada. |
| El laboratorio de red permanecía pendiente. | Cumplido | LAB‑01–LAB‑05D aportaron evidencia suficiente para cerrar la hipótesis arquitectónica. |

Las reglas históricas no deben borrarse.

Cuando exista una diferencia, esta actualización define la metodología vigente.

---

# 84. Congelar integración ante una incertidumbre arquitectónica

La serie Native Wi‑Fi confirmó que resulta válido congelar temporalmente integraciones productivas cuando una incertidumbre puede modificar:

- la frontera entre componentes;
- el modelo de estado;
- la atribución de acciones;
- la política de recovery;
- las condiciones de rollback;
- el significado de una operación;
- los criterios de éxito.

El congelamiento no constituye abandono ni retroceso.

Es una medida metodológica para evitar que una hipótesis no validada se propague por:

- Controller;
- QueueWatcher;
- NetworkManager;
- políticas;
- recovery;
- interfaz de usuario;
- documentación;
- pruebas de regresión.

El congelamiento debe registrar:

```text
Reason
AffectedComponents
AllowedExperiments
ForbiddenIntegrations
ExitCriterion
```

La integración se descongela únicamente cuando:

1. la incertidumbre queda suficientemente caracterizada;
2. existe evidencia reproducible;
3. se documenta el contrato resultante;
4. se identifican las limitaciones;
5. se define una secuencia gradual de implementación.

---

# 85. Todo laboratorio debe declarar su contrato experimental

Antes de actuar, un laboratorio debe declarar:

- identificador;
- objetivo;
- hipótesis;
- precondiciones;
- estado inicial requerido;
- acciones autorizadas;
- acciones prohibidas;
- interacción humana permitida;
- duración;
- timeouts;
- variables observadas;
- resultado esperado;
- criterio de `PASS`;
- criterio de `FAIL`;
- criterio de `INCONCLUSIVE`;
- ubicación de la evidencia.

Ejemplo de contrato:

```text
CanChangeWiFiConnection=True
CanInvokeWlanScan=True
CanInvokeWlanConnect=False
CanModifyProfiles=False
CanReadCredentials=False
CanTouchQueue=False
CanTouchProductionSource=False
WindowsWifiUiMustRemainClosed=True
```

El script debe recordar estas condiciones antes de comenzar.

No debe depender únicamente de que el operador recuerde las reglas acordadas en la conversación.

---

# 86. Las precondiciones deben verificarse, no suponerse

Una precondición necesaria debe comprobarse antes de iniciar el estímulo.

Ejemplos:

- SSID inicial;
- perfil inicial;
- interfaz seleccionada;
- perfil objetivo existente;
- flyout cerrado;
- red objetivo apagada o encendida;
- ausencia de interacción del usuario;
- presencia del actuador requerido;
- ruta de evidencia disponible.

Si una precondición no se cumple, el laboratorio debe detenerse antes de mutar el sistema.

La ausencia de una dependencia, como ocurrió inicialmente con el actuador LAB‑03B requerido por LAB‑05D, debe producir un error explícito y seguro.

No debe reemplazarse silenciosamente por:

- otro script;
- una llamada diferente;
- una simulación;
- un procedimiento manual;
- una aproximación no validada.

---

# 87. Una prueba debe modificar una variable principal por vez

Siempre que sea posible, cada laboratorio debe aislar un único estímulo principal.

| Laboratorio | Variable principal |
| --- | --- |
| LAB‑05A | Apertura del flyout sin caída previa. |
| LAB‑05B | Apertura del flyout después de caída y failover. |
| LAB‑05C | `WlanScan` explícito después de caída y failover. |
| LAB‑05D | `WlanScan` después de una conexión explícita mediante `WlanConnect`. |

La comparación entre laboratorios permitió distinguir:

- interfaz abierta;
- actualización de redes;
- recuperación posterior a caída;
- conexión explícita;
- acción del usuario;
- acción de Windows;
- acción del laboratorio.

Si se modifican varias condiciones simultáneamente, el resultado puede ser útil como observación exploratoria, pero no como evidencia causal suficiente.

---

# 88. Observación, inferencia, autorización y resultado deben separarse

Toda prueba y toda implementación deben conservar cuatro niveles.

## Observación

Dato obtenido directamente:

```text
CurrentSSID=PRIMARY_INTERNET_SSID
ScanCompleted=True
Notification=connection_complete
```

## Inferencia

Interpretación construida a partir de varias observaciones:

```text
ConnectionOrigin=WINDOWS_FAILOVER
TargetVisibility=OBSERVED
EvidenceFreshness=FRESH
```

## Autorización

Decisión de que una acción puede ejecutarse:

```text
SwitchAuthorized=True
RollbackAuthorized=False
```

## Resultado

Estado verificado después de actuar:

```text
ConnectionVerified=True
FinalSSID=PRIMARY_INTERNET_SSID
```

No debe registrarse una inferencia como si fuera una observación nativa.

No debe registrarse una autorización como si fuera un resultado.

No debe registrarse una solicitud aceptada como si fuera una operación completada.

---

# 89. Correlación temporal no equivale automáticamente a causalidad

Cuando una transición ocurre después de un evento, deben registrarse ambas cosas:

```text
Event A occurred
Transition B followed
```

No debe afirmarse automáticamente:

```text
Event A directly caused Transition B
```

LAB‑05C demostró que un `WlanScan` fue seguido por una transición automática.

La formulación metodológicamente correcta es:

> El escaneo actualizó la información disponible y Windows AutoConfig inició posteriormente una transición sin una llamada `WlanConnect` del laboratorio.

No debe afirmarse que `WlanScan` conectó directamente la interfaz.

Para atribuir una acción a PrintSwitch deben existir:

- una operación activa;
- una invocación registrada;
- un destino concreto;
- correlación temporal;
- eventos compatibles;
- verificación final.

---

# 90. Los resultados aparentemente contradictorios deben preservarse

LAB‑05C y LAB‑05D no deben tratarse como resultados incompatibles.

Deben conservarse juntos porque probaron contextos diferentes:

| Laboratorio | Contexto | Resultado |
| --- | --- | --- |
| LAB‑05C | Conexión de failover seleccionada por Windows | El escaneo fue seguido por la restauración de la red perdida. |
| LAB‑05D | Conexión explícita seleccionada mediante `WlanConnect` | El escaneo preservó la conexión explícita. |

La metodología exige preguntar:

- ¿eran iguales las precondiciones?;
- ¿el actor inicial era el mismo?;
- ¿la conexión actual tenía el mismo origen?;
- ¿existía una caída previa?;
- ¿el usuario intervino?;
- ¿se ejecutó `WlanConnect`?;
- ¿se observó la misma ventana temporal?

Una aparente contradicción puede revelar una variable contextual que todavía no estaba modelada.

En este caso permitió identificar la necesidad de `ConnectionOrigin`.

---

# 91. Un `PASS` valida solamente el contrato probado

Un laboratorio con resultado `PASS` demuestra que se cumplieron sus criterios bajo las condiciones registradas.

No demuestra automáticamente que:

- el comportamiento sea universal;
- todas las placas Wi‑Fi respondan igual;
- cualquier versión de Windows responda igual;
- todas las redes tengan la misma política;
- no existan condiciones de carrera;
- no sea necesario verificar el estado final;
- la operación pueda integrarse sin aislamiento previo.

Ejemplo:

```text
LAB-05D=PASS
```

permite concluir:

> En las condiciones de LAB‑05D, la conexión explícita a `PRIMARY_INTERNET_SSID` fue preservada después del escaneo.

No permite concluir:

> Todo escaneo siempre preservará toda conexión explícita en cualquier entorno.

---

# 92. Los estados grises forman parte del resultado

Una prueba no debe forzar todos los resultados a `PASS` o `FAIL`.

Debe permitir estados como:

```text
UNKNOWN
PENDING
STALE
INCONCLUSIVE
INCONSISTENT
DEGRADED
TIMED_OUT
ABORTED_PRECONDITION
```

Ejemplos:

- si no llegó un evento terminal, el resultado puede ser `TIMED_OUT`;
- si el estado Native y otra fuente no coinciden, puede ser `INCONSISTENT`;
- si la evidencia es antigua, puede ser `STALE`;
- si no se controló una variable esencial, puede ser `INCONCLUSIVE`;
- si falló una precondición antes de actuar, puede ser `ABORTED_PRECONDITION`.

Un estado gris no debe convertirse en éxito por conveniencia.

Tampoco debe convertirse automáticamente en fallo funcional si la evidencia no permite esa afirmación.

---

# 93. Operaciones asíncronas requieren evidencia terminal

Para operaciones Native Wi‑Fi se debe distinguir:

```text
InvocationResult
TerminalNotification
FinalState
```

## Escaneo

Un escaneo requiere:

1. invocación;
2. espera de `scan_complete`, `scan_fail` o timeout;
3. lectura de redes;
4. nueva consulta de la conexión;
5. observación de posibles transiciones posteriores.

## Conexión

Una conexión requiere:

1. invocación;
2. espera de `connection_complete`, `connection_attempt_fail` o timeout;
3. consulta final;
4. comparación con el destino esperado.

Regla:

```text
API_RETURN_ZERO != OPERATION_SUCCESS
```

El retorno inmediato informa que Windows aceptó la solicitud, no que completó la operación.

---

# 94. Toda acción potencialmente mutante requiere verificación posterior

Una operación puede tener efectos directos o indirectos.

Después de:

- `WlanScan`;
- `WlanConnect`;
- apertura del flyout en un laboratorio;
- caída o recuperación de un punto de acceso;
- rollback;

se debe consultar nuevamente:

- estado de interfaz;
- SSID;
- perfil;
- eventos;
- origen causal inferido;
- coherencia con la operación activa.

La verificación posterior no es opcional aunque la API haya devuelto cero.

---

# 95. La ausencia de una orden propia es evidencia relevante

Cuando ocurre una transición y PrintSwitch no invocó `WlanConnect`, el sistema debe registrar explícitamente:

```text
PrintSwitchConnectInvocation=False
```

Esto no identifica automáticamente al actor exacto, pero permite excluir una causa.

Según el contexto, el origen puede clasificarse como:

```text
USER_EXPLICIT
WINDOWS_FAILOVER
WINDOWS_AUTORESTORE
UNKNOWN
```

La ausencia de una llamada propia es necesaria para evitar que PrintSwitch se atribuya acciones de Windows.

---

# 96. Rollback requiere propiedad causal de la transición

Antes de ejecutar rollback deben verificarse estas preguntas:

1. ¿PrintSwitch capturó la conexión inicial?
2. ¿PrintSwitch inició la transición de salida?
3. ¿La transición se completó y verificó?
4. ¿La operación sigue activa?
5. ¿El usuario intervino?
6. ¿Windows realizó otra transición?
7. ¿El estado actual sigue siendo coherente con la operación?
8. ¿La conexión inicial continúa siendo un destino válido?

Si se pierde la atribución, el rollback automático debe suspenderse.

Regla metodológica:

> Sólo se revierte automáticamente una mutación propia, identificada y todavía perteneciente a la operación activa.

---

# 97. La evidencia debe permitir reconstruir una línea temporal

Toda prueba de transición debe registrar tiempos relativos o marcas temporales suficientes para ordenar:

- precondición;
- inicio del estímulo;
- invocación;
- desconexión;
- inicio de conexión;
- evento terminal;
- verificación;
- scan;
- refresh;
- transición posterior;
- estado final.

Formato conceptual:

```text
ElapsedMs
Phase
Event
Profile
SSID
ReasonCode
Actor
```

No es suficiente registrar únicamente:

```text
BeforeSSID
AfterSSID
```

La línea temporal es necesaria para:

- atribución;
- detección de condiciones de carrera;
- comparación entre laboratorios;
- diagnóstico de timeouts;
- reproducción del comportamiento.

---

# 98. Evidencia principal y evidencia auxiliar

Cada afirmación debe indicar su fuente principal.

Para operaciones Native Wi‑Fi:

- eventos Native y consultas Native constituyen la evidencia principal;
- `netsh wlan` puede utilizarse como contraste auxiliar;
- la observación visual puede utilizarse como contexto;
- la declaración humana puede registrar una acción externa controlada.

Una fuente auxiliar no debe reemplazar silenciosamente la fuente principal.

Si dos fuentes difieren, debe registrarse la inconsistencia.

No debe elegirse automáticamente la fuente que produzca el resultado esperado.

---

# 99. La ficha de laboratorio debe ser reproducible

Cada laboratorio debe documentar como mínimo:

```text
TestId
Name
Purpose
Hypothesis
InitialConfiguration
Preconditions
AuthorizedActions
ForbiddenActions
HumanActions
ExpectedResult
ObservedResult
Timeline
FinalState
Limitations
PassFailCriterion
Result
EvidencePath
```

También debe registrar parámetros relevantes:

- interfaz;
- perfiles;
- SSID inicial;
- SSID objetivo;
- timeout;
- intervalo de muestreo;
- duración pasiva;
- duración posterior al estímulo.

El script y el archivo de evidencia deben permitir que otra ejecución reproduzca las mismas condiciones sin depender de instrucciones recordadas oralmente.

---

# 100. Criterio de cierre de una hipótesis

Una hipótesis puede cerrarse cuando:

1. la pregunta arquitectónica está definida;
2. las variables principales fueron aisladas;
3. existe evidencia reproducible;
4. los resultados alternativos relevantes fueron comparados;
5. las limitaciones están documentadas;
6. puede derivarse una regla implementable;
7. la regla incluye estados de error e incertidumbre;
8. nuevas pruebas no cambiarían una decisión inmediata de Beta 1.

LAB‑05D cerró la pregunta:

> ¿Un escaneo posterior a una conexión explícita reproduce necesariamente el retorno automático observado después de un failover?

Resultado:

```text
ReturnedToSourceAfterScan=False
FinalSSID=PRIMARY_INTERNET_SSID
Result=PASS_PROGRAMMATIC_ROLLBACK_PRESERVED_AFTER_SCAN
```

Esto permitió distinguir conexión explícita de failover y cerrar la decisión arquitectónica necesaria.

No es necesario continuar experimentando sólo para acumular más ejecuciones de una hipótesis ya suficiente para Beta 1.

---

# 101. Criterio para abrir un nuevo laboratorio

Después del cierre de LAB‑05D, un nuevo laboratorio Native Wi‑Fi debe responder una incertidumbre nueva surgida durante la implementación.

No debe abrirse únicamente porque:

- sea posible medir otra variable;
- se desee repetir indefinidamente un resultado;
- exista curiosidad sin impacto inmediato;
- todavía no se haya cubierto toda combinación imaginable.

Debe abrirse cuando una incertidumbre pueda modificar:

- el contrato del adaptador;
- el modelo de evidencia;
- una autorización;
- el rollback;
- el tratamiento de errores;
- la separación de responsabilidades;
- un criterio de aceptación.

---

# 102. Descongelamiento gradual de integración

La integración debe avanzar en el siguiente orden:

```text
NativeWifiAdapter
    ↓
Evidence & Context Model
    ↓
Discovery contextual
    ↓
NetworkManager
    ↓
Transition Orchestrator
    ↓
Integración aislada
    ↓
Controller + QueueWatcher
    ↓
Endpoint + impresión + rollback
```

Cada capa debe validarse antes de integrar la siguiente.

No se habilita una capa superior si la inferior:

- oculta errores;
- descarta estados grises;
- no produce evidencia estructurada;
- no libera recursos;
- no verifica estados finales;
- confunde correlación con causalidad;
- no permite pruebas aisladas.

---

# 103. Metodología de implementación de `NativeWifiAdapter`

`NativeWifiAdapter` debe desarrollarse inicialmente sin:

- Controller;
- QueueWatcher;
- cola real;
- impresión real;
- decisiones de Policy;
- rollback automático;
- modificación de perfiles;
- lectura de credenciales.

La primera etapa debe validar:

1. carga de tipos Native;
2. apertura del cliente;
3. enumeración de interfaces;
4. selección inequívoca de interfaz;
5. lectura del estado actual;
6. enumeración de perfiles;
7. registro de notificaciones;
8. escaneo y terminación;
9. reconsulta posterior;
10. conexión y terminación;
11. verificación final;
12. liberación de callbacks;
13. cierre del handle;
14. conservación de errores y códigos de razón.

Las decisiones de negocio no deben incorporarse al adaptador para facilitar una prueba.

---

# 104. Gates para `NativeWifiAdapter`

## Gate A — Carga y recursos

Debe demostrar:

- carga determinista;
- apertura correcta;
- cierre correcto;
- ausencia de handles abandonados;
- liberación de memoria Native.

## Gate B — Observación

Debe demostrar:

- interfaz correcta;
- estado correcto;
- SSID y perfil;
- perfiles disponibles;
- errores explícitos.

## Gate C — Notificaciones

Debe demostrar:

- registro;
- recepción;
- orden temporal;
- liberación;
- ausencia de callbacks activos después del cierre.

## Gate D — Escaneo

Debe demostrar:

- solicitud;
- resultado terminal o timeout;
- redes observadas;
- reconsulta obligatoria;
- detección de transición posterior.

## Gate E — Conexión

Debe demostrar:

- solicitud única;
- evento terminal o timeout;
- código de razón;
- verificación del destino;
- distinción entre aceptación y éxito.

## Gate F — Integración permitida

Sólo después de superar los gates anteriores puede integrarse con `NetworkManager`.

---

# 105. Regla de no parche metodológico

Cuando una prueba descubra una diferencia entre el modelo y Windows, no debe agregarse inmediatamente una condición específica como:

```text
if SSID == "PRINTER_NETWORK_SSID"
```

Primero debe determinarse:

- qué dimensión faltaba;
- si el problema es de evidencia;
- si el problema es de causalidad;
- si falta un estado;
- si la responsabilidad pertenece a otra capa;
- si el comportamiento puede generalizarse de forma segura.

LAB‑05C y LAB‑05D no justifican una excepción por nombre de red.

Justifican incorporar `ConnectionOrigin` y una política contextual de escaneo.

---

# 106. Estado metodológico vigente

```text
HISTORICAL_DOCUMENTATION=PRESERVED
NATIVE_WIFI_LABS=CLOSED
INTEGRATION_FREEZE=GRADUALLY_RELEASED
NEXT_IMPLEMENTATION=NativeWifiAdapter
IMPLEMENTATION_MODE=ISOLATED
EVIDENCE_TIMELINE=REQUIRED
TERMINAL_EVENT=REQUIRED
FINAL_STATE_VERIFICATION=REQUIRED
POST_SCAN_REQUERY=REQUIRED
CONNECTION_ORIGIN=REQUIRED
ROLLBACK_ATTRIBUTION=REQUIRED
GRAY_STATES=REQUIRED
NEW_LABS=ONLY_FOR_NEW_UNCERTAINTY
```

A partir de esta actualización, la implementación de Native Wi‑Fi debe seguir esta metodología.

Las prácticas anteriores permanecen documentadas como historia y deben leerse junto con las aclaraciones y gates establecidos en este bloque.
---

<!-- P7-DOC-PRECOMMIT-R9-PRIVACY-NORMALIZATION -->

**Aclaración editorial de privacidad — 2026-09-16.**
Los nombres reales de redes locales, las direcciones IPv4 privadas y las
direcciones MAC/BSSID presentes en esta documentación fueron sustituidos por
identificadores semánticos o seudónimos estables. Esta normalización no cambia
la cronología, los resultados experimentales, las decisiones arquitectónicas
ni las conclusiones históricas del proyecto.
