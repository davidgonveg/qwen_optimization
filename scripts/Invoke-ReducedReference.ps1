#requires -Version 7.4
[CmdletBinding()]
param([string]$RunId=('reduced-'+(Get-Date -Format 'yyyyMMdd-HHmmss')))
$ErrorActionPreference='Stop'
if ($RunId -notmatch '^[a-zA-Z0-9_-]+$') { throw 'RunId inválido' }
$root=Split-Path $PSScriptRoot -Parent
$outDir=Join-Path $root "results/$RunId"
if (Test-Path $outDir) { throw 'RunId existente' }
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
$before=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags'
& (Join-Path $PSScriptRoot 'Start-ProjectOllama.ps1')
$fatal=$null
try {
    & (Join-Path $PSScriptRoot 'Invoke-BenchmarkPilot.ps1') -RunId $RunId -ProtocolPath 'configs/reduced-v1.json'
} catch { $fatal=$_.Exception.Message }
finally {
    $stopError=$null
    try { & (Join-Path $PSScriptRoot 'Stop-ProjectOllama.ps1') } catch { $stopError=$_.Exception.Message }
    $after=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags'
    $same=Test-JsonValue @($before.models | Sort-Object name | ForEach-Object {@{name=$_.name;digest=$_.digest}}) @($after.models | Sort-Object name | ForEach-Object {@{name=$_.name;digest=$_.digest}})
    if (Test-Path $outDir) {
        Write-BenchmarkJson @{captured_at=[DateTime]::UtcNow.ToString('o');global_tags=$after;global_ps=(Invoke-RestMethod 'http://127.0.0.1:11434/api/ps');global_models_unchanged=$same;own_listener=@(Get-NetTCPConnection -State Listen -LocalPort 11435 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess);stop_error=$stopError;runner_error=$fatal;os=(Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize,FreePhysicalMemory);gpu=@(& nvidia-smi --query-gpu=memory.used,memory.total,temperature.gpu --format=csv)} (Join-Path $outDir 'inventory-after.json')
    }
    if ($stopError) { throw "Parada propia falló: $stopError" }
    if (-not $same) { throw 'Modelos habituales distintos tras ejecución' }
}
if ($fatal) { throw $fatal }
