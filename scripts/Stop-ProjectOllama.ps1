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
Write-Output "Detenida exclusivamente la instancia del proyecto: PID $($record.pid)."
