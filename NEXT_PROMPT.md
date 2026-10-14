# Prompt para la siguiente conversación — Fase 1

**Modelo recomendado:** GPT-6.1 Sol (`gpt-6.1-sol`). **Razonamiento:** medium.
**Motivo:** esta fase combina preparación del entorno, configuración de Ollama y diagnóstico de compatibilidad y memoria. Sol ofrece un equilibrio adecuado para esa integración; reservar Astra para bloqueos complejos y Luna para tareas posteriores más acotadas.

Lee `AGENTS.md`, `PROJECT_GUIDE.md` y `PROJECT_STATUS.md` y ejecuta la fase 1 de este proyecto personal: descargar **Qwen3.8-27B** y comprobar que funciona en mi PC. El identificador previsto de Ollama es `qwen3.8:27b`; verifica fuente, variante, digest y compatibilidad antes de descargar. Mantén este modelo como objetivo.

Revalida el hardware y Ollama. Prepara en `E:\Documents\qwen_optimization` las herramientas necesarias, un entorno `.venv` si hace falta y el almacenamiento local de pesos y cachés. Reutiliza Ollama sin modificar el almacén de mis modelos existentes ni interrumpir otras instancias. Si procede, configura una instancia separada con puerto propio y documenta cómo arrancarla y detenerla.

Descarga una variante viable, realiza pruebas breves de español, instrucciones, razonamiento y código sin ejecutar el código generado, y registra respuestas, configuración, tiempos disponibles, memoria y reparto CPU/GPU observado. Conserva esta configuración como referencia reproducible. Explica las decisiones y las limitaciones reales del equipo. No empieces aún benchmarks extensos ni optimización.

Completa el trabajo hasta verificar inferencia local o identificar un bloqueo concreto. Al cerrar:

1. Actualiza `PROJECT_STATUS.md` con tareas completadas, evidencia, decisiones y pendientes; ajusta `PROJECT_GUIDE.md` si hay información nueva relevante.
2. Reescribe `NEXT_PROMPT.md` con un encargo autocontenido para la siguiente conversación, incluyendo modelo de OpenAI recomendado (Luna, Sol o Astra), versión, esfuerzo de razonamiento y motivo. Si la fase 1 está completada, el siguiente encargo será diseñar e implementar la referencia de benchmarks de calidad y rendimiento; si quedan bloqueos, prioriza resolverlos.
3. Revisa los cambios, ejecuta las comprobaciones pertinentes y haz un Git commit de los archivos del proyecto, incluido el nuevo prompt. Haz Git push normal a la rama vigente y comprueba el resultado. Esta operación está autorizada; excluye pesos, cachés, entornos y secretos.
4. Entrega un resumen breve, el estado de Git con rama y hash, y el nuevo prompt listo para copiar junto con su enlace local. Si el push falla, informa el motivo y deja la recuperación registrada.
