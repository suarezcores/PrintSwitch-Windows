# PrintSwitch

## Estado del proyecto

**Fase actual:** documentación e inicio de desarrollo
**Estado:** experimental
**Última actualización:** 2026-08-17

---

## ¿Qué es PrintSwitch?

PrintSwitch es un proyecto orientado a automatizar la conectividad necesaria para imprimir cuando una impresora se encuentra disponible únicamente desde una red distinta de la utilizada actualmente por Windows.

El proyecto se desarrolla siguiendo una metodología basada en evidencia experimental.

> PrintSwitch se desarrolla sobre evidencia, no sobre suposiciones.

---

## Estado actual

### Investigación

✅ Diagnóstico inicial completado
✅ Cola de impresión observada
✅ Persistencia de trabajos validada
✅ Recuperación al restablecer conectividad validada
✅ Múltiples trabajos validados
🟡 Validación sin Internet pendiente
🟡 Validación multimarca pendiente

### Desarrollo

🟡 Arquitectura conceptual definida
⚪ QueueWatcher reutilizable pendiente
⚪ ConnectivityAnalyzer pendiente
⚪ NetworkManager pendiente
⚪ Primer flujo automático pendiente

---

## Documentación disponible

* Metodología de ingeniería
* Base de conocimiento
* Arquitectura observada
* Roadmap

---

## Principio central

PrintSwitch no busca reemplazar al sistema de impresión de Windows ni a los controladores de los fabricantes.

Su objetivo es resolver únicamente la conectividad necesaria para que esos componentes puedan continuar funcionando normalmente.

---

## Próximo hito

Construir un prototipo en modo **dry-run** capaz de:

1. detectar un trabajo pendiente;
2. identificar la impresora;
3. verificar si es accesible;
4. determinar qué red necesita;
5. decidir el cambio de red;
6. registrar la decisión sin modificar todavía la conectividad.
