# PrintSwitch — Índice de evidencias representativas

## 1. Propósito

Este documento presenta una selección curada de evidencias técnicas del desarrollo de PrintSwitch-Windows.

La selección no contiene todos los archivos generados durante el proyecto.

Su objetivo es conservar y publicar las evidencias más representativas de:

- contratos del Core;
- ciclo de vida de QueueWatcher;
- clasificación y política de trabajos;
- evaluación de recovery;
- autorización;
- contexto de red;
- ejecución controlada;
- rollback;
- NetworkManager;
- comportamiento de Windows Native Wi‑Fi;
- cierre experimental de la política Wi‑Fi para Beta 1.

Las evidencias intermedias, intentos bloqueados, mapas extensos y repeticiones permanecen preservados localmente como historia de desarrollo, pero no forman parte de esta colección pública.

---

## 2. Política de preservación

Las evidencias originales no fueron:

- eliminadas;
- reemplazadas;
- normalizadas;
- renombradas;
- modificadas;
- utilizadas como destino de sanitización.

La colección publicada contiene copias derivadas.

Cada copia incluye:

- identificador público;
- hash SHA-256 del original;
- política de sanitización;
- confirmación de preservación del original;
- contenido técnico sanitizado.

La existencia de una copia pública no convierte al archivo derivado en evidencia primaria.

La evidencia primaria continúa siendo el archivo original identificado por su hash.

---

## 3. Política de sanitización

Las copias públicas utilizan:

```text
SanitizationPolicy=SEMANTIC_ROLES_V1
```

Se reemplazaron identificadores domésticos o personales por roles técnicos.

Ejemplos:

```text
<PRIMARY_INTERNET_SSID>
<ALTERNATE_INTERNET_SSID>
<PRINTER_NETWORK_SSID>
<PRINTER_NETWORK_5G_SSID>
<ESP32_AP_SSID>
<OBSERVED_NETWORK_01>
<INTERFACE_GUID_01>
<MAC_OR_BSSID_01>
<PRIVATE_IPV4_01>
C:\Users\<USER>
```

Los marcadores numerados preservan relaciones internas.

Por ejemplo, dos apariciones de:

```text
<MAC_OR_BSSID_01>
```

representan el mismo valor original dentro de la colección sanitizada.

No se publican:

- contraseñas;
- credenciales;
- material de claves;
- nombres personales de usuario;
- direcciones IP originales;
- GUID de interfaces;
- direcciones MAC;
- BSSID;
- nombres privados de redes.

La generación y validación de las copias finalizó con:

```text
GeneratedEvidenceCount=22
ValidationFailureCount=0
Result=PASS_CURATED_EVIDENCE_CREATED_AND_VALIDATED
```

---

## 4. Manifiesto criptográfico

El manifiesto contiene el nombre y hash SHA-256 de cada copia pública:

[Descargar manifiesto de evidencias curadas](evidence/curated/CURATED-EVIDENCE-MANIFEST.txt)

El manifiesto permite:

- verificar integridad;
- detectar modificaciones posteriores;
- identificar cada evidencia pública;
- reproducir una auditoría del conjunto publicado.

---

# 5. Núcleo de aplicación

## Evidencia 1 — Contratos del Core

- **Archivo:** [P7-A1-Core-Contracts.txt](evidence/curated/P7-A1-Core-Contracts.txt)
- **Objetivo:** inventariar los contratos y componentes principales disponibles para la capa de aplicación.
- **Resultado:** los archivos analizados superaron la validación sintáctica registrada por la evidencia.
- **Utilidad:** establece el punto de partida técnico del Punto 7 y permite conocer qué contratos podían consumirse desde el Controller.
- **Alcance:** evidencia estática de estructura y contratos; no demuestra por sí sola ejecución end-to-end.

## Evidencia 2 — Ciclo de vida de QueueWatcher

- **Archivo:** [P7-A4-QueueWatcher-Lifecycle.txt](evidence/curated/P7-A4-QueueWatcher-Lifecycle.txt)
- **Objetivo:** relevar el ciclo de vida, funciones y frontera de QueueWatcher.
- **Resultado:** la estructura analizada quedó disponible para su integración controlada con ApplicationController.
- **Utilidad:** documenta cómo QueueWatcher pasó de ejecución aislada a componente administrado por la aplicación.
- **Alcance:** evidencia estructural; debe leerse junto con las pruebas funcionales posteriores.

---

# 6. Clasificación y política de trabajos

## Evidencia 3 — Taxonomía de trabajos de impresión

- **Archivo:** [P7-B2-R1-JobTaxonomy-20260908-210644.txt](evidence/curated/P7-B2-R1-JobTaxonomy-20260908-210644.txt)
- **Objetivo:** definir categorías para trabajos nuevos, preexistentes y estados relevantes de la cola.
- **Resultado:** se obtuvo una taxonomía utilizable por el clasificador experimental.
- **Utilidad:** evita tratar todos los trabajos detectados como equivalentes.
- **Alcance:** define clasificación; no autoriza recovery por sí sola.

## Evidencia 4 — Matriz de QueueJobClassifier

- **Archivo:** [P7-B2-T1-QueueJobClassifier-Matrix-20260908-214425.txt](evidence/curated/P7-B2-T1-QueueJobClassifier-Matrix-20260908-214425.txt)
- **Objetivo:** probar QueueJobClassifier con múltiples combinaciones de entrada.
- **Resultado:** la matriz concluyó con resultado `PASS`.
- **Utilidad:** demuestra que la clasificación no depende exclusivamente de un único trabajo real.
- **Alcance:** prueba aislada del clasificador.

## Evidencia 5 — Contrato completo de QueuePolicy

- **Archivo:** [P7-B3-R2-QueuePolicyCompleteContract-20260909-140829.txt](evidence/curated/P7-B3-R2-QueuePolicyCompleteContract-20260909-140829.txt)
- **Objetivo:** verificar la completitud del contrato de QueuePolicy.
- **Resultado:** se consolidó la frontera entre clasificación de trabajos y decisión de política.
- **Utilidad:** documenta qué información debe recibir la política y qué tipo de decisión debe producir.
- **Alcance:** evidencia contractual; no ejecuta conmutaciones de red.

## Evidencia 6 — Política con trabajo real

- **Archivo:** [P7-B3-T2-R1-RealJobPolicyRobust-20260909-142139.txt](evidence/curated/P7-B3-T2-R1-RealJobPolicyRobust-20260909-142139.txt)
- **Objetivo:** validar QueuePolicy utilizando información proveniente de un trabajo real.
- **Resultado:** la política produjo una evaluación utilizable sin perder el contexto del trabajo.
- **Utilidad:** complementa las matrices aisladas con una entrada obtenida del entorno real.
- **Alcance:** valida política; no demuestra todavía ejecución física de recovery.

---

# 7. Evaluación y autorización de recovery

## Evidencia 7 — Evaluación real con Epson

- **Archivo:** [P7-B3-I3-T2-R1-RealEpsonRecoveryEvaluation-20260909-200128.txt](evidence/curated/P7-B3-I3-T2-R1-RealEpsonRecoveryEvaluation-20260909-200128.txt)
- **Objetivo:** evaluar el contexto de recovery utilizando la Epson L365 real.
- **Resultado:** se obtuvo evidencia física de alcanzabilidad y contexto de red.
- **Utilidad:** vincula el modelo abstracto con el dispositivo que motivó PrintSwitch.
- **Alcance:** la evaluación no implica autorización automática para cambiar de red.

## Evidencia 8 — Autorización sobre trabajo real

- **Archivo:** [P7-B3-I4-T2-RealJob13Authorization-20260909-204815.txt](evidence/curated/P7-B3-I4-T2-RealJob13Authorization-20260909-204815.txt)
- **Objetivo:** evaluar autorización de recovery con un trabajo real de la cola.
- **Resultado:** se registró una decisión trazable basada en trabajo, contexto y política.
- **Utilidad:** demuestra que la autorización puede separarse de la detección y de la ejecución.
- **Alcance:** autorizar una acción no equivale a haberla ejecutado.

## Evidencia 9 — Matriz adversarial de TargetNetworkContext

- **Archivo:** [P7-B3-I5-T1-R1-TargetNetworkContextAdversarialMatrix-20260910-153734.txt](evidence/curated/P7-B3-I5-T1-R1-TargetNetworkContextAdversarialMatrix-20260910-153734.txt)
- **Objetivo:** someter la resolución del contexto de red objetivo a entradas incompletas y adversariales.
- **Resultado:** la matriz concluyó con resultado `PASS`.
- **Utilidad:** demuestra preservación de estados grises y comportamiento fail-closed.
- **Alcance:** valida resolución de contexto, no conectividad física.

---

# 8. Ejecución controlada

## Evidencia 10 — RecoveryExecutionAdapter adversarial

- **Archivo:** [P7-B3-I6-I7-RecoveryExecutionAdapter-Adversarial-20260910-185048.txt](evidence/curated/P7-B3-I6-I7-RecoveryExecutionAdapter-Adversarial-20260910-185048.txt)
- **Objetivo:** validar RecoveryExecutionAdapter después de las correcciones surgidas de una ejecución adversarial anterior.
- **Resultado:** la ejecución seleccionada concluyó con resultado `PASS`.
- **Utilidad:** conserva el cierre validado sin publicar cada iteración intermedia.
- **Alcance:** prueba aislada del adaptador.

## Evidencia 11 — Controller y orquestador autorizado en dry-run

- **Archivo:** [P7-B3-I6-I9-R6-ControllerAuthorizedRealOrchestratorDryRun-20260911-220015.txt](evidence/curated/P7-B3-I6-I9-R6-ControllerAuthorizedRealOrchestratorDryRun-20260911-220015.txt)
- **Objetivo:** verificar el paso de una autorización válida desde Controller hacia el orquestador real en modo dry-run.
- **Resultado:** la operación recorrió la frontera prevista sin realizar una mutación física de red.
- **Utilidad:** demuestra wiring y ownership antes de habilitar ejecución real.
- **Alcance:** dry-run; no constituye una conmutación Wi‑Fi física.

---

# 9. Rollback y NetworkManager

## Evidencia 12 — Actuador de rollback sometido a red-team

- **Archivo:** [P7-B3-I6-I10-R5B2-RollbackActuatorRedTeam-20260911-232830.txt](evidence/curated/P7-B3-I6-I10-R5B2-RollbackActuatorRedTeam-20260911-232830.txt)
- **Objetivo:** someter el actuador de rollback a entradas adversariales y fallos esperables.
- **Resultado:** la prueba seleccionada concluyó con resultado `PASS`.
- **Utilidad:** demuestra que el actuador mantiene su frontera y no convierte entradas inválidas en éxito.
- **Alcance:** validación previa al contrato Native Wi‑Fi definitivo.

## Evidencia 13 — NetworkManager cuando ya está en destino

- **Archivo:** [P7-B3-I6-I10-R6C-NetworkManagerRuntimeDryRun-20260911-234450.txt](evidence/curated/P7-B3-I6-I10-R6C-NetworkManagerRuntimeDryRun-20260911-234450.txt)
- **Objetivo:** probar la rama `ALREADY_ON_TARGET_NETWORK`.
- **Resultado:** `PASS`.
- **Utilidad:** demuestra mínima intervención cuando no resulta necesario cambiar de red.
- **Alcance:** dry-run del comportamiento de NetworkManager.

## Evidencia 14 — NetworkManager con destino diferente

- **Archivo:** [P7-B3-I6-I10-R6D2-NetworkManagerDifferentTargetDryRun-20260911-235205.txt](evidence/curated/P7-B3-I6-I10-R6D2-NetworkManagerDifferentTargetDryRun-20260911-235205.txt)
- **Objetivo:** probar la evaluación de NetworkManager cuando la red actual y la red objetivo son diferentes.
- **Resultado:** la rama analizada concluyó con resultado `PASS`.
- **Utilidad:** complementa el caso de no intervención con un caso que requiere considerar una transición.
- **Alcance:** dry-run; no prueba todavía el actuador Native definitivo.

---

# 10. Laboratorio Native Wi‑Fi

## Evidencia 15 — Baseline y escaneo Native Wi‑Fi

- **Archivo:** [P7-B3-I6-I10-LAB01-LAB02-NativeWiFiBaselineScan-20260912-212725.txt](evidence/curated/P7-B3-I6-I10-LAB01-LAB02-NativeWiFiBaselineScan-20260912-212725.txt)
- **Objetivo:** obtener un baseline de interfaz, conexión y redes disponibles, seguido por un escaneo Native explícito.
- **Resultado:** el escaneo completó discovery y actualizó la lista de redes.
- **Utilidad:** demuestra que un snapshot pasivo no equivale necesariamente a discovery fresco.
- **Alcance:** en este contexto el escaneo preservó la conexión, pero no establece una garantía universal.

## Evidencia 16 — Correlación de estado de interfaz

- **Archivo:** [P7-B3-I6-I10-LAB02B-InterfaceStateCorrelation-20260912-213448.txt](evidence/curated/P7-B3-I6-I10-LAB02B-InterfaceStateCorrelation-20260912-213448.txt)
- **Objetivo:** validar marshalling de estado de interfaz y correlacionar Native Wi‑Fi con una consulta auxiliar.
- **Resultado:** `PASS`.
- **Utilidad:** documenta la corrección del tratamiento Unicode y la coherencia entre fuentes.
- **Alcance:** valida observación; no ejecuta una transición.

## Evidencia 17 — Conexión Native controlada

- **Archivo:** [P7-B3-I6-I10-LAB03-ControlledNativeConnection-20260912-215529.txt](evidence/curated/P7-B3-I6-I10-LAB03-ControlledNativeConnection-20260912-215529.txt)
- **Objetivo:** ejecutar una única conexión Native Wi‑Fi controlada y registrar la línea temporal ACM.
- **Resultado:** `PASS_CONNECTED_AND_VERIFIED`.
- **Utilidad:** demuestra que `WlanConnect` debe tratarse como solicitud asíncrona seguida por evento terminal y verificación.
- **Alcance:** conexión controlada sin convertir la prueba en integración productiva.

## Evidencia 18 — Failover autónomo de Windows

- **Archivo:** [P7-B3-I6-I10-LAB04B-PrinterNetworkOutage-AutoTransition-20260915-211124.txt](evidence/curated/P7-B3-I6-I10-LAB04B-PrinterNetworkOutage-AutoTransition-20260915-211124.txt)
- **Objetivo:** observar Windows cuando desaparece externamente la red actualmente conectada.
- **Resultado:** `PASS_OUTAGE_AND_WINDOWS_ALTERNATIVE_NETWORK_TRANSITION_OBSERVED`.
- **Utilidad:** demuestra que Windows puede seleccionar otra red sin una orden de conexión de PrintSwitch.
- **Alcance:** transición autónoma de Windows, no rollback de PrintSwitch.

## Evidencia 19 — Control negativo del flyout

- **Archivo:** [P7-B3-I6-I10-LAB05A-WifiFlyoutTrigger-20260915-212758.txt](evidence/curated/P7-B3-I6-I10-LAB05A-WifiFlyoutTrigger-20260915-212758.txt)
- **Objetivo:** determinar si abrir el flyout Wi‑Fi produce por sí solo una transición.
- **Resultado:** `PASS_UI_OPENED_CONNECTION_PRESERVED`.
- **Utilidad:** demuestra que la apertura del panel no es una explicación causal suficiente.
- **Alcance:** control sin caída previa.

## Evidencia 20 — Recuperación después de caída y flyout

- **Archivo:** [P7-B3-I6-I10-LAB05B-OutageRecoveryFlyoutTrigger-20260915-214412.txt](evidence/curated/P7-B3-I6-I10-LAB05B-OutageRecoveryFlyoutTrigger-20260915-214412.txt)
- **Objetivo:** observar si la actualización asociada al flyout era seguida por el retorno a una red recuperada.
- **Resultado:** `PASS_SOURCE_RETURNED_AFTER_UI`.
- **Utilidad:** demuestra que el contexto posterior a failover modifica la respuesta de Windows.
- **Alcance:** correlación contextual; no demuestra una orden directa de conexión desde el flyout.

## Evidencia 21 — Recuperación después de `WlanScan`

- **Archivo:** [P7-B3-I6-I10-LAB05C-OutageRecoveryExplicitNativeScan-20260915-220247.txt](evidence/curated/P7-B3-I6-I10-LAB05C-OutageRecoveryExplicitNativeScan-20260915-220247.txt)
- **Objetivo:** reemplazar la interacción con el flyout por un `WlanScan` Native explícito después del failover.
- **Resultado:** `PASS_SOURCE_RETURNED_AFTER_EXPLICIT_SCAN`.
- **Utilidad:** demuestra que el refresco de redes puede ser seguido por una transición iniciada por Windows AutoConfig.
- **Alcance:** `WlanScan` no conecta directamente, pero puede habilitar una reevaluación de Windows.

## Evidencia 22 — Conexión explícita preservada después del escaneo

- **Archivo:** [P7-B3-I6-I10-LAB05D-ProgrammaticRollbackExplicitScan-20260916-172131.txt](evidence/curated/P7-B3-I6-I10-LAB05D-ProgrammaticRollbackExplicitScan-20260916-172131.txt)
- **Objetivo:** determinar si un escaneo revierte una conexión explícita realizada mediante Native Wi‑Fi.
- **Resultado:** `PASS_PROGRAMMATIC_ROLLBACK_PRESERVED_AFTER_SCAN`.
- **Utilidad:** distingue una conexión explícita de una conexión adoptada por failover y cierra la hipótesis requerida para Beta 1.
- **Alcance:** comportamiento demostrado en el entorno y condiciones registradas; no constituye una garantía universal para todo Windows.

---

# 11. Cómo interpretar esta colección

Las evidencias deben leerse como una secuencia.

```text
Contratos del Core
    ↓
Clasificación de trabajos
    ↓
Policy
    ↓
Evaluación de recovery
    ↓
Autorización
    ↓
Contexto de red
    ↓
Ejecución controlada
    ↓
Rollback
    ↓
Native Wi‑Fi
```

Una evidencia posterior puede ampliar o limitar una interpretación anterior.

No debe eliminarse la observación original.

Debe distinguirse:

```text
ObservedFact
Inference
Decision
Result
```

Un resultado `PASS` valida solamente:

- el contrato declarado;
- las precondiciones registradas;
- la acción ejecutada;
- el criterio de éxito del laboratorio.

No demuestra universalidad fuera de ese alcance.

---

# 12. Evidencias excluidas de la colección pública

Se excluyeron deliberadamente:

- ejecuciones repetidas reemplazadas por una prueba posterior;
- intentos con precondición bloqueada;
- pruebas donde no ocurrió el estímulo esperado;
- mapas internos demasiado extensos;
- salidas de staging;
- radiografías intermedias;
- respaldos de código;
- evidencias cuyo resultado quedó representado por una ejecución final más clara;
- inventarios internos con información innecesaria para explicar el resultado técnico.

La exclusión de la colección pública no implica eliminación de la historia local.

---

# 13. Estado de la colección

```text
CURATED_EVIDENCE_COUNT=22
SANITIZATION_POLICY=SEMANTIC_ROLES_V1
ORIGINAL_EVIDENCE_PRESERVED=True
RAW_PRIVATE_IDENTIFIERS_PUBLISHED=False
VALIDATION_FAILURE_COUNT=0
COLLECTION_STATUS=READY_FOR_DOCUMENTATION_REVIEW
```

La colección todavía debe superar:

1. validación de enlaces mediante MkDocs;
2. revisión de navegación;
3. revisión explícita del staging;
4. decisión humana de commit.