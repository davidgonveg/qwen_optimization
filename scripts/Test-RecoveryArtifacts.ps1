#requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PerformanceRunId,[Parameter(Mandatory)][string]$SustainedRunId,[Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
$root=Split-Path $PSScriptRoot -Parent
if (Test-Path -LiteralPath $OutputPath) { throw 'Validación agregada existente' }
$reference=Get-Content (Join-Path $root 'configs/reference.json') -Raw | ConvertFrom-Json -AsHashtable
$checks=Join-Path $root 'results/recovery-checks-20261015'
$preserved=@(Get-Content (Join-Path $checks 'preserved-before.json') -Raw | ConvertFrom-Json)
foreach ($file in $preserved) {
    if ((Get-FileHash -LiteralPath $file.Path).Hash -ne $file.Hash) { throw "Evidencia histórica modificada: $($file.Path)" }
}
& (Join-Path $PSScriptRoot 'Test-BenchmarkArtifacts.ps1') -RunId reduced-20261014-reference-v1 -AllowPartial -ValidationPath (Join-Path $checks 'quality-final-validation.json')
$sessions=@()
foreach ($pair in @(@{id=$PerformanceRunId;block='performance'},@{id=$SustainedRunId;block='sustained'})) {
    if ($pair.id -notmatch '^[a-zA-Z0-9_-]+$') { throw 'RunId inválido' }
    $dir=Join-Path $root "results/$($pair.id)"
    & (Join-Path $PSScriptRoot 'Test-BenchmarkArtifacts.ps1') -RunId $pair.id -ValidationPath (Join-Path $dir 'validation.json')
    $config=Get-Content (Join-Path $dir 'config.json') -Raw | ConvertFrom-Json -AsHashtable
    $protocol=Get-Content (Join-Path $dir 'protocol.json') -Raw | ConvertFrom-Json -AsHashtable
    $expected=Get-Content (Join-Path $root "configs/recovery-$($pair.block)-v1.json") -Raw | ConvertFrom-Json -AsHashtable
    if (-not (Test-JsonValue $config $reference) -or -not (Test-JsonValue $protocol $expected)) { throw 'Config/protocolo no idénticos' }
    if ((Get-FileHash (Join-Path $dir 'suite.json')).Hash -ne (Get-FileHash (Join-Path $root 'results/reduced-20261014-reference-v1/suite.json')).Hash) { throw 'Suite distinta' }
    $inventory=Get-Content (Join-Path $dir 'inventory-after.json') -Raw | ConvertFrom-Json
    if (-not $inventory.global_models_unchanged -or $inventory.stop_error -or $inventory.runner_error -or $inventory.own_listener.Count) { throw 'Instancia/servicio no preservados' }
    $run=Get-Content (Join-Path $dir 'run.json') -Raw | ConvertFrom-Json
    if ($run.version.version -ne '0.40.3' -or @($run.ps_before.models).Count) { throw 'Runtime/carga inicial distintos' }
    foreach ($name in @('Invoke-BenchmarkPilot.ps1','Invoke-RecoverySession.ps1','Start-ProjectOllama.ps1','Stop-ProjectOllama.ps1','Benchmark.Common.ps1','Benchmark.Schedule.ps1','Measure-ProjectResources.ps1')) {
        $path=Join-Path $PSScriptRoot $name
        $record=@($run.hashes | Where-Object Path -eq $path)
        if ($record.Count -ne 1 -or (Get-FileHash $path).Hash -ne $record[0].Hash) { throw "Script de inferencia cambió tras fijarlo: $name" }
    }
    $telemetry=@(Get-Content (Join-Path $dir 'telemetry.jsonl') | ConvertFrom-Json)
    if (@($telemetry | Where-Object {$_.errors.Count}).Count) { throw 'Errores de sensores: revisar antes de cierre' }
    foreach ($sample in $telemetry) {
        if ($sample.os.FreePhysicalMemory -lt $protocol.safety.min_free_ram_KiB -or ([double]$sample.gpu.memory_total_MiB-[double]$sample.gpu.memory_used_MiB) -lt $protocol.safety.min_free_vram_MiB -or [double]$sample.gpu.temperature_C -ge $protocol.safety.max_gpu_temperature_C) { throw 'Telemetría cruza umbral' }
    }
    $log=Get-Content (Join-Path $dir 'runtime-inference.log') -Raw
    foreach ($pattern in @('offloaded 31/66 layers','--spec-draft-n-max 4','size limit: 8192 MiB','n_ctx\s+= 2048','n_threads = 6')) {
        if ($log -notmatch $pattern) { throw "Runtime efectivo no corroborado: $pattern" }
    }
    $sessions+=@{run_id=$pair.id;block=$pair.block;requests=@(Get-Content (Join-Path $dir 'metrics.json') -Raw | ConvertFrom-Json).Count;config_sha256=(Get-FileHash (Join-Path $dir 'config.json')).Hash;validation_sha256=(Get-FileHash (Join-Path $dir 'validation.json')).Hash}
}
$quality=Get-Content (Join-Path $root 'results/reduced-20261014-reference-v1/quality-scores.json') -Raw | ConvertFrom-Json
$strict=@($quality | Where-Object scorer -ne 'manual')
if ($quality.Count -ne 22 -or $strict.Count -ne 18 -or @($strict | Where-Object {$_.score.pass -eq $true}).Count -ne 15) { throw 'Calidad de origen no corroborada' }
$portable=Get-Content (Join-Path $checks 'portable-runtime-verified.json') -Raw | ConvertFrom-Json
foreach ($binary in $portable.files) {
    if ((Get-FileHash -LiteralPath $binary.Path).Hash -ne $binary.Hash) { throw 'Runtime portátil modificado' }
}
Write-BenchmarkJson @{checked_at=[datetime]::UtcNow.ToString('o');phase2b_complete=$true;phase2_complete=$false;result='aggregate_pass';quality_run='reduced-20261014-reference-v1';quality_strict='15/18';quality_assisted_criteria='10/12; human independent pending';historical_files_unchanged=$preserved.Count;sessions=$sessions;portable_runtime_verified=$true;inference_scripts_unchanged_since_run=$true;scope='Reduced textual reference assembled from distinct sessions; no pooling of historical timing; no optimization'} $OutputPath
Write-Output 'Fase 2B agregada comprobada; fase 2 permanece abierta.'
