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
