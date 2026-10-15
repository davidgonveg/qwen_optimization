#requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$RunId, [Parameter(Mandatory)][ValidateSet('performance','sustained')][string]$Block)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
$root=Split-Path $PSScriptRoot -Parent
if ($RunId -notmatch '^[a-zA-Z0-9_-]+$') { throw 'RunId inválido' }
$outDir=Join-Path $root "results/$RunId"
if (Test-Path $outDir) { throw 'RunId existente' }
$protocolPath="configs/recovery-$Block-v1.json"
$protocol=Get-Content (Join-Path $root $protocolPath) -Raw | ConvertFrom-Json
$os=Get-CimInstance Win32_OperatingSystem
$gpu=@(& nvidia-smi --query-gpu=memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits | ConvertFrom-Csv -Header used,total,temperature)
if ($LASTEXITCODE -ne 0 -or $gpu.Count -ne 1 -or $os.FreePhysicalMemory -lt $protocol.preflight.min_free_ram_KiB -or [double]$gpu[0].temperature -gt $protocol.preflight.max_gpu_temperature_C -or ([double]$gpu[0].total-[double]$gpu[0].used) -lt $protocol.preflight.min_free_vram_MiB) { throw 'Sin margen previo fijado; no se inicia inferencia ni se cierran procesos ajenos' }
$preflight=@{at_utc=[DateTime]::UtcNow.ToString('o');os=($os | Select-Object TotalVisibleMemorySize,FreePhysicalMemory);gpu=$gpu;policy=$protocol.preflight;justification='Sesión nueva sin calidad previa; reserva de entrada conservadora, no garantía; monitor original activo'}
$before=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags'
$fatal=$null
$started=$false
try {
    & (Join-Path $PSScriptRoot 'Start-ProjectOllama.ps1') -ExecutablePath (Join-Path $root $protocol.runtime_executable)
    $started=$true
    & (Join-Path $PSScriptRoot 'Invoke-BenchmarkPilot.ps1') -RunId $RunId -ProtocolPath $protocolPath
} catch { $fatal=$_.Exception.Message }
finally {
    $stopError=$null
    # Start no debe detener un listener ajeno si rechazó puerto ocupado.
    if ($started) {
        try { & (Join-Path $PSScriptRoot 'Stop-ProjectOllama.ps1') } catch { $stopError=$_.Exception.Message }
    }
    if (Test-Path $outDir) {
        Write-BenchmarkJson $preflight (Join-Path $outDir 'preflight.json')
        $after=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags'
        $same=Test-JsonValue @($before.models | Sort-Object name | ForEach-Object {@{name=$_.name;digest=$_.digest}}) @($after.models | Sort-Object name | ForEach-Object {@{name=$_.name;digest=$_.digest}})
        Write-BenchmarkJson @{captured_at=[DateTime]::UtcNow.ToString('o');global_tags=$after;global_ps=(Invoke-RestMethod 'http://127.0.0.1:11434/api/ps');global_models_unchanged=$same;own_listener=@(Get-NetTCPConnection -State Listen -LocalPort 11435 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess);stop_error=$stopError;runner_error=$fatal;os=(Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize,FreePhysicalMemory);gpu=@(& nvidia-smi --query-gpu=memory.used,memory.total,temperature.gpu --format=csv)} (Join-Path $outDir 'inventory-after.json')
        if (-not $same) { throw 'Modelos habituales distintos' }
    }
    if ($stopError) { throw "Parada propia falló: $stopError" }
}
if ($fatal) { throw $fatal }
