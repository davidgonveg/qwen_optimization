#requires -Version 7.4
[CmdletBinding()]
param([string]$RunId = ('pull-' + (Get-Date -Format 'yyyyMMdd-HHmmss')))
$ErrorActionPreference = 'Stop'
if ($RunId -notmatch '^[a-zA-Z0-9_-]+$') { throw 'RunId no válido.' }
$root = Split-Path $PSScriptRoot -Parent
$config = Get-Content (Join-Path $root 'configs/reference.json') -Raw | ConvertFrom-Json
$outDir = Join-Path $root "results/$RunId"
if (Test-Path (Join-Path $outDir 'pull-request.json')) { throw 'Ya existe una descarga registrada con este RunId; usar otro identificador.' }
New-Item -ItemType Directory -Force $outDir | Out-Null
$remote = Invoke-WebRequest 'https://registry.ollama.ai/v2/library/qwen3.8/manifests/27b' -Headers @{Accept='application/vnd.docker.distribution.manifest.v2+json'}
$bytes = if ($remote.Content -is [byte[]]) { $remote.Content } else { [Text.Encoding]::UTF8.GetBytes($remote.Content) }
$remoteDigest = 'sha256:' + [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
if ($remoteDigest -ne $config.expected_digest) { throw "La etiqueta remota cambió: $remoteDigest. Revisar antes de descargar." }
$version = Invoke-RestMethod "$($config.base_url)/api/version"
if ($version.version -ne $config.ollama_version) { throw 'Versión de Ollama distinta de la referencia.' }
$record = Get-Content (Join-Path $root 'runtime/server.json') -Raw | ConvertFrom-Json
$listener = Get-NetTCPConnection -State Listen -LocalPort 11435
if ($listener.OwningProcess -ne $record.pid -or $record.settings.OLLAMA_MODELS -ne (Join-Path $root 'models/ollama')) { throw 'La instancia no coincide con el almacén del proyecto.' }
$bodyPath = Join-Path $outDir 'pull-request.json'
@{model=$config.model;stream=$true} | ConvertTo-Json | Set-Content $bodyPath -Encoding utf8NoBOM
$started = [DateTime]::UtcNow
& curl.exe --silent --show-error --fail-with-body --max-time 7200 --no-buffer -H 'Content-Type: application/json' --data-binary "@$bodyPath" "$($config.base_url)/api/pull" --output (Join-Path $outDir 'pull-progress.jsonl')
$curlExit = $LASTEXITCODE
$last = Get-Content (Join-Path $outDir 'pull-progress.jsonl') -Tail 1 | ConvertFrom-Json
@{started_at=$started.ToString('o');ended_at=[DateTime]::UtcNow.ToString('o');curl_exit=$curlExit;last=$last} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $outDir 'pull-result.json') -Encoding utf8
if ($curlExit -ne 0 -or $last.status -ne 'success') { throw "Descarga fallida. Consultar $outDir." }
$tags = Invoke-RestMethod "$($config.base_url)/api/tags"
$tags | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $outDir 'tags.json') -Encoding utf8
$model = $tags.models | Where-Object name -eq $config.model
if (('sha256:' + ($model.digest -replace '^sha256:', '')) -ne $config.expected_digest) { throw "Digest descargado inesperado: $($model.digest)" }
$localManifest = Join-Path $root 'models/ollama/manifests/registry.ollama.ai/library/qwen3.8/27b'
$originalBlob = Join-Path $root ('models/ollama/blobs/' + ($config.expected_digest -replace ':', '-'))
if (('sha256:' + (Get-FileHash $originalBlob).Hash.ToLowerInvariant()) -ne $config.expected_digest) { throw 'El blob del manifiesto original no coincide.' }
# Ollama 0.40.3 añade capas de procedencia al archivo local; su hash cambia.
$local = Get-Content $localManifest -Raw | ConvertFrom-Json
$original = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
if ($local.config.digest -ne $original.config.digest) { throw 'Configuración local distinta.' }
foreach ($layer in $original.layers) {
    $match = @($local.layers | Where-Object { $_.digest -eq $layer.digest -and $_.size -eq $layer.size -and $_.mediaType -eq $layer.mediaType })
    if ($match.Count -ne 1) { throw "Capa original ausente o distinta: $($layer.digest)" }
}
Write-Output "Descarga verificada: $($model.name), $($model.digest), $($model.size) bytes."
