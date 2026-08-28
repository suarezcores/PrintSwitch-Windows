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