#requires -Version 7.4
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
. (Join-Path $PSScriptRoot 'Benchmark.Schedule.ps1')
$root=Split-Path $PSScriptRoot -Parent
$protocol=Get-Content (Join-Path $root 'configs/reduced-v1.json') -Raw | ConvertFrom-Json
$suite=Get-Content (Join-Path $root $protocol.suite) -Raw | ConvertFrom-Json -AsHashtable
$schedule=@(Get-BenchmarkSchedule $protocol $suite)
if ($schedule.Count -ne (1+$suite.tasks.Count+$protocol.conditions.Count*(1+$protocol.repetitions))) { throw 'Cantidad de schedule incorrecta' }
$perf=@($schedule | Where-Object kind -eq 'performance')
for ($i=0;$i -lt $protocol.repetitions;$i++) {
    $first=if ($i%2 -eq 0) {'input-short'} else {'input-long'}
    if ($perf[$i*2].condition -ne $first -or $perf[$i*2].condition -eq $perf[$i*2+1].condition) { throw 'Orden no equilibrado' }
}
if (@($schedule.id | Sort-Object -Unique).Count -ne $schedule.Count -or @($perf.nonce | Sort-Object -Unique).Count -ne $perf.Count) { throw 'IDs/prefijos duplicados' }
$old=Get-Content (Join-Path $root 'benchmarks/pilot-v1.json') -Raw | ConvertFrom-Json
if (@($suite.tasks | Where-Object {$_.prompt -in $old.tasks.prompt}).Count) { throw 'Prompts de desarrollo repetidos' }
$sample=@{os=@{FreePhysicalMemory=2000000};gpu=@{memory_used_MiB=11500;memory_total_MiB=12288;temperature_C=65}}
if (@(Get-SafetyViolations $sample $protocol.safety 0).Count) { throw 'Parada indebida' }
$sample.os.FreePhysicalMemory=$protocol.safety.min_free_ram_KiB-1
if ('ram_pressure' -notin @(Get-SafetyViolations $sample $protocol.safety 0)) { throw 'RAM sin parada' }
$sample.os.FreePhysicalMemory=$protocol.safety.min_free_ram_KiB
$sample.gpu.memory_used_MiB=12288-$protocol.safety.min_free_vram_MiB
if (@(Get-SafetyViolations $sample $protocol.safety 0).Count) { throw 'Parada indebida en límite de memoria' }
$sample.gpu.memory_used_MiB++
if ('vram_pressure' -notin @(Get-SafetyViolations $sample $protocol.safety 0)) { throw 'VRAM sin parada' }
$sample.gpu.temperature_C=$protocol.safety.max_gpu_temperature_C
if ('temperature' -notin @(Get-SafetyViolations $sample $protocol.safety 0)) { throw 'Temperatura sin parada' }
if ('sensor_errors' -notin @(Get-SafetyViolations $sample $protocol.safety 2)) { throw 'Sensores sin parada' }
$cts=[Threading.CancellationTokenSource]::new()
$linked=[Threading.CancellationTokenSource]::CreateLinkedTokenSource($cts.Token)
$job=Start-ThreadJob -ScriptBlock {param($source) $source.Cancel()} -ArgumentList $cts
$job | Wait-Job -Timeout 5 | Out-Null
if (-not $linked.IsCancellationRequested) { throw 'Cancelación no propagada entre hilos' }
$job | Receive-Job; $job | Remove-Job; $linked.Dispose(); $cts.Dispose()
Write-Output 'Schedule equilibrado, muestras nuevas, umbrales y cancelación enlazada comprobados sin inferencia.'
