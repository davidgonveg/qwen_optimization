# Qwen Optimization

Proyecto personal para aprender a ejecutar y optimizar un modelo Qwen de 27B en este PC, midiendo el equilibrio entre capacidades, velocidad y consumo de recursos.

- [Guía y hoja de ruta](PROJECT_GUIDE.md): objetivos, fases, métricas y criterios de éxito.
- [Instrucciones para Codex](AGENTS.md): reglas permanentes de trabajo en este directorio.
- [Prompt de inicio](START_PROMPT.md): texto para iniciar la puesta en marcha en otra sesión.
- [Estado actual](PROJECT_STATUS.md): evidencia, decisiones y pendientes.
- [Prompt siguiente](NEXT_PROMPT.md): encargo vigente para la próxima conversación.

Flujo de trabajo: leer documentos → ejecutar el prompt → actualizar guía y estado → generar el siguiente prompt → revisar y comprobar → Git commit y Git push a la rama vigente.

El estado operativo y sus evidencias se mantienen en [PROJECT_STATUS.md](PROJECT_STATUS.md). La configuración fijada de Qwen3.8-27B está en [configs/reference.json](configs/reference.json).

## Uso local en PowerShell 7

Desde `E:\Documents\qwen_optimization`, con Ollama **0.40.3** disponible:

```powershell
./scripts/Start-ProjectOllama.ps1
# Solo si faltan los pesos; comprueba que la etiqueta remota conserva el digest.
./scripts/Pull-Reference.ps1
./scripts/Invoke-SmokeTests.ps1
./scripts/Stop-ProjectOllama.ps1
```

La instancia escucha exclusivamente en `127.0.0.1:11435`, guarda pesos en `models/ollama` y logs en `runtime`. Las variables se aplican al proceso hijo y se restauran en el proceso que lo lanza; no cambian las variables del usuario ni el servicio habitual de Ollama en 11434. Cada repetición de pruebas crea un directorio nuevo para conservar los resultados anteriores. No se instala Python: esta fase usa PowerShell, .NET, `curl.exe` y `nvidia-smi` existentes.

Las cuatro pruebas son una comprobación de funcionamiento. El código generado se guarda como texto y se revisa sin ejecutarlo. Consultar [el informe de fase 1](reports/phase1-20261014.md) para resultados y límites.

## Piloto de benchmarks (fase 2A)

El [protocolo](benchmarks/PROTOCOL.md), la [suite personal](benchmarks/pilot-v1.json) y las [condiciones de rendimiento](configs/pilot-v1.json) se fijan antes de generar. No es una puntuación oficial ni cierra la fase 2. Conserva la configuración de referencia y los resultados de fase 1.

```powershell
./scripts/Test-BenchmarkScoring.ps1
./scripts/Start-ProjectOllama.ps1
try {
    # RunId nuevo; exige modelo no residente en la instancia del proyecto.
    ./scripts/Invoke-BenchmarkPilot.ps1 -RunId pilot-MI-NUEVA-EJECUCION
    ./scripts/Test-BenchmarkArtifacts.ps1 -RunId pilot-MI-NUEVA-EJECUCION
} finally {
    ./scripts/Stop-ProjectOllama.ps1
}
# Leer q08/q09/q10 como texto y registrar criterios, evidencias y revisor
# en results/<RunId>/manual-review.json antes del resumen, si se desea incluirlo.
./scripts/Summarize-BenchmarkPilot.ps1 -RunId pilot-MI-NUEVA-EJECUCION
```

El runner envía 23 peticiones secuenciales: compatibilidad/carga, diez tareas de calidad y dos bloques de calentamiento + cinco mediciones. Guarda una copia del protocolo, peticiones, streams crudos con reloj monotónico, respuestas, contadores, errores, inventario y telemetría. En caso de error conserva parciales y aborta sin reintentos. El resumen tampoco sobrescribe uno existente. La revisión de código es estática; nunca ejecutar ni importar los archivos generados.

La carga no residente conserva la caché de disco del sistema. Los bloques de prefijo variable y repetido son intenciones de caché: consultar `prompt_eval_cached_count` antes de afirmar reutilización. El p95 con cinco mediciones es el máximo, solo orientativo. Las tareas personales son de desarrollo; la evaluación final deberá usar muestras nuevas. El resumen separa puntuación automática, revisión asistida y recursos de la GPU completa. No mide energía del PC ni paginación.

Resultado conservado: [informe de fase 2A](reports/phase2a-20261014.md), con evidencia en `results/pilot-20261014-reference-v1`. No se instaló Python ni se ajustó el runtime.

## Referencia reducida (fase 2B)

Suite de 22 tareas nuevas en [reduced-v1](benchmarks/reduced-v1.json), protocolo previo en [PROTOCOL-2B.md](benchmarks/PROTOCOL-2B.md) y condiciones/límites en [configs/reduced-v1.json](configs/reduced-v1.json). Mantiene intacta la referencia. 18 puntuaciones estrictas y cuatro rúbricas asistidas separadas; sin datasets externos ni código ejecutado.

```powershell
./scripts/Test-BenchmarkScoring.ps1
./scripts/Test-BenchmarkSchedule.ps1
# Gestiona arranque/parada propios; RunId siempre nuevo.
./scripts/Invoke-ReducedReference.ps1 -RunId reduced-MI-NUEVA-EJECUCION
# Leer respuestas y documentar revisión asistida con hashes y rúbricas.
./scripts/Summarize-BenchmarkPilot.ps1 -RunId reduced-MI-NUEVA-EJECUCION -ExpectedPerformanceResponse Oviedo
./scripts/Test-BenchmarkArtifacts.ps1 -RunId reduced-MI-NUEVA-EJECUCION
# Regresión sin inferencia, fuera del directorio histórico:
./scripts/Test-BenchmarkArtifacts.ps1 -RunId pilot-20261014-reference-v1 -ValidationPath results/MI-REGRESION-NUEVA.json
```

El runner configurable conserva el comando original de fase 2A. El perfil 2B envía carga, 22 tareas, dos calentamientos y seis medidas por longitud (37 peticiones fijas), seguidos de candidatos sostenidos hasta 180 s, con límite duro de 210 s. El orden corto/largo y largo/corto se alterna; se comprueban rangos de tokens reales. Padding repetitivo y recuperación de una ciudad no prueban comprensión de contexto natural.

El monitor cancela ante RAM libre <1,5 GiB, VRAM libre <384 MiB, GPU >=80 °C o dos errores consecutivos de sensores. Las cancelaciones y fallos conservan parciales; no hay reintentos ni adaptación de parámetros. El wrapper descarga/detiene exclusivamente la instancia propia y comprueba servicio/modelos habituales. Un resumen o validación existente no se sobrescribe; indicar una nueva ruta `-ValidationPath` para una nueva comprobación.

Ejecución del 14 de octubre: [informe de fase 2B](reports/phase2b-20261014.md), evidencia `results/reduced-20261014-reference-v1`. **Incompleta por parada de RAM**, con las 22 tareas de calidad terminadas; faltan repeticiones y carga sostenida. Para auditar parciales usar `Test-BenchmarkArtifacts.ps1 -AllowPartial` y ruta nueva: informa integridad parcial y nunca cierre. Los datos no observados siguen en null; no usar una única medición por longitud como percentiles de referencia. El siguiente prompt prioriza recuperación sin ajustar parámetros.

## Recuperación de fase 2B con sesiones separadas

[Protocolo previo](benchmarks/PROTOCOL-2B-RECOVERY.md) e [informe del 15 de octubre](reports/phase2b-recovery-20261015.md). Se conserva calidad del run original y se miden rendimiento/sostenido en dos procesos nuevos. No agrupar sus latencias con las de la sesión monolítica. Cada sesión exige margen previo y mantiene todas las opciones y paradas de seguridad.

La instalación habitual pasó a 0.40.4 fuera del ensayo. La referencia usa el ZIP portátil oficial **0.40.3** en `runtime/ollama-v0.40.3`, sin modificar el servicio habitual. Procedencia, digest del ZIP y hashes de archivos en `results/recovery-checks-20261015/portable-runtime-verified.json`. Para recuperarlo si falta, descargar [el ZIP oficial v0.40.3](https://github.com/ollama/ollama/releases/download/v0.40.3/ollama-windows-amd64.zip), comprobar tamaño 1468053171 y SHA-256 `e5ecff02dfc7cae8ddf6d6b7a7ac5f727ffeedf4491f44ae75ff5b0820dbbbd5` antes de extraerlo a esa ruta. No usar el instalador global ni cambiar el runtime de la referencia.

```powershell
./scripts/Test-RecoveryProtocol.ps1
# Solo cuando se autorice otra repetición; RunIds nuevos en cada sesión.
./scripts/Invoke-RecoverySession.ps1 -RunId recovery-performance-NUEVO -Block performance
./scripts/Summarize-BenchmarkPilot.ps1 -RunId recovery-performance-NUEVO -ExpectedPerformanceResponse Oviedo
./scripts/Test-BenchmarkArtifacts.ps1 -RunId recovery-performance-NUEVO
./scripts/Invoke-RecoverySession.ps1 -RunId recovery-sustained-NUEVO -Block sustained
./scripts/Summarize-BenchmarkPilot.ps1 -RunId recovery-sustained-NUEVO
./scripts/Test-BenchmarkArtifacts.ps1 -RunId recovery-sustained-NUEVO
```

`Analyze-RecoveryMemory.ps1 -RunId ...` extrae caché del log y alinea RAM con fin de petición; no mide paginación. `Test-RecoveryArtifacts.ps1` audita el conjunto específico del 15 de octubre, incluidos hashes históricos, calidad reutilizada, configuración, scripts, runtime, umbrales y servicio habitual; produce el cierre **agregado** de fase 2B. Una validación individual de sesión nunca cierra la fase. Preparación/fuentes y auditoría del 15 de octubre usan rutas de evidencia fijas: no sobrescribirlas al repetir; utilizar rutas nuevas para futuras auditorías.

Para arranque manual del runtime fijado: `./scripts/Start-ProjectOllama.ps1 -ExecutablePath ./runtime/ollama-v0.40.3/ollama.exe`. La parada protege identidad/puerto y detiene solo la instancia del proyecto.
