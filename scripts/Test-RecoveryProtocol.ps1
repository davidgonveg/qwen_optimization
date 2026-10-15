#requires -Version 7.4
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
. (Join-Path $PSScriptRoot 'Benchmark.Schedule.ps1')
$root=Split-Path $PSScriptRoot -Parent
$original=Get-Content (Join-Path $root 'configs/reduced-v1.json') -Raw | ConvertFrom-Json -AsHashtable
$suite=Get-Content (Join-Path $root $original.suite) -Raw | ConvertFrom-Json -AsHashtable
foreach ($block in @('performance','sustained')) {
    $p=Get-Content (Join-Path $root "configs/recovery-$block-v1.json") -Raw | ConvertFrom-Json -AsHashtable
    foreach ($field in @('conditions','repetitions','prefix_template','performance_prompt','padding_template','padding_unit','safety','sustained','suite')) {
        if (-not (Test-JsonValue $p[$field] $original[$field])) { throw "Parámetro modificado: $field" }
    }
    $schedule=@(Get-BenchmarkSchedule ([pscustomobject]$p) $suite)
    if (@($schedule | Where-Object kind -eq 'quality').Count) { throw 'Calidad no debe repetirse' }
    if ($block -eq 'performance') {
        if ($schedule.Count -ne 15) { throw 'Rendimiento exige 15 peticiones' }
        $oldSchedule=@(Get-BenchmarkSchedule ([pscustomobject]$original) $suite)
        if (-not (Test-JsonValue @($schedule | Where-Object kind -in @('warmup','performance')) @($oldSchedule | Where-Object kind -in @('warmup','performance')))) { throw 'Prompts/orden de longitud modificados' }
    } elseif ($schedule.Count -ne 2 -or $schedule[1].kind -ne 'warmup-sustained') { throw 'Sostenido exige carga y calentamiento' }
    if (@($schedule.id | Sort-Object -Unique).Count -ne $schedule.Count) { throw 'IDs duplicados' }
}
Write-Output 'Recuperación: parámetros idénticos, 15/2 peticiones fijas, orden/prompts de longitud intactos y calidad omitida.'
