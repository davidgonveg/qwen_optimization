# Ficha de referencia reducida — fase 2

Actualizada: 15 de octubre de 2026. **Referencia técnica consolidada; la fase 2 sigue abierta a decisión del usuario.** Esta ficha reúne tres sesiones separadas. No las presenta como un único run ni combina sus latencias.

## Qué se midió

- **Modelo/configuración:** Qwen3.8-27B `qwen3.8:27b`, GGUF Q4_K_M, digest `sha256:aaee06c39dcf2437cde036998d960e1fc1494b8191be7cc9657d01e509097813`; Ollama portátil 0.40.3, instancia del proyecto en `127.0.0.1:11435`. `configs/reference.json` se conserva: contexto 2048, salida máxima 256, semilla 42, `think=false`, concurrencia 1, MTP 4 heredado, seis hilos y 31/66 capas en GPU según el log. El servicio global observado es 0.40.4 y no se modificó.
- **Calidad (medida en la suite personal reducida):** 15/18 aciertos estrictos automáticos; por separado, 10/12 criterios en cuatro tareas con revisión asistida por Codex. La rúbrica asistida de b21 marcó como no conforme la adición «para evitar inconvenientes» y la de b22 la falta de la equivalencia explícita «80 de cada 100». Esos juicios siguen pendientes de revisión humana independiente. No se suman ambos recuentos ni se comparan como mejora con las siete tareas del piloto.
- **Rendimiento residente (sesión recuperada, n=6 por longitud):** entrada corta de 135 tokens: TTFT p50/p95 2,141/2,243 s; total 2,989/3,106 s; generación p50 4,567 tokens/s. Entrada larga de 519 tokens: TTFT 3,053/3,367 s; total 3,901/4,219 s; generación p50 4,456 tokens/s. Las salidas fueron de cuatro tokens y todas respondieron «Oviedo»; p95 es el máximo de seis muestras y orientativo. No es velocidad general de generación.
- **Sostenido (sesión independiente):** siete peticiones, 493 tokens de salida, duración 188,598 s, sin errores, truncamientos ni paradas. La generación p50 pasó de 2,934 tokens/s en las primeras tres peticiones a 2,395 en las últimas dos (−18,4% descriptivo). Es una diferencia observada, no una causa explicada ni evidencia de estabilidad prolongada.
- **Recursos medidos:** en rendimiento, RAM física libre mínima 2,637 GiB, VRAM total pico muestreado 11.467 MiB, GPU pico 67 °C y caché de prompts pico observada 6.301,787 MiB. En sostenido, RAM libre mínima 6,482 GiB, VRAM pico 11.504 MiB, GPU pico 55 °C y caché de prompts 2.466,715 MiB. En ambas sesiones el muestreo fue aproximadamente cada segundo, con huecos mayores; la GPU incluye otros procesos. No se midieron paginación, temperatura CPU, throttling ni respuesta del escritorio.
- **Coste observado:** recuperación de rendimiento+sostenido: 381,202 s de tiempo cliente (~6,35 min), 24 peticiones y 637 tokens de salida. Energía estimada de GPU: 1,524 Wh y 2,956 Wh por sesión, integrando potencia muestreada; incluye carga y otros procesos, no es consumo del PC. Como estimación condicional, repetir también la suite de calidad en una sesión nueva tomaría aproximadamente 9–10 min de inferencia cliente bajo condiciones parecidas; no es un presupuesto garantizado.

## Qué acredita y qué no

La agregación validada acredita una referencia personal de **texto** con identidad, configuración y sesiones recuperadas verificadas: calidad sobre las tareas de desarrollo/referencia indicadas, rendimiento en dos longitudes con seis muestras cada una y una carga sostenida acotada completada. `aggregate-validation.json` confirma `phase2b_complete=true` y `phase2_complete=false`. El ensayo monolítico original se detuvo por presión de RAM; no fue completado. Las sesiones separadas demuestran una forma de recopilar evidencia utilizable, pero no validan el protocolo monolítico ni permiten mezclar sus latencias.

No acredita calidad general, una puntuación oficial, comparación causal entre configuraciones, rendimiento en texto natural largo, estabilidad prolongada, ausencia de paginación/throttling, loglikelihood arbitraria ni evaluación de visión o modo thinking. La suite de código solo se leyó estáticamente; no hubo ejecución ni pass@1. Los 352 archivos históricos fueron preservados por hash.

## Evidencia

- [Informe de recuperación fase 2B](phase2b-recovery-20261015.md): detalle de las sesiones independientes, métricas, límites, costes y validación agregada.
- [Informe del run parcial original](phase2b-20261014.md): contexto de la parada por RAM, resultados de calidad preservados y límites del run monolítico.
- [Informe piloto fase 2A](phase2a-20261014.md): desarrollo, metodología y resultados piloto.
- [Validación agregada](../results/recovery-checks-20261015/aggregate-validation.json) y [resumen de rendimiento](../results/recovery-performance-20261015-v2/summary.json).
- [Resumen sostenido](../results/recovery-sustained-20261015-v1/summary.json) y [resumen de calidad conservado](../results/reduced-20261014-reference-v1/summary.json).
- [Paquete de revisión humana de siete rúbricas](human-review-rubrics-20261015.md): prompts, respuestas literales, rúbricas originales y hashes; decisiones aún vacías.

## Decisión de alcance pendiente

**A. Aceptar el cierre técnico de fase 2 dentro del alcance reducido de texto aquí descrito.** Se cerraría con los límites anteriores y la revisión humana de siete rúbricas aún explícitamente pendiente; no equivaldría a benchmark oficial ni autorizaría optimización.

**B. Autorizar una ampliación concreta antes de cerrar la fase 2.** Añadir una evaluación generativa de GSM8K: comprobar fuente, revisión y licencia; fijar selección, protocolo compatible con la API, extracción y criterios antes de inferir; mantener resultados separados; y documentar costes y limitaciones. Elegir B autoriza este alcance, no optimización ni otras suites.

No se ha elegido ninguna opción. La investigación de la deriva de velocidad (−18,4%) sería otro encargo concreto y no forma parte de B.
