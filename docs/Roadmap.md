# PrintSwitch — Roadmap de desarrollo

**Documento:** RDM-001
**Versión:** 0.1
**Estado:** En desarrollo
**Última actualización:** 2026-08-17
**Relacionado con:** `Methodology.md`, `Knowledge.md`, `Architecture_Observed.md`

---

## 1. Objetivo

Este documento define el desarrollo incremental de PrintSwitch.

El proyecto avanzará mediante prototipos pequeños y verificables.

Cada etapa deberá demostrar una capacidad concreta antes de incorporar la siguiente.

El objetivo inicial no es construir inmediatamente una aplicación completa, sino validar progresivamente la siguiente cadena:

```text
Detectar
   ↓
Interpretar
   ↓
Decidir
   ↓
Cambiar red
   ↓
Verificar
   ↓
Imprimir
   ↓
Restaurar
```

---

# 2. Estado actual

## Fase 0 — Investigación y diagnóstico

**Estado:** COMPLETADA PARCIALMENTE

Se realizaron pruebas destinadas a conocer el comportamiento real del sistema antes de desarrollar la automatización.

### Validado

* identificación de la Epson L365 dentro de Windows;
* identificación de la red utilizada por la impresora;
* identificación de la IP observada de la impresora;
* inspección de la configuración de impresión;
* observación de la cola de Windows mediante PowerShell;
* detección de nuevos trabajos;
* detección de cambios de estado;
* persistencia de trabajos cuando la impresora no es accesible;
* acumulación de múltiples trabajos pendientes;
* recuperación de trabajos al restablecer manualmente la conectividad;
* acceso HTTP local a la impresora;
* funcionamiento de la LAN durante una interrupción de Internet.

### Pendiente de validación

* impresión completa con LAN disponible y WAN desconectada;
* comportamiento con otros fabricantes;
* comportamiento cuando cambia la IP DHCP;
* comportamiento cuando desaparece completamente el SSID requerido.

---

# 3. Fase 1 — Observador de impresión

**Objetivo:** detectar de manera confiable la intención de imprimir.

**Estado:** PROTOTIPO VALIDADO

El script experimental `Watch-PrintQueue.ps1` demostró que es posible observar la cola de impresión y registrar la aparición y evolución de trabajos.

## Capacidades actuales

```text
Trabajo nuevo
     ↓
Detección
     ↓
JobId
     ↓
Documento
     ↓
Estado
     ↓
Páginas / tamaño
     ↓
Registro
```

## Trabajo pendiente

Convertir el script experimental en un componente reutilizable.

Nombre conceptual:

```text
QueueWatcher
```

No deberá contener lógica específica de Epson.

---

# 4. Fase 2 — Analizador de conectividad

**Objetivo:** determinar si la impresora requerida es accesible antes de modificar la red.

**Estado:** PENDIENTE

Nombre conceptual:

```text
ConnectivityAnalyzer
```

Deberá poder realizar comprobaciones progresivas.

Ejemplo:

```text
¿Existe interfaz Wi-Fi?
        ↓
¿SSID actual?
        ↓
¿IP conocida responde?
        ↓
¿Servicio de impresión responde?
        ↓
¿Impresora validada?
```

Las comprobaciones concretas podrán incluir:

* conectividad IP;
* ICMP cuando esté disponible;
* TCP;
* puerto utilizado por Windows;
* HTTP cuando la impresora lo proporcione.

PrintSwitch no deberá considerar un ping fallido como prueba definitiva de que una impresora está desconectada.

---

# 5. Fase 3 — Perfil de impresora

**Objetivo:** separar la identidad de una impresora de su dirección IP actual.

**Estado:** PENDIENTE

Se propone conceptualmente:

```text
PrinterProfile
│
├── WindowsPrinter
├── RequiredSSID
├── MAC
├── Hostname
├── LastKnownIP
├── IPMode
└── ConnectionMetadata
```

Ejemplo del entorno experimental:

```text
WindowsPrinter = L365 Series(Red)
RequiredSSID   = suarezcores
MAC            = 64:EB:8C:E2:EB:06
Hostname       = EPSONE2EB06
LastKnownIP    = 192.168.1.108
IPMode         = dynamic
```

La estructura definitiva deberá surgir de las pruebas y no considerarse cerrada en esta etapa.

---

# 6. Fase 4 — Dos modos de resolución IP

PrintSwitch deberá funcionar tanto en redes administradas como en redes domésticas donde el usuario no tenga acceso al router.

## Modo A — IP conocida

La impresora posee:

* reserva DHCP;
* IP estática;
* o una dirección conocida estable.

Flujo:

```text
Perfil
  ↓
IP conocida
  ↓
Verificación
  ↓
Impresora encontrada
```

Este será inicialmente el modo más sencillo para desarrollar y probar.

---

## Modo B — DHCP dinámico

La IP puede cambiar.

Flujo objetivo:

```text
Última IP conocida
       ↓
¿Sigue siendo válida?
   ┌───┴───┐
   │       │
  SÍ      NO
   │       │
 usar      ▼
       descubrimiento
            ↓
      identificar equipo
            ↓
       actualizar IP
```

PrintSwitch no deberá requerir obligatoriamente una reserva DHCP.

**Estado:** PENDIENTE DE INVESTIGACIÓN Y VALIDACIÓN

---

# 7. Fase 5 — Network Manager

**Objetivo:** gestionar el cambio controlado de red Wi-Fi.

**Estado:** PENDIENTE

Nombre conceptual:

```text
NetworkManager
```

Responsabilidades iniciales:

* obtener SSID actual;
* enumerar redes conocidas;
* comprobar disponibilidad del SSID requerido;
* iniciar conexión;
* detectar éxito o fallo;
* registrar tiempos;
* conservar información de la red original.

Flujo:

```text
SSID actual
    ↓
Guardar origen
    ↓
Buscar SSID requerido
    ↓
Conectar
    ↓
Esperar asociación
    ↓
Verificar conectividad
```

No se almacenarán contraseñas Wi-Fi en texto plano.

Siempre que sea posible se utilizarán perfiles Wi-Fi administrados por Windows.

---

# 8. Fase 6 — Primer PrintSwitch automático

**Objetivo:** integrar QueueWatcher, ConnectivityAnalyzer y NetworkManager.

**Estado:** PENDIENTE

Primera automatización objetivo:

```text
Trabajo nuevo
      ↓
QueueWatcher
      ↓
Identificar impresora
      ↓
ConnectivityAnalyzer
      ↓
¿Accesible?
  ┌───┴────┐
  │        │
 SÍ       NO
  │        │
  │        ▼
  │   NetworkManager
  │        │
  │        ▼
  │   cambiar SSID
  │        │
  │        ▼
  │   verificar
  │        │
  └────────┘
      ↓
Windows continúa
la impresión
```

Esta fase constituirá el primer prototipo que merezca el nombre funcional de PrintSwitch.

---

# 9. Fase 7 — Detección de finalización

**Objetivo:** determinar cuándo PrintSwitch puede abandonar la red de impresión.

**Estado:** PENDIENTE

No deberá asumirse que la desaparición inmediata de un trabajo significa necesariamente que toda actividad de impresión terminó.

Deberán estudiarse:

* estado del trabajo;
* desaparición de la cola;
* múltiples documentos;
* trabajos consecutivos;
* tiempo de seguridad;
* errores del controlador;
* trabajos pausados.

---

# 10. Fase 8 — Retorno automático

**Objetivo:** regresar de manera segura a la red utilizada antes de imprimir.

**Estado:** PENDIENTE

Flujo objetivo:

```text
Impresión finalizada
        ↓
Periodo de seguridad
        ↓
¿Quedan trabajos?
    ┌───┴───┐
   SÍ      NO
    │       │
 esperar    ▼
        red original
             ↓
          conectar
             ↓
          verificar
```

La red original deberá detectarse dinámicamente.

No deberá codificarse `Claro640` como requisito del programa.

PrintSwitch deberá poder regresar a cualquier red desde la que haya iniciado el proceso.

---

# 11. Fase 9 — Manejo de errores

**Objetivo:** evitar que una automatización de red deje al usuario en una situación peor que la original.

**Estado:** PENDIENTE

Casos mínimos:

### SSID requerido inexistente

```text
Trabajo
  ↓
No aparece red
  ↓
No cambiar
  ↓
Registrar
  ↓
Informar
```

### Impresora apagada

La existencia del SSID no deberá interpretarse como disponibilidad de la impresora.

### Cambio de red fallido

PrintSwitch deberá intentar preservar o recuperar la conectividad original.

### IP modificada

Se deberá activar el mecanismo de descubrimiento correspondiente.

### Múltiples trabajos

No deberán producirse cambios repetitivos de red por cada documento.

### Nueva impresión durante el retorno

El sistema deberá decidir si cancelar el retorno o iniciar un nuevo ciclo.

---

# 12. Fase 10 — Logging y diagnóstico

**Objetivo:** hacer observable el comportamiento interno del programa.

**Estado:** INICIADO

Los prototipos actuales ya generan registros.

La versión madura deberá registrar eventos como:

```text
17:32:04 Trabajo detectado
17:32:04 Impresora: L365 Series(Red)
17:32:04 SSID actual: Claro640
17:32:05 Impresora no accesible
17:32:05 Red requerida: suarezcores
17:32:06 Cambio solicitado
17:32:10 Wi-Fi conectado
17:32:11 Impresora accesible
17:32:14 Trabajo procesándose
17:32:38 Cola vacía
17:32:48 Retorno autorizado
17:32:52 Red original restaurada
```

Los logs no deberán almacenar contraseñas Wi-Fi.

---

# 13. Fase 11 — Configuración

**Objetivo:** eliminar valores específicos del código.

**Estado:** PENDIENTE

Los perfiles deberán almacenarse fuera de la lógica principal.

Posible ubicación:

```text
config/
```

PrintSwitch deberá poder manejar en el futuro:

```text
Impresora A → Red A
Impresora B → Red B
Impresora C → Red C
```

sin modificar el código fuente.

---

# 14. Fase 12 — Validación multimarca

**Objetivo:** determinar qué partes de la arquitectura son realmente independientes del fabricante.

**Estado:** PENDIENTE

Prioridad prevista:

```text
1. Epson L365     ← entorno de referencia
2. HP             ← primera validación externa
3. Otros modelos  ← según disponibilidad
```

La compatibilidad solo deberá declararse después de pruebas reproducibles.

---

# 15. Fase 13 — Experiencia de usuario

Una vez estabilizado el núcleo se evaluarán:

* ejecución en segundo plano;
* inicio automático con Windows;
* icono en bandeja del sistema;
* estado de PrintSwitch;
* notificaciones;
* selección de impresoras;
* configuración de redes;
* diagnóstico interactivo;
* instalación y desinstalación.

**Estado:** FUTURO

La interfaz gráfica no es requisito para validar el núcleo.

---

# 16. Fase 14 — Distribución

Objetivos futuros:

* empaquetado;
* instalación sencilla;
* configuración inicial;
* logs accesibles;
* documentación integrada;
* publicación del código;
* releases versionadas.

**Estado:** FUTURO

---

# 17. Línea paralela — Android

Existe interés en resolver un problema equivalente desde dispositivos Android.

Sin embargo, Android posee una arquitectura de impresión y administración Wi-Fi diferente de Windows.

Por ello no se considerará inicialmente una simple adaptación del código de escritorio.

```text
PrintSwitch
│
├── Windows        ← desarrollo principal actual
│
└── Android        ← investigación futura
```

**Estado:** FUTURO

---

# 18. Criterio para versión 0.1 funcional

PrintSwitch podrá considerarse una primera versión funcional cuando pueda demostrar repetidamente:

```text
PC en red A
      ↓
usuario imprime
      ↓
trabajo detectado
      ↓
impresora pertenece a red B
      ↓
cambio automático A → B
      ↓
impresión completada
      ↓
retorno automático B → A
```

sin intervención manual del usuario durante el proceso normal.

---

# 19. Criterio de madurez posterior

Una versión posterior deberá agregar:

* IP dinámica;
* múltiples impresoras;
* manejo robusto de errores;
* independencia razonable del fabricante;
* recuperación ante fallos;
* instalación;
* interfaz de usuario;
* documentación reproducible;
* pruebas automatizadas donde sea posible.

---

# 20. Próximo hito

El siguiente hito técnico será construir el primer prototipo controlado que pueda:

> detectar un trabajo pendiente, comprobar que la impresora no es accesible y determinar que debe realizarse un cambio de red.

En ese primer prototipo el cambio podrá permanecer inicialmente deshabilitado o requerir confirmación para observar la decisión antes de permitir que PrintSwitch modifique la conectividad.

Esto permitirá validar la lógica antes de entregar al programa control efectivo sobre la interfaz Wi-Fi.

# Evolución de alcance — de cambio de Wi-Fi a gestión de conectividad

## Visión inicial

PrintSwitch nació para resolver un problema concreto:

```text
el usuario trabaja conectado a una red
        ↓
envía un trabajo a una impresora ubicada en otra red
        ↓
Windows mantiene el trabajo pendiente
        ↓
el usuario debe cambiar manualmente de Wi-Fi
```

La primera estrategia implementada y validada fue:

```text
detectar trabajo
    ↓
diagnosticar conectividad
    ↓
detectar NETWORK_MISMATCH
    ↓
cambiar al SSID requerido
    ↓
verificar cambio
    ↓
revalidar impresora
```

Esta estrategia ya fue validada end-to-end.

---

# Nueva definición de alcance

A partir del desarrollo y de las pruebas realizadas se amplía la definición conceptual de PrintSwitch.

> **PrintSwitch no es simplemente un programa que cambia de Wi-Fi.**

Su objetivo general pasa a ser:

> **Administrar el camino de conectividad necesario para que Windows pueda alcanzar una impresora de red, interviniendo solamente cuando sea necesario y alterando lo mínimo posible la conectividad existente.**

El cambio de SSID constituye una estrategia posible dentro de ese objetivo general.

---

# Principio de mínima intervención

La evolución futura deberá respetar:

```text
¿la impresora ya es alcanzable?
        │
     ┌──┴──┐
     │     │
    SÍ    NO
     │     │
     ▼     ▼
NO TOCAR   analizar alternativas
```

PrintSwitch no deberá modificar la conectividad solamente porque exista una red objetivo configurada.

Primero deberá determinar si ya existe un camino válido hacia la impresora.

---

# Futuro — Interface / Route Awareness

Actualmente la estrategia principal se concentra en la interfaz Wi-Fi.

A futuro PrintSwitch deberá considerar otras interfaces disponibles.

Ejemplo:

```text
Ethernet activo
      +
Wi-Fi activo
      ↓
¿la impresora ya es alcanzable por Ethernet?
      │
   SÍ ┴ NO
   │    │
   │    └→ evaluar Wi-Fi
   │
   └→ mantener interfaces sin cambios
```

Otro escenario posible:

```text
Ethernet
→ mantiene conectividad general
  Internet / Jabber / VPN / servicios

Wi-Fi
→ puede cambiarse específicamente
  para alcanzar la impresora
```

Esto permitiría minimizar microcortes o interrupciones en aplicaciones sensibles a cambios de red.

---

# Futuro — PrinterDiscovery

Actualmente los perfiles se definen explícitamente en:

```text
config/printers.json
```

A futuro se propone un componente:

```text
PrinterDiscovery
```

responsable de consultar el subsistema de impresión de Windows.

Deberá poder obtener información como:

```text
impresoras instaladas
nombre
driver
puerto
estado
impresora predeterminada
tipo de puerto
hostname o IP cuando sea identificable
```

El objetivo será aprovechar primero la información que Windows ya posee antes de solicitar datos manualmente al usuario.

---

# Impresora predeterminada

La impresora predeterminada podrá utilizarse como:

```text
candidata principal
```

pero no deberá considerarse automáticamente la única impresora relevante.

PrintSwitch deberá poder trabajar con múltiples destinos configurados.

---

# Futuro — estrategias por tipo de destino

La validación inicial se realizó con una Epson L365 utilizando evidencias como:

```text
ICMP
TCP 9100
TCP 80
```

Sin embargo, estas pruebas no deberán convertirse en requisitos universales.

Windows puede utilizar diferentes mecanismos según la impresora y su configuración:

```text
Standard TCP/IP
RAW / TCP 9100
LPR
WSD / WS-Print
IPP / IPPS
monitores de puerto específicos
```

Por lo tanto, la arquitectura futura deberá tender a:

```text
PrinterDiscovery
      ↓
identificar tipo de destino
      ↓
seleccionar estrategia de conectividad
      ↓
ConnectivityAnalyzer
```

---

# Estrategia actualmente validada

La estrategia disponible actualmente puede considerarse:

```text
Strategy 1
Wi-Fi Target Switching
```

Estado:

```text
detección de trabajo              ✔
configuración externa             ✔
validación de configuración       ✔
diagnóstico de conectividad       ✔
cambio automático de Wi-Fi        ✔
verificación del cambio           ✔
revalidación posterior            ✔
logging persistente               ✔
optimización de latencia          ✔
```

Esta estrategia no será descartada cuando aparezcan nuevas capacidades.

Pasará a formar parte de un conjunto más amplio de estrategias de conectividad.

---

# Evolución conceptual

```text
Problema real
    ↓
automatización específica
    ↓
prototipo funcional
    ↓
core modular
    ↓
configuración externa
    ↓
validación
    ↓
logging
    ↓
optimización
    ↓
gestión inteligente de conectividad
```

---

# Roadmap futuro

## Corto plazo

```text
[ ] consolidar documentación del prototipo funcional
[ ] mantener pruebas de regresión
[ ] preparar configuración para múltiples impresoras
[ ] mejorar trazabilidad de ejecución
```

## Medio plazo

```text
[ ] PrinterDiscovery
[ ] detección de impresora predeterminada
[ ] análisis de puertos configurados en Windows
[ ] estrategias según tipo de puerto/protocolo
[ ] pruebas con HP
[ ] pruebas con Lexmark
```

## Largo plazo

```text
[ ] Interface / Route Awareness
[ ] coexistencia Ethernet + Wi-Fi
[ ] selección de ruta con mínima intervención
[ ] asistente de configuración
[ ] empaquetado / ejecutable
[ ] pruebas en equipos externos
[ ] publicación de documentación
[ ] dominio y hosting del sitio
```