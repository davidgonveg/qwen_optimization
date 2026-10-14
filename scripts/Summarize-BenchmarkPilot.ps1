#requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$RunId, [string]$SummaryPath='', [string]$ExpectedPerformanceResponse='')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
if ($RunId -notmatch '^[a-zA-Z0-9_-]+$') { throw 'RunId inválido' }
$root=Split-Path $PSScriptRoot -Parent; $outDir=Join-Path $root "results/$RunId"
if (-not $SummaryPath) { $SummaryPath=Join-Path $outDir 'summary.json' }
if (Test-Path -LiteralPath $SummaryPath) { throw 'Resumen existente; preservar resultados' }
$metrics=@(Get-Content (Join-Path $outDir 'metrics.json') -Raw | ConvertFrom-Json)
$scores=@(Get-Content (Join-Path $outDir 'quality-scores.json') -Raw | ConvertFrom-Json)
$suite=Get-Content (Join-Path $outDir 'suite.json') -Raw | ConvertFrom-Json
$status=Get-Content (Join-Path $outDir 'run-status.json') -Raw | ConvertFrom-Json
$protocol=Get-Content (Join-Path $outDir 'protocol.json') -Raw | ConvertFrom-Json
$manualPath=Join-Path $outDir 'manual-review.json'
$manual=$null
if (Test-Path $manualPath) { $manual=Get-Content $manualPath -Raw | ConvertFrom-Json }
function Get-Distribution($Values) {
    $items=@($Values | Where-Object { $null -ne $_ } | Sort-Object)
    if (-not $items.Count) { return @{n=0;p50=$null;p95=$null;min=$null;max=$null} }
    return @{n=$items.Count;p50=$items[[int][Math]::Ceiling(0.5*$items.Count)-1];p95=$items[[int][Math]::Ceiling(0.95*$items.Count)-1];min=$items[0];max=$items[-1]}
}
$conditions=@()
foreach ($group in @($metrics | Where-Object { $_.sample.kind -eq 'performance' } | Group-Object {$_.sample.condition})) {
    $valid=@($group.Group | Where-Object { -not $_.error -and $_.final.done -and $_.final.done_reason -eq 'stop' -and $_.content_characters -gt 0 })
    $conditions+=@{id=$group.Name;n_planned=$protocol.repetitions;n_requested=$group.Count;n_valid=$valid.Count;failures=$group.Count-$valid.Count;not_attempted=$protocol.repetitions-$group.Count;total_seconds=(Get-Distribution $valid.client_total_seconds);ttft_seconds=(Get-Distribution $valid.ttft_seconds);generation_tokens_per_second=(Get-Distribution $valid.tokens_per_second);samples=@($group.Group | ForEach-Object { @{id=$_.sample.id;input_tokens=$_.final.prompt_eval_count;cached_tokens=$_.final.prompt_eval_cached_count;output_tokens=$_.final.eval_count;total_seconds=$_.client_total_seconds;ttft_seconds=$_.ttft_seconds;generation_tokens_per_second=$_.tokens_per_second;uncached_prompt_tokens_per_second=$_.uncached_prompt_tokens_per_second;done_reason=$_.final.done_reason;error=$_.error} })}
}
$telemetry=@(Get-Content (Join-Path $outDir 'telemetry.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
$logical=(Get-Content (Join-Path $outDir 'inventory-before.json') -Raw | ConvertFrom-Json).cpu.NumberOfLogicalProcessors
$ws=@(); $private=@(); $cpuPercent=@(); $energyJ=0.0; $energyCovered=0.0; $gaps=@(); $previous=$null
foreach ($sample in $telemetry) {
    if ($null -ne $sample.processes -and @($sample.processes).Count) {
        $ws+=($sample.processes | Measure-Object WorkingSetSize -Sum).Sum
        $private+=($sample.processes | Measure-Object PrivatePageCount -Sum).Sum
    }
    if ($previous) {
        $dt=(([datetime]$sample.at_utc)-([datetime]$previous.at_utc)).TotalSeconds
        $gaps+=$dt
        # Este piloto requiere una GPU; no mezclar potencias de dispositivos distintos.
        if ($dt -gt 0 -and $null -ne $sample.gpu.power_W -and $null -ne $previous.gpu.power_W -and $sample.gpu.power_W -ne '[N/A]' -and $previous.gpu.power_W -ne '[N/A]') {
            $energyJ+=(([double]::Parse($sample.gpu.power_W,[Globalization.CultureInfo]::InvariantCulture)+[double]::Parse($previous.gpu.power_W,[Globalization.CultureInfo]::InvariantCulture))/2)*$dt
            $energyCovered+=$dt
        }
        # Sumar solo procesos presentes en ambos intervalos; nuevos procesos se omiten hasta la próxima muestra.
        $delta=0.0; $matched=0
        foreach ($process in $sample.processes) {
            $old=@($previous.processes | Where-Object ProcessId -eq $process.ProcessId)
            if ($old.Count -eq 1) {
                $d=([double]$process.KernelModeTime+[double]$process.UserModeTime)-([double]$old[0].KernelModeTime+[double]$old[0].UserModeTime)
                if ($d -ge 0) { $delta+=$d; $matched++ }
            }
        }
        if ($dt -gt 0 -and $matched -gt 0) { $cpuPercent+=100*$delta/1e7/$dt/$logical }
    }
    $previous=$sample
}
function Get-GpuValues([string]$Field) {
    @($telemetry | ForEach-Object { if ($null -ne $_.gpu.$Field -and $_.gpu.$Field -ne '[N/A]') { [double]::Parse($_.gpu.$Field,[Globalization.CultureInfo]::InvariantCulture) } })
}
$sensorErrors=@($telemetry | Where-Object { @($_.errors).Count -gt 0 })
$auto=@($scores | Where-Object scorer -ne 'manual')
$gpuPower=@(Get-GpuValues 'power_W')
$sustained=@($metrics | Where-Object {$_.sample.kind -eq 'sustained'})
function Get-SustainedWindow($Items, $Sensors) {
    return @{requests=$Items.Count;generation_tokens_per_second=(Get-Distribution $Items.tokens_per_second);output_tokens=(Get-Distribution $Items.final.eval_count);ttft_seconds=(Get-Distribution $Items.ttft_seconds);gpu_temperature_C=(Get-Distribution @($Sensors | ForEach-Object {if ($null -ne $_.gpu.temperature_C -and $_.gpu.temperature_C -ne '[N/A]') {[double]$_.gpu.temperature_C}}));free_ram_KiB=(Get-Distribution $Sensors.os.FreePhysicalMemory)}
}
$sustainedSummary=$null
if ($status.sustained) {
    $start=[datetime]$status.sustained.started_at; $end=[datetime]$status.sustained.ended_at
    $firstItems=@($sustained | Where-Object {([datetime]$_.started_at) -lt $start.AddSeconds(60)})
    $lastItems=@($sustained | Where-Object {([datetime]$_.started_at) -ge $end.AddSeconds(-60)})
    $firstSensors=@($telemetry | Where-Object {([datetime]$_.at_utc) -ge $start -and ([datetime]$_.at_utc) -lt $start.AddSeconds(60)})
    $lastSensors=@($telemetry | Where-Object {([datetime]$_.at_utc) -ge $end.AddSeconds(-60) -and ([datetime]$_.at_utc) -le $end})
    $sustainedSummary=@{status=$status.sustained;first_60_seconds=(Get-SustainedWindow $firstItems $firstSensors);last_60_seconds=(Get-SustainedWindow $lastItems $lastSensors);samples=@($sustained | ForEach-Object {@{id=$_.sample.id;started_at=$_.started_at;total_seconds=$_.client_total_seconds;ttft_seconds=$_.ttft_seconds;generation_tokens_per_second=$_.tokens_per_second;input_tokens=$_.final.prompt_eval_count;cached_tokens=$_.final.prompt_eval_cached_count;output_tokens=$_.final.eval_count;done_reason=$_.final.done_reason;error=$_.error}});note='Ventanas por inicio de petición; tamaños y salida pueden diferir; no prueba causal de throttling'}
}
foreach ($condition in $conditions) {
    foreach ($item in $condition.samples) {
        $metric=$metrics | Where-Object {$_.sample.id -eq $item.id}
        $nearest=$telemetry | Sort-Object { [Math]::Abs((([datetime]$_.at_utc)-([datetime]$metric.started_at)).TotalSeconds) } | Select-Object -First 1
        $item.initial_telemetry=@{at_utc=$nearest.at_utc;distance_seconds=[Math]::Abs((([datetime]$nearest.at_utc)-([datetime]$metric.started_at)).TotalSeconds);gpu_temperature_C=$nearest.gpu.temperature_C;free_ram_KiB=$nearest.os.FreePhysicalMemory}
        $item.expected_response=$(if ($ExpectedPerformanceResponse) {$ExpectedPerformanceResponse} else {$null})
        $item.response_exact=$(if ($ExpectedPerformanceResponse -and -not $item.error) {([IO.File]::ReadAllText((Join-Path $outDir "$($item.id)-response.txt")).Trim() -ceq $ExpectedPerformanceResponse)} else {$null})
    }
}
$summary=@{
    run_id=$RunId;generated_at=[DateTime]::UtcNow.ToString('o');requests=$metrics.Count;request_errors=@($metrics | Where-Object error).Count;truncations=@($metrics | Where-Object truncated).Count;incomplete_or_empty=@($metrics | Where-Object {-not $_.final.done -or $_.content_characters -eq 0}).Count
    client_request_seconds_sum=($metrics | Measure-Object client_total_seconds -Sum).Sum
    output_tokens_sum=($metrics.final | Measure-Object eval_count -Sum).Sum
    quality=@{automatic_tasks=$auto.Count;automatic_pass=@($auto | Where-Object {$_.score.pass -eq $true}).Count;automatic_invalid=@($auto | Where-Object {$_.score.status -eq 'invalid'}).Count;manual_tasks=@($scores | Where-Object scorer -eq 'manual').Count;manual_review=$manual;split=$suite.split;note='Muestra heterogénea personal, sin inferencia de calidad poblacional ni puntuación oficial'}
    compatibility=@($metrics | Where-Object {$_.sample.kind -eq 'compatibility'} | Select-Object logprobs_observed,client_total_seconds,ttft_seconds,final,error)
    performance=$conditions
    sustained=$sustainedSummary;run_complete=$status.complete;fatal_error=$status.fatal_error
    telemetry=@{samples=$telemetry.Count;error_samples=$sensorErrors.Count;errors=@($sensorErrors | ForEach-Object {$_.errors});first_utc=$telemetry[0].at_utc;last_utc=$telemetry[-1].at_utc;interval_seconds=(Get-Distribution $gaps);collection_seconds=(Get-Distribution $telemetry.collection_seconds);gpu_vram_MiB=(Get-Distribution (Get-GpuValues 'memory_used_MiB'));gpu_temperature_C=(Get-Distribution (Get-GpuValues 'temperature_C'));gpu_power_W=(Get-Distribution $gpuPower);gpu_utilization_percent=(Get-Distribution (Get-GpuValues 'utilization_percent'));tree_working_set_bytes=(Get-Distribution $ws);tree_private_committed_bytes=(Get-Distribution $private);tree_cpu_percent_of_all_logical_processors=(Get-Distribution $cpuPercent);system_free_RAM_KiB=(Get-Distribution $telemetry.os.FreePhysicalMemory);gpu_energy_Wh=$(if ($energyCovered -gt 0) {$energyJ/3600} else {$null});energy_coverage_seconds=$energyCovered;energy_scope='GPU completa, potencia integrada por trapecios, sin restar reposo; no energía del PC';unavailable=@('paginación','temperatura CPU','throttling','energía del PC','respuesta interactiva')}
}
Write-BenchmarkJson $summary $SummaryPath
Write-Output "Resumen guardado: $SummaryPath"
