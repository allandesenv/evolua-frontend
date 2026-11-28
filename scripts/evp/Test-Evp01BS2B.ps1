param([Parameter(Mandatory=$true)][string]$TargetSha,[string]$Root=(Join-Path $HOME 'Desktop\Zenith IT\Evolua'))
$ErrorActionPreference='Stop'
$stage='PREFLIGHT'
$repo=Join-Path $Root 'evolua-private-core'
$base='8818c45dc8466819278935ca2b6c44695de879d0'
$branch='feat/evp-private-core'
$previous=Join-Path $Root '_evidence\evp01b-s2a-20261127-211727-021'
$probe=Join-Path $previous 'evp_cipher_probe'
$evidence=Join-Path $Root ('_evidence\evp01b-s2b-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$paths=@('docs/engineering/EVP-01B_S2B_INTEGRITY_PROFILE.md','tools/evp/sqlcipher_probe/profile_integrity_test.dart.txt','scripts/evp/Test-Evp01BS2B.ps1')
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
    if(!(Test-Path -LiteralPath $probe -PathType Container)){throw 'Missing original probe; do not regenerate'}
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
    $debugApk=Join-Path $probe 'build\app\outputs\flutter-apk\app-debug.apk'
    if((Get-FileHash -LiteralPath $debugApk -Algorithm SHA256).Hash -ne 'B60DCBA83E1F5D06697E1EF214B4C52F9F88950864A69859F2EC47039F79F936'){throw 'S2A GREEN APK hash mismatch'}
    $profileSource=Join-Path $probe 'integration_test\profile_integrity_test.dart'
    if(!(Test-Path -LiteralPath $profileSource)){Copy-Item -LiteralPath (Join-Path $templates 'profile_integrity_test.dart.txt') -Destination $profileSource}
    SameFile (Join-Path $templates 'profile_integrity_test.dart.txt') $profileSource
    Write-Host 'S1=GREEN_REUSED; S2A=GREEN_REUSED; DEBUG_APK=VERIFIED'
    Push-Location -LiteralPath $probe
    try {
        $stage='PROFILE_ANALYZE'
        FlutterChecked @('analyze','--no-pub','integration_test/profile_integrity_test.dart') 'profile-analyze.log'
        $stage='DISK_PREFLIGHT_BEFORE_BUILD'
        Assert-DiskCapacity
        $stage='PROBE_APK_BUILD'
        if(@(Get-ActiveWrappers).Count){throw 'Another Gradle wrapper started after host preflight; concurrent build prevented'}
        Write-Host "ETAPA=$stage"
        $timer=[Diagnostics.Stopwatch]::StartNew()
        FlutterChecked @('build','apk','--profile','--no-pub','--target-platform=android-arm64','--target=integration_test/profile_integrity_test.dart') 'probe-build.log'
        $timer.Stop()
        $buildSeconds=[math]::Round($timer.Elapsed.TotalSeconds,1)
        $apk=Join-Path $probe 'build\app\outputs\flutter-apk\app-profile.apk'
        if(!(Test-Path -LiteralPath $apk -PathType Leaf)){throw 'APK missing after successful build'}
        $apkHash=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
        Write-Host "APK_SHA256=$apkHash"
        Write-Host "BUILD_SECONDS=$buildSeconds"
        SameFile (Join-Path $previous 'probe-pubspec.lock') (Join-Path $probe 'pubspec.lock')
        $stage='PROBE_PREBUILT_DEVICE_TEST'
        Write-Host "ETAPA=$stage"
        FlutterChecked @('drive','--profile','--no-pub','--driver=test_driver/integration_test.dart','--target=integration_test/profile_integrity_test.dart',("--use-application-binary="+$apk),'-d',$device,'--timeout=600') 'probe-drive.log'
        if((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash -ne $apkHash){throw 'APK changed during device execution'}
        $log=Join-Path $evidence 'probe-drive.log'
        if(!(Select-String -LiteralPath $log -SimpleMatch 'EVP_S2B_NATIVE_CHECKS=PASS')){throw 'Native completion marker missing; inspect drive log'}
        if(!(Select-String -LiteralPath $log -SimpleMatch 'All tests passed')){throw 'Driver success marker missing; inspect drive log'}
        $metrics=@(Select-String -LiteralPath $log -Pattern 'EVP_S2B?_[A-Z0-9_]+=[^ ]+' -AllMatches | ForEach-Object {$_.Matches.Value})
    } finally {Pop-Location}
    Clean
    $stage='PROFILE_ALIGNMENT'
    $alignment=@()
    $alignmentOk=$true
    $sdkHome=if($env:ANDROID_HOME){$env:ANDROID_HOME}elseif($env:ANDROID_SDK_ROOT){$env:ANDROID_SDK_ROOT}else{Join-Path $env:LOCALAPPDATA 'Android\sdk'}
    $zipalign=@(Get-ChildItem -LiteralPath (Join-Path $sdkHome 'build-tools') -Directory -ErrorAction SilentlyContinue | Where-Object {$_.Name -match '^\d+\.\d+\.\d+$' -and [version]$_.Name -ge [version]'35.0.0'} | Sort-Object {[version]$_.Name} -Descending | ForEach-Object {Join-Path $_.FullName 'zipalign.exe'} | Where-Object {Test-Path -LiteralPath $_} | Select-Object -First 1)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    foreach($item in @(@{Name='DEBUG';Path=$debugApk},@{Name='PROFILE';Path=$apk})){
        if($zipalign.Count){
            $old=$ErrorActionPreference
            try {
                $ErrorActionPreference='Continue'
                & $zipalign[0] -c -P 16 -v 4 $item.Path 2>&1 | ForEach-Object {"$_"} | Set-Content -LiteralPath (Join-Path $evidence ("zipalign-"+$item.Name+".log"))
                $zipRc=$LASTEXITCODE
            } finally {$ErrorActionPreference=$old}
            $alignment+=("ZIPALIGN_"+$item.Name+"="+$(if($zipRc -eq 0){'PASS'}else{'FAIL'}))
            if($zipRc -ne 0){$alignmentOk=$false}
        } else {
            $alignment+=("ZIPALIGN_"+$item.Name+"=TOOL_NOT_FOUND")
            $alignmentOk=$false
        }
        $archive=[IO.Compression.ZipFile]::OpenRead($item.Path)
        try {
            $libs=@($archive.Entries | Where-Object {$_.FullName -match '^lib/(arm64-v8a|x86_64)/[^/]+\.so$'})
            if(!$libs.Count -or !@($libs|Where-Object {$_.Name -match 'sqlcipher'}).Count){throw 'Expected 64-bit SQLCipher library missing'}
            foreach($lib in $libs){
                $stream=$lib.Open()
                $mem=[IO.MemoryStream]::new()
                try {
                    $stream.CopyTo($mem)
                    $mem.Position=0
                    $reader=[IO.BinaryReader]::new($mem)
                    $ident=$reader.ReadBytes(16)
                    if($ident.Length -ne 16 -or $ident[0] -ne 127 -or $ident[1] -ne 69 -or $ident[2] -ne 76 -or $ident[3] -ne 70 -or $ident[4] -ne 2 -or $ident[5] -ne 1){throw 'Expected ELF64 little-endian'}
                    $mem.Position=32
                    $phoff=$reader.ReadUInt64()
                    $mem.Position=54
                    $phsize=$reader.ReadUInt16()
                    $phnum=$reader.ReadUInt16()
                    if($phsize -lt 56 -or $phnum -eq 0 -or ($phoff+([uint64]$phsize*$phnum)) -gt $mem.Length){throw 'Invalid ELF program headers'}
                    $loads=0
                    $minAlign=[uint64]::MaxValue
                    $ok=$true
                    for($i=0;$i -lt $phnum;$i++){
                        $mem.Position=[long]($phoff+([uint64]$i*$phsize))
                        $type=$reader.ReadUInt32()
                        if($type -ne 1){continue}
                        $loads++
                        $null=$reader.ReadUInt32()
                        $offset=$reader.ReadUInt64()
                        $vaddr=$reader.ReadUInt64()
                        $null=$reader.ReadUInt64()
                        $null=$reader.ReadUInt64()
                        $null=$reader.ReadUInt64()
                        $align=$reader.ReadUInt64()
                        if($align -lt $minAlign){$minAlign=$align}
                        if($align -lt 16384 -or ($offset % 16384) -ne ($vaddr % 16384)){$ok=$false}
                    }
                    if(!$loads){$ok=$false}
                    $line="ELF_$($item.Name)=$($lib.FullName) LOADS=$loads MIN_ALIGN=$minAlign STATUS=$(if($ok){'PASS'}else{'FAIL'})"
                    $line | Tee-Object -FilePath (Join-Path $evidence 'elf-alignment.log') -Append | Out-Host
                    $alignment+=$line
                    if(!$ok){$alignmentOk=$false}
                } finally {$stream.Dispose();$mem.Dispose()}
            }
        } finally {$archive.Dispose()}
    }
    $verdict=if($alignmentOk){'PASS_EVP01B_S2B_PROFILE_INTEGRITY_ALIGNMENT'}else{'NO_GO_ALIGNMENT_REVIEW'}
    $result=@("VERDICT=$verdict","HEAD=$TargetSha",'S1=GREEN_REUSED','S2A=GREEN_REUSED','PROFILE_NATIVE=PASS','MODE=PROFILE_ARM64',"APK_SHA256=$apkHash","BUILD_SECONDS=$buildSeconds",'PRODUCTION_BUILD=NOT_RUN','PRODUCTION=UNCHANGED','RELEASE=NO_GO')+$metrics+$alignment
    $result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8
    $result | Out-Host
    Write-Host "RESULTADO=$evidence\RESULTADO.txt"
    if(!$alignmentOk){Write-Host 'NEXT=Send receipt; native profile passed; alignment requires separate review'}
} catch {
    $result=@('VERDICT=NO_GO',"ETAPA=$stage","ERRO=$($_.Exception.Message)","LINHA=$($_.InvocationInfo.ScriptLineNumber)",'NEXT=Send output and relevant sanitized log; preserve evidence and do not reset/clean/retry blindly')
    if(Test-Path -LiteralPath $evidence){$result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8}
    $result | Out-Host
    throw
}
