param([Parameter(Mandatory=$true)][string]$TargetSha,[string]$Root=(Join-Path $HOME 'Desktop\Zenith IT\Evolua'))
$ErrorActionPreference='Stop'
$stage='PREFLIGHT'
$repo=Join-Path $Root 'evolua-private-core'
$base='4cae7c104f4f49edf65d2e8cda7f17b49f41538d'
$branch='feat/evp-private-core'
$paths=@('docs/engineering/EVP-01B_S2A_SQLCIPHER.md','tools/evp/sqlcipher_probe/pubspec.yaml.txt','tools/evp/sqlcipher_probe/native_test.dart.txt','scripts/evp/Test-Evp01BS2A.ps1')
$evidence=Join-Path $Root ('_evidence\evp01b-s2a-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$probe=Join-Path $evidence 'evp_cipher_probe'
function GitChecked([string[]]$ArgsList) {
    $result=& git -C $repo @ArgsList
    if($LASTEXITCODE -ne 0){throw "Git failed: $($ArgsList[0]) EXITCODE=$LASTEXITCODE"}
    return $result
}
function Clean {if(@(GitChecked @('status','--porcelain=v1','--untracked-files=all')).Count){throw 'Worktree not clean'}}
function FlutterChecked([string[]]$ArgsList,[string]$Log) {
    $old=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        & flutter @ArgsList 2>&1 | ForEach-Object {"$_"} | Tee-Object -FilePath (Join-Path $evidence $Log) | Out-Host
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
    if($before -ne $base -and $before -ne $TargetSha){throw 'Unexpected local HEAD'}
    New-Item -ItemType Directory -Path $evidence -Force | Out-Null
    $stage='ANDROID_DEVICE_PREFLIGHT'
    $raw=& flutter devices --machine
    if($LASTEXITCODE -ne 0){throw 'flutter devices failed'}
    $devices=@(($raw -join [Environment]::NewLine | ConvertFrom-Json) | Where-Object {$_.targetPlatform -like 'android-*' -and $_.emulator -eq $false -and $_.isSupported -ne $false})
    if($devices.Count -ne 1){throw 'Connect exactly one supported physical Android device via USB with debugging authorized'}
    $device=$devices[0].id
    Write-Host "DEVICE_NAME=$($devices[0].name)"
    $stage='FETCH_AND_ALLOWLIST'
    GitChecked @('fetch','origin',"refs/heads/$branch") | Out-Host
    if((GitChecked @('rev-parse','FETCH_HEAD')) -ne $TargetSha){throw 'Remote HEAD differs from target'}
    if((GitChecked @('rev-parse',($TargetSha+'^'))) -ne $base){throw 'Unexpected target parent'}
    if(@(Compare-Object @($paths|Sort-Object) @(GitChecked @('diff','--name-only',$base,$TargetSha)|Sort-Object)).Count){throw 'Allowlist mismatch'}
    if($before -ne $TargetSha){GitChecked @('merge','--ff-only',$TargetSha) | Out-Host}
    if((GitChecked @('rev-parse','HEAD')) -ne $TargetSha){throw 'Sync mismatch'}
    Clean
    $stage='ISOLATED_PROJECT'
    FlutterChecked @('--version') 'flutter-version.log'
    FlutterChecked @('create','--no-pub','--platforms=android','--org','br.com.zenithit.evpqa','--project-name','evp_cipher_probe',$probe) 'flutter-create.log'
    $gradle=Join-Path $probe 'android\app\build.gradle.kts'
    if(!(Test-Path -LiteralPath $gradle)){throw 'Unexpected generated Gradle format'}
    if(!(Select-String -LiteralPath $gradle -Pattern 'applicationId\s*=\s*"br\.com\.zenithit\.evpqa\.evp_cipher_probe"')){throw 'Unexpected probe application ID'}
    $templates=Join-Path $repo 'tools\evp\sqlcipher_probe'
    Copy-Item -LiteralPath (Join-Path $templates 'pubspec.yaml.txt') -Destination (Join-Path $probe 'pubspec.yaml')
    New-Item -ItemType Directory -Path (Join-Path $probe 'integration_test') | Out-Null
    Copy-Item -LiteralPath (Join-Path $templates 'native_test.dart.txt') -Destination (Join-Path $probe 'integration_test\native_test.dart')
    Push-Location -LiteralPath $probe
    try {
        $stage='PROBE_DEPENDENCIES'
        FlutterChecked @('pub','get') 'probe-pub-get.log'
        Copy-Item -LiteralPath (Join-Path $probe 'pubspec.lock') -Destination (Join-Path $evidence 'probe-pubspec.lock')
        $stage='PROBE_ANALYZE'
        FlutterChecked @('analyze','--no-pub','integration_test/native_test.dart') 'probe-analyze.log'
        $stage='PROBE_ANDROID_DEBUG'
        FlutterChecked @('test','--no-pub','integration_test/native_test.dart','-d',$device,'--reporter','expanded') 'probe-android.log'
        if(!(Select-String -LiteralPath (Join-Path $evidence 'probe-android.log') -SimpleMatch 'EVP_S2_NATIVE_CHECKS=PASS')){throw 'Native completion marker missing'}
    } finally {Pop-Location}
    Clean
    $metrics=@(Select-String -LiteralPath (Join-Path $evidence 'probe-android.log') -Pattern 'EVP_S2_[A-Z0-9_]+=[^ ]+' -AllMatches | ForEach-Object {$_.Matches.Value})
    $result=@('VERDICT=PASS_EVP01B_S2A_NATIVE_PROBE',"HEAD=$TargetSha",'S1=GREEN_REUSED','MODE=DEBUG_OBSERVATIONAL','PRODUCTION_BUILD=NOT_RUN','PRODUCTION=UNCHANGED','RELEASE=NO_GO')+$metrics
    $result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8
    $result | Out-Host
    Write-Host "RESULTADO=$evidence\RESULTADO.txt"
} catch {
    $result=@('VERDICT=NO_GO',"ETAPA=$stage","ERRO=$($_.Exception.Message)","LINHA=$($_.InvocationInfo.ScriptLineNumber)",'NEXT=Send output and sanitized relevant log; preserve evidence and do not reset/clean/retry blindly')
    if(Test-Path -LiteralPath $evidence){$result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8}
    $result | Out-Host
    throw
}
