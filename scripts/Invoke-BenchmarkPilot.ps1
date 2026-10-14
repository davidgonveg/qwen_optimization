#requires -Version 7.4
[CmdletBinding()]
param([string]$RunId=('pilot-'+(Get-Date -Format 'yyyyMMdd-HHmmss')), [string]$ProtocolPath='configs/pilot-v1.json')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
. (Join-Path $PSScriptRoot 'Benchmark.Schedule.ps1')
if ($RunId -notmatch '^[a-zA-Z0-9_-]+$') { throw 'RunId no válido' }
$root=Split-Path $PSScriptRoot -Parent
$outDir=Join-Path $root "results/$RunId"
if (Test-Path -LiteralPath $outDir) { throw 'Resultados existentes; usar otro RunId' }
$config=Get-Content (Join-Path $root 'configs/reference.json') -Raw | ConvertFrom-Json
$protocol=Get-Content (Join-Path $root $ProtocolPath) -Raw | ConvertFrom-Json
$protocolDocument=if ($protocol.protocol_document) { $protocol.protocol_document } else { 'benchmarks/PROTOCOL.md' }
$suite=Get-Content (Join-Path $root $protocol.suite) -Raw | ConvertFrom-Json -AsHashtable
$record=Get-Content (Join-Path $root 'runtime/server.json') -Raw | ConvertFrom-Json
$process=Get-Process -Id $record.pid
$listener=Get-NetTCPConnection -State Listen -LocalPort 11435
if ($listener.OwningProcess -ne $record.pid -or $process.Path -ne $record.executable -or $process.StartTime.ToUniversalTime() -ne ([datetime]$record.start_time).ToUniversalTime() -or $record.settings.OLLAMA_MODELS -ne (Join-Path $root 'models/ollama')) { throw 'Instancia no reconocida' }
$version=Invoke-RestMethod "$($config.base_url)/api/version"
$tags=Invoke-RestMethod "$($config.base_url)/api/tags"
$model=@($tags.models | Where-Object name -eq $config.model)
if ($model.Count -ne 1 -or $version.version -ne $config.ollama_version -or ('sha256:'+($model[0].digest -replace '^sha256:','')) -ne $config.expected_digest -or $model[0].details.quantization_level -ne $config.quantization) { throw 'Identidad/version/cuantización distinta' }
$originalBlob=Join-Path $root ('models/ollama/blobs/'+($config.expected_digest -replace ':','-'))
if (('sha256:'+(Get-FileHash $originalBlob).Hash.ToLowerInvariant()) -ne $config.expected_digest) { throw 'Manifiesto original distinto' }
$original=Get-Content $originalBlob -Raw | ConvertFrom-Json
$local=Get-Content (Join-Path $root 'models/ollama/manifests/registry.ollama.ai/library/qwen3.8/27b') -Raw | ConvertFrom-Json
if ($local.config.digest -ne $original.config.digest) { throw 'Config de artefacto distinto' }
foreach ($layer in $original.layers) {
    if (@($local.layers | Where-Object { $_.digest -eq $layer.digest -and $_.size -eq $layer.size }).Count -ne 1) { throw 'Capas locales distintas' }
    $blob=Get-Item (Join-Path $root ('models/ollama/blobs/'+($layer.digest -replace ':','-')))
    if ($blob.Length -ne $layer.size) { throw 'Tamaño de capa distinto' }
}
$psBefore=Invoke-RestMethod "$($config.base_url)/api/ps"
if (@($psBefore.models).Count) { throw 'Para observar carga no residente el runner exige instancia propia sin modelos cargados' }
New-Item -ItemType Directory $outDir | Out-Null
Copy-Item (Join-Path $root 'configs/reference.json') (Join-Path $outDir 'config.json')
Copy-Item (Join-Path $root $ProtocolPath) (Join-Path $outDir 'protocol.json')
Copy-Item (Join-Path $root $protocol.suite) (Join-Path $outDir 'suite.json')
Copy-Item (Join-Path $root $protocolDocument) (Join-Path $outDir 'PROTOCOL.md')
$files=@(Get-ChildItem $PSScriptRoot -Filter '*.ps1')+@(Get-Item (Join-Path $root 'configs/reference.json'),(Join-Path $root $ProtocolPath),(Join-Path $root $protocol.suite),(Join-Path $root $protocolDocument))
Write-BenchmarkJson @{started_at=[DateTime]::UtcNow.ToString('o');code_revision=(& git -C $root rev-parse HEAD);working_tree_status=@(& git -C $root status --porcelain);hashes=@($files | Get-FileHash | Select-Object Path,Hash);powershell=$PSVersionTable.PSVersion.ToString();dotnet=[System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription;server=$record;tags=$tags;version=$version;ps_before=$psBefore;manifest_original_sha256=$config.expected_digest;layer_sizes_verified=$true;weights_rehashed=$false} (Join-Path $outDir 'run.json')
Write-BenchmarkJson @{captured_at=[DateTime]::UtcNow.ToString('o');global_tags=(Invoke-RestMethod 'http://127.0.0.1:11434/api/tags');global_ps=(Invoke-RestMethod 'http://127.0.0.1:11434/api/ps');os=(Get-CimInstance Win32_OperatingSystem | Select-Object Version,TotalVisibleMemorySize,FreePhysicalMemory);cpu=(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors);gpu=@(& nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used,temperature.gpu,power.draw --format=csv);gpu_processes=@(& nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv);disk=(Get-PSDrive E | Select-Object Used,Free)} (Join-Path $outDir 'inventory-before.json')
Write-BenchmarkJson (Invoke-RestMethod "$($config.base_url)/api/show" -Method Post -ContentType 'application/json' -Body (@{model=$config.model}|ConvertTo-Json)) (Join-Path $outDir 'show.json')
$stopPath=Join-Path $outDir 'telemetry.stop'
$safetyCancellation=[Threading.CancellationTokenSource]::new()
$readyPath=Join-Path $outDir 'telemetry.ready'
$telemetry=Start-ThreadJob -FilePath (Join-Path $PSScriptRoot 'Measure-ProjectResources.ps1') -ArgumentList (Join-Path $outDir 'telemetry.jsonl'),$stopPath,$record.pid,$protocol.safety,(Join-Path $outDir 'safety-abort.json'),$safetyCancellation,$readyPath,(Join-Path $PSScriptRoot 'Benchmark.Schedule.ps1')
$client=[Net.Http.HttpClient]::new(); $client.Timeout=[TimeSpan]::FromSeconds($config.request_timeout_seconds)
$metrics=[Collections.Generic.List[object]]::new(); $scores=[Collections.Generic.List[object]]::new(); $fatal=$null
$samples=@(Get-BenchmarkSchedule $protocol $suite)
$sustainedSamples=@()
if ($protocol.sustained) {
    $sustainedSamples=@(1..$protocol.sustained.max_requests | ForEach-Object {
        $nonce='sustained-'+$_.ToString('D3')
        @{id=$nonce;kind='sustained';condition='sustained-variable-prefix';repetition=$_;nonce=$nonce;prompt=($protocol.prefix_template.Replace('{nonce}',$nonce)+$protocol.sustained.prompt)}
    })
}
Write-BenchmarkJson $samples (Join-Path $outDir 'schedule.json')
Write-BenchmarkJson $sustainedSamples (Join-Path $outDir 'sustained-candidates.json')
$sustainedStatus=$null
try {
    for ($i=0;$i -lt 100 -and -not (Test-Path $readyPath);$i++) {
        if ($telemetry.State -in @('Failed','Completed')) { throw 'Monitor terminado antes de primera muestra' }
        Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Path $readyPath)) { throw 'Monitor no listo en diez segundos' }
    foreach ($sample in $samples) {
        if ($safetyCancellation.IsCancellationRequested -or $telemetry.State -ne 'Running') { throw 'Monitor cancelado o no activo' }
        Write-Output "Iniciando $($sample.id) [$($sample.kind)]"
        $request=@{model=$config.model;messages=@(@{role='user';content=$sample.prompt});stream=$true;think=$config.think;keep_alive=$config.keep_alive;options=$config.options}
        if ($sample.logprobs) { $request.logprobs=$true; $request.top_logprobs=1 }
        $metric=Invoke-BenchmarkRequest $client $config $outDir $sample $request $safetyCancellation
        $metrics.Add($metric)
        Write-BenchmarkJson @($metrics) (Join-Path $outDir 'metrics.json')
        if ($sample.kind -eq 'quality') {
            $score=Get-QualityScore $sample.task ([IO.File]::ReadAllText((Join-Path $outDir "$($sample.id)-response.txt"))) $metric
            $scores.Add(@{id=$sample.id;area=$sample.task.area;scorer=$sample.task.scorer;score=$score})
            Write-BenchmarkJson @($scores) (Join-Path $outDir 'quality-scores.json')
        }
        Write-Output "$($sample.id): $($metric.client_total_seconds.ToString('F2')) s; cache=$($metric.final.prompt_eval_cached_count); tokens=$($metric.final.eval_count); error=$($metric.error)"
        if ($metric.error) { throw "Petición fallida: $($sample.id). No se continúa automáticamente." }
        if ($protocol.sustained -and ($metric.truncated -or $metric.content_characters -eq 0)) { throw 'Salida truncada/vacía: se aborta referencia reducida' }
        if ($protocol.sustained -and $sample.kind -in @('warmup','performance')) {
            $condition=$protocol.conditions | Where-Object id -eq $sample.condition
            if ($null -eq $metric.final.prompt_eval_count -or $metric.final.prompt_eval_count -lt $condition.min_tokens -or $metric.final.prompt_eval_count -gt $condition.max_tokens -or ($metric.final.prompt_eval_count+$config.options.num_predict) -gt $config.options.num_ctx) { throw "Entrada fuera de rango/contexto: $($sample.id)" }
        }
    }
    if ($protocol.sustained) {
        $sustainedWatch=[Diagnostics.Stopwatch]::StartNew()
        $sustainedStatus=@{started_at=[DateTime]::UtcNow.ToString('o');target_seconds=$protocol.sustained.target_seconds;hard_limit_seconds=$protocol.sustained.hard_limit_seconds;complete=$false;requests=0;elapsed_seconds=0;stop_reason='running'}
        Write-BenchmarkJson $sustainedStatus (Join-Path $outDir 'sustained-status.json')
        foreach ($sample in $sustainedSamples) {
            if ($sustainedWatch.Elapsed.TotalSeconds -ge $protocol.sustained.target_seconds) { break }
            if ($safetyCancellation.IsCancellationRequested -or $telemetry.State -ne 'Running') { throw 'Monitor cancelado o no activo' }
            $remaining=$protocol.sustained.hard_limit_seconds-$sustainedWatch.Elapsed.TotalSeconds
            if ($remaining -le 0) { throw 'Límite duro sostenido' }
            Write-Output "Iniciando $($sample.id) [sustained]"
            $request=@{model=$config.model;messages=@(@{role='user';content=$sample.prompt});stream=$true;think=$config.think;keep_alive=$config.keep_alive;options=$config.options}
            $metric=Invoke-BenchmarkRequest $client $config $outDir $sample $request $safetyCancellation ([Math]::Min($remaining,$config.request_timeout_seconds))
            $metrics.Add($metric)
            Write-BenchmarkJson @($metrics) (Join-Path $outDir 'metrics.json')
            $sustainedStatus.requests++
            $sustainedStatus.elapsed_seconds=$sustainedWatch.Elapsed.TotalSeconds
            Write-BenchmarkJson $sustainedStatus (Join-Path $outDir 'sustained-status.json')
            Write-Output "$($sample.id): $($metric.client_total_seconds.ToString('F2')) s; tokens=$($metric.final.eval_count); error=$($metric.error)"
            if ($metric.error -or $metric.truncated -or $metric.content_characters -eq 0) { throw "Fallo sostenido: $($sample.id)" }
        }
        $sustainedStatus.complete=$sustainedWatch.Elapsed.TotalSeconds -ge $protocol.sustained.target_seconds -and $sustainedWatch.Elapsed.TotalSeconds -le $protocol.sustained.hard_limit_seconds -and -not $safetyCancellation.IsCancellationRequested
        $sustainedStatus.stop_reason=if ($sustainedStatus.complete) { 'target_reached' } else { 'request_cap_or_limit' }
        if (-not $sustainedStatus.complete) { throw 'Carga sostenida no completó objetivo dentro de límites' }
    }
} catch { $fatal=$_.Exception.Message }
finally {
    if ($sustainedStatus) {
        $sustainedStatus.elapsed_seconds=$sustainedWatch.Elapsed.TotalSeconds
        $sustainedStatus.ended_at=[DateTime]::UtcNow.ToString('o')
        if ($fatal) { $sustainedStatus.complete=$false; $sustainedStatus.stop_reason=$fatal }
        Write-BenchmarkJson $sustainedStatus (Join-Path $outDir 'sustained-status.json')
    }
    $client.Dispose()
    New-Item -ItemType File $stopPath | Out-Null
    $telemetry | Wait-Job -Timeout 10 | Out-Null
    $telemetry | Receive-Job | Out-String | Set-Content (Join-Path $outDir 'telemetry-job.txt') -Encoding utf8
    $telemetryState=$telemetry.State.ToString()
    if ($telemetry.State -ne 'Completed') { $telemetry | Stop-Job }
    $telemetry | Remove-Job
    Copy-Item (Join-Path $root 'runtime/server.stderr.log') (Join-Path $outDir 'runtime-inference.log')
    $expected=$samples.Count+$(if ($sustainedStatus) {$sustainedStatus.requests} else {0})
    Write-BenchmarkJson @{finished_at=[DateTime]::UtcNow.ToString('o');fatal_error=$fatal;requests_completed=$metrics.Count;fixed_requests=$samples.Count;expected_requests=$expected;telemetry_state=$telemetryState;complete=($null -eq $fatal -and $metrics.Count -eq $expected -and $telemetryState -eq 'Completed');safety_cancelled=$safetyCancellation.IsCancellationRequested;sustained=$sustainedStatus} (Join-Path $outDir 'run-status.json')
    $safetyCancellation.Dispose()
}
if ($fatal) { throw $fatal }
Write-Output "Piloto registrado en $outDir; completar revisión manual y resumen."
