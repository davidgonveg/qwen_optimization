# Fase 2B: diagnóstico y recuperación de sesiones

15 de octubre de 2026. **Fase 2B completa mediante evidencia agregada de sesiones distintas; fase 2 abierta.** Calidad de origen preservada, seis medidas por longitud y 188,598 s sostenidos validados. Sin optimización ni ejecución de código generado.

## Qué explica la presión de RAM

La evidencia del 14 de octubre permite observar crecimiento del árbol propio y caché de prompts, sin aislar causalidad completa. Tras carga no residente había 8,042 GiB libres; al terminar las 22 tareas, 2,580 GiB; tras calentamientos 2,208/1,751 GiB; al cancelar, 1,366 GiB. La caché del log llegó a 8121,435 MiB, frente al límite efectivo de 8192 MiB. Los checkpoints ocupan cientos de MiB aun con entradas breves: no basta con contar tokens o solo pesos.

[Ollama v0.40.3 fijado](https://github.com/ollama/ollama/tree/eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21) selecciona b11351 en [LLAMA_CPP_VERSION](https://github.com/ollama/ollama/blob/eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21/LLAMA_CPP_VERSION). Ese tag resuelve a 631109b34da437a3c4a5ebd75091d677671392e3. [common/common.h, línea 634](https://github.com/ggml-org/llama.cpp/blob/631109b34da437a3c4a5ebd75091d677671392e3/common/common.h#L634) fija 8192 MiB; [server-context.cpp](https://github.com/ggml-org/llama.cpp/blob/631109b34da437a3c4a5ebd75091d677671392e3/tools/server/server-context.cpp#L1351) crea la caché y salva/carga prompts al seleccionar tareas. Las fuentes fijadas concuerdan con el log de la referencia. Consultadas el 15 de octubre; URLs y hashes UTF-8 en recovery-checks-20261015/pinned-sources.json.

**Hipótesis comprobada operativamente:** procesos nuevos por bloque evitan heredar la caché acumulada durante calidad. El resultado puede acreditar viabilidad de ese protocolo; no prueba una fuga, elimina todas las causas externas ni demuestra que cambiar caché aceleraría el modelo. No se midieron fallos de página, paginación, temperatura CPU, energía PC, throttling o respuesta del escritorio. Memoria privada comprometida y RAM residente son magnitudes distintas.

## Incidencia de versión y referencia conservada

Antes de inferir, el guard de arranque detectó Ollama **0.40.4** instalado y detuvo el intento recovery-performance-20261015-v1. No hubo servidor propio ni peticiones del modelo en ese intento. El servicio habitual también comunica 0.40.4; no consta qué proceso externo realizó la actualización. Sus binarios actuales/helper b42b7e6d3 se identificaron inicialmente al investigar fuentes y no deben atribuirse al runtime histórico. La corrección queda explícita en portable-runtime-verified.json y startup-version-rejection.json; se conservan las observaciones originales.

Para mantener **0.40.3** se descargó el ZIP portátil oficial a cache/downloads y se extrajo dentro de runtime/ollama-v0.40.3, sin instalar ni modificar PATH, servicio o almacén habitual. [Paquete oficial](https://github.com/ollama/ollama/releases/download/v0.40.3/ollama-windows-amd64.zip): **1.468.053.171 bytes**, SHA-256 `e5ecff02dfc7cae8ddf6d6b7a7ac5f727ffeedf4491f44ae75ff5b0820dbbbd5`, coincidente con el digest publicado. Helper 0.5.0-dev/build 1/631109b34, coherente con el pin. Sin hashes binarios históricos no se acredita igualdad byte a byte con la instalación anterior; sí versión, fuente oficial, identidad del modelo y comportamiento efectivo registrado. Los binarios, ZIP y pesos quedan ignorados por Git; se versiona su procedencia/hashes.

Se corrigió además el chequeo CLI: --version consulta por defecto el servidor habitual y puede mostrar su versión aunque se invoque otro cliente. Se dirige temporalmente al puerto propio aún libre para comprobar el cliente; tras arrancar se exige también API 0.40.3 y propietario correcto. Arranque/parada portátil sin inferencia probado antes de los benchmarks.

No se cambió configs/reference.json: Qwen3.8-27B qwen3.8:27b, GGUF Q4_K_M, digest sha256:aaee06c39dcf2437cde036998d960e1fc1494b8191be7cc9657d01e509097813. Contexto 2048, máximo 256, semilla 42, think=false, concurrencia 1, muestreo original, MTP 4, 6 hilos, 31/66 capas GPU y Flash Attention efectiva. Caché 8192 MiB sin ajustes. No se descargaron pesos ni se sustituyó el modelo.

## Protocolo nuevo y rendimiento

Definido antes de inferencia en benchmarks/PROTOCOL-2B-RECOVERY.md y configs/recovery-{performance,sustained}-v1.json. Dos procesos/sesiones independientes. Requisito previo adicional: >=18 GiB RAM libres, >=10240 MiB VRAM libres y GPU <=60 °C. No garantiza viabilidad; monitor original cancela con RAM libre <1,5 GiB, VRAM libre <384 MiB, GPU >=80 °C o dos errores/ausencias consecutivos. No se cerraron procesos ajenos ni se redujo ningún umbral.

Rendimiento: **results/recovery-performance-20261015-v2**, 15 peticiones completas: carga +2 calentamientos +12 medidas. Orden AB BA AB BA AB BA idéntico a v1; no se agregan las mediciones antiguas. Calentamientos y carga excluidos de percentiles. La carga no residente duró **53,608 s** cliente, con caché de archivos Windows sin vaciar. Entradas 135/519 tokens en rangos previos y con presupuesto <2048; caché de 7 tokens en las doce medidas, salida de 4 tokens, todas «Oviedo». No truncamientos, errores ni parada.

| Condición, n=6 | TTFT p50/p95 (s) | Total p50/p95 (s) | Generación p50 (tokens/s) |
| --- | --- | --- | --- |
| Corta, 135 tokens | 2,141 / 2,243 | 2,989 / 3,106 | 4,567 |
| Larga, 519 tokens | 3,053 / 3,367 | 3,901 / 4,219 | 4,456 |

Nearest-rank: p95 es máximo, orientativo con seis muestras. Salida brevísima y padding repetitivo; no representa velocidad general ni comprensión de documentos naturales. Temperatura por inicio de petición 55..60 °C, con distancia al sensor registrada; no igualación térmica exacta. Separar esta condición de sesión de la monolítica anterior.

98 muestras sin errores, intervalo mediano 1,012 s y máximo **2,070 s**; la colección llegó a 2,068 s, por lo que el muestreo nominal de un segundo no fue uniforme. RAM libre mínima **2,637 GiB**, residente árbol pico **15,880 GiB**, privada comprometida **26,812 GiB**. VRAM pico **11467 MiB**, margen 821 MiB; GPU pico **67 °C /130,60 W**. Caché de prompts máxima observada **6301,787 MiB /14 prompts**. Energía GPU estimada **1,524 Wh /104,522 s** de cobertura, incluye otros procesos y carga. Tiempo cliente de peticiones **103,195 s**. Las muestras pueden omitir picos entre ellas.

## Calidad conservada

Se reutilizan exclusivamente las 22 tareas completas de results/reduced-20261014-reference-v1: **15/18 estrictas** y **10/12 criterios asistidos**, sin sumarlas ni modificar criterios. Configuración/suite y hashes de respuestas comprobados. Las rúbricas siguen pendientes de revisión humana independiente. Los resultados del piloto y fases previas se conservan; no se presentan diferencias entre suites como mejoras.

## Carga sostenida completada y variación observada

**results/recovery-sustained-20261015-v1**: proceso independiente, RAM libre previa **18,933 GiB**, GPU **51 °C** (rendimiento empezó con 19,916 GiB/58 °C). Carga no residente **56,030 s** cliente; calentamiento sostenido **33,802 s**, 82 tokens, excluido del bloque. **7 peticiones sostenidas completas**, 77 tokens de entrada/caché 0 en todas, salidas 66..72 tokens, total **493 tokens**. Duración monotónica **188,598 s**, dentro de 180..210; suma cliente activa **188,175 s**, diferencia de ~0,423 s por preparación/registro entre llamadas. Sin pausas intencionadas, reinicios, errores, length ni paradas; última petición comenzó antes de 180 s y terminó dentro del límite duro. No se ejecutó el texto generado.

| Ventana, por inicio de petición | Primeros 60 s | Últimos 60 s |
| --- | --- | --- |
| Peticiones incluidas | 3 | 2 |
| Generación p50 (tokens/s) | 2,934 | 2,395 |
| Tokens salida p50 | 70 | 66 |
| TTFT p50 (s) | 1,910 | 1,845 |
| GPU temperatura p50/pico (°C) | 47/52 | 50/55 |
| RAM libre mínima (GiB) | 7,643 | 6,482 |

La generación p50 de estas ventanas cae **18,4%**; no afirmar velocidad constante. Hay solo tres/dos peticiones, salidas diferentes, caché acumulada y procesos ajenos. No se midieron throttling, frecuencias ni paginación; la temperatura observada no demuestra una causa térmica. La prueba demuestra que ese bloque terminó con recursos dentro de los límites muestreados, sin acreditar estabilidad prolongada o explicar causalmente la deriva.

275 muestras sin errores: intervalo mediano **1,013 s**, máximo **1,351 s**; colección máxima **1,349 s**. RAM libre mínima **6,482 GiB**, residente árbol pico **11,944 GiB**, privada comprometida **22,803 GiB**. VRAM pico **11504 MiB**, margen 784 MiB; GPU pico **55 °C/69,40 W**. Caché de prompts máxima del log **2466,715 MiB**. Energía de toda la GPU **2,956 Wh /278,718 s** de cobertura, incluye carga/calentamiento y otros procesos; no energía exclusiva del bloque ni del PC. Suma de las nueve peticiones de sesión **278,007 s**.

En ambas sesiones se revalidaron digest, manifiesto/capas/tamaños y API 0.40.3; no rehash completo de pesos. Recursos/temperatura ajenos y caché Windows no se igualaron. Tras cada sesión se detuvo solo su instancia: PIDs 228 y 32928; listener 11435 vacío y modelos/digests habituales intactos. Inventario final: RAM libre **18,701 GiB**; servicio habitual 0.40.4 accesible. Ver inventarios para instantes/unidades exactos.

## Validación y estado de cierre

`results/recovery-checks-20261015/aggregate-validation.json`: **aggregate_pass**, phase2b_complete=true y phase2_complete=false. Identidades/config/suite coherentes, 352 archivos históricos intactos por SHA-256, calidad de origen reextraída, dos sesiones válidas y runtime portátil sin modificaciones. Las validaciones individuales indican session_complete=true y phase_complete=false; el run monolítico original mantiene partial_integrity_pass/phase_complete=false. No se reescribió ningún resultado previo.

Comprobaciones: doce casos de scoring; schedule original/recuperación/orden/prompts/umbrales/cancelación enlazada; arranque/parada portátil sin inferencia; sintaxis PowerShell y JSON; streams/finales/contadores/caché/velocidades/opciones/tiempos de 24 peticiones nuevas; telemetría, duración/límites, hashes de scripts de inferencia fijados antes de cada run y hashes del runtime. El validador rechaza el origen incompleto como cierre. La primera comparación del resumen contra el esquema antiguo del piloto dio diferencias: solo campos incorporados en fase 2B y redacción, no métricas. Recalculado contra el resumen ya generalizado de la fase 2B: idéntico excepto fecha, sin tocar el directorio del piloto. Ambas comprobaciones están conservadas, con explicación.

Los únicos cambios de scripts posteriores al inicio de inferencia son de análisis/validación; hashes finales en recovery-checks-20261015/final-script-hashes.json. Runner, monitor, schedule, arranque/parada y configuración conservan los hashes fijados para las peticiones nuevas. Copias de los siete scripts efectivos, verificadas contra ambos runs, en recovery-checks-20261015/inference-source; conservan bytes/finales de línea independientemente de futuros checkouts. La descarga portátil no alteró el runtime aplicado a la referencia (0.40.3); se aisló de una instalación global actualizada externamente.

Coste medido de recuperación: **381,202 s =6,353 min** sumando tiempos cliente de ambas sesiones, **24 peticiones/637 tokens de salida**; añade preparación, descarga portátil/verificación y análisis. Repetir solo rendimiento+sostenido es aproximadamente 6,4 min bajo condiciones parecidas, sin garantía. Repetir además calidad en una tercera sesión nueva requiere su carga y ~122,5 s observados de calidad: estimación **9..10 min**, sin repetirla ahora ni presentar el agregado como un run continuo. ZIP **1468053171 bytes**, runtime extraído **1941752691 bytes**, evidencia nueva ~**1,24 MB** antes de los últimos metadatos, según final-checks.json. Pesos y binarios fuera de Git.

Pendientes: revisión humana independiente de siete rúbricas entre 2A/2B; decisión explícita sobre suficiencia del alcance de fase 2; deriva sostenida por explicar si se autoriza investigar más. Visión, thinking, loglikelihood arbitraria, benchmarks oficiales, aislamiento real para código, fiabilidad prolongada y optimización siguen fuera del alcance. No se inicia fase 3.
