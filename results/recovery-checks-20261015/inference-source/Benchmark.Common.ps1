#requires -Version 7.4
function Write-BenchmarkJson($Value, [string]$Path) {
    ConvertTo-Json -InputObject $Value -Depth 40 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Get-QualityScore($Task, [string]$Content, $Metric) {
    if ($Metric.error -or -not $Metric.final.done -or $Metric.final.done_reason -ne 'stop' -or [string]::IsNullOrWhiteSpace($Content)) {
        return @{status='invalid';pass=$false;reason='Error, incompleto, truncado o vacío'}
    }
    if ($Task.scorer -eq 'manual') { return @{status='pending_manual';pass=$null;rubric=$Task.rubric} }
    $pass = $false; $reason = $null
    if ($Task.scorer -eq 'exact') { $pass = $Content.Trim() -ceq $Task.expected }
    elseif ($Task.scorer -eq 'json_exact') {
        try {
            $document = [System.Text.Json.JsonDocument]::Parse($Content.Trim())
            try {
                $properties = @($document.RootElement.EnumerateObject())
                if (@($properties.Name | Sort-Object -Unique).Count -ne $properties.Count) { throw 'Claves duplicadas' }
                $actual = ConvertFrom-Json -InputObject $Content -AsHashtable
                $expected = $Task.expected
                # Comparación recursiva de valores JSON, independiente del orden de claves.
                $pass = Test-JsonValue $actual $expected
            } finally { $document.Dispose() }
        } catch { $reason = $_.Exception.Message }
    } else { throw "Scorer desconocido: $($Task.scorer)" }
    return @{status='scored';pass=$pass;reason=$reason;expected=$Task.expected}
}

function Test-JsonValue($Actual, $Expected) {
    if ($null -eq $Expected) { return $null -eq $Actual }
    if ($Expected -is [System.Collections.IDictionary]) {
        if ($Actual -isnot [System.Collections.IDictionary] -or $Actual.Count -ne $Expected.Count) { return $false }
        foreach ($key in $Expected.Keys) {
            if (-not @($Actual.Keys).Contains($key) -or -not (Test-JsonValue $Actual[$key] $Expected[$key])) { return $false }
        }
        return $true
    }
    if ($Expected -is [array]) {
        if ($Actual -isnot [array] -or $Actual.Count -ne $Expected.Count) { return $false }
        for ($i=0; $i -lt $Expected.Count; $i++) { if (-not (Test-JsonValue $Actual[$i] $Expected[$i])) { return $false } }
        return $true
    }
    if ($Expected -is [string]) { return $Actual -is [string] -and $Actual -ceq $Expected }
    if ($Expected -is [bool]) { return $Actual -is [bool] -and $Actual -eq $Expected }
    if ($Actual -is [string] -or $Actual -is [bool] -or $null -eq $Actual) { return $false }
    return $Actual -eq $Expected
}

function Invoke-BenchmarkRequest($Client, $Config, [string]$OutDir, $Sample, $Request, $SafetyCancellation=$null, [double]$TimeoutSeconds=0) {
    $id = $Sample.id
    $requestJson = ConvertTo-Json -InputObject $Request -Depth 15
    $requestJson | Set-Content (Join-Path $OutDir "$id-request.json") -Encoding utf8
    $psBefore = Invoke-RestMethod "$($Config.base_url)/api/ps"
    $writer = [IO.StreamWriter]::new((Join-Path $OutDir "$id-stream.jsonl"), $false, [Text.UTF8Encoding]::new($false))
    $writer.AutoFlush = $true
    $httpRequest = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, "$($Config.base_url)/api/chat")
    $httpRequest.Content = [Net.Http.StringContent]::new($requestJson,[Text.Encoding]::UTF8,'application/json')
    if ($TimeoutSeconds -le 0) { $TimeoutSeconds=$Config.request_timeout_seconds }
    $cancel = if ($SafetyCancellation) { [Threading.CancellationTokenSource]::CreateLinkedTokenSource($SafetyCancellation.Token) } else { [Threading.CancellationTokenSource]::new() }
    $cancel.CancelAfter([TimeSpan]::FromSeconds($TimeoutSeconds))
    $content = [Text.StringBuilder]::new(); $thinking = [Text.StringBuilder]::new()
    $firstChunk=$null; $firstContent=$null; $firstThinking=$null; $final=$null; $errorText=$null
    $response=$null; $reader=$null; $logprobsObserved=$false
    $started = [DateTime]::UtcNow.ToString('o')
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $response = $Client.SendAsync($httpRequest,[Net.Http.HttpCompletionOption]::ResponseHeadersRead,$cancel.Token).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode() | Out-Null
        $reader = [IO.StreamReader]::new($response.Content.ReadAsStreamAsync($cancel.Token).GetAwaiter().GetResult())
        while ($true) {
            $line=$reader.ReadLineAsync($cancel.Token).GetAwaiter().GetResult()
            if ($null -eq $line) { break }
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $elapsed=$watch.Elapsed.TotalSeconds
            # Conservar incluso una línea que no se pueda parsear.
            $writer.WriteLine((@{client_elapsed_seconds=$elapsed;raw=$line} | ConvertTo-Json -Compress))
            if ($null -eq $firstChunk) { $firstChunk=$elapsed }
            $chunk=$line | ConvertFrom-Json
            if ($chunk.error) { throw $chunk.error }
            if ($chunk.logprobs -or $chunk.message.logprobs) { $logprobsObserved=$true }
            if ($chunk.message.content) {
                if ($null -eq $firstContent) { $firstContent=$elapsed }
                $content.Append($chunk.message.content) | Out-Null
            }
            if ($chunk.message.thinking) {
                if ($null -eq $firstThinking) { $firstThinking=$elapsed }
                $thinking.Append($chunk.message.thinking) | Out-Null
            }
            if ($chunk.done) { $final=$chunk; break }
        }
        if ($null -eq $final) { throw 'Stream incompleto, sin done=true' }
    } catch { $errorText=$_.Exception.Message }
    finally {
        $watch.Stop(); $writer.Dispose()
        if ($reader) { $reader.Dispose() }; if ($response) { $response.Dispose() }
        $httpRequest.Dispose(); $cancel.Dispose()
    }
    [IO.File]::WriteAllText((Join-Path $OutDir "$id-response.txt"),$content.ToString(),[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $OutDir "$id-thinking.txt"),$thinking.ToString(),[Text.UTF8Encoding]::new($false))
    $speed=$null; $promptSpeed=$null; $ttft=$null
    if ($null -ne $final.eval_count -and $final.eval_duration -gt 0) { $speed=$final.eval_count/($final.eval_duration/1e9) }
    if ($null -ne $final.prompt_eval_cached_count -and $null -ne $final.prompt_eval_count -and $final.prompt_eval_count -ge $final.prompt_eval_cached_count -and $final.prompt_eval_duration -gt 0) {
        $promptSpeed=($final.prompt_eval_count-$final.prompt_eval_cached_count)/($final.prompt_eval_duration/1e9)
    }
    $firstText=@(@($firstContent,$firstThinking) | Where-Object { $null -ne $_ })
    if ($firstText.Count) { $ttft=($firstText | Measure-Object -Minimum).Minimum }
    $metric=@{sample=$Sample;started_at=$started;ended_at=[DateTime]::UtcNow.ToString('o');client_total_seconds=$watch.Elapsed.TotalSeconds;first_chunk_seconds=$firstChunk;first_content_seconds=$firstContent;first_thinking_seconds=$firstThinking;ttft_seconds=$ttft;tokens_per_second=$speed;uncached_prompt_tokens_per_second=$promptSpeed;final=$final;error=$errorText;truncated=($final.done_reason -eq 'length');content_characters=$content.Length;thinking_characters=$thinking.Length;logprobs_observed=$logprobsObserved;ps_before=$psBefore;ps_after=$null;ps_after_error=$null}
    try { $metric.ps_after=Invoke-RestMethod "$($Config.base_url)/api/ps" } catch { $metric.ps_after_error=$_.Exception.Message }
    Write-BenchmarkJson $metric (Join-Path $OutDir "$id-metrics.json")
    return $metric
}
