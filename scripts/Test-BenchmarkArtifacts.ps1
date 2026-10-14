#requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$RunId)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
if ($RunId -notmatch '^[a-zA-Z0-9_-]+$') { throw 'RunId inválido' }
$root=Split-Path $PSScriptRoot -Parent; $outDir=Join-Path $root "results/$RunId"
$config=Get-Content (Join-Path $outDir 'config.json') -Raw | ConvertFrom-Json -AsHashtable
$suite=Get-Content (Join-Path $outDir 'suite.json') -Raw | ConvertFrom-Json -AsHashtable
$metrics=@(Get-Content (Join-Path $outDir 'metrics.json') -Raw | ConvertFrom-Json -AsHashtable)
$scores=@(Get-Content (Join-Path $outDir 'quality-scores.json') -Raw | ConvertFrom-Json -AsHashtable)
$schedule=@(Get-Content (Join-Path $outDir 'schedule.json') -Raw | ConvertFrom-Json -AsHashtable)
$status=Get-Content (Join-Path $outDir 'run-status.json') -Raw | ConvertFrom-Json
if (-not $status.complete -or $metrics.Count -ne 23 -or $schedule.Count -ne 23 -or $scores.Count -ne 10) { throw 'Piloto incompleto' }
$summaryPath=Join-Path $outDir 'summary.json'
if (Test-Path $summaryPath) {
    $summary=Get-Content $summaryPath -Raw | ConvertFrom-Json
    if ($summary.telemetry.error_samples -eq 0 -and $summary.telemetry.errors.Count -ne 0) { throw 'Resumen: lista vacía de errores serializada incorrectamente' }
    foreach ($condition in $summary.performance) {
        $values=@($condition.samples.total_seconds | Sort-Object)
        if ($condition.total_seconds.p50 -ne $values[2] -or $condition.total_seconds.p95 -ne $values[4]) { throw 'Percentiles distintos del protocolo nearest-rank con n=5' }
    }
}
$manualPath=Join-Path $outDir 'manual-review.json'
if (Test-Path $manualPath) {
    $review=Get-Content $manualPath -Raw | ConvertFrom-Json
    foreach ($taskReview in $review.tasks) {
        if ($taskReview.id -notin @('q08','q09','q10') -or $taskReview.criteria.Count -ne 3 -or (Get-FileHash (Join-Path $outDir "$($taskReview.id)-response.txt")).Hash.ToLowerInvariant() -ne $taskReview.response_sha256) { throw 'Revisión sin respuesta/rúbrica identificada' }
    }
}
foreach ($metric in $metrics) {
    $id=$metric.sample.id
    $request=Get-Content (Join-Path $outDir "$id-request.json") -Raw | ConvertFrom-Json -AsHashtable
    if (-not (Test-JsonValue $request.options $config.options) -or $request.model -ne $config.model -or $request.think -ne $config.think -or $request.messages[0].content -cne $metric.sample.prompt) { throw "Petición distinta: $id" }
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
    if ($metric.first_content_seconds -ne $firstContent -or $metric.first_thinking_seconds -ne $firstThinking -or $metric.first_chunk_seconds -ne $rows[0].client_elapsed_seconds -or $metric.client_total_seconds -lt $lastTime) { throw "Tiempos difieren: $id" }
    $last=$rows[-1].raw | ConvertFrom-Json -AsHashtable
    if (-not (Test-JsonValue $last $metric.final) -or -not $last.done -or $metric.error) { throw "Final incoherente: $id" }
    if ($metric.sample.kind -eq 'quality') {
        $task=$suite.tasks | Where-Object id -eq $id
        $computed=Get-QualityScore $task $content.ToString() $metric
        $saved=$scores | Where-Object id -eq $id
        if (-not (Test-JsonValue $computed $saved.score)) { throw "Score incoherente: $id" }
    }
}
foreach ($group in @($metrics | Where-Object {$_.sample.kind -eq 'performance'} | Group-Object {$_.sample.condition})) {
    if ($group.Count -ne 5) { throw 'Condición sin cinco repeticiones' }
}
Get-ChildItem $outDir -Filter '*.json' | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null }
$telemetry=@(Get-Content (Join-Path $outDir 'telemetry.jsonl') | ForEach-Object {$_ | ConvertFrom-Json})
if ($telemetry.Count -lt 2 -or $status.telemetry_state -ne 'Completed') { throw 'Telemetría incompleta' }
Write-BenchmarkJson @{checked_at=[DateTime]::UtcNow.ToString('o');requests_checked=$metrics.Count;quality_scores_recomputed=$scores.Count;telemetry_samples=$telemetry.Count;result='pass';checks=@('options unchanged','response equals concatenated stream','monotonic timestamps','first text timings','final matches raw stream','quality extraction','5 repetitions per condition','JSON parse','summary empty errors and nearest-rank percentiles when present','manual review response hashes when present')} (Join-Path $outDir 'validation.json')
Write-Output 'Artefactos comprobados: peticiones, streams, tiempos, scores, finales y telemetría coherentes.'
