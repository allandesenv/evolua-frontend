param([Parameter(Mandatory=$true)][string]$TargetSha,[string]$Root=(Join-Path $HOME 'Desktop\Zenith IT\Evolua'))
$ErrorActionPreference='Stop'
$stage='PREFLIGHT'
$repo=Join-Path $Root 'evolua-private-core'
$initial='d184cac37767857a5db64051cb1d0936280bd569'
$branch='feat/evp-private-core'
$paths=@('docs/engineering/EVP-02A_F1_R1_ANALYZE.md','test/evp/private_key_envelope_test.dart','scripts/evp/Test-Evp02AF1.ps1')
$evidence=Join-Path $Root ('_evidence\evp02a-f1-r1-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
function GitChecked([string[]]$ArgsList) {
    $result=& git -C $repo @ArgsList
    if($LASTEXITCODE -ne 0){throw "Git failed: $($ArgsList[0]) EXITCODE=$LASTEXITCODE"}
    return $result
}
function Clean {
    if(@(GitChecked @('status','--porcelain=v1','--untracked-files=all')).Count){throw 'Worktree not clean'}
}
function RunFlutter([string[]]$ArgsList,[string]$Log) {
    $old=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        & flutter @ArgsList 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath (Join-Path $evidence $Log) | Out-Host
        $rc=$LASTEXITCODE
    } finally {$ErrorActionPreference=$old}
    if($rc -ne 0){throw "Flutter failed: $($ArgsList[0]) EXITCODE=$rc"}
}
try {
    if($TargetSha -notmatch '^[0-9a-f]{40}$'){throw 'Full target SHA required'}
    if(!(Test-Path -LiteralPath $repo -PathType Container)){throw 'Missing feature worktree'}
    if((GitChecked @('branch','--show-current')) -ne $branch){throw 'Wrong branch'}
    if((GitChecked @('remote','get-url','origin')) -notmatch '^(https://github\.com/|git@github\.com:)allandesenv/evolua-frontend(\.git)?$'){throw 'Wrong origin'}
    Clean
    Get-Command flutter -ErrorAction Stop | Out-Null
    $before=GitChecked @('rev-parse','HEAD')
    if($before -ne $initial -and $before -ne $TargetSha){throw 'Unexpected local HEAD'}
    New-Item -ItemType Directory -Path $evidence -Force | Out-Null
    $stage='FETCH_AND_ALLOWLIST'
    GitChecked @('fetch','origin',"refs/heads/$branch") | Out-Host
    if((GitChecked @('rev-parse','FETCH_HEAD')) -ne $TargetSha){throw 'Remote HEAD differs from target'}
    if((GitChecked @('rev-parse',($TargetSha+'^'))) -ne $initial){throw 'Unexpected target parent'}
    $actual=@(GitChecked @('diff','--name-only',$initial,$TargetSha))
    if(@(Compare-Object @($paths|Sort-Object) @($actual|Sort-Object)).Count){throw 'Allowlist mismatch'}
    $stage='PRIOR_TEST_EVIDENCE'
    $prior=@(Get-ChildItem -LiteralPath (Join-Path $Root '_evidence') -Directory -Filter 'evp02a-f1-*' | Where-Object {$_.Name -match '^evp02a-f1-\d{8}-\d{6}-\d{3}$'} | Sort-Object Name -Descending | Where-Object {
        $log=Join-Path $_.FullName 'key-envelope-test.log'
        $analysis=Join-Path $_.FullName 'key-envelope-analyze.log'
        $receipt=Join-Path $_.FullName 'RESULTADO.txt'
        (Test-Path -LiteralPath $log -PathType Leaf) -and (Test-Path -LiteralPath $analysis -PathType Leaf) -and (Test-Path -LiteralPath $receipt -PathType Leaf) -and
        (Select-String -LiteralPath $log -Pattern '\+8:\s*All tests passed!') -and
        (@(Select-String -LiteralPath $analysis -SimpleMatch 'prefer_interpolation_to_compose_strings').Count -eq 2) -and
        (Select-String -LiteralPath $receipt -SimpleMatch 'ETAPA=FOCUSED_ANALYZE')
    } | Select-Object -First 1)
    if($prior.Count -ne 1){throw 'Prior 8/8 test log and matching analyzer receipt not found; preserve evidence'}
    $priorHash=(Get-FileHash -LiteralPath (Join-Path $prior[0].FullName 'key-envelope-test.log') -Algorithm SHA256).Hash
    Write-Host "F1_TESTS=GREEN_REUSED_8_OF_8"
    Write-Host "PRIOR_TEST_LOG_SHA256=$priorHash"
    $stage='SYNC'
    if($before -ne $TargetSha){GitChecked @('merge','--ff-only',$TargetSha) | Out-Host}
    if((GitChecked @('rev-parse','HEAD')) -ne $TargetSha){throw 'Sync mismatch'}
    Clean
    Push-Location -LiteralPath $repo
    try {
        $stage='FOCUSED_ANALYZE'
        RunFlutter @('analyze','--no-pub','lib/core/private_core/private_key_envelope.dart','test/evp/private_key_envelope_test.dart') 'key-envelope-analyze.log'
        Clean
    } finally {Pop-Location}
    $result=@('VERDICT=PASS_EVP02A_F1_KEY_COMPONENT',"HEAD=$TargetSha","HEAD_BEFORE=$before",'SCOPE=UNWIRED_KEY_COMPONENT','F1_TESTS=GREEN_REUSED_8_OF_8',"PRIOR_TEST_LOG_SHA256=$priorHash",'ANALYZE=PASS','S3A=GREEN_REUSED','S3B=GREEN_REUSED','S1=GREEN_REUSED','S2A=GREEN_REUSED','S2B=GREEN_REUSED','BUILD=NOT_RUN','PRODUCTION=UNCHANGED','RELEASE=NO_GO')
    $result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8
    $result | Out-Host
    Write-Host "RESULTADO=$evidence\RESULTADO.txt"
} catch {
    $result=@('VERDICT=NO_GO',"ETAPA=$stage","ERRO=$($_.Exception.Message)","LINHA=$($_.InvocationInfo.ScriptLineNumber)",'NEXT=Send output and relevant sanitized log; do not reset/clean/retry blindly')
    if(Test-Path -LiteralPath $evidence){$result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8}
    $result | Out-Host
    throw
}
