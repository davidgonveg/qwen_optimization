#requires -Version 7.4
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$recordPath = Join-Path $root 'runtime/server.json'
$record = Get-Content $recordPath -Raw | ConvertFrom-Json
$process = Get-Process -Id $record.pid -ErrorAction SilentlyContinue
if (-not $process) { Write-Output 'La instancia del proyecto ya está detenida.'; return }
if ($process.Path -ne $record.executable -or $process.StartTime.ToUniversalTime() -ne ([datetime]$record.start_time).ToUniversalTime()) {
    throw 'El PID fue reutilizado; se rechaza detener ese proceso.'
}
$listener = Get-NetTCPConnection -State Listen -LocalPort 11435 -ErrorAction SilentlyContinue
if ($listener -and $listener.OwningProcess -ne $record.pid) { throw 'Propietario del puerto inesperado.' }
Invoke-RestMethod 'http://127.0.0.1:11435/api/generate' -Method Post -ContentType 'application/json' -Body '{"model":"qwen3.8:27b","keep_alive":0}' -TimeoutSec 60 | Out-Null
Stop-Process -Id $record.pid
$process.WaitForExit(10000) | Out-Null
if (-not $process.HasExited) { throw 'La instancia propia no terminó en diez segundos.' }
# Windows puede conservar brevemente el listener tras terminar el proceso.
for ($attempt = 0; $attempt -lt 50; $attempt++) {
    $remaining = @(Get-NetTCPConnection -State Listen -LocalPort 11435 -ErrorAction SilentlyContinue)
    if ($remaining.Count -eq 0) { break }
    if (@($remaining | Where-Object OwningProcess -ne $record.pid).Count) { throw 'El puerto fue ocupado por otro proceso; no se detiene.' }
    Start-Sleep -Milliseconds 100
}
if ($remaining.Count) { throw 'El puerto propio no quedó libre después de la parada.' }
Write-Output "Detenida exclusivamente la instancia del proyecto: PID $($record.pid)."
