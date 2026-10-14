#requires -Version 7.4
function Get-BenchmarkSchedule($Protocol, $Suite) {
    $samples=[Collections.Generic.List[object]]::new()
    $samples.Add(@{id='compatibility-nonresident';kind='compatibility';condition='nonresident-disk-cache-uncontrolled';prompt='Responde únicamente: listo';logprobs=$true})
    foreach ($task in $Suite.tasks) { $samples.Add(@{id=$task.id;kind='quality';condition='resident-quality';prompt=$task.prompt;task=$task}) }
    if ($Protocol.sustained) {
        foreach ($condition in $Protocol.conditions) {
            $samples.Add((New-LengthSample $Protocol $condition 0 'warmup'))
        }
        for ($i=1;$i -le $Protocol.repetitions;$i++) {
            $ordered=@($Protocol.conditions)
            if ($i % 2 -eq 0) { [array]::Reverse($ordered) }
            foreach ($condition in $ordered) { $samples.Add((New-LengthSample $Protocol $condition $i 'performance')) }
        }
    } else {
        foreach ($condition in $Protocol.conditions) {
            for ($i=0;$i -le $Protocol.repetitions;$i++) {
                $nonce=$condition.nonces[$i]
                $samples.Add(@{id=($condition.id+'-'+$i);kind=$(if ($i -eq 0) {'warmup'} else {'performance'});condition=$condition.id;repetition=$i;nonce=$nonce;prompt=($Protocol.prefix_template.Replace('{nonce}',$nonce)+$Protocol.performance_prompt)})
            }
        }
    }
    return @($samples)
}
function New-LengthSample($Protocol, $Condition, [int]$Repetition, [string]$Kind) {
    $nonce=($Condition.id+'-'+$Repetition.ToString('D3'))
    return @{id=$nonce;kind=$Kind;condition=$Condition.id;repetition=$Repetition;nonce=$nonce;prompt=($Protocol.prefix_template.Replace('{nonce}',$nonce)+$Protocol.padding_template+($Protocol.padding_unit*$Condition.padding_repeats)+$Protocol.performance_prompt)}
}
function Get-SafetyViolations($Sample, $Policy, [int]$SensorErrorStreak) {
    $reasons=@()
    if ($SensorErrorStreak -ge $Policy.max_consecutive_sensor_errors) { $reasons+='sensor_errors' }
    if ($null -ne $Sample.os.FreePhysicalMemory -and $Sample.os.FreePhysicalMemory -lt $Policy.min_free_ram_KiB) { $reasons+='ram_pressure' }
    if ($null -ne $Sample.gpu.memory_total_MiB -and $null -ne $Sample.gpu.memory_used_MiB -and ($Sample.gpu.memory_total_MiB -as [double]) -and ($Sample.gpu.memory_used_MiB -as [double])) {
        if (([double]$Sample.gpu.memory_total_MiB-[double]$Sample.gpu.memory_used_MiB) -lt $Policy.min_free_vram_MiB) { $reasons+='vram_pressure' }
    }
    if ($null -ne $Sample.gpu.temperature_C -and $Sample.gpu.temperature_C -ne '[N/A]' -and [double]$Sample.gpu.temperature_C -ge $Policy.max_gpu_temperature_C) { $reasons+='temperature' }
    return $reasons
}
