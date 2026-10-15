# Estado del proyecto

Actualizado: 15 de octubre de 2026.

## Hito actual

**Fase 2B completa mediante tres fuentes de evidencia separadas.** Calidad del run parcial del 14 de octubre preservada (22 tareas, 15/18 estrictas, 10/12 criterios asistidos), más sesiones nuevas de rendimiento (seis medidas por longitud) y sostenido (188,598 s, siete peticiones). Validación agregada satisfactoria; el run monolítico original sigue incompleto. Ficha consolidada en `reports/phase2-reference-20261015.md`; paquete con las siete rúbricas, respuestas literales y hashes en `reports/human-review-rubrics-20261015.md`. **Fase 2 abierta, sin optimización**, pendiente decisión de alcance y decisiones humanas. Referencia y 352 archivos históricos comprobados por hash, sin modificaciones.

## Evidencias

- Modelo `qwen3.8:27b`, GGUF Q4_K_M, 27.3B, digest `sha256:aaee06c39dcf2437cde036998d960e1fc1494b8191be7cc9657d01e509097813`, tamaño 17.741.872.154 bytes. Arquitectura `qwen35` compartida por Qwen3.8; no se sustituyó el modelo.
- Fuente Qwen oficial, licencia Apache-2.0, revisión consultada `1d4bf0f2ff6012fd82039f2fa52739d0dd7c60c0`; commit exacto de conversión GGUF desconocido. Metadatos y fuentes en `results/phase1-20261014`.
- Revalidado: RTX 3060 de 12 GiB, Ryzen 5 5500 de 6 núcleos/12 hilos, aproximadamente 32 GiB RAM, driver 591.86 y PowerShell 7.6.5. El artefacto exige Ollama >=0.32.12. Referencia ejecutada con Ollama **0.40.3 portátil oficial fijado** en runtime/ollama-v0.40.3; instalación/servicio habitual observados en **0.40.4** el 15 de octubre, sin modificarlos. Un arranque con versión distinta fue rechazado antes de inferencia. ZIP 1468053171 bytes/SHA256 e5ecff02dfc7cae8ddf6d6b7a7ac5f727ffeedf4491f44ae75ff5b0820dbbbd5; helper 631109b34 coherente con fuente b11351. No hay hashes binarios históricos para identidad byte a byte con el día anterior.
- Instancia separada `127.0.0.1:11435`, almacén `models/ollama`. Sin `.venv` ni instalaciones nuevas. Modelos globales qwen3-embedding:0.6b, qwen3:8b y gemma4:12b preservados. Al cierre la instancia propia quedó detenida, el puerto 11435 libre y el servicio habitual siguió respondiendo; evidencia en `inventory-after.json`.
- Referencia `configs/reference.json`: contexto 2.048, salida máxima 256, semilla 42, `think=false`, concurrencia 1, muestreo recomendado de Qwen para no-thinking y reparto automático. Runtime: 31/66 capas GPU, 6 hilos, MTP heredado de 4 tokens y Flash Attention efectiva. Scripts de arranque, descarga, pruebas, telemetría y parada en `scripts`.
- Descarga completada en 260,76 s. Digest de API y manifiesto original/capas locales comprobados. La API omite el prefijo `sha256:`; Ollama añade capas de procedencia al manifiesto local. El verificador normaliza el prefijo y comprueba el blob original, sin exigir igualdad del hash del archivo reescrito.
- Pruebas `results/smoke-20261014-reference`: español 161,40 s total (94,79 s carga; primer contenido 130,45 s), JSON 6,33 s, cálculo 22,86 s y código 9,57 s. Las tres peticiones residentes tuvieron primer contenido 1,71–1,79 s y generación 3,92–6,32 tokens/s. Son una observación por tarea, sin p50/p95 ni comparación controlada.
- Revisión: español e instrucciones cumplen; código plausible mediante lectura estática, nunca ejecutado. Cálculo incorrecto: tras 36−7=29 respondió 9 por niño/resto 2; correcto 5/resto 4. La inferencia técnica funciona; la calidad no se da por validada.
- 199 muestras de recursos sin errores: VRAM total pico 11.381 MiB; temperatura GPU pico 59 °C; potencia GPU pico 70,61 W; working set del árbol pico 10,56 GiB; memoria privada comprometida pico 21,40 GiB; RAM libre del sistema mínimo 8,03 GiB. GPU incluye otros procesos. No se midieron fallos de página ni energía del PC.
- Detalles, método, límites y reproducción en `reports/phase1-20261014.md` y `README.md`. Los resultados iniciales permanecen intactos; las repeticiones crean nuevos directorios.
- Recuperación: `reports/phase2b-recovery-20261015.md`, `results/recovery-performance-20261015-v2`, `results/recovery-sustained-20261015-v1` y `results/recovery-checks-20261015/aggregate-validation.json` (phase2b_complete=true, phase2_complete=false). Configs/protocolo previos separados; caché/runtime/opciones/umbrales de referencia intactos. Fuentes Ollama eab97e9 y llama.cpp 631109b fijadas; log concuerda con caché por defecto de 8192 MiB.
- Rendimiento: n=6 por condición, 135/519 tokens, caché 7/salida 4, doce respuestas Oviedo. TTFT p50/p95 corta 2,141/2,243 s; larga 3,053/3,367 s. Total p50/p95 2,989/3,106 y 3,901/4,219 s; generación p50 4,567/4,456 tokens/s. p95 máximo orientativo. RAM libre mínimo 2,637 GiB; caché pico 6301,787 MiB, VRAM 11467 MiB y GPU 67 °C. 98 muestras sin errores, intervalo máximo 2,070 s.
- Sostenido: siete peticiones/493 tokens en 188,598 s dentro del límite 210; sin error/truncamiento/parada. RAM libre mínimo 6,482 GiB, caché pico 2466,715 MiB, VRAM 11504 MiB, GPU 55 °C. 275 muestras sin errores. Generación p50 primeras/últimas ventanas 60 s: 2,934 (n=3) y 2,395 (n=2), caída descriptiva 18,4%, sin demostrar causa térmica ni estabilidad prolongada. No se midió paginación.
- Coste nuevo: 24 peticiones/637 tokens, 381,202 s de tiempo cliente (~6,35 min); energía GPU por sesión 1,524 Wh/104,522 s y 2,956 Wh/278,718 s, incluye cargas y otros procesos. No energía del PC. PIDs propios 228/32928 detenidos, 11435 libre y tres modelos/digests habituales preservados; RAM libre final inventariada 18,701 GiB.
- Ficha breve consolidada: `reports/phase2-reference-20261015.md`. Resume calidad, latencia, recursos, coste y límites con enlaces a las evidencias crudas; diferencia observaciones de estimaciones y evita sumar suites o sesiones incompatibles.
- Revisión humana preparada pero no recibida: `reports/human-review-rubrics-20261015.md` contiene q08/q09/q10 y b19/b20/b21/b22 con prompt, respuesta literal, rúbrica fijada antes de inferencia y SHA-256 comprobado contra el archivo de respuesta. Casillas vacías. No se ejecutó q10; revisiones asistidas originales intactas.

## Decisiones

- La fase 1 cierra puesta en marcha, no aprobación de calidad para uso diario. No inferir calidad general a partir de una respuesta ni atribuir el fallo a Q4_K_M o a no-thinking sin comparación.
- Conservar la referencia y el comportamiento heredado del runtime. No ajustar MTP, contexto o reparto GPU antes de medir la referencia de fase 2.
- Fase 2A validó el procedimiento; fase 2B reúne ahora calidad preservada y rendimiento/sostenido completos en sesiones separadas. No equiparar el agregado a una sesión continua ni mezclar latencias históricas. Mantener fases 1/2A como desarrollo y reduced-v1 como referencia personal expuesta; no relajar criterios. Evaluación amplia y optimización requieren alcance posterior.
- La referencia consolidada acredita únicamente una referencia personal reducida de texto, con el alcance y limitaciones detallados en `reports/phase2-reference-20261015.md`. Se presentó al usuario la decisión: (A) aceptar el cierre técnico con revisión humana aún explícitamente pendiente, o (B) autorizar una ampliación concreta propuesta con GSM8K generativo. No se ha elegido; no marcar fase 2 completa ni iniciar ampliación/fase 3 hasta decisión explícita.
- Mantener los umbrales previos de fase 2B: RAM libre 1,5 GiB, VRAM libre 384 MiB, GPU 80 °C y máximo dos errores consecutivos de sensores. La parada por RAM es evidencia de viabilidad insuficiente del protocolo monolítico, no autorización para modificar caché/runtime ni repetir silenciosamente.
- Próximo modelo recomendado: **GPT-6 Luna (`gpt-6-luna`), razonamiento medium**, para consolidar evidencia existente, preparar revisión humana y explicar límites, sin nueva implementación/inferencia. Tarea acotada tras resolver la recuperación; nombres/esfuerzo comprobados en [ficha oficial](https://developers.openai.com/api/docs/models/gpt-6-luna) y catálogo de sesión el 15 de octubre. No cambia automáticamente el modelo ni garantiza acceso. Si aparece diagnóstico nuevo, reconsiderar Sol.
- Git: seguir `main` y upstream `origin/main`, remoto `git@github.com:davidgonveg/qwen_optimization.git`. Excluir `models`, `runtime`, cachés y entornos; versionar evidencia pequeña pertinente.

## Próximo paso y pendientes

Ejecutar `NEXT_PROMPT.md`: recibir las decisiones de la revisión humana si el usuario las aporta y registrar la elección explícita de alcance de fase 2. Si autoriza ampliación, acordar protocolo y ejecutar solo el alcance autorizado; no inferir autorización de una respuesta incompleta. No repetir trabajo documental ya consolidado, ni repetir inferencia ni iniciar optimización sin autorización. La revisión humana solo se registra al recibir decisiones reales del usuario; otra lectura de Codex sigue siendo asistida.

Logprobs generados comprobados, loglikelihood arbitraria no demostrado. El sostenido acotado terminó, con deriva de velocidad descriptiva pendiente de explicación si se autoriza investigarla. No acredita rendimiento constante ni fiabilidad prolongada. Visión, thinking, benchmarks oficiales, aislamiento de código y optimización fuera de alcance. El protocolo monolítico sigue sin viabilidad demostrada; la referencia recuperada requiere sesiones separadas. No declarar fase 2 completa sin decisión explícita del usuario.

## Registro de continuidad y Git

### Consolidación y revisión humana — 15 de octubre

- Se creó `reports/phase2-reference-20261015.md` con resultados por fuente/sesión, costes, recursos, límites y decisión de alcance. Recuentos y medidas se tomaron de informes y resúmenes existentes; no se repitió inferencia ni se alteraron resultados.
- Se creó `reports/human-review-rubrics-20261015.md` con las siete tareas manuales, prompts/respuestas originales, criterios y hashes SHA-256 que coinciden con los metadatos de revisión y archivos de respuesta. No contiene juicios humanos; q10 queda expresamente estático y sin ejecución.
- Decisión de alcance aún pendiente: aceptar el cierre técnico de fase 2 como referencia reducida de texto, manteniendo revisión humana pendiente, o autorizar la ampliación propuesta GSM8K con protocolo generativo fijado antes de inferencia. Fase 2 no se declara completa y fase 3 no se inicia.

### Recuperación fase 2B — 15 de octubre

- Fuentes fijadas e hipótesis previas en `benchmarks/PROTOCOL-2B-RECOVERY.md`; dos configuraciones nuevas, sin modificar referencia ni protocolos anteriores. Entradas conservadoras adicionales de 18 GiB libres/10 GiB VRAM/GPU <=60 °C; paradas originales intactas.
- Incidencia de actualización externa 0.40.4 resuelta aislando ZIP portátil oficial 0.40.3, sin instalar globalmente. Verificación de cliente dirigida al puerto propio y de API tras arranque. Evidencia del rechazo inicial, paquete y prueba sin inferencia conservada.
- Calidad original reutilizada, dos sesiones completadas sin reintentos de inferencia ni parada. Las validaciones de sesión no cierran por sí solas fase 2B; `aggregate-validation.json` acredita cierre agregado. No fase 3 ni ejecución de código generado.
- 352 archivos históricos/configuración idénticos por hash. Scorer/schedule/sintaxis/JSON, 24 streams/finales/contadores/opciones y 373 muestras de telemetría comprobados. Piloto validado sin inferencia y resumen recalculado fuera de su carpeta: idéntico al esquema generalizado de fase 2B excepto fecha. La comparación inicial con el esquema antiguo se conserva y explica como diferencia de campos/redacción, sin cambios de métricas.
- Scripts de inferencia/monitor/arranque/parada conservan hashes previos a los runs; análisis/validadores finales registrados en `final-script-hashes.json`. No se sustituyen datos ausentes por cero ni se reescriben parciales.
- Cierre con diff/comprobaciones y commit/push normal autorizado en main/origin/main. Hash/resultado definitivos en el mensaje final; cualquier fallo se registrará antes de terminar.

### Fase 2B — Parcial por presión de RAM

- Definiciones nuevas fijadas antes de inferencia: `benchmarks/reduced-v1.json`, `configs/reduced-v1.json`, `benchmarks/PROTOCOL-2B.md`. 22 tareas originales CC0/zero-shot, sin datasets externos, instalaciones ni ejecución de código.
- Evidencia: `results/reduced-20261014-reference-v1`; informe: `reports/phase2b-20261014.md`. Protocolo v1: carga +22 tareas +2 calentamientos +12 medidas alternadas, luego 180 s sostenidos con límite 210 s.
- 27 finales completos y una cancelación en `input-long-002`, sin reintentos. 22 scores: 15/18 estrictos, errores de resto/cambio/tilde; lectura asistida 10/12 criterios, dos juicios conservadores pendientes de revisión humana.
- Entradas reales 135/519; ambos calentamientos completos y una medida válida por longitud, caché 7 tokens y salida 4; ambas responden Oviedo. N=1 no aporta percentiles útiles. Nueve medidas no intentadas, una incompleta; sostenido no iniciado y sin mediciones inventadas.
- Parada a las 20:03:11,62 Madrid: RAM libre 1,366 GiB <1,5. 191 muestras sin errores: RAM residente árbol pico 17,698 GiB, privada comprometida ~28,623 GiB; VRAM pico 11.391 MiB, GPU 64 °C/107,74 W; energía GPU 2,499 Wh/193,127 s. Sin paginación/energía PC/throttling medidos.
- Log: cache RAM de prompts límite 8192 MiB, hasta 25 prompts/8121,435 MiB; acumulación/checkpoints es hipótesis de contribución, no fuga ni causalidad aislada. Diagnóstico crudo en memory-diagnosis.json. No se cambió caché/MTP/contexto/runtime.
- Tiempo de peticiones 191,628 s (3,194 min), 335 tokens conocidos. Repetición completa estimada condicional 7–9 min, sin viabilidad probada. Instancia PID 31280 detenida, puerto 11435 libre, 11434/modelos habituales intactos.
- Scorer, schedule/umbral/cancelación y ensayo del monitor con umbral sintético comprobados. ThreadJob no conservaba PSScriptRoot para auxiliar: corregido/probado antes de inferencia pasando ruta explícita.
- Regresión del piloto sin inferencia y sin escribir en su directorio: streams/scores válidos, resumen numérico/telemetría/percentiles idénticos. Preservación comprobada por Git diff. Actual: `validation.json` dice `partial_integrity_pass`, `phase_complete=false`; validador normal rechaza cierre. Cambios posteriores solo resumen/validador para parciales, hashes finales registrados.
- Revisión/diff/comprobaciones y commit/push normal en main/origin/main al cierre. Hash/resultado definitivos en el mensaje final; si falla se registrará recuperación. Pesos/runtime/cachés excluidos.

### Fase 2A

- Protocolo/manifiestos fijados antes de ejecutar. Diez tareas originales CC0, zero-shot, desarrollo; sin datasets/paquetes externos ni ejecución de código generado.
- Evidencia: `results/pilot-20261014-reference-v1`; informe: `reports/phase2a-20261014.md`. Identidad/tamaños revalidados, definiciones/hashes, peticiones/streams/textos, métricas/scores, revisión asistida, inventarios y telemetría.
- Calidad automática: 4/7 estrictas. q01 cálculo correcto pero Markdown; q02 Markdown y 74,8 en vez de 74; q04 «si» sin tilde exigida. Tres tareas revisadas por Codex: 9/9 criterios, sin validación humana independiente ni pass@1.
- Cinco mediciones por condición, calentamientos excluidos. Variable: caché 0/61, TTFT p50/p95 1,881/1,936 s, total 11,280/13,708 s, generación p50 2,374 tokens/s. Idéntico: caché 57/61, TTFT 0,774/0,855 s, total 9,190/9,434 s, generación p50 2,628 tokens/s. Orden, temperatura y tokens de salida confunden causalidad. Con n=5, p95 es máximo y orientativo.
- Carga no residente: 50,65 s API, primer contenido 52,99 s y total 53,79 s; caché Windows sin vaciar. API real devuelve logprobs solicitados, sin acreditar loglikelihood arbitraria. Opciones/contexto/MTP/hilos/offload intactos.
- 248 muestras sin errores: VRAM pico 11.511 MiB, GPU 64 °C/71,05 W; RAM residente árbol pico 14,65 GiB, privada comprometida 25,55 GiB, RAM libre mínimo 3,02 GiB. Energía GPU estimada 2,883 Wh/253,118 s, incluye otros procesos; no energía PC ni paginación. Suma peticiones 251,99 s (~4,2 min).
- Doce casos del scorer, sintaxis/JSON, 23 streams reconstruidos, diez scores recalculados, cinco mediciones por condición y percentiles coherentes: `validation.json`.
- Correcciones posteriores: lista vacía de errores serializada correctamente (resumen inicial conservado); parada espera proceso/puerto tras observar desaparición diferida del listener. Arranque/parada de regresión sin inferencia probado. Ambos PIDs propios detenidos, 11435 libre, servicio/modelos habituales intactos en `inventory-after.json`.

### Historial previo

- Preparación: fase 0 documental; sin descarga/inferencia.
- Puesta en marcha: fase 1 con descarga, configuración local, cuatro pruebas y evidencias. La conversación se interrumpió durante la descarga; se comprobó que había terminado antes de continuar.
- Corregidos y verificados los errores del comprobador de digest y la comparación de fechas de parada, documentados en el informe. Comprobadas sintaxis, protección del puerto, identidad y parada de la instancia propia; lista global de modelos intacta.
- Revisados diff y archivos excluidos; JSON y coherencia de streams comprobados. Git conserva los bytes de `results` sin conversión de finales de línea; los espacios originales de los logs no se reformatean. Después se realiza commit/push normal autorizado. Hash y resultado definitivo en el mensaje final, evitando commits que se referencian a sí mismos. Si falla el push se registrará recuperación sin sobrescribir el remoto.
