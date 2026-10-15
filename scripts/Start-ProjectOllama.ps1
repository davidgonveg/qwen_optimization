#requires -Version 7.4
[CmdletBinding()]
param([string]$ExecutablePath='')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$runtime = Join-Path $root 'runtime'
$port = 11435
if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) {
    throw "El puerto $port ya está ocupado; no se reutiliza ni interrumpe su propietario."
}
$exe = if ($ExecutablePath) { (Get-Item -LiteralPath $ExecutablePath).FullName } else { (Get-Command ollama -CommandType Application).Source }
# --version consulta el servicio: dirigirlo al puerto propio aún libre para
# comprobar la versión cliente, sin confundirla con la del servicio habitual.
$versionHost=[Environment]::GetEnvironmentVariable('OLLAMA_HOST','Process')
try {
    [Environment]::SetEnvironmentVariable('OLLAMA_HOST','127.0.0.1:11435','Process')
    $version = (& $exe --version 2>&1 | Out-String).Trim()
} finally { [Environment]::SetEnvironmentVariable('OLLAMA_HOST',$versionHost,'Process') }
if ($version -notmatch '(?m)^(?:ollama version is|Warning: client version is) 0\.40\.3\s*$') { throw "Runtime distinto de la referencia 0.40.3: $version" }
New-Item -ItemType Directory -Force -Path $runtime, (Join-Path $root 'models/ollama') | Out-Null
$settings = @{
    OLLAMA_HOST = '127.0.0.1:11435'
    OLLAMA_MODELS = (Join-Path $root 'models/ollama')
    OLLAMA_NUM_PARALLEL = '1'
    OLLAMA_MAX_LOADED_MODELS = '1'
    OLLAMA_CONTEXT_LENGTH = '2048'
    OLLAMA_KEEP_ALIVE = '5m'
    OLLAMA_NO_CLOUD = '1'
}
$previous = @{}
try {
    foreach ($key in $settings.Keys) {
        $previous[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        [Environment]::SetEnvironmentVariable($key, $settings[$key], 'Process')
    }
    $process = Start-Process -FilePath $exe -ArgumentList 'serve' -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'server.stdout.log') -RedirectStandardError (Join-Path $runtime 'server.stderr.log')
} finally {
    foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process') }
}
@{pid=$process.Id; start_time=$process.StartTime.ToUniversalTime().ToString('o'); executable=$exe; settings=$settings} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $runtime 'server.json') -Encoding utf8
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Seconds 1
    $process.Refresh()
    if ($process.HasExited) { throw 'Ollama terminó; consultar runtime/server.stderr.log.' }
    try {
        $apiVersion = Invoke-RestMethod 'http://127.0.0.1:11435/api/version' -TimeoutSec 2
        $listener = Get-NetTCPConnection -State Listen -LocalPort $port
        if ($listener.OwningProcess -ne $process.Id) { throw 'El puerto pertenece a otro proceso.' }
        if ($apiVersion.version -ne '0.40.3') { throw 'Versión inesperada de la API.' }
        Write-Output "Ollama $($apiVersion.version), PID $($process.Id), http://127.0.0.1:11435"
        return
    } catch { if ($attempt -eq 29) { throw } }
}
