#requires -Version 7.4
[CmdletBinding()]
param([string]$RunId=('pilot-'+(Get-Date -Format 'yyyyMMdd-HHmmss')))
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
if ($RunId -notmatch '^[a-zA-Z0-9_-]+$') { throw 'RunId no válido' }
$root=Split-Path $PSScriptRoot -Parent
$outDir=Join-Path $root "results/$RunId"
if (Test-Path -LiteralPath $outDir) { throw 'Resultados existentes; usar otro RunId' }
$config=Get-Content (Join-Path $root 'configs/reference.json') -Raw | ConvertFrom-Json
$protocol=Get-Content (Join-Path $root 'configs/pilot-v1.json') -Raw | ConvertFrom-Json
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
Copy-Item (Join-Path $root 'configs/pilot-v1.json') (Join-Path $outDir 'protocol.json')
Copy-Item (Join-Path $root $protocol.suite) (Join-Path $outDir 'suite.json')
Copy-Item (Join-Path $root 'benchmarks/PROTOCOL.md') (Join-Path $outDir 'PROTOCOL.md')
$files=@(Get-ChildItem $PSScriptRoot -Filter '*.ps1')+@(Get-Item (Join-Path $root 'configs/reference.json'),(Join-Path $root 'configs/pilot-v1.json'),(Join-Path $root $protocol.suite),(Join-Path $root 'benchmarks/PROTOCOL.md'))
Write-BenchmarkJson @{started_at=[DateTime]::UtcNow.ToString('o');code_revision=(& git -C $root rev-parse HEAD);working_tree_status=@(& git -C $root status --porcelain);hashes=@($files | Get-FileHash | Select-Object Path,Hash);powershell=$PSVersionTable.PSVersion.ToString();dotnet=[System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription;server=$record;tags=$tags;version=$version;ps_before=$psBefore;manifest_original_sha256=$config.expected_digest;layer_sizes_verified=$true;weights_rehashed=$false} (Join-Path $outDir 'run.json')
Write-BenchmarkJson @{captured_at=[DateTime]::UtcNow.ToString('o');global_tags=(Invoke-RestMethod 'http://127.0.0.1:11434/api/tags');global_ps=(Invoke-RestMethod 'http://127.0.0.1:11434/api/ps');os=(Get-CimInstance Win32_OperatingSystem | Select-Object Version,TotalVisibleMemorySize,FreePhysicalMemory);cpu=(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors);gpu=@(& nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used,temperature.gpu,power.draw --format=csv);gpu_processes=@(& nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv);disk=(Get-PSDrive E | Select-Object Used,Free)} (Join-Path $outDir 'inventory-before.json')
Write-BenchmarkJson (Invoke-RestMethod "$($config.base_url)/api/show" -Method Post -ContentType 'application/json' -Body (@{model=$config.model}|ConvertTo-Json)) (Join-Path $outDir 'show.json')
$stopPath=Join-Path $outDir 'telemetry.stop'
$telemetry=Start-ThreadJob -FilePath (Join-Path $PSScriptRoot 'Measure-ProjectResources.ps1') -ArgumentList (Join-Path $outDir 'telemetry.jsonl'),$stopPath,$record.pid
$client=[Net.Http.HttpClient]::new(); $client.Timeout=[TimeSpan]::FromSeconds($config.request_timeout_seconds)
$metrics=[Collections.Generic.List[object]]::new(); $scores=[Collections.Generic.List[object]]::new(); $fatal=$null
try {
    $samples=[Collections.Generic.List[object]]::new()
    $samples.Add(@{id='compatibility-nonresident';kind='compatibility';condition='nonresident-disk-cache-uncontrolled';prompt='Responde únicamente: listo';logprobs=$true})
    foreach ($task in $suite.tasks) { $samples.Add(@{id=$task.id;kind='quality';condition='resident-quality';prompt=$task.prompt;task=$task}) }
    foreach ($condition in $protocol.conditions) {
        for ($i=0;$i -le $protocol.repetitions;$i++) {
            $nonce=$condition.nonces[$i]
            $samples.Add(@{id=($condition.id+'-'+$i);kind=$(if ($i -eq 0) {'warmup'} else {'performance'});condition=$condition.id;repetition=$i;nonce=$nonce;prompt=($protocol.prefix_template.Replace('{nonce}',$nonce)+$protocol.performance_prompt)})
        }
    }
    Write-BenchmarkJson @($samples) (Join-Path $outDir 'schedule.json')
    foreach ($sample in $samples) {
        Write-Output "Iniciando $($sample.id) [$($sample.kind)]"
        $request=@{model=$config.model;messages=@(@{role='user';content=$sample.prompt});stream=$true;think=$config.think;keep_alive=$config.keep_alive;options=$config.options}
        if ($sample.logprobs) { $request.logprobs=$true; $request.top_logprobs=1 }
        $metric=Invoke-BenchmarkRequest $client $config $outDir $sample $request
        $metrics.Add($metric)
        Write-BenchmarkJson @($metrics) (Join-Path $outDir 'metrics.json')
        if ($sample.kind -eq 'quality') {
            $score=Get-QualityScore $sample.task ([IO.File]::ReadAllText((Join-Path $outDir "$($sample.id)-response.txt"))) $metric
            $scores.Add(@{id=$sample.id;area=$sample.task.area;scorer=$sample.task.scorer;score=$score})
            Write-BenchmarkJson @($scores) (Join-Path $outDir 'quality-scores.json')
        }
        Write-Output "$($sample.id): $($metric.client_total_seconds.ToString('F2')) s; cache=$($metric.final.prompt_eval_cached_count); tokens=$($metric.final.eval_count); error=$($metric.error)"
        if ($metric.error) { throw "Petición fallida: $($sample.id). No se continúa automáticamente." }
    }
} catch { $fatal=$_.Exception.Message }
finally {
    $client.Dispose()
    New-Item -ItemType File $stopPath | Out-Null
    $telemetry | Wait-Job -Timeout 10 | Out-Null
    $telemetry | Receive-Job | Out-String | Set-Content (Join-Path $outDir 'telemetry-job.txt') -Encoding utf8
    $telemetryState=$telemetry.State.ToString()
    if ($telemetry.State -ne 'Completed') { $telemetry | Stop-Job }
    $telemetry | Remove-Job
    Copy-Item (Join-Path $root 'runtime/server.stderr.log') (Join-Path $outDir 'runtime-inference.log')
    Write-BenchmarkJson @{finished_at=[DateTime]::UtcNow.ToString('o');fatal_error=$fatal;requests_completed=$metrics.Count;expected_requests=23;telemetry_state=$telemetryState;complete=($null -eq $fatal -and $metrics.Count -eq 23)} (Join-Path $outDir 'run-status.json')
}
if ($fatal) { throw $fatal }
Write-Output "Piloto registrado en $outDir; completar revisión manual y resumen."
