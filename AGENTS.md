# Instrucciones permanentes para Codex

## Propósito

Lee `PROJECT_GUIDE.md`, `PROJECT_STATUS.md` y `NEXT_PROMPT.md` antes de actuar. Este es un proyecto personal y educativo: ayudar a entender los experimentos forma parte del resultado. Comunica en español, con explicaciones prácticas y sin complicar innecesariamente la infraestructura.

## Flujo entre conversaciones

- `PROJECT_GUIDE.md` contiene la guía estable; `PROJECT_STATUS.md` contiene el estado real, evidencias, decisiones y pendientes; `NEXT_PROMPT.md` contiene el encargo autocontenido de la siguiente conversación. `START_PROMPT.md` conserva el prompt inicial como referencia.
- Ejecutar el alcance del prompt vigente sin adelantar fases. Al finalizar, actualizar la guía si hay cambios de criterio y actualizar siempre el estado y el prompt siguiente. Si quedan tareas bloqueadas o incompletas, registrarlas y darles prioridad en el siguiente prompt; no declarar una fase terminada sin evidencia.
- El usuario autoriza hacer un Git commit y un Git push al cierre de cada conversación con cambios del proyecto, incluyendo la documentación actualizada y el nuevo prompt. Usar la rama vigente y su remoto/upstream; no crear ni cambiar ramas sin necesidad. La rama inicial es `main` y el remoto es `origin`.
- Antes del commit revisar el diff y ejecutar las comprobaciones apropiadas. Incluir solo archivos del proyecto pertinentes; excluir pesos, entornos, cachés, secretos y cambios ajenos. No usar `git add .` sin revisar lo que incluiría.
- Hacer un commit con mensaje descriptivo y push normal, nunca forzado. Comprobar el resultado e informar rama, hash y éxito o fallo. Si falla autenticación o hay divergencia, preservar el trabajo, informar el motivo y registrar la recuperación pendiente sin sobrescribir el remoto.
- Si no hay cambios, no crear commits vacíos. Entregar siempre el enlace a `NEXT_PROMPT.md` y el prompt listo para copiar. El informe final indicará tareas completadas, pendientes y resultado de Git.

## Recomendación de modelo para cada conversación

- Cada prompt nuevo y su entrega al usuario deben indicar familia y versión recomendadas (Luna, Sol o Astra), esfuerzo de razonamiento y una justificación breve vinculada a las tareas concretas. Incluir esta recomendación dentro de `NEXT_PROMPT.md`; no dejarla solo en el chat.
- Elegir el modelo más eficiente que previsiblemente cumpla la calidad requerida: Luna para tareas acotadas y rutinarias; Sol para implementación, integración y diagnóstico con varias dependencias; Astra para investigación difícil, problemas ambiguos o decisiones metodológicas complejas. No recomendar siempre el más potente por defecto.
- Reconsiderar la elección en cada cierre según el siguiente encargo. Verificar nombres y disponibilidad con fuentes oficiales y el catálogo de la sesión cuando proceda; no inventar costes ni asegurar acceso a un modelo.
- La recomendación no cambia automáticamente el modelo de la conversación. Si aparecen bloqueos que exigen mayor capacidad, explicar el motivo y proponer el modelo para continuar.
- Para la próxima fase 1: **GPT-6.1 Sol (`gpt-6.1-sol`), razonamiento medium**. Requiere integrar Ollama, almacenamiento local y diagnóstico de memoria/compatibilidad; es una elección equilibrada para este alcance.

## Alcance y orden

- El encargo inicial consiste únicamente en preparar la documentación. No inicia descargas, instalación ni experimentos.
- Cuando el usuario pida empezar, ejecutar la fase 1: identificar el modelo, preparar el entorno, descargar una referencia ejecutable y verificar inferencia local.
- Después construir y ejecutar la fase 2 de benchmarks. No pasar a optimización hasta tener una referencia reproducible y autorización del usuario para esa fase.
- El usuario ha confirmado **Qwen3.8-27B**, disponible como `qwen3.8:27b` en Ollama. Verificar la variante y su digest antes de descargar pesos. No sustituirlo por Qwen3.5 ni por un modelo más pequeño por iniciativa propia.

## Entorno

- Usar `E:\Documents\qwen_optimization` para código, configuraciones, resultados, descargas, cachés y un entorno Python `.venv` cuando haga falta.
- Preferir PowerShell y herramientas compatibles con Windows. Comprobar versiones y compatibilidad antes de instalar. Si una herramienta exige WSL o Docker, explicar la necesidad antes de modificar el sistema.
- Reutilizar Ollama. No cambiar su almacén global, borrar modelos existentes ni interrumpir instancias ajenas. Para guardar pesos aquí, estudiar una instancia separada con `OLLAMA_MODELS` y puerto propio, evitando conflictos con el servicio existente.
- No instalar paquetes Python globalmente. Fijar versiones de herramientas y dependencias utilizadas; ignorar en Git pesos, cachés, `.venv` y archivos voluminosos.
- No reservar VRAM completa para pesos: medir también cachés, contexto y otros procesos.

## Experimentos y evidencia

- Conservar intacta la referencia y sus resultados. Cada variante tendrá identificador y configuración propios.
- Verificar fuentes oficiales para formatos, modelos y compatibilidad. Registrar repositorio, revisión/digest, cuantización, runtime y parámetros reales.
- Cambiar una variable cada vez; si se cambia backend, repetir la referencia en ese backend antes de atribuir diferencias a los pesos.
- Separar calidad del modelo de rendimiento del sistema. No llamar «mejor» a una variante por una única puntuación ni por generar menos tokens de razonamiento.
- Guardar respuestas, métricas por muestra, errores, configuraciones y telemetría. Nunca inventar medidas ni reemplazar datos ausentes por cero.
- No ejecutar código producido por el modelo directamente en el PC. Los benchmarks de código que lo ejecuten requieren aislamiento real y límites de recursos; `.venv` no es un aislamiento de seguridad.
- Registrar compatibilidad y limitaciones de cada benchmark. Una API sin logprobs adecuados no sirve automáticamente para tareas que requieren loglikelihood.
- Explicar cada técnica, su hipótesis, coste y resultado. Mantener la guía y el estado del proyecto actualizados después de cada hito.

## Límites de la fase futura

La poda, la cuantización propia, el ajuste fino y la destilación son experimentos futuros. No prometer aceleración por introducir ceros en pesos: hacen falta formatos y kernels que aprovechen esa estructura. No suponer que una técnica de otra arquitectura o GPU funcionará aquí.
