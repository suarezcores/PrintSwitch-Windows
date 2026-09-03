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
---

> **Nota de evolución documental — conciliación del Roadmap Alpha (27/08/2026)**
>
> Las secciones anteriores representan objetivos, hipótesis de evolución y
> tareas planteadas durante etapas previas del proyecto.
>
> Se conservan como registro histórico.
>
> A partir de este punto se concilia ese Roadmap con el estado realmente
> alcanzado durante el cierre del Alpha.
>
> Ante una contradicción, las secciones posteriores a este corte representan
> el estado vigente de planificación.

# Conciliación del Roadmap — cierre Alpha

## 18. Propósito de la conciliación

El desarrollo Alpha permitió completar o redefinir varios objetivos que
anteriormente aparecían como pendientes.

La arquitectura implementada incorporó:

```text
Interface / Route Awareness
preservación de Ethernet
política de intervención mínima
evaluación contextual de Wi-Fi
ejecución autorizada
validación post-switch
orquestación operativa
```

Por lo tanto, el Roadmap debe distinguir entre:

```text
objetivo histórico
        |
        v
estado alcanzado
        |
        v
siguiente evolución
```

---

## 19. Interface / Route Awareness — alcanzado

El objetivo de analizar interfaces y rutas antes de cambiar de red quedó
implementado mediante:

```text
InterfacePathAnalyzer.ps1
RouteAnalyzer.ps1
```

Se validaron escenarios con:

```text
camino Ethernet único
camino Wi-Fi único
múltiples caminos alcanzables
camino candidato no alcanzable
```

Estado:

```text
ALCANZADO EN ALPHA
```

---

## 20. Coexistencia Ethernet + Wi-Fi — alcanzado

Se validó un escenario donde Ethernet y Wi-Fi pertenecían simultáneamente a:

```text
192.168.1.0/24
```

y ambas interfaces podían alcanzar la Epson L365.

El sistema clasificó:

```text
MULTIPLE_REACHABLE_PATHS
```

sin intentar cambiar de red.

Estado:

```text
ALCANZADO EN ALPHA
```

---

## 21. Intervención mínima — alcanzado

El sistema ya no considera que detectar un trabajo de impresión sea motivo
suficiente para cambiar de Wi-Fi.

La política vigente es:

```text
si existe camino funcional
    NO_ACTION
```

y también:

```text
si existe camino local candidato
pero la impresora no responde
    NO_SWITCH_PRINTER_UNREACHABLE
```

Estado:

```text
ALCANZADO EN ALPHA
```

---

## 22. Preservación de Ethernet — alcanzado

La arquitectura establece que PrintSwitch:

```text
no modifica Ethernet
```

Se implementaron y validaron:

```text
EthernetPresentBefore
EthernetPresentAfter
EthernetPreserved
```

El script de simulación:

```text
scripts\Test-EthernetPreservation.ps1
```

obtuvo:

```text
4/4 PASS
```

Estado:

```text
ALCANZADO EN ALPHA
```

---

## 23. Evolución de la estrategia inicial de cambio Wi-Fi

Las primeras estrategias podían interpretarse como una relación directa:

```text
trabajo detectado
        |
        v
SSID incorrecto
        |
        v
cambiar Wi-Fi
```

La arquitectura Alpha reemplaza esa lógica por:

```text
trabajo detectado
        |
        v
analizar caminos reales
        |
        v
analizar rutas
        |
        v
aplicar política
        |
        v
evaluar Wi-Fi sólo si corresponde
        |
        v
decidir
        |
        v
ejecutar sólo si está autorizado
        |
        v
validar recuperación
```

Estado:

```text
ESTRATEGIA REDEFINIDA E IMPLEMENTADA
```

---

## 24. Recuperación End-to-End — alcanzada con Epson L365

Se validó el flujo completo con:

```text
Epson encendida
Ethernet desconectado
Wi-Fi inicial = Claro640
SSID objetivo = suarezcores
```

Resultado:

```text
Claro640
   |
   v
suarezcores
   |
   v
NETWORK_SWITCH_VERIFIED
   |
   v
RECOVERY_CONFIRMED_FAST
   |
   v
CONTEXTUAL_RECOVERY_SUCCESS
```

La recuperación fue confirmada aproximadamente a los:

```text
1496 ms
```

y la página física fue impresa correctamente.

Estado:

```text
ALCANZADO EN ALPHA
```

Alcance:

```text
Windows
Epson L365
TCP 9100
entorno probado
```

---

## 25. No intervención contextual — alcanzada

Se validó que PrintSwitch pueda tener recuperación habilitada y, aun así,
decidir no intervenir.

Caso representativo:

```text
Jabber activo
Ethernet disponible
Wi-Fi = Claro640
Epson apagada
RecoveryEnabled = True
```

Resultado:

```text
SwitchAuthorized = False
SwitchExecuted   = False
```

Estado:

```text
ALCANZADO EN ALPHA
```

---

## 26. Happy path integrado — alcanzado

Se validó el escenario donde:

```text
Epson encendida
Ethernet desconectado
Wi-Fi = suarezcores
RecoveryEnabled = True
```

El trabajo atravesó el orquestador y produjo:

```text
UNIQUE_REACHABLE_PATH
EXISTING_REACHABLE_PATH
NO_ACTION
```

sin realizar cambios de red.

Estado:

```text
ALCANZADO EN ALPHA
```

---

## 27. Orquestación operativa — alcanzada

La recuperación dejó de estar distribuida entre lógica experimental y lógica
duplicada dentro de `QueueWatcher`.

El flujo vigente es:

```text
QueueWatcher
    |
    v
PrintRecoveryOrchestrator
```

El orquestador coordina:

```text
InterfacePathAnalyzer
RouteAnalyzer
ConnectivityPolicy
WiFiCandidateEvaluator
SwitchDecision
NetworkManager
RecoveryValidator
ConnectivityAnalyzer
```

`ContextualRecoveryTest.ps1` queda como antecedente experimental.

Estado:

```text
ALCANZADO EN ALPHA
```

---

## 28. Estado conciliado de objetivos históricos

| Objetivo | Estado al cierre Alpha |
|---|---|
| Detectar trabajos de impresión | Alcanzado |
| Observar cola en tiempo real | Alcanzado |
| Analizar conectividad | Alcanzado |
| Distinguir Ethernet y Wi-Fi | Alcanzado |
| Analizar caminos por interfaz | Alcanzado |
| Analizar ruta efectiva | Alcanzado |
| Detectar múltiples caminos | Alcanzado |
| Preservar Ethernet | Alcanzado |
| Aplicar política de intervención mínima | Alcanzado |
| Evaluar SSID objetivo | Alcanzado |
| Detectar perfil Wi-Fi conocido | Alcanzado |
| Considerar visibilidad Wi-Fi temporal | Alcanzado |
| Decidir cambio de Wi-Fi | Alcanzado |
| Ejecutar cambio autorizado | Alcanzado |
| Verificar cambio de SSID | Alcanzado |
| Validar recuperación TCP después del cambio | Alcanzado |
| Integrar recuperación en QueueWatcher | Alcanzado |
| Imprimir físicamente después de recuperación | Alcanzado |
| No intervenir si ya existe camino válido | Alcanzado |
| No cambiar red por impresora apagada | Alcanzado |
| Descubrir impresora automáticamente | Pendiente |
| Soportar múltiples impresoras | Pendiente |
| Validar otra marca de impresora | Pendiente |
| Retornar automáticamente al estado de red previo | Pendiente |
| Soportar protocolos distintos de TCP 9100 | Pendiente |
| Crear interfaz gráfica | Pendiente |
| Implementar versión Android | Pendiente |

---

## 29. Lección del Roadmap Alpha

El Alpha mostró que la dificultad principal no era:

```text
cómo cambiar de Wi-Fi
```

sino:

```text
cómo decidir correctamente
si debe cambiarse
```

El foco futuro debe continuar priorizando:

```text
conocimiento del contexto
+
intervención mínima
+
validación posterior
```

antes que agregar automatizaciones más agresivas.

---

# Roadmap Post-Alpha

## 30. Criterio para la siguiente etapa

El siguiente ciclo no debe comenzar agregando características indiscriminadas.

La prioridad es convertir el Alpha funcional en una base reproducible y
generalizable.

Secuencia recomendada:

```text
cerrar documentación
        |
        v
crear regresiones
        |
        v
validar segundo hardware
        |
        v
generalizar identidad
        |
        v
generalizar protocolos
        |
        v
ampliar automatización
```

---

## 31. Consolidación documental inmediata

Objetivo:

```text
cerrar formalmente el estado Alpha
```

Tareas:

```text
actualizar documentación arquitectónica
actualizar conocimiento
actualizar pruebas experimentales
conciliar Roadmap
actualizar metodología
crear checkpoint Alpha
actualizar índice MkDocs
validar build
```

Criterio de cierre:

```text
documentación reproducible
sin contradicciones no señalizadas
build MkDocs correcto
Git limpio después del commit
```

Prioridad:

```text
INMEDIATA
```

---

## 32. Batería de regresión Alpha

Crear un conjunto de pruebas repetibles para escenarios ya validados.

Mínimo:

```text
1. Ethernet único y Epson accesible
2. Ethernet + Wi-Fi ambos accesibles
3. Epson apagada con camino Ethernet candidato
4. sin Ethernet + Wi-Fi incorrecto
5. Wi-Fi ya correcto
6. SSID objetivo no visible
7. recuperación en dry-run
8. recuperación autorizada
9. preservación Ethernet
```

Objetivo:

```text
detectar regresiones antes de agregar nuevas funciones
```

Prioridad:

```text
ALTA
```

---

## 33. Segunda impresora / hardware diferente

La primera expansión importante debe ser validar el modelo con una segunda
impresora.

Preferentemente:

```text
otro fabricante
```

por ejemplo:

```text
HP
```

Objetivo:

```text
separar conocimiento realmente genérico
de comportamiento específico Epson
```

Se debe relevar:

```text
tipo de puerto
protocolo
descubrimiento
dirección IP
driver
estado de cola
respuesta ante impresora apagada
```

Prioridad:

```text
ALTA
```

---

## 34. PrinterDiscovery

Actualmente la identidad operativa de la Epson está configurada explícitamente.

Evolución propuesta:

```text
PrinterDiscovery
```

Responsabilidades posibles:

```text
enumerar impresoras instaladas
identificar puerto
identificar IP
detectar protocolo
detectar hostname
obtener propiedades de Windows
asociar impresora con configuración PrintSwitch
```

El descubrimiento no debe depender exclusivamente de una IP fija.

Prioridad:

```text
ALTA DESPUÉS DE SEGUNDO HARDWARE
```

---

## 35. Identidad dinámica de impresora

La configuración actual usa:

```text
IP conocida
SSID conocido
```

La evolución debe permitir identificar una impresora por una combinación de:

```text
nombre de cola
hostname
MAC cuando sea observable
IP
puerto
protocolo
identidad del driver
```

Objetivo:

```text
reducir dependencia de configuraciones manuales rígidas
```

Debe contemplarse DHCP dinámico.

Prioridad:

```text
MEDIA-ALTA
```

---

## 36. Estrategias por protocolo

El Alpha fue validado principalmente con:

```text
RAW TCP 9100
```

La evolución debe abstraer la comprobación de servicio.

Modelo futuro:

```text
PrinterReachabilityStrategy
        |
        +--> Raw9100
        +--> IPP
        +--> LPR
        +--> WSD
        +--> otras estrategias
```

Cada estrategia debe definir su propia evidencia positiva de alcanzabilidad.

Prioridad:

```text
MEDIA
```

---

## 37. Retorno a la conectividad previa

El Alpha puede cambiar:

```text
Claro640 -> suarezcores
```

pero todavía no implementa un retorno automático general.

Una futura estrategia debe considerar:

```text
SSID previo
estado previo
trabajo finalizado
conectividad de Internet
otras aplicaciones
tiempo de gracia
```

No debe implementarse simplemente como:

```text
imprimió
   |
   v
volver inmediatamente
```

La restauración debe ser contextual y validada.

Prioridad:

```text
MEDIA
```

---

## 38. Múltiples impresoras

El orquestador ya acepta:

```text
PrinterName
TargetIP
TargetSSID
```

lo que prepara parte de la arquitectura.

Sin embargo, el soporte multi-impresora requerirá:

```text
configuración por impresora
política por dispositivo
trabajos simultáneos
destinos en diferentes redes
prioridades
conflictos entre recuperaciones
```

Ejemplo de conflicto futuro:

```text
Printer A requiere SSID A
Printer B requiere SSID B
```

La solución debe evitar oscilaciones de red.

Prioridad:

```text
MEDIA
```

---

## 39. Evolución hacia producto

La interfaz gráfica no es prioridad inmediata.

Debe aparecer después de estabilizar:

```text
motor de decisión
configuración
descubrimiento
regresiones
logging
```

Una futura UI podría mostrar:

```text
impresoras observadas
estado
red requerida
camino actual
última recuperación
acciones disponibles
historial
```

El core debe continuar funcionando independientemente de la UI.

Prioridad:

```text
POSTERIOR
```

---

## 40. Línea paralela Android

La investigación Android continúa siendo una posible evolución separada.

Problema observado:

```text
Epson iPrint
+
red local sin Internet
```

puede producir una experiencia distinta a Windows.

Una versión Android requerirá estudiar:

```text
selección de Wi-Fi
restricciones del sistema operativo
permisos
APIs de conectividad
mantenimiento de Internet
descubrimiento local
impresión desde aplicaciones
```

No debe asumirse que la arquitectura Windows puede trasladarse directamente.

Prioridad:

```text
PARALELA / EXPERIMENTAL
```

---

## 41. Criterio aproximado para una etapa Pre-Beta

PrintSwitch no debería considerarse Pre-Beta sólo porque el Alpha funciona con
la Epson L365.

Un posible criterio mínimo sería:

```text
Alpha estable
+
regresiones automatizadas
+
segunda impresora validada
+
al menos dos fabricantes
+
identidad menos dependiente de IP fija
+
abstracción básica de protocolos
+
configuración multi-impresora inicial
+
logging consolidado
+
documentación reproducible
```

La denominación de etapa deberá depender de evidencia real, no de calendario.

---

## 42. Dirección Post-Alpha

La dirección inmediata del proyecto es:

```text
menos supuestos
más descubrimiento

menos configuración rígida
más identidad contextual

menos decisiones basadas en SSID
más decisiones basadas en alcanzabilidad

menos automatización ciega
más intervención mínima verificable
```

El objetivo Post-Alpha no es que PrintSwitch cambie redes con mayor frecuencia.

El objetivo es que pueda decidir correctamente en una variedad mayor de
entornos y dispositivos.


---

# Roadmap vigente — Septiembre 2026

> **Estado documental**
>
> Todo el roadmap anterior se conserva como registro histórico de la
> planificación y evolución de PrintSwitch-Windows.
>
> Los objetivos, prioridades y estados anteriores representan decisiones
> reales tomadas durante Alpha y Post-Alpha y no deben ser reescritos
> retroactivamente.
>
> Esta sección establece el estado vigente del roadmap a partir del
> checkpoint:
>
> ```text
> commit 55316dd
> FEAT: consolida recovery operacional y diagnostico opcional
> ```

---

## 43. Criterio de avance desde este checkpoint

La evolución inmediata de PrintSwitch debe continuar siendo incremental.

No se avanzará directamente hacia:

```text
UI
instalador
servicio residente
multi-impresora completa
correlación física compleja
```

antes de validar suficientemente el motor operacional.

La secuencia vigente es:

```text
1. cerrar milestone endpoint-aware
        |
        v
2. consolidar inconsistencias del recovery
        |
        v
3. validar Brother dentro del mismo modelo
        |
        v
4. consolidar Discovery + Policy
        |
        v
5. integrar QueueWatcher
        |
        v
6. regresiones y casos raros
        |
        v
7. aplicación / UI
        |
        v
8. multi-impresora y otros fabricantes
```

Cada etapa debe producir evidencia antes de habilitar la siguiente.

---

## 44. Punto 1 — Cierre del milestone endpoint-aware

Estado:

```text
COMPLETADO
```

El objetivo era abandonar la dependencia operacional de una asociación rígida:

```text
impresora
+
IP fija
+
TCP 9100
```

y pasar a:

```text
cola
   |
   v
endpoint
   |
   v
reachability strategy
```

Se incorporaron y validaron componentes específicos para esta abstracción:

```text
PrinterEndpointResolver.ps1
PrinterEndpointReachability.ps1
PrinterServiceProbe.ps1
PrinterDiscovery.ps1
```

Los analizadores de caminos fueron adaptados para utilizar:

```text
OperationalTargetIP
OperationalTcpPort
```

en lugar de asumir TCP 9100 como puerto operacional universal.

---

## 45. Evidencia de cierre del Punto 1

La Epson L365 permitió validar el modelo endpoint-aware.

La cola:

```text
L365 Series(Red)
```

fue resuelta como:

```text
Transport    = NETWORK
Protocol     = LPR
Destination  = 192.168.1.108
TcpPort      = 515
QueueName    = ENPQueue
Strategy     = LPR_TCP
```

Posteriormente se ejecutó una recuperación física completa:

```text
Claro640
   |
   v
suarezcores
```

utilizando como objetivo operacional:

```text
192.168.1.108:515
```

Resultado:

```text
RecoverySucceeded     = True
FinalClassification   = CONTEXTUAL_RECOVERY_SUCCESS
```

Por lo tanto:

```text
PUNTO 1 = CERRADO
```

---

## 46. Punto 2 — Consolidación de inconsistencias

Estado:

```text
COMPLETADO
```

El objetivo fue estabilizar el contrato del Orchestrator antes de introducir
formalmente una segunda impresora.

Se trabajó sobre:

```text
semántica de preservación Ethernet
versionado del Orchestrator
TargetIP vs OperationalTargetIP
OperationalTcpPort
policy opcional
dependencias obligatorias
ConnectivityAnalyzer
```

---

## 47. EthernetPreservationStatus

La semántica quedó definida como:

```text
Ethernet no existía antes
    -> NOT_APPLICABLE

Ethernet existía y continúa activa
    -> PRESERVED

Ethernet existía y se perdió
    -> FAILED
```

El campo:

```text
EthernetPreserved
```

queda asociado a:

```text
null
True
False
```

respectivamente.

Esto evita considerar un escenario sin Ethernet inicial como un fallo de
preservación.

---

## 48. TargetIP y destino operacional

La precedencia quedó definida como:

```text
TargetIP explícito
        |
        +--> existe
        |      |
        |      v
        | OperationalTargetIP = TargetIP
        |
        +--> no existe
               |
               v
OperationalTargetIP = destino resuelto del endpoint
```

El puerto operacional se obtiene del endpoint:

```text
OperationalTcpPort = Endpoint.TcpPort
```

La precedencia fue validada en dry-run mediante un destino alternativo,
confirmando que los analizadores posteriores utilizaron el override y no la
dirección configurada originalmente en la cola.

---

## 49. ConnectivityAnalyzer deja de ser dependencia operacional

`ConnectivityAnalyzer.ps1` continúa disponible como componente diagnóstico.

Sin embargo:

```text
NO
```

es un requisito para determinar el éxito del recovery.

La recuperación operacional se determina mediante:

```text
NetworkSwitchVerified
        +
RecoveryValidator.RecoveryConfirmed
        +
RouteAfter.TargetReachable
```

Se realizó una prueba E2E con:

```text
ConnectivityAnalyzer.ps1
```

temporalmente ausente.

Resultado:

```text
ConnectivityAfter     = NOT_AVAILABLE
RecoverySucceeded     = True
FinalClassification   = CONTEXTUAL_RECOVERY_SUCCESS
```

Por lo tanto:

```text
ConnectivityAnalyzer
        |
        v
diagnóstico opcional
```

queda separado de:

```text
autoridad operacional de recovery
```

---

## 50. Cierre formal del Punto 2

El estado de código utilizado para cerrar esta etapa es:

```text
commit 55316dd
FEAT: consolida recovery operacional y diagnostico opcional
```

Los checks previos al commit fueron:

```text
PowerShell Parser = PASS
git diff --check  = PASS
```

El commit fue publicado en:

```text
main
origin/main
```

y el working tree quedó limpio.

Por lo tanto:

```text
PUNTO 2 = CERRADO
```

No deben incorporarse nuevas correcciones funcionales pertenecientes a este
punto salvo que una regresión posterior demuestre un defecto real.

---

## 51. Punto 3 — Validación Brother dentro del mismo modelo

Estado:

```text
SIGUIENTE ETAPA
```

Hardware disponible:

```text
Brother HL-1212W
```

Windows expone actualmente dos colas relevantes:

```text
Brother HL-1210W series
Brother HL-1210W series USB
```

El objetivo de esta etapa no es agregar soporte especial para Brother.

El objetivo es comprobar si la arquitectura genérica existente puede
interpretar correctamente ambas colas.

---

## 52. Caso Brother USB

El modelo esperado es:

```text
cola Brother USB
        |
        v
endpoint USB
        |
        v
USB_PRESENCE
```

### USB conectado

Resultado esperado:

```text
REACHABLE
    |
    v
NO_ACTION
```

No debe existir evaluación de recovery Wi-Fi.

### USB desconectado

Resultado esperado:

```text
UNREACHABLE
    |
    v
NO_WIFI_ACTION
```

PrintSwitch no debe inventar una recuperación de red simplemente porque el
endpoint USB dejó de estar disponible.

### Estado incierto

Resultado esperado:

```text
UNKNOWN
    |
    v
FAIL SAFE
    |
    v
NO_WIFI_ACTION
```

---

## 53. Caso Brother Network

La cola de red observada utiliza:

```text
PortName  = BRWC48E8F7B140F
Transport = NETWORK
Protocol  = LPR
TcpPort   = 515
QueueName = BINARY_P1
```

El hostname observado es:

```text
BRWC48E8F7B140F
```

En el entorno donde puede resolverse se observó:

```text
192.168.100.12
```

La validación formal debe comprobar:

```text
cola
  |
  v
endpoint NETWORK
  |
  v
resolución de hostname
  |
  v
LPR / TCP 515
  |
  v
reachability
  |
  v
path analysis
```

sin agregar lógica específica para Brother al Orchestrator.

---

## 54. Criterio de aprobación del Punto 3

El Punto 3 podrá considerarse cerrado cuando exista evidencia reproducible de
los siguientes escenarios:

```text
[ ] Brother USB conectado
    -> endpoint USB
    -> REACHABLE
    -> NO_ACTION
    -> ningún cambio Wi-Fi

[ ] Brother USB desconectado
    -> endpoint USB
    -> UNREACHABLE
    -> ningún recovery Wi-Fi inventado

[ ] Brother NETWORK alcanzable
    -> endpoint NETWORK
    -> LPR / 515
    -> camino existente
    -> NO_ACTION

[ ] Brother NETWORK no resoluble o sin evidencia suficiente
    -> UNKNOWN / clasificación segura
    -> ningún cambio Wi-Fi no autorizado
```

Además:

```text
[ ] no debe agregarse hardcoding Brother al runtime común

[ ] Epson debe continuar funcionando después de las pruebas

[ ] Ethernet debe continuar siendo preservado

[ ] policy ausente no debe convertir la cola Brother en inválida
```

Sólo después de estas comprobaciones:

```text
PUNTO 3 = CERRADO
```

---

## 55. Punto 4 — Consolidar Discovery + Policy

Estado:

```text
PENDIENTE
```

El modelo conceptual ya existe:

```text
Windows / Registry / PnP / Spooler
             |
             v
          Discovery
             |
             v
         QueueContext


config/policy.json
             |
             v
      intención del usuario
```

Sin embargo, la consolidación definitiva pertenece a una etapa posterior a la
validación Brother.

Objetivos:

```text
PrinterDiscovery como inventario automático
discovery.json como snapshot regenerable
policy.json como intención persistente
printers.json solamente como compatibilidad legacy
```

No debe adelantarse la eliminación de:

```text
config/printers.json
```

mientras existan componentes Alpha que todavía lo utilicen.

---

## 56. Punto 5 — Integración completa con QueueWatcher

Estado:

```text
PENDIENTE
```

El objetivo es que la operación cotidiana deje de requerir ejecución manual
del Orchestrator.

El flujo buscado es:

```text
trabajo
   |
   v
QueueWatcher
   |
   v
cola
   |
   v
endpoint
   |
   v
paths
   |
   v
policy
   |
   v
acción mínima
```

`-EnableRecovery` deberá continuar significando:

```text
permiso para ejecutar una recuperación necesaria
```

y nunca:

```text
forzar un cambio de Wi-Fi
```

---

## 57. Punto 6 — Regresiones y casos raros

Estado:

```text
PENDIENTE
```

La batería deberá incluir al menos:

```text
impresora apagada

SSID objetivo no visible

perfil Wi-Fi conocido pero servicio no disponible

múltiples caminos existentes

múltiples caminos alcanzables

hostname no resoluble

USB conectado

USB desconectado

USB aparece durante ejecución

USB desaparece durante ejecución

endpoint UNKNOWN

policy ausente

recovery no autorizado

fallo de NetworkManager

switch realizado pero endpoint no recuperado

Ethernet presente antes y después

Ethernet ausente desde el inicio
```

El principio para los casos ambiguos será:

```text
FAIL SAFE
```

Una falta de evidencia no debe producir automáticamente una modificación de
conectividad.

---

## 58. Punto 7 — Aplicación y UI

Estado:

```text
POSTERIOR
```

La interfaz será una capa sobre el motor.

No deberá contener una segunda implementación de las decisiones de
conectividad.

La evolución prevista incluye:

```text
agente residente
system tray
estado de impresoras
logs
configuración mínima
historial de recuperaciones
instalador
```

La UI deberá consumir las decisiones y resultados producidos por el core.

---

## 59. Punto 8 — Multi-impresora y otros fabricantes

Estado:

```text
FUTURO
```

Después de estabilizar Epson + Brother se incorporarán nuevas fuentes de
evidencia.

Entre ellas:

```text
HP
otras impresoras
múltiples trabajos simultáneos
múltiples endpoints por dispositivo físico
correlación USB / NETWORK
```

En esta etapa será necesario evolucionar hacia un modelo semejante a:

```text
QueueWatcher
      |
      v
Job Contexts
      |
      v
Endpoint Resolver
      |
      v
Path Analyzer por trabajo
      |
      v
Conflict / Resource Manager
      |
      v
Decision Engine
      |
      v
acciones
```

Wi-Fi deberá considerarse un recurso compartido cuya modificación puede
afectar a más de un trabajo.

USB y Ethernet pueden coexistir sin exigir el mismo tipo de arbitraje.

---

## 60. Regla de prioridad para la evolución futura

Las decisiones futuras deben favorecer el camino de menor intervención.

Conceptualmente:

```text
endpoint ya alcanzable
        |
        v
costo mínimo


USB disponible
Ethernet disponible
Wi-Fi actual funcional
        |
        v
preferidos


cambio de Wi-Fi
        |
        v
mayor costo


interrumpir otro trabajo
        |
        v
costo muy alto
```

Este modelo de costos todavía no constituye una implementación.

Es una dirección arquitectónica para la etapa multi-contexto.

---

## 61. Estado general — Septiembre 2026

El roadmap vigente queda:

```text
[COMPLETADO] 1. Cierre endpoint-aware

[COMPLETADO] 2. Consolidación de inconsistencias

[SIGUIENTE]   3. Validación Brother

[PENDIENTE]   4. Consolidar Discovery + Policy

[PENDIENTE]   5. Integración QueueWatcher

[PENDIENTE]   6. Regresiones y casos raros

[POSTERIOR]   7. Aplicación / UI

[FUTURO]      8. Multi-impresora / otros fabricantes
```

La regla para avanzar continúa siendo:

> **No promover una capacidad por diseño esperado. Promoverla cuando exista
> evidencia reproducible de que funciona y de que no rompe los escenarios ya
> validados.**

El siguiente trabajo funcional comienza en:

```text
PUNTO 3
VALIDACIÓN BROTHER
```

y no en la construcción de UI ni en la expansión prematura del sistema.