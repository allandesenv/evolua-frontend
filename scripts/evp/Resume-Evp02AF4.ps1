param([Parameter(Mandatory=$true)][string]$TargetSha,[string]$Root=(Join-Path $HOME 'Desktop\Zenith IT\Evolua'))
$ErrorActionPreference='Stop'
$stage='PREFLIGHT'
$repo=Join-Path $Root 'evolua-private-core'
$base='edc4c91f9b3459539b10d38dc80a942d682c30cb'
$failedHead='5178c4f14a91bf35b2c42873cc07209cb14616e7'
$branch='feat/evp-private-core'
$previous=Join-Path $Root '_evidence\evp02a-f4-20261128-002432-976'
$evidence=Join-Path $Root ('_evidence\evp02a-f4-r1-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$probe=Join-Path $previous 'evp_store_probe'
$paths=@('android/app/src/main/kotlin/com/example/evolua_frontend/PrivateStoreChannel.kt','scripts/evp/Resume-Evp02AF4.ps1','docs/engineering/EVP-02A_F4_R1_SCHEMA_VERSION.md','docs/engineering/EVP_CONTINUITY_WORKFLOW.md')
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
function Assert-DiskCapacity {
    $gradleHome=if($env:GRADLE_USER_HOME){$env:GRADLE_USER_HOME}else{Join-Path $HOME '.gradle'}
    $pubHome=if($env:PUB_CACHE){$env:PUB_CACHE}else{Join-Path $env:LOCALAPPDATA 'Pub\Cache'}
    $sdkHome=if($env:ANDROID_HOME){$env:ANDROID_HOME}elseif($env:ANDROID_SDK_ROOT){$env:ANDROID_SDK_ROOT}else{Join-Path $env:LOCALAPPDATA 'Android\sdk'}
    $locations=@(
        @{Role='PROBE';Path=$probe;MinimumGiB=12}
        @{Role='TEMP';Path=[IO.Path]::GetTempPath();MinimumGiB=12}
        @{Role='GRADLE';Path=$gradleHome;MinimumGiB=12}
        @{Role='PUB';Path=$pubHome;MinimumGiB=4}
        @{Role='ANDROID_SDK';Path=$sdkHome;MinimumGiB=4}
    )
    $shortfalls=@()
    foreach($location in $locations) {
        $volume=[IO.Path]::GetPathRoot([IO.Path]::GetFullPath($location.Path))
        $drive=[IO.DriveInfo]::new($volume)
        if(!$drive.IsReady){throw "Drive not ready: $volume"}
        $free=$drive.AvailableFreeSpace
        $freeGiB=[math]::Round($free/1GB,2)
        $minBytes=$location.MinimumGiB*1GB
        $line="DISK_ROLE=$($location.Role) VOLUME=$volume FREE_GIB=$freeGiB MIN_GIB=$($location.MinimumGiB)"
        $line | Tee-Object -FilePath (Join-Path $evidence 'disk-preflight.log') -Append | Out-Host
        if($free -lt $minBytes){$shortfalls+=("$($location.Role): $volume $freeGiB GiB free")}
    }
    if($shortfalls.Count){throw ('Insufficient disk capacity: '+($shortfalls -join '; ')+'. Free space without deleting the probe or evidence; recommend 20 GiB on build volumes.')}
    Write-Host 'DISK_PREFLIGHT=PASS'
}
function FlutterChecked([string[]]$ArgsList,[string]$Log) {
    $old=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        & flutter @ArgsList 2>&1 | ForEach-Object {"$_"} | Tee-Object -FilePath (Join-Path $evidence $Log) | Out-Host
        $rc=$LASTEXITCODE
    } finally {$ErrorActionPreference=$old}
    if($rc -ne 0){
        $logPath=Join-Path $evidence $Log
        if(Test-Path -LiteralPath $logPath){
            Write-Host 'ROOT_DIAGNOSTICS_BEGIN'
            $matchesFound=@(Select-String -LiteralPath $logPath -Pattern '^\s*(e:|error:|Error:|FAILURE:|Caused by:|Exception:|\* What went wrong:|Execution failed for task|>\s+A failure occurred|>\s+Compilation error|.*Unresolved reference|.*No space left|.*Could not resolve)' -Context 0,2 | Select-Object -First 30)
            if($matchesFound.Count){$matchesFound | ForEach-Object {$_.ToString()} | Out-Host}
            else{Get-Content -LiteralPath $logPath -Tail 50 | Out-Host}
            Write-Host 'ROOT_DIAGNOSTICS_END'
        }
        throw "Flutter failed: $($ArgsList[0]) EXITCODE=$rc"
    }
}
try {
    if($TargetSha -notmatch '^[0-9a-f]{40}$'){throw 'Full target SHA required'}
    if(!(Test-Path -LiteralPath $repo -PathType Container)){throw 'Missing feature worktree'}
    if((GitChecked @('branch','--show-current')) -ne $branch){throw 'Wrong branch'}
    if((GitChecked @('remote','get-url','origin')) -notmatch '^(https://github\.com/|git@github\.com:)allandesenv/evolua-frontend(\.git)?$'){throw 'Wrong origin'}
    Clean
    Get-Command flutter -ErrorAction Stop | Out-Null
    $before=GitChecked @('rev-parse','HEAD')
    if($before -ne $failedHead -and $before -ne $TargetSha){throw 'Unexpected local HEAD'}
    New-Item -ItemType Directory -Path $evidence -Force | Out-Null
    $stage='DISK_PREFLIGHT'
    Assert-DiskCapacity
    $stage='GRADLE_HOST_PREFLIGHT'
    function Get-ActiveWrappers {
        @(Get-CimInstance Win32_Process | Where-Object {
            ($_.Name -eq 'java.exe' -or $_.Name -eq 'javaw.exe') -and
            $_.CommandLine -match 'org\.gradle\.wrapper\.GradleWrapperMain'
        })
    }
    $hostWait=[Diagnostics.Stopwatch]::StartNew()
    $hostLog=Join-Path $evidence 'gradle-host-wait.log'
    $lastReport=-30
    $wrappers=@(Get-ActiveWrappers)
    while($wrappers.Count -gt 0) {
        $elapsed=[int]$hostWait.Elapsed.TotalSeconds
        if($elapsed-$lastReport -ge 30) {
            foreach($wrapper in $wrappers) {
                $proc=Get-Process -Id $wrapper.ProcessId -ErrorAction SilentlyContinue
                $parent=Get-Process -Id $wrapper.ParentProcessId -ErrorAction SilentlyContinue
                $ownership='UNKNOWN_OR_OTHER'
                if($wrapper.CommandLine -and $wrapper.CommandLine.Replace('/','\').IndexOf($probe,[StringComparison]::OrdinalIgnoreCase) -ge 0){$ownership='PROBE_PATH_MATCH'}
                $cpu=if($proc){[math]::Round($proc.CPU,2)}else{'EXITED'}
                $parentName=if($parent){$parent.ProcessName}else{'EXITED'}
                $line="GRADLE_WAIT_SECONDS=$elapsed PID=$($wrapper.ProcessId) PARENT=$($wrapper.ParentProcessId) PARENT_NAME=$parentName OWNER=$ownership CPU_SECONDS=$cpu"
                $line | Tee-Object -FilePath $hostLog -Append | Out-Host
            }
            $lastReport=$elapsed
        }
        if($elapsed -ge 600){throw 'Gradle wrapper still active after bounded wait; inspect gradle-host-wait.log. No process was terminated.'}
        Start-Sleep -Seconds 5
        $wrappers=@(Get-ActiveWrappers)
    }
    Write-Host "GRADLE_HOST_READY=PASS WAIT_SECONDS=$([int]$hostWait.Elapsed.TotalSeconds)"
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
    if((GitChecked @('rev-parse',($TargetSha+'^'))) -ne $failedHead){throw 'Unexpected target parent'}
    if(@(Compare-Object @($paths|Sort-Object) @(GitChecked @('diff','--name-only',$failedHead,$TargetSha)|Sort-Object)).Count){throw 'Allowlist mismatch'}
    if($before -ne $TargetSha){GitChecked @('merge','--ff-only',$TargetSha) | Out-Host}
    if((GitChecked @('rev-parse','HEAD')) -ne $TargetSha){throw 'Sync mismatch'}
    Clean
    $stage='F3_GREEN_EVIDENCE'
    $prior=Join-Path $Root '_evidence\evp02a-f3-r2-20261128-001022-882\RESULTADO.txt'
    $receipt=@(Get-Content -LiteralPath $prior)
    foreach($marker in @('VERDICT=PASS_EVP02A_F3_ARTIFACT_GATE',"HEAD=$base",'OFFLINE_GRAPH=PASS_ARM64_SCOPED','AAR_SHA256=1E57857ADFD29E2F5DDB4686E1E5EC6659920220D4BF182FDB5EF085B5577100')){
        if($receipt -notcontains $marker){throw "F3 evidence missing: $marker"}
    }
    $gradleHome=if($env:GRADLE_USER_HOME){$env:GRADLE_USER_HOME}else{Join-Path $HOME '.gradle'}
    $aars=@(Get-ChildItem -LiteralPath (Join-Path $gradleHome 'caches\modules-2\files-2.1\net.zetetic\sqlcipher-android\4.20.0') -Recurse -File -Filter 'sqlcipher-android-4.20.0.aar')
    if($aars.Count -ne 1 -or (Get-FileHash -LiteralPath $aars[0].FullName -Algorithm SHA256).Hash -ne '1E57857ADFD29E2F5DDB4686E1E5EC6659920220D4BF182FDB5EF085B5577100'){throw 'Approved AAR identity mismatch'}
    $stage='REUSE_F4_PREPARATION'
    $oldReceipt=@(Get-Content -LiteralPath (Join-Path $previous 'RESULTADO.txt'))
    if($oldReceipt -notcontains 'ETAPA=PROBE_APK_BUILD' -or $oldReceipt -notcontains 'ERRO=Flutter failed: build EXITCODE=1'){throw 'Original F4 receipt mismatch'}
    $oldBuild=Join-Path $previous 'probe-build.log'
    if(!(Select-String -LiteralPath $oldBuild -Pattern "PrivateStoreChannel\.kt:123:28 Unresolved reference 'setVersion'")){throw 'Original Kotlin diagnostic missing'}
    $hostTest=Join-Path $previous 'host-test.log'
    $hostAnalyze=Join-Path $previous 'host-analyze.log'
    $probeAnalyze=Join-Path $previous 'profile-analyze.log'
    if(!(Select-String -LiteralPath $hostTest -Pattern '\+5:\s*All tests passed!')){throw 'Host five-test PASS missing'}
    foreach($logPath in @($hostAnalyze,$probeAnalyze)){if(!(Select-String -LiteralPath $logPath -SimpleMatch 'No issues found!')){throw 'Prior analyzer PASS missing'}}
    $hostTestHash=(Get-FileHash -LiteralPath $hostTest -Algorithm SHA256).Hash
    $hostAnalyzeHash=(Get-FileHash -LiteralPath $hostAnalyze -Algorithm SHA256).Hash
    $probeAnalyzeHash=(Get-FileHash -LiteralPath $probeAnalyze -Algorithm SHA256).Hash
    $oldBuildHash=(Get-FileHash -LiteralPath $oldBuild -Algorithm SHA256).Hash
    $templates=Join-Path $repo 'tools\evp\store_probe'
    $gradle=Join-Path $probe 'android\app\build.gradle.kts'
    if(!(Select-String -LiteralPath $gradle -Pattern 'applicationId\s*=\s*"br\.com\.zenithit\.evpqa\.evp_store_probe"')){throw 'Unexpected probe application ID'}
    $gradleText=Get-Content -LiteralPath $gradle -Raw
    if($gradleText -notmatch 'implementation\("net\.zetetic:sqlcipher-android:4\.20\.0"\)' -or $gradleText -notmatch 'strictly\("4\.20\.0"\)' -or $gradleText -notmatch 'implementation\("androidx\.sqlite:sqlite:2\.7\.0"\)'){throw 'Probe dependency declaration changed'}
    $main=Join-Path $probe 'android\app\src\main\kotlin\br\com\zenithit\evpqa\evp_store_probe\MainActivity.kt'
    SameFile (Join-Path $templates 'MainActivity.kt.txt') $main
    SameFile (Join-Path $templates 'pubspec.yaml.txt') (Join-Path $probe 'pubspec.yaml')
    SameFile (Join-Path $templates 'native_test.dart.txt') (Join-Path $probe 'integration_test\native_test.dart')
    SameFile (Join-Path $repo 'tools\evp\sqlcipher_probe\driver.dart.txt') (Join-Path $probe 'test_driver\integration_test.dart')
    foreach($name in @('private_store.dart','private_key_envelope.dart')){
        SameFile (Join-Path $repo ('lib\core\private_core\'+$name)) (Join-Path $probe ('lib\'+$name))
    }
    $lock=Join-Path $probe 'pubspec.lock'
    SameFile (Join-Path $previous 'probe-pubspec.lock') $lock
    $manifest=Join-Path $probe 'android\app\src\main\AndroidManifest.xml'
    [xml]$xml=Get-Content -LiteralPath $manifest -Raw
    if($xml.SelectSingleNode('/manifest/application').GetAttribute('allowBackup','http://schemas.android.com/apk/res/android') -ne 'false'){throw 'Probe backup protection changed'}
    $stage='SYNC_FOCAL_NATIVE_SOURCE'
    $nativeRelative='android/app/src/main/kotlin/com/example/evolua_frontend/PrivateStoreChannel.kt'
    $nativeSource=Join-Path $repo $nativeRelative
    $nativeDestination=Join-Path $probe $nativeRelative
    $oldBlob=GitChecked @('rev-parse',($failedHead+':'+$nativeRelative))
    $newBlob=GitChecked @('rev-parse',($TargetSha+':'+$nativeRelative))
    $scratchBlob=GitChecked @('hash-object',('--path='+$nativeRelative),$nativeDestination)
    if($scratchBlob -ne $oldBlob -and $scratchBlob -ne $newBlob){throw 'Scratch native source unexpectedly modified'}
    if($scratchBlob -eq $oldBlob){
        Copy-Item -LiteralPath $nativeDestination -Destination (Join-Path $evidence 'PrivateStoreChannel.before.kt.txt')
        Copy-Item -LiteralPath $nativeSource -Destination $nativeDestination -Force
    }
    SameFile $nativeSource $nativeDestination
    Write-Host 'HOST_TESTS=GREEN_REUSED_5_OF_5'
    Write-Host 'HOST_ANALYZE=GREEN_REUSED'
    Write-Host 'PROBE_ANALYZE=GREEN_REUSED'
    Write-Host 'PROBE_PREPARATION=GREEN_REUSED'
    Write-Host 'NATIVE_SOURCE=FOCAL_SYNC_PASS'
    Push-Location -LiteralPath $probe
    try {
        $stage='DISK_PREFLIGHT_BEFORE_BUILD'
        Assert-DiskCapacity
        $stage='PROBE_APK_BUILD'
        if(@(Get-ActiveWrappers).Count){throw 'Another Gradle wrapper started after host preflight; concurrent build prevented'}
        Write-Host "ETAPA=$stage"
        $timer=[Diagnostics.Stopwatch]::StartNew()
        FlutterChecked @('build','apk','--profile','--no-pub','--target-platform=android-arm64','--target=integration_test/native_test.dart') 'probe-build.log'
        $timer.Stop()
        $buildSeconds=[math]::Round($timer.Elapsed.TotalSeconds,1)
        $apk=Join-Path $probe 'build\app\outputs\flutter-apk\app-profile.apk'
        if(!(Test-Path -LiteralPath $apk -PathType Leaf)){throw 'APK missing after successful build'}
        $apkHash=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
        Write-Host "APK_SHA256=$apkHash"
        Write-Host "BUILD_SECONDS=$buildSeconds"
        @("HEAD=$TargetSha","APK_SHA256=$apkHash","BUILD_SECONDS=$buildSeconds",'HOST_TESTS=GREEN_REUSED_5_OF_5','HOST_ANALYZE=GREEN_REUSED','PROBE_ANALYZE=GREEN_REUSED','BUILD=PASS') | Set-Content -LiteralPath (Join-Path $evidence 'BUILD_CHECKPOINT.txt') -Encoding UTF8
        SameFile (Join-Path $previous 'probe-pubspec.lock') $lock
        $stage='PROBE_PREBUILT_DEVICE_TEST'
        Write-Host "ETAPA=$stage"
        FlutterChecked @('drive','--profile','--no-pub','--driver=test_driver/integration_test.dart','--target=integration_test/native_test.dart',("--use-application-binary="+$apk),'-d',$device,'--timeout=600') 'probe-drive.log'
        if((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash -ne $apkHash){throw 'APK changed during device execution'}
        $log=Join-Path $evidence 'probe-drive.log'
        if(!(Select-String -LiteralPath $log -SimpleMatch 'EVP_F4_NATIVE_CHECKS=PASS')){throw 'Native completion marker missing; inspect drive log'}
        if(!(Select-String -LiteralPath $log -SimpleMatch 'All tests passed')){throw 'Driver success marker missing; inspect drive log'}
        $metrics=@(Select-String -LiteralPath $log -Pattern 'EVP_F4_[A-Z0-9_]+=[^ ]+' -AllMatches | ForEach-Object {$_.Matches.Value})
    } finally {Pop-Location}
    Clean
    $result=@('VERDICT=PASS_EVP02A_F4_ISOLATED_PRIVATE_STORE',"HEAD=$TargetSha",'S1=GREEN_REUSED','S2A=GREEN_REUSED','S2B=GREEN_REUSED','S3A=GREEN_REUSED','S3B=GREEN_REUSED','F1=GREEN_REUSED','F2=GREEN_REUSED','F3=GREEN_REUSED','HOST_TESTS=GREEN_REUSED_5_OF_5','HOST_ANALYZE=GREEN_REUSED','PROBE_ANALYZE=GREEN_REUSED','PROBE_PREPARATION=GREEN_REUSED',"HOST_TEST_LOG_SHA256=$hostTestHash","HOST_ANALYZE_LOG_SHA256=$hostAnalyzeHash","PROBE_ANALYZE_LOG_SHA256=$probeAnalyzeHash","ORIGINAL_BUILD_LOG_SHA256=$oldBuildHash",'FEATURE_GATE=OFF','MODE=PROFILE_ARM64',"APK_SHA256=$apkHash","BUILD_SECONDS=$buildSeconds",'PRODUCTION_BUILD=NOT_RUN','PRODUCTION=UNCHANGED','RELEASE=NO_GO')+$metrics
    $result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8
    $result | Out-Host
    Write-Host "RESULTADO=$evidence\RESULTADO.txt"
} catch {
    $result=@('VERDICT=NO_GO',"ETAPA=$stage","ERRO=$($_.Exception.Message)","LINHA=$($_.InvocationInfo.ScriptLineNumber)",'NEXT=Send output and relevant sanitized log; preserve evidence and do not reset/clean/retry blindly')
    if(Test-Path -LiteralPath $evidence){$result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8}
    $result | Out-Host
    Write-Host "RESULTADO=$evidence\RESULTADO.txt"
    throw
}
