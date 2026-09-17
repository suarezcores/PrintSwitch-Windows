## Actualización 2026-09-16 — Cierre experimental y contrato Native Wi‑Fi para Beta 1

### Propósito de esta actualización

Esta sección se agrega después de completar la serie experimental LAB‑01–LAB‑05D.

No reemplaza, elimina ni reescribe las observaciones y conclusiones registradas anteriormente. Los resultados previos forman parte de la historia experimental de PrintSwitch y deben conservarse porque documentan:

- qué conocía el proyecto en cada momento;
- qué hipótesis estaban abiertas;
- qué comportamiento se había observado;
- qué nuevas pruebas obligaron a ampliar o corregir la interpretación;
- por qué se tomaron las decisiones actuales.

Cuando una interpretación anterior resulta incompleta a partir de nueva evidencia, se mantiene el registro original y se añade una aclaración fechada como ésta.

---

### 1. Motivo del laboratorio Native Wi‑Fi

La integración productiva de PrintSwitch había quedado temporalmente congelada para comprender con evidencia controlada cómo Windows:

- enumera interfaces y perfiles Wi‑Fi;
- actualiza la lista de redes disponibles;
- ejecuta una conexión solicitada por una aplicación;
- responde ante la caída de la red conectada;
- selecciona una red alternativa;
- reacciona cuando reaparece una red perdida;
- diferencia una conexión de recuperación automática de una conexión explícita;
- puede cambiar de red después de un escaneo aunque PrintSwitch no haya solicitado una conexión.

El objetivo no era únicamente comprobar que `WlanConnect` y `WlanScan` funcionaran.

También era necesario establecer qué acciones podían producir efectos indirectos a través de Windows AutoConfig y qué evidencia debía conservar PrintSwitch antes de automatizar la conmutación utilizada para imprimir.

---

### 2. Alcance de la decisión para Beta 1

Para la Beta 1 se adopta **Native Wi‑Fi API** como mecanismo productivo para:

- enumerar interfaces;
- consultar el estado de la interfaz;
- consultar SSID, perfil y BSSID;
- enumerar perfiles guardados;
- registrar notificaciones ACM;
- solicitar escaneos explícitos;
- ejecutar conexiones explícitas mediante perfiles existentes;
- verificar el resultado de una transición.

`netsh wlan` puede continuar utilizándose en:

- diagnósticos;
- laboratorios;
- comparación de evidencia;
- soporte técnico;
- inspección manual.

Sin embargo, `netsh wlan` no será el actuador principal de la implementación productiva de Beta 1.

---

### 3. Evidencia consolidada

| Laboratorio | Resultado confirmado | Consecuencia para el diseño |
| --- | --- | --- |
| LAB‑01/LAB‑02 | Native Wi‑Fi enumeró correctamente la interfaz y un `WlanScan` explícito descubrió redes disponibles. | Native Wi‑Fi resulta apto para observación y discovery. |
| LAB‑02B | Se corrigió y validó el tratamiento de estructuras y texto Unicode. | La capa Native debe encapsular correctamente el marshalling y no exponerlo al resto del sistema. |
| LAB‑03A/LAB‑03B | Una única llamada autorizada a `WlanConnect` produjo una transición verificable. | La conexión debe modelarse como una operación asíncrona, correlacionada con eventos ACM y verificación final. |
| LAB‑04B | Ante la caída de `PRINTER_NETWORK_SSID`, Windows abandonó esa red y se conectó autónomamente a `PRIMARY_INTERNET_SSID`. | PrintSwitch debe reconocer transiciones iniciadas por Windows y evitar adjudicárselas. |
| LAB‑05A | Abrir el panel Wi‑Fi no produjo por sí solo una transición automática. | La apertura del flyout no es una causa suficiente para explicar un cambio de red. |
| LAB‑05B | Después de una caída, la actualización de redes asociada al flyout fue seguida por el retorno de `PRIMARY_INTERNET_SSID` a `PRINTER_NETWORK_SSID`. | La recuperación automática depende del contexto previo y de la actualización de disponibilidad. |
| LAB‑05C | Después del failover causado por una caída, un `WlanScan` explícito fue seguido por el retorno automático a `PRINTER_NETWORK_SSID`. | `WlanScan` puede tener efectos indirectos a través de Windows AutoConfig. |
| LAB‑05D | Después de un `WlanConnect` explícito desde `PRINTER_NETWORK_SSID` hacia `PRIMARY_INTERNET_SSID`, un nuevo `WlanScan` no provocó el retorno a `PRINTER_NETWORK_SSID`. | Windows distingue, al menos conductualmente, una conexión explícita de una conexión adoptada como failover. |

---

### 4. Resultado específico de LAB‑05D

LAB‑05D comenzó con:

- SSID inicial: `PRINTER_NETWORK_SSID`;
- perfil de retorno explícito: `PRIMARY_INTERNET_SSID`;
- interfaz Wi‑Fi cerrada y sin interacción del usuario;
- conexión ejecutada mediante el actuador Native Wi‑Fi validado en LAB‑03B;
- una única llamada a `WlanConnect`;
- sin modificación de perfiles;
- sin lectura de credenciales;
- sin intervención de QueueWatcher, Controller o código productivo.

La transición Native Wi‑Fi registró:

- `wlan_notification_acm_disconnecting` para `PRINTER_NETWORK_SSID`;
- `wlan_notification_acm_disconnected`;
- `wlan_notification_acm_connection_start` para `PRIMARY_INTERNET_SSID`;
- `wlan_notification_acm_connection_complete`;
- `WlanConnectResult=0`;
- `TerminalReasonCode=0`;
- verificación Native final en `PRIMARY_INTERNET_SSID`;
- verificación adicional mediante `netsh` en `PRIMARY_INTERNET_SSID`.

Después de la conexión explícita:

1. se mantuvo una fase pasiva de 90 segundos;
2. Windows permaneció conectado a `PRIMARY_INTERNET_SSID`;
3. se invocó un `WlanScan` explícito;
4. el escaneo finalizó correctamente en aproximadamente 1963 ms;
5. `PRINTER_NETWORK_SSID` estaba visible después del escaneo;
6. se observaron otros 120 segundos;
7. Windows permaneció conectado a `PRIMARY_INTERNET_SSID`.

Resultado:

```text
PASS_PROGRAMMATIC_ROLLBACK_PRESERVED_AFTER_SCAN

### 5. Aclaración sobre conclusiones anteriores

Las pruebas iniciales mostraron que un escaneo podía descubrir redes sin modificar la conexión activa.

Esa observación continúa siendo válida para los casos concretos en los que fue obtenida.

Sin embargo, LAB‑05B y LAB‑05C demostraron que no puede generalizarse como una propiedad universal de `WlanScan`.

Por lo tanto:

- se conserva la evidencia anterior;
- no se modifica retroactivamente el resultado de LAB‑01/LAB‑02;
- se amplía la interpretación arquitectónica;
- `WlanScan` deja de considerarse una operación garantizadamente observacional;
- su posible efecto depende del contexto de conexión y recuperación de Windows.

Esta actualización reemplaza únicamente la generalización arquitectónica anterior. No reemplaza ni elimina la evidencia histórica que le dio origen.

---

### 6. Modelo causal mínimo de Beta 1

PrintSwitch debe representar el origen conocido o inferido de la conexión mediante un estado interno equivalente a:

```text
USER_EXPLICIT
PRINTSWITCH_EXPLICIT
WINDOWS_FAILOVER
WINDOWS_AUTORESTORE
UNKNOWN
```

#### `USER_EXPLICIT`

La conexión fue seleccionada explícitamente por el usuario fuera de PrintSwitch.

Conducta:

- respetar la conexión;
- no atribuirla a PrintSwitch;
- no ejecutar rollback automático sobre una acción que no pertenece al sistema.

#### `PRINTSWITCH_EXPLICIT`

La conexión fue solicitada por PrintSwitch y confirmada mediante eventos y verificación final.

Conducta:

- conservar la atribución mientras la operación continúe vigente;
- permitir rollback solamente si corresponde a esa operación;
- verificar nuevamente el estado después de cualquier escaneo.

#### `WINDOWS_FAILOVER`

Windows abandonó una red perdida y seleccionó una alternativa disponible.

Conducta:

- considerar que un escaneo puede provocar la restauración de la red perdida;
- no tratar `WlanScan` como una observación neutra;
- reevaluar el estado inmediatamente después del escaneo;
- evitar una segunda conexión si Windows ya inició una transición.

#### `WINDOWS_AUTORESTORE`

Windows regresó automáticamente a una red que había desaparecido.

Conducta:

- registrar la transición como iniciada por Windows;
- cancelar cualquier acción redundante de PrintSwitch;
- continuar desde el estado real alcanzado.

#### `UNKNOWN`

La evidencia disponible no permite atribuir con seguridad la transición.

Conducta:

- conservar el estado gris;
- no inventar una causa;
- aplicar una política conservadora;
- observar y reevaluar antes de ejecutar rollback o una nueva conexión.

`ConnectionOrigin` es una inferencia interna de PrintSwitch. Windows no entrega directamente este valor como una propiedad única.

---

### 7. Contrato de observación

Antes de cualquier acción Native Wi‑Fi, PrintSwitch debe registrar, cuando estén disponibles:

- GUID de interfaz;
- descripción de interfaz;
- estado de interfaz;
- SSID;
- perfil;
- BSSID;
- calidad de señal;
- fecha y hora;
- operación activa;
- origen causal conocido o inferido.

Una transición sólo puede considerarse iniciada por PrintSwitch cuando:

1. existe una orden activa;
2. la orden identifica un destino concreto;
3. se registra la invocación correspondiente;
4. los eventos ocurren dentro de la ventana temporal esperada;
5. el destino observado coincide con el solicitado.

Un cambio no correlacionado con una orden activa no debe registrarse como éxito implícito de PrintSwitch.

Si Windows o el usuario producen una transición durante una evaluación, PrintSwitch debe registrar el nuevo estado, cancelar cualquier orden redundante y reevaluar el flujo.

---

### 8. Contrato de escaneo

`WlanScan` debe tratarse como una acción con posibles efectos indirectos.

Antes de escanear se debe guardar:

- conexión actual;
- perfil actual;
- SSID actual;
- `ConnectionOrigin`;
- propósito del escaneo;
- operación que lo autorizó;
- marca temporal del inicio.

Después de cualquiera de estos resultados:

- `scan_complete`;
- `scan_fail`;
- timeout;

PrintSwitch debe:

1. consultar nuevamente el estado de la interfaz;
2. consultar nuevamente el SSID y el perfil;
3. registrar cualquier diferencia;
4. observar notificaciones de desconexión o conexión posteriores;
5. reevaluar el flujo antes de ejecutar otra acción.

Un resultado inmediato como:

```text
WlanScanResult=0
```

significa que Windows aceptó la solicitud.

No demuestra:

- que el escaneo haya terminado;
- que la lista de redes ya esté actualizada;
- que la red objetivo esté visible;
- que la conexión actual haya sido preservada;
- que Windows no vaya a iniciar una transición posterior.

Cuando `ConnectionOrigin` sea `WINDOWS_FAILOVER` o `UNKNOWN`, el escaneo debe considerarse una acción de mayor impacto.

En esos contextos, sólo debe ejecutarse cuando discovery resulte necesario para la decisión actual y el orquestador pueda aceptar y procesar una posible transición iniciada por Windows AutoConfig.

---

### 9. Contrato de conexión explícita

La Beta 1 utilizará perfiles Wi‑Fi existentes en Windows.

La existencia de un perfil sólo demuestra que Windows conserva una configuración para esa red.

No demuestra:

- que el SSID esté disponible;
- que las credenciales sigan siendo válidas;
- que la autenticación vaya a completarse;
- que exista conectividad IP;
- que la ruta hacia la impresora sea correcta;
- que la Epson L365 responda;
- que el endpoint requerido esté disponible.

`WlanConnect` es una operación asíncrona.

Un resultado inmediato igual a cero sólo indica que Windows aceptó la solicitud de conexión.

La conexión se considera exitosa únicamente cuando:

1. se recibe una notificación terminal compatible con éxito;
2. no existe un código terminal de fallo;
3. la interfaz finaliza en estado conectado;
4. el perfil final coincide con el solicitado;
5. el SSID final coincide con el esperado.

Los siguientes estados deben permanecer diferenciados:

- solicitud aceptada;
- conexión iniciada;
- conexión completada;
- conexión fallida;
- timeout;
- destino diferente;
- resultado indeterminado.

PrintSwitch no debe convertir una solicitud aceptada en un resultado exitoso antes de completar la verificación.

---

### 10. Contrato de rollback

PrintSwitch sólo puede revertir automáticamente una transición que él mismo haya iniciado y verificado dentro de la operación activa.

La red de retorno se obtiene de la conexión capturada antes de la conmutación.

No debe deducirse a partir de:

- una prioridad global;
- el nombre de una red preferida;
- el orden de perfiles almacenados;
- la última red que reapareció;
- una suposición fija como `PRIMARY_INTERNET_SSID`.

El rollback debe ejecutarse como otra conexión explícita:

1. invocar `WlanConnect` al perfil inicial;
2. esperar la notificación terminal;
3. consultar nuevamente la interfaz;
4. verificar perfil y SSID;
5. registrar el resultado final.

Después de un rollback explícito y verificado, el estado causal interno debe quedar registrado como:

```text
ConnectionOrigin=PRINTSWITCH_EXPLICIT
```

Esto no significa que PrintSwitch sea propietario permanente de la conexión.

Significa únicamente que la última transición verificada fue iniciada explícitamente por PrintSwitch.

Si durante la operación el usuario o Windows realizan una transición no atribuible a PrintSwitch, se pierde la autorización automática de rollback y el sistema debe reevaluar el contexto.

PrintSwitch nunca debe ejecutar un retorno automático únicamente porque una red anterior vuelva a estar visible.

---

### 11. Separación obligatoria de evidencias

La implementación no debe representar todo el estado de red mediante un único valor booleano.

| Dimensión | Pregunta que debe responder |
| --- | --- |
| Perfil | ¿Existe el perfil requerido? |
| Discovery | ¿El SSID fue observado en una lista suficientemente reciente? |
| Autenticación | ¿Windows completó la conexión? |
| Conexión | ¿La interfaz terminó en el SSID y perfil esperados? |
| Ruta | ¿Existe una ruta válida hacia la red de la impresora? |
| Endpoint | ¿La impresora responde en el puerto o protocolo requerido? |
| Atribución | ¿Quién inició la transición observada? |
| Recovery | ¿Corresponde rollback, espera, cancelación o reevaluación? |

Los estados desconocidos o incompletos deben conservarse como tales.

La ausencia de evidencia no equivale automáticamente a:

- `false`;
- indisponibilidad confirmada;
- conexión fallida;
- operación exitosa;
- autorización para conmutar.

La arquitectura debe conservar los estados grises hasta obtener evidencia suficiente o alcanzar un timeout explícito.

---

### 12. Flujo Native Wi‑Fi previsto para Beta 1

El flujo productivo deberá seguir esta secuencia general:

1. capturar el contexto de conexión inicial;
2. determinar si el destino ya está conectado;
3. comprobar si ya existe un camino válido hacia la impresora;
4. evitar la conmutación cuando ese camino ya exista;
5. ejecutar discovery sólo cuando resulte necesario;
6. reevaluar la conexión inmediatamente después del escaneo;
7. autorizar una única conexión hacia la red objetivo;
8. invocar `WlanConnect`;
9. esperar el evento terminal;
10. verificar SSID y perfil;
11. verificar por separado la ruta hacia la impresora;
12. verificar por separado el endpoint de impresión;
13. ejecutar o liberar el trabajo de impresión;
14. comprobar que se conserva la atribución de la transición;
15. ejecutar un rollback explícito hacia la conexión inicial;
16. esperar el evento terminal del rollback;
17. verificar el estado final;
18. continuar observando cambios posteriores de Windows o del usuario.

Si Windows alcanza por su cuenta el destino mientras PrintSwitch está evaluando, el sistema debe cancelar cualquier conexión redundante y continuar desde el estado real observado.

La conexión a una red Wi‑Fi no demuestra por sí sola que la impresora sea accesible.

Por ese motivo deben mantenerse separadas:

```text
WiFiConnected
RouteAvailable
PrinterEndpointReachable
```

---

### 13. Límites de Beta 1

La Beta 1 incluye:

- uso productivo de Native Wi‑Fi;
- una interfaz Wi‑Fi operativa;
- perfiles previamente configurados en Windows;
- observación del estado;
- notificaciones ACM;
- discovery explícito;
- conexión por perfil;
- verificación final;
- rollback explícito y atribuible;
- tolerancia normal de aproximadamente 3–4 segundos para un escaneo;
- evidencia suficiente para reconstruir la secuencia causal.

La Beta 1 no incluye:

- creación automática de perfiles;
- lectura o administración de contraseñas;
- modificación automática de prioridades de Windows;
- eliminación o reordenamiento de perfiles;
- políticas generales para múltiples adaptadores;
- escenarios corporativos con directivas de grupo;
- sustitución del administrador Wi‑Fi de Windows;
- inferencia causal avanzada más allá del modelo mínimo necesario.

Estas capacidades pueden evaluarse posteriormente como hardening o Beta 2.

---

### 14. Decisión de cierre experimental

La serie LAB‑01–LAB‑05D aporta evidencia suficiente para definir el contrato Native Wi‑Fi de Beta 1.

La hipótesis que justificaba LAB‑05D queda resuelta:

> Un escaneo posterior a una conexión explícita y verificada de PrintSwitch no reprodujo el retorno automático observado después de un failover de Windows.

Por lo tanto:

- no se requieren nuevos laboratorios para decidir si Beta 1 utilizará Native Wi‑Fi;
- Native Wi‑Fi queda adoptado para Beta 1;
- la fase experimental específica queda cerrada;
- las integraciones pueden descongelarse de manera gradual;
- nuevos laboratorios sólo se abrirán ante incertidumbres nuevas surgidas durante la implementación.

El cierre experimental no convierte todos los comportamientos de Windows en certezas universales.

Establece que existe evidencia suficiente para implementar una política conservadora, observable y verificable para Beta 1.

---

### 15. Orden de descongelamiento

La integración debe reanudarse en capas:

1. implementar `NativeWifiAdapter`;
2. incorporar el modelo de evidencia y contexto;
3. incorporar `ConnectionOrigin`;
4. integrar discovery con una política contextual de `WlanScan`;
5. integrar conexión explícita y correlación de eventos;
6. integrar rollback explícito y verificable;
7. probar el orquestador de forma aislada;
8. integrar `NetworkManager`;
9. integrar Controller y QueueWatcher;
10. validar el flujo completo con endpoint e impresión real.

El orden conceptual queda expresado como:

```text
LAB Native Wi‑Fi cerrado
    ↓
D0 — Evidence & Context Model
    ↓
D2 — Discovery contextual
    ↓
NativeWifiAdapter
    ↓
NetworkManager
    ↓
Transition Orchestrator
    ↓
Integración aislada
    ↓
R7 — Controller + QueueWatcher + impresión + rollback
```

Cada nivel debe producir evidencia determinista antes de habilitar el siguiente.

El descongelamiento es gradual. La aprobación de Native Wi‑Fi no autoriza a modificar simultáneamente todas las integraciones productivas.

---

### 16. Criterios de aceptación de la integración

La integración Native Wi‑Fi de Beta 1 deberá demostrar que:

- ningún `WlanConnect` se considera exitoso sólo por retornar cero;
- toda conexión espera una notificación terminal;
- toda conexión verifica el SSID y el perfil finales;
- ningún `WlanScan` se considera neutro sin reconsultar la conexión;
- toda transición conserva actor, motivo y correlación temporal cuando sea posible;
- ningún rollback automático se ejecuta sin atribución;
- una transición autónoma de Windows evita una segunda orden redundante;
- perfil, visibilidad, conexión, ruta y endpoint permanecen separados;
- los timeouts y estados indeterminados se informan explícitamente;
- la evidencia permite reconstruir qué solicitó PrintSwitch y qué hizo Windows;
- un cambio del usuario no se interpreta como una acción de PrintSwitch;
- un cambio de Windows AutoConfig no se interpreta como una conexión solicitada por PrintSwitch;
- la recuperación nunca depende únicamente del orden de perfiles almacenados.

---

### 17. Estado vigente después de LAB‑05D

```text
Fase experimental Native Wi‑Fi: CERRADA
LAB‑01–LAB‑05D: COMPLETADOS
Native Wi‑Fi para Beta 1: APROBADO
Integraciones productivas: HABILITADAS GRADUALMENTE
Próximo componente: NativeWifiAdapter
QueueWatcher y Controller: TODAVÍA SIN INTEGRACIÓN DIRECTA
Historia experimental previa: CONSERVADA
```

Esta actualización constituye el cierre del laboratorio Native Wi‑Fi y la base contractual para la siguiente fase de implementación.

La documentación anterior permanece como registro histórico del proceso.

Las conclusiones vigentes deben interpretarse mediante esta actualización, sin eliminar las observaciones, hipótesis o decisiones provisionales que permitieron llegar a ella.
---

<!-- P7-DOC-PRECOMMIT-R9-PRIVACY-NORMALIZATION -->

**Aclaración editorial de privacidad — 2026-09-16.**
Los nombres reales de redes locales, las direcciones IPv4 privadas y las
direcciones MAC/BSSID presentes en esta documentación fueron sustituidos por
identificadores semánticos o seudónimos estables. Esta normalización no cambia
la cronología, los resultados experimentales, las decisiones arquitectónicas
ni las conclusiones históricas del proyecto.
