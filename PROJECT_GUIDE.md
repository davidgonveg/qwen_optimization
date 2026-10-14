# Guía del proyecto: Qwen de 27B en un PC doméstico

## Intención

Este es un proyecto personal para practicar inferencia local, evaluación y optimización de LLMs. La meta es obtener la mejor experiencia posible con el modelo elegido en mi PC: reducir latencia, aumentar velocidad, controlar memoria y consumo y conservar sus capacidades en la mayor medida posible.

No se busca una infraestructura empresarial ni una promesa de mejorar todas las métricas simultáneamente. Se busca aprender con experimentos reproducibles y elegir un equilibrio demostrado entre calidad y rendimiento. Mantener el modelo de 27B como objetivo; un modelo menor solo podrá añadirse como comparación si lo solicita el usuario.

## Modelo confirmado

El usuario ha confirmado **Qwen3.8-27B**, disponible como `Qwen/Qwen3.8-27B` y `qwen3.8:27b` en Ollama. En la fase 1 se descargaron **17.741.872.154 bytes** de la variante **GGUF Q4_K_M**, con digest `sha256:aaee06c39dcf2437cde036998d960e1fc1494b8191be7cc9657d01e509097813`. El runtime comunica 27.3B para el modelo de lenguaje, y se incluye un proyector visual BF16 de 931.146.016 bytes. En este contexto, 27B significa aproximadamente **27.000 millones de parámetros**, no 27 billones en la escala larga española.

La arquitectura se identifica como `qwen35` / `Qwen3_5ForConditionalGeneration`: Qwen3.8 comparte la base arquitectónica de Qwen3.5, según la ficha oficial; esto no sustituye el modelo elegido. Es multimodal, pero las comprobaciones iniciales usan solo texto. La licencia es Apache-2.0. Revisión del repositorio oficial consultada: `1d4bf0f2ff6012fd82039f2fa52739d0dd7c60c0`; no se dispone de evidencia del commit exacto utilizado para convertir el GGUF. El digest de Ollama fija el artefacto realmente ejecutado.

La ficha de Ollama ofrece también un artefacto MLX/safetensors con otro digest. La referencia de Windows es exclusivamente GGUF/llamacpp. Ollama 0.40.3 conserva el manifiesto original como blob y añade capas de procedencia al archivo de manifiesto local: verificar el digest de la API, el blob original y las capas originales, en lugar de exigir que el archivo local reescrito tenga el mismo hash.

No asumir que todos los modelos Qwen comparten arquitectura ni copiar recomendaciones de otras variantes sin comprobarlas. Priorizar evaluación de texto inicialmente; si se confirma un modelo multimodal, documentar su alcance y proponer una suite de visión separada.

## Equipo comprobado el 14 de octubre de 2026

| Componente | Dato observado |
| --- | --- |
| GPU | NVIDIA GeForce RTX 3060 |
| VRAM | 12.288 MiB (12 GiB) |
| CPU | AMD Ryzen 5 5500 |
| RAM comunicada por Windows | 34.221.400.064 bytes, aproximadamente 31,9 GiB |
| Driver NVIDIA | 591.86 |
| Ollama | 0.40.3, instalado y responde a la CLI |
| Modelos enumerados | qwen3-embedding:0.6b, qwen3:8b, gemma4:12b |
| Directorio de trabajo | `E:\Documents\qwen_optimization` |
| Espacio libre observado en E: | Aproximadamente 1,43 TB decimales |

En el inventario inicial el modelo objetivo no figuraba entre los instalados. Tras la fase 1 está en el almacén separado del proyecto; la lista de los modelos del servicio habitual se conserva. El campo `requires` del artefacto GGUF exige Ollama 0.32.12 y la instalación 0.40.3 supera ese requisito. La compatibilidad práctica se comprueba además mediante inferencia; una versión instalada por sí sola no es evidencia suficiente.

Una estimación elemental para 27B es 54 GB de pesos a 16 bits o 13,5 GB a 4 bits, antes de escalas, metadatos y memoria de ejecución. Es una estimación, no una medición. Por ello no se presupone que una variante de 4 bits quepa completamente en esta GPU. El contexto, las cachés y el reparto CPU/GPU también cuentan. Descargar un modelo cuantizado para poder arrancar será una decisión de viabilidad de la referencia; todavía no demuestra una mejora propia.

## Fase 0 — Preparación documental

Resultado conservado: esta guía, las instrucciones permanentes y el prompt de inicio. La fase 0 no incluyó descargas ni creación de entornos.

## Fase 1 — Descargar y comprobar que funciona

1. Confirmar identificador exacto, fuente oficial, licencia, revisión y variante. Comprobar compatibilidad de Ollama y estimar descarga, espacio, RAM y VRAM.
2. Preparar únicamente las herramientas necesarias. Crear `.venv` cuando se necesite Python y dirigir cachés y descargas al proyecto. No descargar primero todos los pesos de máxima precisión si no hacen falta para esta fase.
3. Descargar una variante ejecutable del objetivo, preferiblemente mediante Ollama. Guardar digest, tamaño y cuantización reales: las etiquetas remotas pueden cambiar.
4. Ejecutar pruebas breves de español, instrucciones, razonamiento sencillo y código. Registrar petición, respuesta, duración, errores y ubicación CPU/GPU observada. Estas pruebas son de funcionamiento, no un benchmark de calidad.
5. Empezar con contexto moderado, por ejemplo 2.048–4.096 tokens si es compatible, y concurrencia 1. Verificar que el límite total incluye entrada, razonamiento y salida. Medir antes de ampliar el contexto.
6. Documentar una configuración de referencia que complete inferencia sin errores y permita continuar. Si resulta lenta, conservar ese dato y explicar el cuello de botella.

**Criterio de cierre:** identidad resuelta, pesos disponibles, ejecución local verificada y comando/configuración reproducibles. Una prueba de arranque no permite afirmar todavía que el modelo funciona bien para uso diario.

### Referencia operativa comprobada el 14 de octubre de 2026

- Configuración: `configs/reference.json`; Ollama 0.40.3, modelo/digest anteriores, contexto 2.048, máximo 256 tokens de salida, concurrencia 1, semilla 42, `think=false` y muestreo no-thinking recomendado por Qwen: temperatura 0,7, top_p 0,8, top_k 20, min_p 0, presence_penalty 1,5 y repeat_penalty 1.
- Instancia: `127.0.0.1:11435`, almacén `models/ollama`, variables solo del proceso, sin cambios de entorno del usuario. Scripts de arranque/parada propios; se comprueba el propietario del puerto y la identidad del proceso antes de detenerlo. No hace falta `.venv` en esta fase.
- Reparto CPU/GPU automático del runtime, sin ajuste de optimización. El artefacto trae `draft_num_predict=4` y activa MTP por defecto; debe conservarse y registrarse al repetir la referencia. El runtime resuelve 6 hilos y Flash Attention habilitada; consultar el informe y las evidencias de ejecución para buffers y contexto efectivos.
- Las pruebas fijas de `configs/smoke-prompts.json` cubren español, instrucciones, cálculo sencillo y código guardado como texto. El runner usa streaming y un reloj monotónico; guarda peticiones, fragmentos, respuestas, métricas de la API y telemetría. Cada repetición exige un RunId nuevo.
- El muestreo nominal cada segundo registra la GPU completa y el árbol de procesos de la instancia, RAM de Windows y CPU acumulada. No mide temperatura CPU, consumo del PC completo ni fallos de página; no confundir memoria virtual comprometida con paginación efectivamente medida. Los errores de sensores se guardan como tales.
- La primera petición incluye la carga de un modelo no residente; no se ha vaciado la caché de archivos del sistema. Las siguientes reutilizan el modelo y pueden reutilizar prefijos. Estas condiciones aún no forman un benchmark controlado.
- Las cuatro peticiones completaron inferencia; la respuesta de cálculo fue incorrecta (29 entre 5: 5 y resto 4; respondió 9 y 2). Esto no impide cerrar la puesta en marcha, pero exige evaluar calidad en la fase 2 sin atribuir el fallo a la cuantización o al modo de razonamiento sin comparación.

Comandos de reproducción e informe: `README.md` y `reports/phase1-20261014.md`. Evidencias de identidad: `results/phase1-20261014`; pruebas y telemetría: `results/smoke-20261014-reference`.

## Fase 2 — Construir la referencia de evaluación

Medir capacidades y rendimiento por separado, usando herramientas estándar cuando sean compatibles. Evitar una batería enorme al principio: piloto corto para validar el procedimiento, suite reducida para iterar y evaluación más amplia para candidatos finales. Las muestras reducidas no se presentarán como puntuaciones oficiales completas.

### Capacidades

Propuesta inicial, sujeta a disponibilidad, licencias y compatibilidad del backend:

| Área | Suite candidata | Qué guardar |
| --- | --- | --- |
| Conocimiento | MMLU o MMLU-Pro | Exactitud, puntuación por área, protocolo |
| Razonamiento matemático | GSM8K | Exactitud y método de extracción de respuesta |
| Seguimiento de instrucciones | IFEval | Métricas estrictas y relajadas por separado |
| Código | HumanEval/MBPP mediante un evaluador compatible | pass@1, tests, fallos y entorno aislado |
| Español y uso personal | Conjunto local fijo de tareas | Rúbrica previa, respuestas y revisión humana |
| Contexto | Recuperación y preguntas sobre textos a varias longitudes | Aciertos, truncamientos y longitud efectiva |

Considerar `lm-evaluation-harness` para las tareas que soporte. Verificar cada tarea y el tipo de inferencia requerido. No asumir que la API de chat de Ollama expone las probabilidades necesarias para todas las tareas de elección múltiple: usar un backend compatible o documentar una evaluación generativa distinta, sin equipararla al protocolo estándar.

Fijar revisión del dataset, selección de muestras, semillas, few-shot, plantilla, extracción de respuestas, parámetros de generación, límite de salida y modo de razonamiento. Separar desarrollo/calibración del conjunto final de evaluación. En la suite personal, incluir programación, explicación, español e instrucciones con criterios puntuables. No basar la calidad únicamente en otro LLM como juez.

### Rendimiento y recursos

| Grupo | Métricas |
| --- | --- |
| Latencia | Tiempo de carga; tiempo hasta primer token (TTFT); primer contenido visible si hay razonamiento; latencia total p50/p95 |
| Velocidad | Tokens/s de procesamiento de entrada y generación; tokens de entrada/salida/razonamiento cuando se puedan distinguir |
| GPU | VRAM usada y pico, utilización, temperatura, potencia, frecuencias y motivos de throttling cuando estén disponibles |
| CPU y sistema | Utilización, RAM del proceso y del sistema, paginación, carga y respuesta del PC; temperatura CPU si un sensor fiable la expone |
| Almacenamiento | Tamaño de pesos y variantes, tamaño de cachés y resultados |
| Consumo | Energía GPU estimada integrando potencia; energía del PC solo si existe una medición adecuada |
| Fiabilidad | Errores, OOM, timeouts, respuestas truncadas y ejecuciones incompletas |

Muestrear GPU con `nvidia-smi`, por ejemplo cada segundo, y recursos del sistema con herramientas compatibles. Especificar intervalo, unidades, fuente y alcance: un pico muestreado puede omitir máximos entre muestras. La potencia GPU no representa consumo del PC completo. Los sensores no disponibles se marcan como tales.

La API de Ollama ofrece contadores y duraciones que pueden ayudar a medir carga, evaluación de entrada y generación. Medir TTFT desde el cliente mediante streaming y reloj monotónico; no deducirlo de la duración total. Documentar si el primer fragmento contiene razonamiento o respuesta visible.

### Protocolo reproducible

- Guardar inventario de software/hardware y configuración completa por ejecución.
- Separar carga en frío, inferencia con modelo residente y reutilización de caché de prefijo. Controlar y registrar estas condiciones; variar prefijos en el perfil sin caché sin alterar el contenido evaluado.
- Empezar con un usuario y concurrencia 1. Probar varias longitudes de entrada y presupuestos de salida; medir longitudes reales y finales anticipados.
- Para rendimiento, hacer calentamiento y al menos 5 repeticiones por condición viable; ampliar si hay mucho ruido. Mostrar muestras individuales y tamaño de muestra. Un p95 con pocas muestras es orientativo.
- Registrar estado térmico inicial y procesos que compiten por recursos. Añadir una prueba sostenida para detectar degradación térmica; comparar condiciones iniciales parecidas.
- Usar prompts fijos y parámetros iguales entre variantes. Separar modos con y sin razonamiento; menos tokens generados no prueban inferencia más rápida.
- Informar incertidumbre de calidad cuando sea posible, por ejemplo intervalos o comparación pareada sobre las mismas muestras. No interpretar diferencias mínimas como mejoras concluyentes.

**Criterio de cierre:** runner repetible, resultados crudos, informe de referencia, límites conocidos y costes estimados para repetir la suite. El usuario debe poder comprender qué se ha medido y reproducirlo.

## Fase 3 — Optimizar, más adelante

Esta fase queda fuera del encargo actual y no se inicia automáticamente. Comparar cada variante con la referencia conservada:

1. Ajustes de inferencia: reparto GPU/CPU, contexto, cachés, hilos y opciones del runtime compatibles con el modelo.
2. Cuantizaciones disponibles y, si es viable, cuantización propia con calibración separada de la evaluación. Evitar recuantizar pesos ya degradados cuando exista una fuente adecuada.
3. Otros runtimes compatibles, comparando primero la misma referencia para separar efectos del backend y de los pesos.
4. Poda estructurada u otras técnicas experimentales solo después de comprobar soporte, coste y beneficio plausible. La poda no estructurada puede no acelerar nada en este hardware.
5. Ajuste posterior o destilación solo si se plantea como experimento explícito y cabe en el presupuesto local. No suponer que entrenar o cuantizar pesos completos es viable en 12 GB.

Para cada experimento guardar hipótesis, única variable principal, configuración, coste, resultados y decisión. Mantener una tabla de compromisos o frontera de Pareto: una variante se descarta si otra mejora sus métricas relevantes sin empeorar las demás. Acordar tras la referencia objetivos prácticos de TTFT, velocidad, contexto y caída de calidad aceptable; no inventar ahora cifras de éxito.

## Modelo de OpenAI para la siguiente conversación

Cada cierre debe recomendar en `NEXT_PROMPT.md` un modelo, su versión y esfuerzo de razonamiento, con una razón relacionada con el encargo. Priorizar eficiencia sin sacrificar la calidad necesaria: Luna para tareas acotadas, Sol para implementación e integración y Astra para investigación o diagnóstico especialmente difíciles. Revisar la recomendación en cada conversación; no asignar un modelo fijo a todas las fases.

Para la siguiente conversación (fase 2A: runner y piloto) se recomienda **GPT-6.1 Sol (`gpt-6.1-sol`) con razonamiento medium**: requiere integrar streaming, telemetría, evaluación generativa y control de caché. El catálogo de esta sesión incluye esa versión y esfuerzo, y la [ficha oficial](https://developers.openai.com/api/docs/models/gpt-6.1-sol), consultada el 14 de octubre de 2026, confirma el nombre y `medium`. Es una recomendación práctica, no una evaluación propia ni una garantía de acceso en otras cuentas.

## Organización prevista

Crear estas carpetas cuando hagan falta, no por adelantado:

```text
.venv/                 Entorno Python
models/                Pesos y almacén local de Ollama
cache/                 Cachés de descargas y datasets
configs/               Configuraciones versionadas
scripts/               Preparación y runners
benchmarks/            Definiciones, rúbricas y manifiestos de muestras
results/<run_id>/      Configuración, respuestas, métricas y telemetría
reports/               Informes comparativos y decisiones
```

Cada ejecución debe incluir identificador, fecha, versión del código, modelo/digest, backend, parámetros, dataset/revisión, estado de caché, muestras, métricas y fallos. Guardar datos estructurados en JSON/JSONL o CSV y un informe legible en Markdown. El historial debe distinguir resultados medidos, estimaciones e hipótesis.

## Fuentes verificadas para orientar el inicio

Consultadas el 14 de octubre de 2026; volver a comprobar compatibilidad al implementar:

- [Ficha oficial de Qwen3.8-27B](https://huggingface.co/Qwen/Qwen3.8-27B).
- [Etiqueta qwen3.8:27b de Ollama](https://ollama.com/library/qwen3.8:27b); no tratar su tamaño o digest como inmutables.
- [API de generación de Ollama](https://docs.ollama.com/api/generate), para streaming y métricas de inferencia.
- [LM Evaluation Harness de EleutherAI](https://github.com/EleutherAI/lm-evaluation-harness), para evaluación estandarizada y compatibilidad de backends.
