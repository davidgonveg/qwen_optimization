#requires -Version 7.4
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Benchmark.Common.ps1')
$ok=@{error=$null;final=@{done=$true;done_reason='stop'}}
$task=@{scorer='json_exact';expected=@{n=7;a=@(2,4)}}
$cases=@(
    @{text='{"a":[2,4],"n":7}';pass=$true},
    @{text='{"n":7.0,"a":[2,4]}';pass=$true},
    @{text='{"n":"7","a":[2,4]}';pass=$false},
    @{text='{"n":7,"a":[4,2]}';pass=$false},
    @{text='{"n":7,"a":[2,4],"extra":1}';pass=$false},
    @{text='{"n":7,"n":8,"a":[2,4]}';pass=$false},
    @{text='{"N":7,"a":[2,4]}';pass=$false},
    @{text='```json {"n":7,"a":[2,4]} ```';pass=$false},
    @{text='{"n":7,"a":[2,4]} trailing';pass=$false}
)
foreach ($case in $cases) { if ((Get-QualityScore $task $case.text $ok).pass -ne $case.pass) { throw "Scorer falla: $($case.text)" } }
if ((Get-QualityScore $task '{"n":7,"a":[2,4]}' @{error=$null;final=@{done=$true;done_reason='length'}}).status -ne 'invalid') { throw 'Truncamiento calificado como válido' }
if ((Get-QualityScore @{scorer='exact';expected='sí'} 'Sí' $ok).pass) { throw 'Exactitud dejó de ser sensible a mayúsculas' }
if ((Get-QualityScore @{scorer='manual';rubric=@('criterio')} 'texto' $ok).status -ne 'pending_manual') { throw 'Rúbrica manual puntuada automáticamente' }
Write-Output '12 comprobaciones de extracción, tipos, duplicados, exactitud, truncamiento y revisión manual correctas.'
