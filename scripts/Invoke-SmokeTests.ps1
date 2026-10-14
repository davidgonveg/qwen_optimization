#requires -Version 7.4
[CmdletBinding()]
param([string]$RunId = ('smoke-' + (Get-Date -Format 'yyyyMMdd-HHmmss')))
$ErrorActionPreference = 'Stop'
if ($RunId -notmatch '^[a-zA-Z0-9_-]+$') { throw 'RunId no válido.' }
$root = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $root "results/$RunId"
if (Test-Path -LiteralPath $outDir) { throw 'El directorio de resultados ya existe; usar otro RunId para conservar la referencia.' }
$config = Get-Content (Join-Path $root 'configs/reference.json') -Raw | ConvertFrom-Json
$prompts = Get-Content (Join-Path $root 'configs/smoke-prompts.json') -Raw | ConvertFrom-Json
$version = Invoke-RestMethod "$($config.base_url)/api/version"
$tags = Invoke-RestMethod "$($config.base_url)/api/tags"
$model = $tags.models | Where-Object name -eq $config.model
if ($version.version -ne $config.ollama_version -or ('sha256:' + ($model.digest -replace '^sha256:', '')) -ne $config.expected_digest) { throw 'Versión o digest distintos de la referencia.' }
$serverRecord = Get-Content (Join-Path $root 'runtime/server.json') -Raw | ConvertFrom-Json
$listener = Get-NetTCPConnection -State Listen -LocalPort 11435
if ($listener.OwningProcess -ne $serverRecord.pid) { throw 'Instancia no reconocida.' }
New-Item -ItemType Directory $outDir | Out-Null
Copy-Item (Join-Path $root 'configs/reference.json') (Join-Path $outDir 'config.json')
Copy-Item (Join-Path $root 'configs/smoke-prompts.json') (Join-Path $outDir 'prompts.json')
@{started_at=[DateTime]::UtcNow.ToString('o');code_revision=(& git -C $root rev-parse HEAD);working_tree_status=@(& git -C $root status --porcelain);script_hashes=@(Get-ChildItem $PSScriptRoot -Filter '*.ps1' | Get-FileHash -Algorithm SHA256 | Select-Object Path,Hash);powershell=$PSVersionTable.PSVersion.ToString();server=$serverRecord;tags=$tags;ps_before=(Invoke-RestMethod "$($config.base_url)/api/ps");notes='Pruebas de funcionamiento, una muestra por área; sin ejecución del código generado. TTFT medido hasta primer fragmento no vacío, no token individual. CPU acumulada: unidades de 100 ns de Win32_Process. RAM del sistema: KiB. GPU: alcance total del dispositivo.'} | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outDir 'run.json') -Encoding utf8
$show = Invoke-RestMethod "$($config.base_url)/api/show" -Method Post -ContentType 'application/json' -Body (@{model=$config.model} | ConvertTo-Json)
$show | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $outDir 'show.json') -Encoding utf8
$stopPath = Join-Path $outDir 'telemetry.stop'
$telemetry = Start-ThreadJob -FilePath (Join-Path $PSScriptRoot 'Measure-ProjectResources.ps1') -ArgumentList (Join-Path $outDir 'telemetry.jsonl'),$stopPath,$serverRecord.pid
$client = [Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds($config.request_timeout_seconds)
$metrics = @()
try {
    foreach ($prompt in $prompts) {
        $request = @{model=$config.model;messages=@(@{role='user';content=$prompt.prompt});stream=$true;think=$config.think;keep_alive=$config.keep_alive;options=$config.options}
        $requestJson = $request | ConvertTo-Json -Depth 10
        $requestJson | Set-Content (Join-Path $outDir "$($prompt.id)-request.json") -Encoding utf8
        $streamWriter = [IO.StreamWriter]::new((Join-Path $outDir "$($prompt.id)-stream.jsonl"), $false, [Text.UTF8Encoding]::new($false))
        $streamWriter.AutoFlush = $true
        $body = [Net.Http.StringContent]::new($requestJson, [Text.Encoding]::UTF8, 'application/json')
        $httpRequest = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, "$($config.base_url)/api/chat")
        $httpRequest.Content = $body
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $cancellation = [Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($config.request_timeout_seconds))
        $firstChunk = $null; $firstContent = $null; $firstThinking = $null; $final = $null
        $content = [Text.StringBuilder]::new(); $thinking = [Text.StringBuilder]::new()
        $errorText = $null; $httpResponse = $null; $reader = $null
        try {
            Write-Output "Iniciando $($prompt.id)..."
            $httpResponse = $client.SendAsync($httpRequest, [Net.Http.HttpCompletionOption]::ResponseHeadersRead, $cancellation.Token).GetAwaiter().GetResult()
            $httpResponse.EnsureSuccessStatusCode() | Out-Null
            $stream = $httpResponse.Content.ReadAsStreamAsync($cancellation.Token).GetAwaiter().GetResult()
            $reader = [IO.StreamReader]::new($stream)
            while ($true) {
                $line = $reader.ReadLineAsync($cancellation.Token).GetAwaiter().GetResult()
                if ($null -eq $line) { break }
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                $elapsed = $watch.Elapsed.TotalSeconds
                if ($null -eq $firstChunk) { $firstChunk = $elapsed }
                $chunk = $line | ConvertFrom-Json
                $streamWriter.WriteLine((@{client_elapsed_seconds=$elapsed;response=$chunk} | ConvertTo-Json -Depth 20 -Compress))
                if ($chunk.error) { throw $chunk.error }
                if ($chunk.message.content) {
                    if ($null -eq $firstContent) { $firstContent = $elapsed }
                    $content.Append($chunk.message.content) | Out-Null
                }
                if ($chunk.message.thinking) {
                    if ($null -eq $firstThinking) { $firstThinking = $elapsed }
                    $thinking.Append($chunk.message.thinking) | Out-Null
                }
                if ($chunk.done) { $final = $chunk; break }
            }
            if ($null -eq $final) { throw 'Stream incompleto, sin done=true.' }
        } catch { $errorText = $_.Exception.Message }
        finally {
            $watch.Stop(); $streamWriter.Dispose()
            if ($reader) { $reader.Dispose() }
            if ($httpResponse) { $httpResponse.Dispose() }
            $httpRequest.Dispose(); $cancellation.Dispose()
        }
        $content.ToString() | Set-Content (Join-Path $outDir "$($prompt.id)-response.txt") -Encoding utf8
        $thinking.ToString() | Set-Content (Join-Path $outDir "$($prompt.id)-thinking.txt") -Encoding utf8
        $speed = $null; $promptSpeed = $null
        if ($final.eval_duration -gt 0) { $speed = $final.eval_count / ($final.eval_duration / 1e9) }
        if ($final.prompt_eval_duration -gt 0) { $promptSpeed = $final.prompt_eval_count / ($final.prompt_eval_duration / 1e9) }
        $metric = @{id=$prompt.id;client_total_seconds=$watch.Elapsed.TotalSeconds;first_chunk_seconds=$firstChunk;first_content_seconds=$firstContent;first_thinking_seconds=$firstThinking;tokens_per_second=$speed;prompt_tokens_per_second=$promptSpeed;final=$final;error=$errorText;content_characters=$content.Length;thinking_characters=$thinking.Length;ps_after=(Invoke-RestMethod "$($config.base_url)/api/ps")}
        $metrics += $metric
        $metric | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $outDir "$($prompt.id)-metrics.json") -Encoding utf8
        Write-Output "$($prompt.id): $($watch.Elapsed.TotalSeconds.ToString('F2')) s; error=$errorText"
    }
} finally {
    $client.Dispose()
    New-Item -ItemType File $stopPath | Out-Null
    $telemetry | Wait-Job -Timeout 10 | Out-Null
    $telemetry | Receive-Job | Out-String | Set-Content (Join-Path $outDir 'telemetry-job.txt') -Encoding utf8
    if ($telemetry.State -ne 'Completed') { $telemetry | Stop-Job }
    $telemetry | Remove-Job
    $metrics | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $outDir 'metrics.json') -Encoding utf8
}
if ($metrics.Count -ne 4 -or @($metrics | Where-Object { $_.error -or $_.final.done_reason -ne 'stop' -or $_.content_characters -eq 0 }).Count -gt 0) { throw "Alguna prueba falló o se truncó. Consultar $outDir." }
Write-Output "Cuatro respuestas completas guardadas en $outDir. Revisar su contenido manualmente."
