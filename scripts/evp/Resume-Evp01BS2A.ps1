param([Parameter(Mandatory=$true)][string]$TargetSha,[string]$Root=(Join-Path $HOME 'Desktop\Zenith IT\Evolua'))
$ErrorActionPreference='Stop'
$stage='PREFLIGHT'
$repo=Join-Path $Root 'evolua-private-core'
$base='cd3538073cae1c769aec4b71742f3c9af606ae83'
$branch='feat/evp-private-core'
$previous=Join-Path $Root '_evidence\evp01b-s2a-20261127-211727-021'
$probe=Join-Path $previous 'evp_cipher_probe'
$evidence=Join-Path $Root ('_evidence\evp01b-s2a-r1-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$paths=@('docs/engineering/EVP-01B_S2A_R1_BUILD_SPLIT.md','tools/evp/sqlcipher_probe/driver.dart.txt','scripts/evp/Resume-Evp01BS2A.ps1')
function GitChecked([string[]]$ArgsList) {
    $result=& git -C $repo @ArgsList
    if($LASTEXITCODE -ne 0){throw "Git failed: $($ArgsList[0]) EXITCODE=$LASTEXITCODE"}
    return $result
}
function Clean {
    if(@(GitChecked @('status','--porcelain=v1','--untracked-files=all')).Count){throw 'Worktree not clean'}
}
function SameFile([string]$A,[string]$B) {
    if(!(Test-Path -LiteralPath $A -PathType Leaf) -or !(Test-Path -LiteralPath $B -PathType Leaf)){throw 'Required preserved file missing'}
    if((Get-FileHash -LiteralPath $A -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $B -Algorithm SHA256).Hash){throw "Preserved file differs: $A"}
}
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
    if(!(Test-Path -LiteralPath $probe -PathType Container)){throw 'Missing original probe; do not regenerate'}
    if((GitChecked @('branch','--show-current')) -ne $branch){throw 'Wrong branch'}
    if((GitChecked @('remote','get-url','origin')) -notmatch '^(https://github\.com/|git@github\.com:)allandesenv/evolua-frontend(\.git)?$'){throw 'Wrong origin'}
    Clean
    Get-Command flutter -ErrorAction Stop | Out-Null
    $before=GitChecked @('rev-parse','HEAD')
    if($before -ne $base -and $before -ne $TargetSha){throw 'Unexpected local HEAD'}
    New-Item -ItemType Directory -Path $evidence -Force | Out-Null
    $stage='GRADLE_HOST_PREFLIGHT'
    $wrappers=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^java(w)?\.exe$' -and $_.CommandLine -match 'org\.gradle\.wrapper\.GradleWrapperMain'})
    if($wrappers.Count){throw ('Active Gradle wrapper PIDs: '+(($wrappers | Select-Object -ExpandProperty ProcessId) -join ',')+'; allow existing build to finish before resuming')}
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
    $stage='REUSE_VERIFIED_PROBE'
    $templates=Join-Path $repo 'tools\evp\sqlcipher_probe'
    SameFile (Join-Path $templates 'pubspec.yaml.txt') (Join-Path $probe 'pubspec.yaml')
    SameFile (Join-Path $templates 'native_test.dart.txt') (Join-Path $probe 'integration_test\native_test.dart')
    SameFile (Join-Path $previous 'probe-pubspec.lock') (Join-Path $probe 'pubspec.lock')
    if(!(Select-String -LiteralPath (Join-Path $previous 'probe-analyze.log') -SimpleMatch 'No issues found!')){throw 'Prior analyze success marker missing'}
    $gradle=Join-Path $probe 'android\app\build.gradle.kts'
    if(!(Select-String -LiteralPath $gradle -Pattern 'applicationId\s*=\s*"br\.com\.zenithit\.evpqa\.evp_cipher_probe"')){throw 'Unexpected probe application ID'}
    $driverFolder=Join-Path $probe 'test_driver'
    if(!(Test-Path -LiteralPath $driverFolder)){New-Item -ItemType Directory -Path $driverFolder | Out-Null}
    $driver=Join-Path $driverFolder 'integration_test.dart'
    if(!(Test-Path -LiteralPath $driver)){Copy-Item -LiteralPath (Join-Path $templates 'driver.dart.txt') -Destination $driver}
    SameFile (Join-Path $templates 'driver.dart.txt') $driver
    Write-Host 'PRIOR_PREPARATION=GREEN_REUSED; S1=GREEN_REUSED'
    Push-Location -LiteralPath $probe
    try {
        $stage='PROBE_APK_BUILD'
        Write-Host "ETAPA=$stage"
        $timer=[Diagnostics.Stopwatch]::StartNew()
        FlutterChecked @('build','apk','--debug','--no-pub','--target=integration_test/native_test.dart') 'probe-build.log'
        $timer.Stop()
        $buildSeconds=[math]::Round($timer.Elapsed.TotalSeconds,1)
        $apk=Join-Path $probe 'build\app\outputs\flutter-apk\app-debug.apk'
        if(!(Test-Path -LiteralPath $apk -PathType Leaf)){throw 'APK missing after successful build'}
        $apkHash=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
        Write-Host "APK_SHA256=$apkHash"
        Write-Host "BUILD_SECONDS=$buildSeconds"
        SameFile (Join-Path $previous 'probe-pubspec.lock') (Join-Path $probe 'pubspec.lock')
        $stage='PROBE_PREBUILT_DEVICE_TEST'
        Write-Host "ETAPA=$stage"
        FlutterChecked @('drive','--debug','--no-pub','--driver=test_driver/integration_test.dart','--target=integration_test/native_test.dart',("--use-application-binary="+$apk),'-d',$device,'--timeout=600') 'probe-drive.log'
        if((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash -ne $apkHash){throw 'APK changed during device execution'}
        $log=Join-Path $evidence 'probe-drive.log'
        if(!(Select-String -LiteralPath $log -SimpleMatch 'EVP_S2_NATIVE_CHECKS=PASS')){throw 'Native completion marker missing; inspect drive log'}
        if(!(Select-String -LiteralPath $log -SimpleMatch 'All tests passed')){throw 'Driver success marker missing; inspect drive log'}
        $metrics=@(Select-String -LiteralPath $log -Pattern 'EVP_S2_[A-Z0-9_]+=[^ ]+' -AllMatches | ForEach-Object {$_.Matches.Value})
    } finally {Pop-Location}
    Clean
    $result=@('VERDICT=PASS_EVP01B_S2A_NATIVE_PROBE',"HEAD=$TargetSha",'S1=GREEN_REUSED','PREPARATION=GREEN_REUSED','MODE=DEBUG_OBSERVATIONAL',"APK_SHA256=$apkHash","BUILD_SECONDS=$buildSeconds",'PRODUCTION_BUILD=NOT_RUN','PRODUCTION=UNCHANGED','RELEASE=NO_GO')+$metrics
    $result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8
    $result | Out-Host
    Write-Host "RESULTADO=$evidence\RESULTADO.txt"
} catch {
    $result=@('VERDICT=NO_GO',"ETAPA=$stage","ERRO=$($_.Exception.Message)","LINHA=$($_.InvocationInfo.ScriptLineNumber)",'NEXT=Send output and relevant sanitized log; preserve evidence and do not reset/clean/retry blindly')
    if(Test-Path -LiteralPath $evidence){$result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8}
    $result | Out-Host
    throw
}
