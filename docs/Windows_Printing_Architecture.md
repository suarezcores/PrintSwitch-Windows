# Arquitectura de impresión de Windows y fundamento de PrintSwitch

## Print Spooler y cola de impresión no son lo mismo

Uno de los conceptos fundamentales para comprender la arquitectura de PrintSwitch es distinguir el **Print Spooler de Windows** de una **cola de impresión**.

El Print Spooler es un servicio central del sistema operativo que participa en la administración del sistema de impresión. Puede gestionar simultáneamente múltiples impresoras y múltiples trabajos.

La cola, en cambio, representa los trabajos asociados a una determinada impresora lógica configurada en Windows.

De manera simplificada:

```text
                         WINDOWS
                            │
                     PRINT SPOOLER
                            │
             ┌──────────────┼──────────────┐
             │              │              │
             ▼              ▼              ▼
       Epson L365        HP Laser      Microsoft PDF
             │              │              │
          Trabajo 1      Trabajo 4       Trabajo 7
          Trabajo 2      Trabajo 5
          Trabajo 3
```

Por lo tanto:

```text
Print Spooler ≠ Cola de impresión
```

El **Spooler** forma parte de la infraestructura general que administra el sistema de impresión.

Una **cola** corresponde a una impresora lógica determinada y contiene los trabajos destinados a ella.

Cuando el usuario abre en Windows una ventana similar a:

```text
L365 Series(Red)

Documento                  Estado
------------------------------------------
documento.pdf              Imprimiendo
imagen.jpg                 En cola
informe.docx               Error
```

está observando una representación de la cola correspondiente a `L365 Series(Red)`, no el estado completo del Print Spooler.

Esta distinción es importante para PrintSwitch porque permite observar un sistema centralizado de impresión y luego identificar qué trabajos pertenecen a cada impresora.

---

## ¿Dónde aparece el driver?

El driver tampoco debe interpretarse simplemente como un programa del fabricante que observa permanentemente una cola esperando poder comunicarse con una impresora.

Dentro del subsistema de impresión existen diferentes componentes encargados de transformar, procesar y transportar el trabajo hasta el dispositivo correspondiente.

De manera conceptual:

```text
Aplicación
   │
   │ "quiero imprimir"
   ▼
Windows
   │
   ▼
Print Spooler
   │
   ▼
Cola / trabajo
   │
   ▼
Procesamiento / Driver
   │
   ▼
Mecanismo de transporte
   │
   ├── USB
   ├── TCP/IP
   ├── IPP
   ├── WSD
   └── otros
   │
   ▼
Impresora física
```

La implementación exacta puede variar dependiendo del tipo de impresora, del controlador instalado y del mecanismo de impresión utilizado.

El driver puede participar en tareas como:

- procesamiento del trabajo;
- conversión hacia formatos comprensibles por la impresora;
- exposición de capacidades particulares del dispositivo;
- configuración de opciones de impresión;
- comunicación bidireccional cuando corresponde.

Sin embargo, desde el punto de vista de PrintSwitch, no siempre resulta necesario conocer todos esos detalles internos.

Windows ya dispone de información sobre:

```text
qué trabajo existe
a qué impresora pertenece
qué estado tiene
qué cola lo administra
```

Por lo tanto, PrintSwitch puede comenzar su análisis utilizando información genérica proporcionada por Windows y recurrir posteriormente a mecanismos específicos del fabricante solamente cuando sean necesarios.

---

## ¿Por qué PrintSwitch observa Windows y no directamente Epson?

Una primera solución al problema original podría haber consistido en desarrollar PrintSwitch específicamente alrededor de Epson.

Por ejemplo:

```text
PrintSwitch
     │
     ▼
Software / API / protocolo Epson
     │
     ▼
Epson L365
```

Este enfoque podría resolver el problema particular, pero introduciría inmediatamente una dependencia fuerte respecto del fabricante.

Una HP, Brother, Canon u otra impresora podría requerir una implementación completamente diferente.

El enfoque elegido para PrintSwitch parte de otra observación:

> La intención de imprimir ya es conocida por Windows antes de que PrintSwitch necesite hacer nada.

Cuando una aplicación envía un trabajo, ese trabajo entra en el subsistema de impresión del sistema operativo.

Por lo tanto:

```text
Word / PDF / navegador / etc.
              │
              ▼
            Windows
              │
              ▼
        Print Spooler
              │
              ▼
       trabajo de impresión
              │
              ▼
          PrintSwitch
```

Actualmente `QueueWatcher.ps1` consulta los trabajos que Windows expone mediante `Win32_PrintJob` y selecciona aquellos correspondientes a la impresora configurada.

Esto significa que PrintSwitch:

```text
NO reemplaza al Print Spooler
NO modifica al Print Spooler
NO necesita inicialmente hablar con Epson
NO necesita generar nuevamente el trabajo
```

En la arquitectura actual tampoco resulta estrictamente correcto decir que PrintSwitch **intercepta** al Print Spooler.

El término más preciso es:

> **PrintSwitch observa información sobre los trabajos que Windows expone desde su subsistema de impresión y reacciona cuando detecta un evento relevante.**

Esto permite utilizar al sistema operativo como una capa de abstracción entre PrintSwitch y los diferentes fabricantes.

---

## Ventaja arquitectónica: independencia del fabricante

La decisión anterior introduce una propiedad potencialmente muy importante para PrintSwitch: la posibilidad de construir una parte considerable del programa de forma independiente del fabricante de la impresora.

Conceptualmente:

```text
                         WINDOWS
                            │
                     PRINT SPOOLER
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
          ▼                 ▼                 ▼
        EPSON              HP              BROTHER
          │                 │                 │
          │                 │                 │
       Cola A            Cola B            Cola C
          │                 │                 │
          └─────────────────┼─────────────────┘
                            │
                            ▼
                       QueueWatcher
```

QueueWatcher no necesita inicialmente preguntarse:

```text
¿esto es Epson?
¿esto es HP?
¿esto es Brother?
```

Su primera pregunta puede ser mucho más general:

```text
¿apareció un trabajo de impresión que me interesa?
```

Luego pueden existir capas posteriores encargadas de determinar qué necesita esa impresora concreta.

Esto permite imaginar una arquitectura futura:

```text
                        PrintSwitch
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
        CAPA GENÉRICA               ADAPTADORES
          WINDOWS                    OPCIONALES
              │                           │
              │                       ┌───┼────┐
              │                       │   │    │
              ▼                       ▼   ▼    ▼
        trabajos/colas              Epson HP Brother ...
        red
        SSID
        TCP/IP
        IPP
        conectividad
```

De esta forma, una Epson L365 no define necesariamente el alcance del proyecto.

La L365 debe considerarse:

> **el dispositivo experimental de referencia utilizado durante el desarrollo inicial de PrintSwitch.**

La compatibilidad real con otros fabricantes deberá comprobarse experimentalmente más adelante.

Por lo tanto, la independencia de fabricante es actualmente un **objetivo arquitectónico fundamentado**, no todavía una compatibilidad multimarca demostrada.

---

## La cola y la conectividad son problemas diferentes

Otro punto fundamental aparece cuando se separa la existencia del trabajo de la posibilidad física o lógica de alcanzar la impresora.

Windows puede conocer perfectamente que existe un trabajo:

```text
Documento
    │
    ▼
Print Spooler
    │
    ▼
Cola Epson
    │
    ▼
Trabajo pendiente
```

mientras simultáneamente ocurre:

```text
PC
 │
 ├── conectada a Claro640
 │
 └── Epson accesible solamente desde suarezcores
```

En ese escenario no existe una contradicción.

Windows sabe:

```text
"hay que imprimir este documento"
```

pero eso no significa necesariamente que en ese instante exista un camino válido hasta el dispositivo físico.

Esta separación fue observada experimentalmente durante el desarrollo de PrintSwitch.

Un trabajo enviado mientras la PC estaba conectada a una red desde la cual la Epson no resultaba alcanzable quedó pendiente.

Posteriormente, al cambiar la PC a la red adecuada, el trabajo pudo continuar sin necesidad de que el usuario volviera a generarlo manualmente.

Conceptualmente:

```text
APLICACIÓN
    │
    ▼
Trabajo generado
    │
    ▼
Cola de Windows
    │
    │
    │   impresora inaccesible
    │
    ▼
Trabajo pendiente
    │
    │
    │   conectividad restaurada
    ▼
Trabajo continúa
    │
    ▼
Impresora
```

Este comportamiento es uno de los fundamentos principales de PrintSwitch.

El programa no necesita necesariamente reconstruir ni reenviar el documento.

Puede concentrarse en detectar que:

```text
existe un trabajo
        +
no existe actualmente el camino adecuado
```

y eventualmente intentar restaurar ese camino.

---

## Separación entre detección y diagnóstico

A partir de lo anterior, PrintSwitch separa deliberadamente dos responsabilidades.

### QueueWatcher

Responde principalmente:

```text
¿ocurrió un evento de impresión que me interesa?
```

Su función actual es observar los trabajos expuestos por Windows y detectar nuevos trabajos asociados a una determinada impresora.

Conceptualmente:

```text
Windows / Print Spooler
          │
          ▼
       Trabajo
          │
          ▼
     QueueWatcher
          │
          ▼
PRINT_JOB_DETECTED
```

### ConnectivityAnalyzer

Una vez detectado el trabajo, aparece una pregunta completamente diferente:

```text
¿existe actualmente el contexto de conectividad necesario
para alcanzar esa impresora?
```

ConnectivityAnalyzer releva actualmente:

```text
SSID actual
SSID requerido
estado informado por Windows
ICMP / Ping
TCP 9100
HTTP 80
```

y utiliza esa evidencia para producir una clasificación.

Actualmente:

```text
NETWORK_MISMATCH

PRINTER_REACHABLE

PRINTER_UNREACHABLE_ON_TARGET_NETWORK
```

Por lo tanto:

```text
QueueWatcher
      │
      │ detecta intención
      ▼
ConnectivityAnalyzer
      │
      │ analiza posibilidad
      ▼
Classification
```

Esta separación evita mezclar dos problemas distintos:

```text
"alguien quiere imprimir"
```

y:

```text
"la impresora puede ser alcanzada"
```

---

## ¿Qué aporta realmente PrintSwitch?

PrintSwitch no pretende reemplazar aquello que Windows ya hace correctamente.

Windows ya sabe:

- que existe una impresora lógica;
- que una aplicación solicitó una impresión;
- que existe un trabajo;
- a qué impresora pertenece;
- que el trabajo está pendiente, imprimiendo o presenta determinado estado;
- cómo administrar su cola.

PrintSwitch agrega otra capa de razonamiento:

> **¿Existe en este momento el contexto de conectividad necesario para que el trabajo pueda alcanzar el dispositivo al cual está destinado?**

La arquitectura actual puede representarse así:

```text
                    APLICACIÓN
                        │
                        ▼
                      WINDOWS
                        │
                        ▼
                  PRINT SPOOLER
                        │
                        ▼
                 COLA / TRABAJO
                        │
                        ▼
                   QueueWatcher
                        │
                  evento detectado
                        │
                        ▼
              ConnectivityAnalyzer
                        │
              ┌─────────┼─────────┐
              │         │         │
              ▼         ▼         ▼
             SSID      TCP       Estado
                       IP        Windows
              │         │         │
              └─────────┼─────────┘
                        ▼
                  CLASIFICACIÓN
                        │
          ┌─────────────┼─────────────────┐
          │             │                 │
          ▼             ▼                 ▼
      NETWORK_       PRINTER_       PRINTER_UNREACHABLE_
      MISMATCH       REACHABLE      ON_TARGET_NETWORK
          │
          ▼
       DECISIÓN
          │
          ▼
        ACCIÓN
       (futura)
```

En la etapa actual:

```text
Percibir    ✔
Relevar     ✔
Clasificar  ✔
Decidir     ✔ básico
Actuar      ✘
Verificar   ✘
Recuperar   ✘
```

El programa ya posee un flujo funcional:

```text
esperar
   ↓
detectar
   ↓
relevar
   ↓
clasificar
   ↓
proponer
   ↓
volver a esperar
```

pero permanece deliberadamente en modo:

```text
DRY-RUN
```

Por lo tanto, todavía no modifica automáticamente la conectividad.

---

## Principio arquitectónico resultante

A partir de todo lo anterior se adopta como principio de diseño:

> **PrintSwitch debe utilizar primero las abstracciones genéricas proporcionadas por Windows y recurrir a mecanismos específicos de fabricante solamente cuando aporten información o capacidades que no puedan obtenerse de forma genérica.**

Esto permite que el proyecto evolucione desde:

```text
"resolver el problema de una Epson L365"
```

hacia:

```text
"gestionar el contexto de conectividad requerido por trabajos
de impresión administrados por Windows"
```

sin asumir todavía que la compatibilidad multimarca está demostrada experimentalmente.