param([Parameter(Mandatory=$true)][string]$TargetSha,[string]$Root=(Join-Path $HOME 'Desktop\Zenith IT\Evolua'))
$ErrorActionPreference='Stop'
$stage='PREFLIGHT'
$repo=Join-Path $Root 'evolua-private-core'
$initial='6752fd12b17670ab20ed52707e071b3ed0527fc3'
$branch='feat/evp-private-core'
$paths=@('docs/engineering/EVP_CONTINUITY_WORKFLOW.md','docs/engineering/EVP-01B_S1_INVENTORY.md','test/evp/private_crypto_spike_test.dart','scripts/evp/Test-Evp01BS1.ps1')
$evidence=Join-Path $Root ('_evidence\evp01b-s1-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
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
    $stage='SYNC'
    if($before -ne $TargetSha){GitChecked @('merge','--ff-only',$TargetSha) | Out-Host}
    if((GitChecked @('rev-parse','HEAD')) -ne $TargetSha){throw 'Sync mismatch'}
    Clean
    Push-Location -LiteralPath $repo
    try {
        $stage='TOOLCHAIN'
        RunFlutter @('--version') 'flutter-version.log'
        $stage='LOCKED_DEPENDENCIES'
        RunFlutter @('pub','get','--enforce-lockfile') 'pub-get.log'
        Clean
        $stage='FOCUSED_TEST'
        RunFlutter @('test','--no-pub','test/evp/private_crypto_spike_test.dart','--reporter','expanded') 'crypto-test.log'
        $stage='FOCUSED_ANALYZE'
        RunFlutter @('analyze','--no-pub','test/evp/private_crypto_spike_test.dart') 'crypto-analyze.log'
        Clean
    } finally {Pop-Location}
    $result=@('VERDICT=PASS_EVP01B_S1_FOCUSED',"HEAD=$TargetSha","HEAD_BEFORE=$before",'SCOPE=CRYPTO_SPIKE_ONLY','BUILD=NOT_RUN','PRODUCTION=UNCHANGED','RELEASE=NO_GO')
    $result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8
    $result | Out-Host
    Write-Host "RESULTADO=$evidence\RESULTADO.txt"
} catch {
    $result=@('VERDICT=NO_GO',"ETAPA=$stage","ERRO=$($_.Exception.Message)","LINHA=$($_.InvocationInfo.ScriptLineNumber)",'NEXT=Send output and relevant sanitized log; do not reset/clean/retry blindly')
    if(Test-Path -LiteralPath $evidence){$result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8}
    $result | Out-Host
    throw
}
