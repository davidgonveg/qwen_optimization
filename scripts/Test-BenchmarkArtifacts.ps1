#requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$RunId, [string]$ValidationPath='', [switch]$AllowPartial)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
. (Join-Path $PSScriptRoot 'Benchmark.Schedule.ps1')
if ($RunId -notmatch '^[a-zA-Z0-9_-]+$') { throw 'RunId inválido' }
$root=Split-Path $PSScriptRoot -Parent; $outDir=Join-Path $root "results/$RunId"
$config=Get-Content (Join-Path $outDir 'config.json') -Raw | ConvertFrom-Json -AsHashtable
$suite=Get-Content (Join-Path $outDir 'suite.json') -Raw | ConvertFrom-Json -AsHashtable
$metrics=@(Get-Content (Join-Path $outDir 'metrics.json') -Raw | ConvertFrom-Json -AsHashtable)
$scores=@(Get-Content (Join-Path $outDir 'quality-scores.json') -Raw | ConvertFrom-Json -AsHashtable)
$schedule=@(Get-Content (Join-Path $outDir 'schedule.json') -Raw | ConvertFrom-Json -AsHashtable)
$status=Get-Content (Join-Path $outDir 'run-status.json') -Raw | ConvertFrom-Json
$protocol=Get-Content (Join-Path $outDir 'protocol.json') -Raw | ConvertFrom-Json
$expectedSchedule=@(Get-BenchmarkSchedule $protocol $suite)
if (-not $ValidationPath) { $ValidationPath=Join-Path $outDir 'validation.json' }
if (Test-Path -LiteralPath $ValidationPath) { throw 'Validación existente; indicar ruta nueva para preservar evidencia' }
if (-not $AllowPartial -and -not $status.complete) { throw 'Ejecución incompleta: no constituye referencia cerrada' }
if ($metrics.Count -ne $status.requests_completed -or $schedule.Count -ne $expectedSchedule.Count -or -not (Test-JsonValue $schedule $expectedSchedule)) { throw 'Schedule/recuento incoherente' }
$qualityMetrics=@($metrics | Where-Object {$_.sample.kind -eq 'quality'})
$expectedQuality=if ($protocol.reuse_quality_run) {0} else {$suite.tasks.Count}
if ($scores.Count -ne $qualityMetrics.Count -or (-not $AllowPartial -and ($metrics.Count -ne $status.expected_requests -or $scores.Count -ne $expectedQuality))) { throw 'Recuentos incompletos/incoherentes' }
if (@($metrics.sample.id | Sort-Object -Unique).Count -ne $metrics.Count) { throw 'IDs duplicados' }
for ($i=0;$i -lt [Math]::Min($metrics.Count,$schedule.Count);$i++) { if (-not (Test-JsonValue $metrics[$i].sample $schedule[$i])) { throw 'Orden/muestra distinto de schedule' } }
if ($protocol.sustained -and $protocol.session_block -ne 'performance') {
    $sustained=@($metrics | Where-Object {$_.sample.kind -eq 'sustained'})
    $candidates=@(Get-Content (Join-Path $outDir 'sustained-candidates.json') -Raw | ConvertFrom-Json -AsHashtable)
    if (-not $AllowPartial -and (-not $status.sustained.complete -or $status.sustained.elapsed_seconds -lt $protocol.sustained.target_seconds -or $status.sustained.elapsed_seconds -gt $protocol.sustained.hard_limit_seconds -or $sustained.Count -ne $status.sustained.requests -or $sustained.Count -gt $protocol.sustained.max_requests -or (Test-Path (Join-Path $outDir 'safety-abort.json')))) { throw 'Sostenido incompleto/límites excedidos' }
    for ($i=0;$i -lt $sustained.Count;$i++) { if (-not (Test-JsonValue $sustained[$i].sample $candidates[$i])) { throw 'Candidato sostenido cambiado' } }
}
$summaryPath=Join-Path $outDir 'summary.json'
if (Test-Path $summaryPath) {
    $summary=Get-Content $summaryPath -Raw | ConvertFrom-Json
    if ($summary.telemetry.error_samples -eq 0 -and $summary.telemetry.errors.Count -ne 0) { throw 'Resumen: lista vacía de errores serializada incorrectamente' }
    foreach ($condition in $summary.performance) {
        $values=@($condition.samples.total_seconds | Sort-Object)
        $valid=@($metrics | Where-Object {$_.sample.condition -eq $condition.id -and $_.sample.kind -eq 'performance' -and -not $_.error -and $_.final.done -and $_.final.done_reason -eq 'stop' -and $_.content_characters -gt 0})
        $values=@($valid.client_total_seconds | Sort-Object)
        if ($values.Count -gt 0 -and ($condition.total_seconds.p50 -ne $values[[int][Math]::Ceiling(0.5*$values.Count)-1] -or $condition.total_seconds.p95 -ne $values[[int][Math]::Ceiling(0.95*$values.Count)-1])) { throw 'Percentiles distintos de nearest-rank' }
    }
}
$manualPath=Join-Path $outDir 'manual-review.json'
if (Test-Path $manualPath) {
    $review=Get-Content $manualPath -Raw | ConvertFrom-Json
    foreach ($taskReview in $review.tasks) {
        $task=@($suite.tasks | Where-Object id -eq $taskReview.id)
        if ($task.Count -ne 1 -or $task[0].scorer -ne 'manual' -or $taskReview.criteria.Count -ne $task[0].rubric.Count -or (Get-FileHash (Join-Path $outDir "$($taskReview.id)-response.txt")).Hash.ToLowerInvariant() -ne $taskReview.response_sha256) { throw 'Revisión sin respuesta/rúbrica identificada' }
    }
}
foreach ($metric in $metrics) {
    $id=$metric.sample.id
    $request=Get-Content (Join-Path $outDir "$id-request.json") -Raw | ConvertFrom-Json -AsHashtable
    if (-not (Test-JsonValue $request.options $config.options) -or $request.model -ne $config.model -or $request.think -ne $config.think -or $request.keep_alive -ne $config.keep_alive -or $request.stream -ne $true -or $request.messages[0].content -cne $metric.sample.prompt) { throw "Petición distinta: $id" }
    $rows=@(Get-Content (Join-Path $outDir "$id-stream.jsonl") | ForEach-Object { $_ | ConvertFrom-Json })
    $content=[Text.StringBuilder]::new(); $thinking=[Text.StringBuilder]::new(); $lastTime=-1.0
    $firstContent=$null; $firstThinking=$null
    foreach ($row in $rows) {
        if ($row.client_elapsed_seconds -lt $lastTime) { throw "Reloj no monotónico: $id" }
        $lastTime=$row.client_elapsed_seconds
        $chunk=$row.raw | ConvertFrom-Json
        if ($chunk.message.content) { if ($null -eq $firstContent) {$firstContent=$lastTime}; $content.Append($chunk.message.content) | Out-Null }
        if ($chunk.message.thinking) { if ($null -eq $firstThinking) {$firstThinking=$lastTime}; $thinking.Append($chunk.message.thinking) | Out-Null }
    }
    if ($content.ToString() -cne [IO.File]::ReadAllText((Join-Path $outDir "$id-response.txt")) -or $thinking.ToString() -cne [IO.File]::ReadAllText((Join-Path $outDir "$id-thinking.txt"))) { throw "Stream y respuesta difieren: $id" }
    $firstChunk=if ($rows.Count) {$rows[0].client_elapsed_seconds} else {$null}
    if ($metric.first_content_seconds -ne $firstContent -or $metric.first_thinking_seconds -ne $firstThinking -or $metric.first_chunk_seconds -ne $firstChunk -or $metric.client_total_seconds -lt $lastTime) { throw "Tiempos difieren: $id" }
    $finalChunks=@($rows | ForEach-Object {$_.raw | ConvertFrom-Json -AsHashtable} | Where-Object done)
    if ($metric.error -and $AllowPartial) {
        if ($null -ne $metric.final -or $finalChunks.Count -ne 0) { throw "Error parcial con final inesperado: $id" }
    } else {
        if ($finalChunks.Count -ne 1 -or -not (Test-JsonValue $finalChunks[0] $metric.final) -or $metric.error) { throw "Final incoherente: $id" }
        if ($null -eq $metric.final.prompt_eval_count -or $metric.final.prompt_eval_count -le 0 -or $null -eq $metric.final.eval_count -or $metric.final.eval_count -le 0 -or $metric.final.eval_duration -le 0) { throw "Contadores ausentes/no válidos: $id" }
        if ($null -ne $metric.final.prompt_eval_cached_count -and ($metric.final.prompt_eval_cached_count -lt 0 -or $metric.final.prompt_eval_cached_count -gt $metric.final.prompt_eval_count)) { throw "Caché incoherente: $id" }
        $speed=$metric.final.eval_count/($metric.final.eval_duration/1e9)
        if ([math]::Abs($metric.tokens_per_second-$speed) -gt 1e-10) { throw "Velocidad incoherente: $id" }
    }
    if ($metric.sample.kind -eq 'quality') {
        $task=$suite.tasks | Where-Object id -eq $id
        $computed=Get-QualityScore $task $content.ToString() $metric
        $saved=$scores | Where-Object id -eq $id
        if (-not (Test-JsonValue $computed $saved.score)) { throw "Score incoherente: $id" }
    }
    if ($protocol.sustained -and -not $metric.error -and $metric.sample.kind -in @('warmup','performance')) {
        $condition=$protocol.conditions | Where-Object id -eq $metric.sample.condition
        if ($metric.final.prompt_eval_count -lt $condition.min_tokens -or $metric.final.prompt_eval_count -gt $condition.max_tokens -or ($metric.final.prompt_eval_count+$config.options.num_predict) -gt $config.options.num_ctx -or $metric.ps_after.models[0].context_length -ne $config.options.num_ctx) { throw 'Longitud/contexto no válido' }
    }
}
foreach ($group in @($metrics | Where-Object {$_.sample.kind -eq 'performance'} | Group-Object {$_.sample.condition})) {
    if (-not $AllowPartial -and $group.Count -ne $protocol.repetitions) { throw 'Condición sin repeticiones configuradas' }
}
if (-not $AllowPartial) {
    if ($status.fatal_error -or $status.safety_cancelled -or (Test-Path (Join-Path $outDir 'safety-abort.json'))) { throw 'No puede cerrarse con fallo/parada' }
    if ($protocol.session_block -eq 'performance') {
        foreach ($condition in $protocol.conditions) {
            $valid=@($metrics | Where-Object {$_.sample.kind -eq 'performance' -and $_.sample.condition -eq $condition.id -and -not $_.error -and $_.final.done_reason -eq 'stop' -and $_.content_characters -gt 0})
            if ($valid.Count -ne $protocol.repetitions -or $valid.Count -lt 5) { throw 'Faltan medidas válidas por longitud' }
        }
    }
    if (@($metrics | Where-Object {$_.error -or $_.truncated -or -not $_.final.done -or $_.content_characters -eq 0}).Count) { throw 'Finales no válidos en sesión completa' }
}
Get-ChildItem $outDir -Filter '*.json' | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null }
$telemetry=@(Get-Content (Join-Path $outDir 'telemetry.jsonl') | ForEach-Object {$_ | ConvertFrom-Json})
if ($telemetry.Count -lt 2 -or $status.telemetry_state -ne 'Completed') { throw 'Telemetría incompleta' }
Write-BenchmarkJson @{checked_at=[DateTime]::UtcNow.ToString('o');requests_checked=$metrics.Count;quality_scores_recomputed=$scores.Count;telemetry_samples=$telemetry.Count;phase_complete=($status.complete -and -not $protocol.session_block);session_complete=$status.complete;scope=$(if($protocol.session_block){$protocol.session_block+' session only; aggregate required'}else{'original protocol'});partial_mode=[bool]$AllowPartial;result=$(if ($AllowPartial -and -not $status.complete) {'partial_integrity_pass'} else {'pass'});checks=@('options unchanged','configured schedule/executed prefix','response equals concatenated stream','monotonic timestamps','first text timings','complete finals or explicit partial error','quality extraction','configured repetitions/sustained required only in complete mode','input ranges/context for complete responses','JSON parse','summary empty errors and nearest-rank percentiles when present','manual review response hashes when present','positive final counters/cache bounds/generation rate')} $ValidationPath
Write-Output 'Artefactos comprobados: peticiones, streams, tiempos, scores, finales y telemetría coherentes.'
