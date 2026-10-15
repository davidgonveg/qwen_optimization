# Fase 2B: recuperación con sesiones separadas, v1

Fijado el 15 de octubre de 2026 antes de inferencia. Se conserva el protocolo monolítico y su resultado parcial. Esta es otra condición de sesión; no se mezclan sus latencias con las anteriores. No constituye variante de pesos o de parámetros.

## Hipótesis y margen

En v1, RAM libre tras carga: 8,042 GiB; tras calidad: 2,580 GiB; al cancelar: 1,366 GiB. Caché de prompts 0..8121,435 MiB y checkpoints de cientos de MiB, con límite efectivo 8192 MiB. El crecimiento de esta caché es una contribución plausible; no se ha aislado toda la memoria ni medido paginación o fuga. La hipótesis de recuperación es que empezar cada bloque en un proceso nuevo evita heredar los 22 prompts de calidad. No se cambia la política de caché ni se borra la caché Windows.

Fuente oficial fijada: Ollama v0.40.3, commit eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21; LLAMA_CPP_VERSION=b11351, commit 631109b34da437a3c4a5ebd75091d677671392e3. common/common.h establece cache_ram_mib=8192; server-context.cpp crea la caché y salva/restaura prompts al cambiar tareas. Los logs locales determinan el comportamiento observado.

Incidencia previa sin inferencia: el servicio/instalación habitual ahora comunica 0.40.4 y su helper b42b7e6d3. El guard rechazó el arranque antes de crear resultados. No atribuir esos hashes al runtime de ayer. Para conservar exactamente la versión de referencia se recupera el ZIP oficial v0.40.3 (1468053171 bytes, SHA256 e5ecff02dfc7cae8ddf6d6b7a7ac5f727ffeedf4491f44ae75ff5b0820dbbbd5) dentro de runtime/ollama-v0.40.3, ignorado por Git; sin instalar, cambiar PATH ni reemplazar la instalación global. Ambas configuraciones fijan runtime_executable. Verificar versión cliente con OLLAMA_HOST al puerto propio, pues --version por defecto comunica la versión del servidor habitual; confirmar además API 0.40.3, helper y hashes del paquete en la sesión. Registrar procedencia y comparación: sin hashes históricos binarios no se demuestra igualdad byte a byte con la instalación de ayer.

Entrada conservadora por sesión: >=18 GiB de RAM física libre, >=10240 MiB VRAM libre y GPU <=60 °C, sin modelos en la instancia propia. Son requisitos previos adicionales, no modificaciones de los umbrales de parada. La carga anterior consumió aproximadamente 9,6 GiB de RAM libre; 14 cambios de prompt a ~0,3..0,5 GiB suponen ~4,2..7 GiB adicionales en rendimiento: margen esperado ~1,4..4,2 GiB partiendo de 18 GiB. Es una estimación que puede fallar; la memoria actual y el monitor deciden. Sostenido usa salidas más largas y menos cambios por minuto, pero su consumo no se presume garantizado. Si falla una sesión, conservar parciales y no reintentar automáticamente.

## Invariantes

Mismo configs/reference.json completo, modelo/digest/Q4_K_M, Ollama 0.40.3, contexto 2048, máximo 256, semilla 42, think=false, concurrencia 1, MTP 4 y reparto automático. Mismos prompts, rangos y muestreo que v1. Sin ajustes de caché, hilos, offload, pesos, backend, runtime o umbrales. No ejecutar código generado. No cerrar procesos ajenos.

Calidad: reutilizar las 22 respuestas y scores de results/reduced-20261014-reference-v1, con config/suite idénticas y validación parcial de integridad. Mantener 15/18 estrictas y 10/12 criterios asistidos separados y revisión humana pendiente. La integridad del origen no cierra el run monolítico. Guardar hashes de todos los archivos de origen y fuentes de regresión antes/después.

## Sesiones previstas

1. Rendimiento, RunId nuevo, configs/recovery-performance-v1.json. Proceso nuevo; API /ps vacía, petición no residente de compatibilidad fuera de percentiles. Dos calentamientos (corto/largo) excluidos. Seis repeticiones por longitud, AB BA AB BA AB BA, con los mismos nonces/prompts de v1; no mezclar la única repetición antigua. Entrada aproximada 128/512, rangos 96..192 y 384..640 tokens; entrada+256<=2048. Registrar contexto, tokens reales, caché, respuesta Oviedo, finales, errores, TTFT y tiempos. Parar la instancia propia al terminar.
2. Sostenido, otro RunId/proceso nuevo, configs/recovery-sustained-v1.json. Comprobar de nuevo margen/temperatura antes de arrancar. Compatibilidad/carga no residente excluida; calentamiento del mismo prompt sostenido con nonce sustained-warmup excluido. Después mismo prompt de copia de seguridad con nonces sustained-001..060; sin pausas, reinicios ni descargas dentro del bloque. Objetivo monotónico >=180 s, no lanzar peticiones a partir de 180; límite duro 210 s, máximo 60 peticiones y timeout por petición acotado al tiempo restante. Guardar la última respuesta aunque haga superar 180 s. Cap/error/vacío/length/parada antes del objetivo impiden cierre. Parar solo instancia propia.

No igualación térmica exacta: el filtro inicial limita variación, y se conservan temperatura inicial, por petición y ventanas de primeros/últimos 60 s. No sumar cargas o pausas entre procesos al tiempo sostenido. La caché de archivos Windows permanece sin controlar; la caché de prompts empieza nueva y crece dentro de cada sesión; comprobar contadores y log. Tres minutos no acreditan uso prolongado ni permiten atribuir deriva a throttling.

## Monitor y cierre

Monitor original cada segundo, listo antes de inferir, cancelación HTTP enlazada: RAM libre <1572864 KiB, VRAM libre <384 MiB, GPU >=80 °C o dos errores/ausencias de sensores consecutivos. Guardar parciales/null/evento y parada propia. Validar streams, finales y contadores, opciones, schedule, seis válidas por condición, rangos/contexto, duración sostenida, telemetría y ausencia de eventos. Resumir por sesión con nearest-rank (n=6, p95 máximo orientativo); potencia/energía de toda la GPU, no del PC.

El cierre agregado de fase 2B exige calidad de origen íntegra + sesión de rendimiento completa + sesión sostenida completa + validación conjunta de identidades/configuraciones/hashes, servicio habitual preservado e instancia propia detenida. Cada sesión completa por sí sola no cierra fase 2B. Si no hay margen o el monitor cancela, registrar pendiente prioritario y no modificar parámetros sin autorización. Fase 2 permanece abierta para acordar alcance posterior; sin optimización automática.

Fuentes: [Ollama fijado](https://github.com/ollama/ollama/tree/eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21), [pin](https://github.com/ollama/ollama/blob/eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21/LLAMA_CPP_VERSION), [defaults](https://github.com/ggml-org/llama.cpp/blob/631109b34da437a3c4a5ebd75091d677671392e3/common/common.h), [contexto](https://github.com/ggml-org/llama.cpp/blob/631109b34da437a3c4a5ebd75091d677671392e3/tools/server/server-context.cpp). Consultadas 15-10-2026.
