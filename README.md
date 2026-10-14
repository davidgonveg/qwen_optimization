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
