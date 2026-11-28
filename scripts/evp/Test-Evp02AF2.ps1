param([Parameter(Mandatory=$true)][string]$TargetSha,[string]$Root=(Join-Path $HOME 'Desktop\Zenith IT\Evolua'))
$ErrorActionPreference='Stop'
$stage='PREFLIGHT'
$repo=Join-Path $Root 'evolua-private-core'
$base='ffa06c5eb2307ad5fa1f73cbe2433d52db19c8d9'
$branch='feat/evp-private-core'
$evidence=Join-Path $Root ('_evidence\evp02a-f2-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$probe=Join-Path $evidence 'evp_native_db_probe'
$paths=@('docs/engineering/EVP-02A_F2_NATIVE_SQLCIPHER_REVIEW.md','tools/evp/native_db_probe/pubspec.yaml.txt','tools/evp/native_db_probe/MainActivity.kt.txt','tools/evp/native_db_probe/native_test.dart.txt','scripts/evp/Test-Evp02AF2.ps1')
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
    if((GitChecked @('rev-parse',($TargetSha+'^'))) -ne $base){throw 'Unexpected target parent'}
    if(@(Compare-Object @($paths|Sort-Object) @(GitChecked @('diff','--name-only',$base,$TargetSha)|Sort-Object)).Count){throw 'Allowlist mismatch'}
    if($before -ne $TargetSha){GitChecked @('merge','--ff-only',$TargetSha) | Out-Host}
    if((GitChecked @('rev-parse','HEAD')) -ne $TargetSha){throw 'Sync mismatch'}
    Clean
    $stage='ISOLATED_NATIVE_DB_PROJECT'
    $templates=Join-Path $repo 'tools\evp\native_db_probe'
    FlutterChecked @('--version') 'flutter-version.log'
    FlutterChecked @('create','--no-pub','--platforms=android','--org','br.com.zenithit.evpqa','--project-name','evp_native_db_probe',$probe) 'flutter-create.log'
    $gradle=Join-Path $probe 'android\app\build.gradle.kts'
    if(!(Select-String -LiteralPath $gradle -Pattern 'applicationId\s*=\s*"br\.com\.zenithit\.evpqa\.evp_native_db_probe"')){throw 'Unexpected probe application ID'}
    $gradleText=Get-Content -LiteralPath $gradle -Raw
    $gradleText += @'

dependencies {
    implementation("net.zetetic:sqlcipher-android:4.20.0")
    implementation("androidx.sqlite:sqlite:2.7.0")
}
'@
    [IO.File]::WriteAllText($gradle,$gradleText,[Text.UTF8Encoding]::new($false))
    $main=Join-Path $probe 'android\app\src\main\kotlin\br\com\zenithit\evpqa\evp_native_db_probe\MainActivity.kt'
    if(!(Test-Path -LiteralPath $main -PathType Leaf)){throw 'Unexpected Kotlin template'}
    Copy-Item -LiteralPath (Join-Path $templates 'MainActivity.kt.txt') -Destination $main -Force
    Copy-Item -LiteralPath (Join-Path $templates 'pubspec.yaml.txt') -Destination (Join-Path $probe 'pubspec.yaml') -Force
    New-Item -ItemType Directory -Path (Join-Path $probe 'integration_test'),(Join-Path $probe 'test_driver') | Out-Null
    Copy-Item -LiteralPath (Join-Path $templates 'native_test.dart.txt') -Destination (Join-Path $probe 'integration_test\native_test.dart')
    Copy-Item -LiteralPath (Join-Path $repo 'tools\evp\sqlcipher_probe\driver.dart.txt') -Destination (Join-Path $probe 'test_driver\integration_test.dart')
    $manifest=Join-Path $probe 'android\app\src\main\AndroidManifest.xml'
    [xml]$xml=Get-Content -LiteralPath $manifest -Raw
    $application=$xml.SelectSingleNode('/manifest/application')
    if(!$application){throw 'Unexpected manifest'}
    $application.SetAttribute('allowBackup','http://schemas.android.com/apk/res/android','false')
    $xml.Save($manifest)
    SameFile (Join-Path $templates 'MainActivity.kt.txt') $main
    SameFile (Join-Path $templates 'native_test.dart.txt') (Join-Path $probe 'integration_test\native_test.dart')
    Write-Host 'S1=GREEN_REUSED; S2A=GREEN_REUSED; S2B=GREEN_REUSED; S3A=GREEN_REUSED'
    Push-Location -LiteralPath $probe
    try {
        $stage='PROBE_DEPENDENCIES'
        FlutterChecked @('pub','get') 'probe-pub-get.log'
        $lock=Join-Path $probe 'pubspec.lock'
        Copy-Item -LiteralPath $lock -Destination (Join-Path $evidence 'probe-pubspec.lock')
        $stage='PROFILE_ANALYZE'
        FlutterChecked @('analyze','--no-pub','integration_test/native_test.dart') 'profile-analyze.log'
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
        SameFile (Join-Path $evidence 'probe-pubspec.lock') $lock
        $stage='PROBE_PREBUILT_DEVICE_TEST'
        Write-Host "ETAPA=$stage"
        FlutterChecked @('drive','--profile','--no-pub','--driver=test_driver/integration_test.dart','--target=integration_test/native_test.dart',("--use-application-binary="+$apk),'-d',$device,'--timeout=600') 'probe-drive.log'
        if((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash -ne $apkHash){throw 'APK changed during device execution'}
        $log=Join-Path $evidence 'probe-drive.log'
        if(!(Select-String -LiteralPath $log -SimpleMatch 'EVP_F2_NATIVE_CHECKS=PASS')){throw 'Native completion marker missing; inspect drive log'}
        if(!(Select-String -LiteralPath $log -SimpleMatch 'All tests passed')){throw 'Driver success marker missing; inspect drive log'}
        $metrics=@(Select-String -LiteralPath $log -Pattern 'EVP_F2_[A-Z0-9_]+=[^ ]+' -AllMatches | ForEach-Object {$_.Matches.Value})
    } finally {Pop-Location}
    Clean
    $result=@('VERDICT=PASS_EVP02A_F2_NATIVE_SQLCIPHER',"HEAD=$TargetSha",'S1=GREEN_REUSED','S2A=GREEN_REUSED','S2B=GREEN_REUSED','S3A=GREEN_REUSED','S3B=GREEN_REUSED','F1=GREEN_REUSED','MODE=PROFILE_ARM64',"APK_SHA256=$apkHash","BUILD_SECONDS=$buildSeconds",'PRODUCTION_BUILD=NOT_RUN','PRODUCTION=UNCHANGED','RELEASE=NO_GO')+$metrics
    $result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8
    $result | Out-Host
    Write-Host "RESULTADO=$evidence\RESULTADO.txt"
} catch {
    $result=@('VERDICT=NO_GO',"ETAPA=$stage","ERRO=$($_.Exception.Message)","LINHA=$($_.InvocationInfo.ScriptLineNumber)",'NEXT=Send output and relevant sanitized log; preserve evidence and do not reset/clean/retry blindly')
    if(Test-Path -LiteralPath $evidence){$result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8}
    $result | Out-Host
    throw
}
