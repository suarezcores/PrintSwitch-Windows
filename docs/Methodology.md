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

Wi-Fi       : Claro640
Ethernet    : desconectado
Epson       : encendida
Brother     : encendida
USB Brother : desconectado
Recovery    : habilitado
SSID visibles:
    Claro640
    suarezcores
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

recovery Claro640 -> suarezcores

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
Claro640
suarezcores
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