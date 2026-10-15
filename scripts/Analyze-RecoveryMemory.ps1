#requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$RunId)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
$root=Split-Path $PSScriptRoot -Parent
if ($RunId -notmatch '^[a-zA-Z0-9_-]+$') { throw 'RunId inválido' }
$dir=Join-Path $root "results/$RunId"
$output=Join-Path $dir 'memory-analysis.json'
if (Test-Path $output) { throw 'Análisis existente' }
$lines=@(Get-Content (Join-Path $dir 'runtime-inference.log'))
$states=@(for ($i=0;$i -lt $lines.Count;$i++) {
    if ($lines[$i] -match 'cache state: (\d+) prompts, ([\d.]+) MiB') {
        @{line=$i+1;prompts=[int]$Matches[1];cache_MiB=[double]::Parse($Matches[2],[Globalization.CultureInfo]::InvariantCulture)}
    }
})
$telemetry=@(Get-Content (Join-Path $dir 'telemetry.jsonl') | ConvertFrom-Json)
$metrics=@(Get-Content (Join-Path $dir 'metrics.json') -Raw | ConvertFrom-Json)
$aligned=@(foreach ($metric in $metrics) {
    $closest=$telemetry | Sort-Object {[math]::Abs((([datetime]$_.at_utc)-([datetime]$metric.ended_at)).TotalSeconds)} | Select-Object -First 1
    @{id=$metric.sample.id;kind=$metric.sample.kind;request_end=$metric.ended_at;sample_at=$closest.at_utc;distance_seconds=[math]::Abs((([datetime]$closest.at_utc)-([datetime]$metric.ended_at)).TotalSeconds);free_ram_GiB=$closest.os.FreePhysicalMemory/1MB;working_set_tree_GiB=($closest.processes | Measure-Object WorkingSetSize -Sum).Sum/1GB;private_committed_tree_GiB=($closest.processes | Measure-Object PrivatePageCount -Sum).Sum/1GB;cached_tokens=$metric.final.prompt_eval_cached_count;input_tokens=$metric.final.prompt_eval_count;output_tokens=$metric.final.eval_count}
})
Write-BenchmarkJson @{run_id=$RunId;cache_states=$states;cache_peak_MiB=($states.cache_MiB | Measure-Object -Maximum).Maximum;cache_limit_MiB=8192;request_end_nearest_telemetry=$aligned;interpretation='New process avoids inherited prompts; cache grows within session. Temporal association does not isolate all allocations or external processes. Private committed is not physical RAM/paging.';not_measured=@('paging','memory leak','causal throttling','CPU temperature','PC energy')} $output
