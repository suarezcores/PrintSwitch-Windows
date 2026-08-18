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