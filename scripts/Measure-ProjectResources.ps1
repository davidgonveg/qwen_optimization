#requires -Version 7.4
param([string]$OutputPath, [string]$StopPath, [int]$ServerPid)
$ErrorActionPreference = 'Stop'
$writer = [IO.StreamWriter]::new($OutputPath, $false, [Text.UTF8Encoding]::new($false))
$writer.AutoFlush = $true
try {
    while (-not (Test-Path -LiteralPath $StopPath)) {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $sample = @{at_utc=[DateTime]::UtcNow.ToString('o'); gpu=$null; os=$null; processes=$null; errors=@()}
        try {
            $gpuText = & nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu,temperature.gpu,power.draw --format=csv,noheader,nounits
            if ($LASTEXITCODE -ne 0) { throw 'nvidia-smi falló.' }
            $sample.gpu = $gpuText | ConvertFrom-Csv -Header memory_used_MiB,memory_total_MiB,utilization_percent,temperature_C,power_W
        } catch { $sample.errors += $_.Exception.Message }
        try {
            $sample.os = Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize,FreePhysicalMemory,TotalVirtualMemorySize,FreeVirtualMemory
            $all = Get-CimInstance Win32_Process
            $ids = @($ServerPid)
            do {
                $new = @($all | Where-Object { $_.ParentProcessId -in $ids -and $_.ProcessId -notin $ids } | Select-Object -ExpandProperty ProcessId)
                $ids += $new
            } while ($new.Count -gt 0)
            $sample.processes = @($all | Where-Object ProcessId -in $ids | Select-Object ProcessId,ParentProcessId,Name,WorkingSetSize,PrivatePageCount,KernelModeTime,UserModeTime)
        } catch { $sample.errors += $_.Exception.Message }
        $sample.collection_seconds = $watch.Elapsed.TotalSeconds
        $writer.WriteLine(($sample | ConvertTo-Json -Depth 8 -Compress))
        $remaining = 1000 - $watch.Elapsed.TotalMilliseconds
        if ($remaining -gt 0) { Start-Sleep -Milliseconds ([int]$remaining) }
    }
} finally { $writer.Dispose() }
