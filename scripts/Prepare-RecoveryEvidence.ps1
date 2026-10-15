#requires -Version 7.4
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
$root=Split-Path $PSScriptRoot -Parent
$dest=Join-Path $root 'results/recovery-checks-20261015'
if (Test-Path (Join-Path $dest 'preserved-before.json')) { throw 'Evidencia ya preparada' }
$old=@('results/phase1-20261014','results/smoke-20261014-reference','results/pilot-20261014-reference-v1','results/reduced-20261014-reference-v1','configs/reference.json')
$hashes=@($old | ForEach-Object {Get-ChildItem -LiteralPath (Join-Path $root $_) -Recurse -File} | Get-FileHash | Select-Object Path,Hash)
Write-BenchmarkJson $hashes (Join-Path $dest 'preserved-before.json')
$sources=@(
    @{repo='ollama/ollama';revision='eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21';paths=@('LLAMA_CPP_VERSION','llama/server/CMakeLists.txt','llm/llama_server.go')},
    @{repo='ggml-org/llama.cpp';revision='631109b34da437a3c4a5ebd75091d677671392e3';paths=@('common/common.h','tools/server/server-context.cpp')},
    @{repo='ggml-org/llama.cpp';revision='b42b7e6d3059503dd4bed6ca5dcf342bb6379f67';paths=@('common/common.h','tools/server/server-context.cpp')}
)
$records=@(foreach ($source in $sources) {
    foreach ($path in $source.paths) {
        $url="https://raw.githubusercontent.com/$($source.repo)/$($source.revision)/$path"
        $content=(Invoke-WebRequest $url).Content
        $sha=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($content))).ToLowerInvariant()
        @{url=$url;sha256_utf8_content=$sha;lines=($content -split "`n").Count;checked_at=[datetime]::UtcNow.ToString('o');relevant_lines=@(($content -split "`n") | Select-String -Pattern 'cache_ram_mib.*8192|LLAMA_CPP_GIT_TAG|prompt_cache = std::make_unique|prompt_save\(' | ForEach-Object {$_.LineNumber})}
    }
})
$exe=(Get-Command ollama -CommandType Application).Source
$helper=Join-Path (Split-Path $exe) 'lib/ollama/llama-server.exe'
Write-BenchmarkJson @{sources=$records;binary=@(Get-Item $exe,$helper | Get-FileHash | Select-Object Path,Hash);helper_version=(& $helper --version 2>&1 | Out-String);interpretation='Distribution pin b11351 vs binary advertised b42b7e6d3; exact build provenance not established; both pinned sources inspected, runtime unchanged'} (Join-Path $dest 'pinned-sources.json')
Write-Output 'Hashes históricos y fuentes fijadas guardados sin inferencia.'
