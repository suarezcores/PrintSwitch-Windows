# PrintSwitch — Arquitectura observada

**Documento:** ARC-001
**Versión:** 0.1
**Estado:** En desarrollo
**Última actualización:** 2026-08-17
**Relacionado con:** `Methodology.md`, `Knowledge.md`

---

## 1. Objetivo

Este documento describe la arquitectura observada durante las pruebas iniciales de PrintSwitch.

No representa todavía la arquitectura definitiva del software.

Su propósito es identificar los componentes que participan realmente en una impresión y determinar en qué punto puede intervenir PrintSwitch.

---

## 2. Entorno experimental

El entorno utilizado durante las pruebas contiene varias redes Wi-Fi.

La computadora puede estar conectada a una red diferente de aquella donde se encuentra la impresora.

El escenario principal observado fue:

```text
                    ┌─────────────────┐
                    │      PC         │
                    │    Windows      │
                    └────────┬────────┘
                             │
                       Wi-Fi actual
                             │
                    ┌────────▼────────┐
                    │    Claro640     │
                    └─────────────────┘

                       SIN ACCESO
                            X
                            │
                    ┌───────▼─────────┐
                    │   suarezcores   │
                    │     Router      │
                    └───────┬─────────┘
                            │
                            │ LAN
                            ▼
                    ┌─────────────────┐
                    │   Epson L365    │
                    │ 192.168.1.108   │
                    └─────────────────┘
```

En este estado la computadora puede generar trabajos de impresión, pero no posee conectividad con la impresora.

---

## 3. Flujo observado de un trabajo

Durante las pruebas se observó el siguiente comportamiento:

```text
Aplicación
   │
   │ solicitud de impresión
   ▼
Windows
   │
   ▼
Cola de impresión
   │
   │ trabajo registrado
   ▼
Controlador / sistema de impresión
   │
   ▼
Intento de comunicación
   │
   X
Impresora inaccesible
```

El fallo de comunicación no provoca necesariamente la desaparición del trabajo.

El trabajo permanece disponible en la cola.

**Clasificación:** `[OBSERVADO]`

---

## 4. Recuperación observada

Cuando la computadora cambia posteriormente a la red `suarezcores`:

```text
PC
 │
 │ cambio de Wi-Fi
 ▼
suarezcores
 │
 │ conectividad LAN
 ▼
Epson L365
```

el sistema de impresión puede continuar procesando los trabajos pendientes.

Durante las pruebas no fue necesario regresar a Word o Bloc de notas para solicitar nuevamente la impresión.

**Clasificación:** `[OBSERVADO]`

---

## 5. Punto de observación para PrintSwitch

Las aplicaciones que originaron los documentos fueron diferentes.

Sin embargo, los trabajos terminaron siendo visibles desde una infraestructura común de Windows.

Por lo tanto, el punto inicial elegido para PrintSwitch será:

```text
                 Aplicaciones
                /      |      \
               /       |       \
            Word    Bloc     Otras
               \       |       /
                \      |      /
                 ▼     ▼     ▼

             COLA DE WINDOWS
                    │
                    │
              PrintSwitch
```

PrintSwitch no necesita inicialmente conocer qué aplicación creó el documento.

Necesita detectar la existencia y estado del trabajo.

**Clasificación:** `[DECISIÓN]`

---

## 6. Separación entre cola y conectividad

Las pruebas muestran dos problemas diferentes:

### Capa de impresión

Determina si existen trabajos pendientes.

```text
¿Hay trabajo?
     │
    SÍ
     ▼
Existe intención de imprimir
```

### Capa de red

Determina si existe un camino hacia la impresora.

```text
¿Impresora accesible?
        │
      NO
        ▼
Debe resolverse conectividad
```

PrintSwitch deberá mantener separadas ambas responsabilidades.

**Clasificación:** `[DECISIÓN]`

---

## 7. Arquitectura conceptual de PrintSwitch

A partir de las observaciones actuales se propone provisionalmente:

```text
┌──────────────────────┐
│     QueueWatcher     │
│                      │
│ Observa trabajos     │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ ConnectivityAnalyzer │
│                      │
│ ¿La impresora está   │
│ disponible?          │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│    NetworkManager    │
│                      │
│ Determina / cambia   │
│ la red necesaria     │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│    PrinterMonitor    │
│                      │
│ Verifica recuperación│
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│        Logger        │
│                      │
│ Registra decisiones  │
│ y resultados         │
└──────────────────────┘
```

Los nombres representan responsabilidades conceptuales.

No implican todavía clases, procesos, servicios o archivos definitivos.

**Clasificación:** `[INFERIDO]`

---

## 8. Principio de independencia del fabricante

QueueWatcher deberá operar sobre la infraestructura de impresión de Windows siempre que sea posible.

La lógica central no deberá depender directamente de Epson.

Los componentes específicos de un fabricante deberán quedar aislados cuando sean necesarios.

Ejemplo:

```text
                PrintSwitch Core
                      │
            ┌─────────┴─────────┐
            │                   │
      Windows Spooler      Connectivity
                                │
                   ┌────────────┼────────────┐
                   │            │            │
                 Epson          HP         Otros
              (si requiere) (si requiere) (si requiere)
```

La independencia efectiva respecto de otros fabricantes todavía debe validarse experimentalmente.

**Clasificación:** `[DECISIÓN]` + `[PENDIENTE]`

---

## 9. Identidad y ubicación

PrintSwitch deberá diferenciar:

```text
IDENTIDAD DE IMPRESORA
        ≠
UBICACIÓN IP ACTUAL
```

Una dirección IP obtenida mediante DHCP puede cambiar.

Por ello, una futura configuración podrá contener múltiples atributos:

```text
PrinterProfile
│
├── WindowsPrinter
├── RequiredSSID
├── MAC
├── Hostname
├── LastKnownIP
└── IPMode
```

`LastKnownIP` deberá tratarse como información potencialmente variable.

El mecanismo definitivo de descubrimiento todavía no está definido.

**Clasificación:** `[DECISIÓN]` + `[PENDIENTE]`

---

## 10. Internet y LAN

La arquitectura debe distinguir explícitamente:

```text
                INTERNET
                    │
             servicios externos
                    │
          ─────────────────────
                    │
                   WAN
                    │
              ┌─────▼─────┐
              │  Router   │
              └─────┬─────┘
                    │
                   LAN
              ┌─────▼─────┐
              │ Impresora │
              └───────────┘
```

Se ha comprobado acceso HTTP local a la Epson L365 durante una interrupción de Internet.

Todavía está pendiente comprobar mediante un experimento controlado que la impresión completa se realiza sin WAN.

---

## 11. Principio de intervención mínima

PrintSwitch no deberá reemplazar innecesariamente funciones que Windows ya realiza correctamente.

Si Windows:

* conserva el trabajo;
* administra la cola;
* reintenta la comunicación;
* continúa la impresión cuando vuelve la conectividad;

PrintSwitch deberá concentrarse en resolver la condición que Windows no puede resolver por sí mismo:

> proporcionar temporalmente la conectividad de red necesaria.

**Clasificación:** `[DECISIÓN]`

---

## 12. Flujo objetivo provisional

El comportamiento buscado actualmente es:

```text
Trabajo aparece
       │
       ▼
QueueWatcher
       │
       ▼
¿Impresora accesible?
       │
   ┌───┴────┐
   │        │
  SÍ       NO
   │        │
   │        ▼
   │   identificar red
   │        │
   │        ▼
   │   cambiar conexión
   │        │
   │        ▼
   │   verificar impresora
   │        │
   └────────┤
            ▼
      Windows continúa
       la impresión
            │
            ▼
       trabajo termina
            │
            ▼
    retorno controlado
     a la red original
```

Este flujo constituye actualmente una arquitectura objetivo y deberá validarse mediante implementación incremental.

---

## 13. Próximo paso de ingeniería

La siguiente etapa experimental será pasar de un observador pasivo de la cola a un prototipo capaz de:

1. detectar un nuevo trabajo;
2. identificar la impresora correspondiente;
3. registrar la red actual;
4. determinar que la impresora no es accesible;
5. decidir qué red requiere;
6. realizar el cambio de red de forma controlada;
7. verificar la recuperación;
8. registrar el resultado.

La restauración automática de la red original deberá implementarse después de validar de forma segura el cambio hacia la red de impresión.
