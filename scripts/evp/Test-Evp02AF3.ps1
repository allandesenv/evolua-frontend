param([Parameter(Mandatory=$true)][string]$TargetSha,[string]$Root=(Join-Path $HOME 'Desktop\Zenith IT\Evolua'))
$ErrorActionPreference='Stop'
$stage='PREFLIGHT'
$repo=Join-Path $Root 'evolua-private-core'
$base='b1e1eb9219361412f05cfb59f199f6e4a6a0f016'
$branch='feat/evp-private-core'
$prior=Join-Path $Root '_evidence\evp02a-f2-20261127-235902-332'
$probe=Join-Path $prior 'evp_native_db_probe'
$evidence=Join-Path $Root ('_evidence\evp02a-f3-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$expectedApk='5A034F976A0B9D5A4D0F15C039EE4754E051F6B8A311193BD03FBC5ACCEA3678'
$paths=@('docs/engineering/EVP-02A_F3_ADOPTION_GATE.md','scripts/evp/Test-Evp02AF3.ps1')
function GitChecked([string[]]$ArgsList) {
    $result=& git -C $repo @ArgsList
    if($LASTEXITCODE -ne 0){throw "Git failed: $($ArgsList[0]) EXITCODE=$LASTEXITCODE"}
    return $result
}
function Clean {
    if(@(GitChecked @('status','--porcelain=v1','--untracked-files=all')).Count){throw 'Worktree not clean'}
}
function SameFile([string]$A,[string]$B) {
    if((Get-FileHash -LiteralPath $A -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $B -Algorithm SHA256).Hash){throw 'Preserved source mismatch'}
}
function NativeLog([string]$Exe,[string[]]$ArgsList,[string]$Log) {
    $old=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        & $Exe @ArgsList 2>&1 | ForEach-Object {"$_"} | Tee-Object -FilePath (Join-Path $evidence $Log) | Out-Host
        $rc=$LASTEXITCODE
    } finally {$ErrorActionPreference=$old}
    if($rc -ne 0){throw "Native tool failed: $([IO.Path]::GetFileName($Exe)) EXITCODE=$rc"}
}
function EntryHash($Entry) {
    $stream=$Entry.Open()
    $sha=[Security.Cryptography.SHA256]::Create()
    try {return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}
    finally {$sha.Dispose();$stream.Dispose()}
}
try {
    if($TargetSha -notmatch '^[0-9a-f]{40}$'){throw 'Full SHA required'}
    if((GitChecked @('branch','--show-current')) -ne $branch){throw 'Wrong branch'}
    if((GitChecked @('remote','get-url','origin')) -notmatch '^(https://github\.com/|git@github\.com:)allandesenv/evolua-frontend(\.git)?$'){throw 'Wrong origin'}
    Clean
    $before=GitChecked @('rev-parse','HEAD')
    if($before -ne $base -and $before -ne $TargetSha){throw 'Unexpected local HEAD'}
    New-Item -ItemType Directory -Path $evidence -Force | Out-Null
    $stage='FETCH_AND_ALLOWLIST'
    GitChecked @('fetch','origin',"refs/heads/$branch") | Out-Host
    if((GitChecked @('rev-parse','FETCH_HEAD')) -ne $TargetSha){throw 'Remote HEAD differs from target'}
    if((GitChecked @('rev-parse',($TargetSha+'^'))) -ne $base){throw 'Unexpected parent'}
    if(@(Compare-Object @($paths|Sort-Object) @(GitChecked @('diff','--name-only',$base,$TargetSha)|Sort-Object)).Count){throw 'Allowlist mismatch'}
    if($before -ne $TargetSha){GitChecked @('merge','--ff-only',$TargetSha) | Out-Host}
    Clean
    $stage='F2_EVIDENCE'
    $receipt=Join-Path $prior 'RESULTADO.txt'
    $lines=@(Get-Content -LiteralPath $receipt)
    foreach($required in @('VERDICT=PASS_EVP02A_F2_NATIVE_SQLCIPHER',"HEAD=$base","APK_SHA256=$expectedApk",'EVP_F2_CIPHER_VERSION=4.20.0','EVP_F2_SQLITE_VERSION=3.54.1','EVP_F2_ENCRYPTED_FILE=PASS','EVP_F2_WRONG_KEY_READONLY_UNCHANGED=PASS','EVP_F2_RECOVERY_INTEGRITY=PASS','EVP_F2_MISSING_NO_CREATE=PASS','EVP_F2_ORIGINAL_UNCHANGED=PASS','EVP_F2_NATIVE_CHECKS=PASS')){
        if($lines -notcontains $required){throw "Missing receipt marker: $required"}
    }
    $apk=Join-Path $probe 'build\app\outputs\flutter-apk\app-profile.apk'
    if((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash -ne $expectedApk){throw 'F2 APK hash mismatch'}
    $templates=Join-Path $repo 'tools\evp\native_db_probe'
    SameFile (Join-Path $templates 'MainActivity.kt.txt') (Join-Path $probe 'android\app\src\main\kotlin\br\com\zenithit\evpqa\evp_native_db_probe\MainActivity.kt')
    SameFile (Join-Path $templates 'native_test.dart.txt') (Join-Path $probe 'integration_test\native_test.dart')
    SameFile (Join-Path $templates 'pubspec.yaml.txt') (Join-Path $probe 'pubspec.yaml')
    SameFile (Join-Path $prior 'probe-pubspec.lock') (Join-Path $probe 'pubspec.lock')
    $receiptHash=(Get-FileHash -LiteralPath $receipt -Algorithm SHA256).Hash
    Write-Host 'F2=GREEN_REUSED; APK_IDENTITY=PASS'
    $stage='NATIVE_ARTIFACT'
    $gradleHome=if($env:GRADLE_USER_HOME){$env:GRADLE_USER_HOME}else{Join-Path $HOME '.gradle'}
    $cache=Join-Path $gradleHome 'caches\modules-2\files-2.1\net.zetetic\sqlcipher-android\4.20.0'
    $aars=@(Get-ChildItem -LiteralPath $cache -Recurse -File -Filter 'sqlcipher-android-4.20.0.aar')
    if($aars.Count -ne 1){throw 'Expected exactly one cached vendor AAR'}
    $aarHash=(Get-FileHash -LiteralPath $aars[0].FullName -Algorithm SHA256).Hash
    Write-Host "AAR_SHA256=$aarHash"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $aarArchive=[IO.Compression.ZipFile]::OpenRead($aars[0].FullName)
    $archive=[IO.Compression.ZipFile]::OpenRead($apk)
    $metrics=@()
    try {
        $aarEntry=$aarArchive.GetEntry('jni/arm64-v8a/libsqlcipher.so')
        $apkEntry=$archive.GetEntry('lib/arm64-v8a/libsqlcipher.so')
        if(!$aarEntry -or !$apkEntry){throw 'ARM64 SQLCipher missing'}
        $metrics+=("AAR_ARM64_LIB_SHA256="+(EntryHash $aarEntry))
        $metrics+=("APK_ARM64_LIB_SHA256="+(EntryHash $apkEntry))
        $libs=@($archive.Entries | Where-Object {$_.FullName -match '^lib/(arm64-v8a|x86_64)/[^/]+\.so$'})
        foreach($lib in $libs){
            $stream=$lib.Open()
            $mem=[IO.MemoryStream]::new()
            try {
                $stream.CopyTo($mem);$mem.Position=0
                $reader=[IO.BinaryReader]::new($mem)
                $ident=$reader.ReadBytes(16)
                if($ident.Length -ne 16 -or $ident[0] -ne 127 -or $ident[1] -ne 69 -or $ident[2] -ne 76 -or $ident[3] -ne 70 -or $ident[4] -ne 2 -or $ident[5] -ne 1){throw 'Expected ELF64 little-endian'}
                $mem.Position=32;$phoff=$reader.ReadUInt64()
                $mem.Position=54;$phsize=$reader.ReadUInt16();$phnum=$reader.ReadUInt16()
                if($phsize -lt 56 -or $phnum -eq 0 -or ($phoff+([uint64]$phsize*$phnum)) -gt $mem.Length){throw 'Invalid ELF headers'}
                $loads=0;$minAlign=[uint64]::MaxValue;$ok=$true
                for($i=0;$i -lt $phnum;$i++){
                    $mem.Position=[long]($phoff+([uint64]$i*$phsize))
                    if($reader.ReadUInt32() -ne 1){continue}
                    $loads++;$null=$reader.ReadUInt32()
                    $offset=$reader.ReadUInt64();$vaddr=$reader.ReadUInt64()
                    $null=$reader.ReadUInt64();$null=$reader.ReadUInt64();$null=$reader.ReadUInt64()
                    $align=$reader.ReadUInt64()
                    if($align -lt $minAlign){$minAlign=$align}
                    if($align -lt 16384 -or ($offset % 16384) -ne ($vaddr % 16384)){$ok=$false}
                }
                $line="ELF=$($lib.FullName) LOADS=$loads MIN_ALIGN=$minAlign STATUS=$(if($ok -and $loads){'PASS'}else{'FAIL'})"
                $line | Tee-Object -FilePath (Join-Path $evidence 'elf-alignment.log') -Append | Out-Host
                $metrics+=$line
                if(!$ok -or !$loads){throw 'ELF alignment failed'}
            } finally {$stream.Dispose();$mem.Dispose()}
        }
    } finally {$archive.Dispose();$aarArchive.Dispose()}
    $stage='ZIP_ALIGNMENT'
    $sdk=if($env:ANDROID_HOME){$env:ANDROID_HOME}elseif($env:ANDROID_SDK_ROOT){$env:ANDROID_SDK_ROOT}else{Join-Path $env:LOCALAPPDATA 'Android\sdk'}
    $zipalign=@(Get-ChildItem -LiteralPath (Join-Path $sdk 'build-tools') -Directory | Where-Object {$_.Name -match '^\d+\.\d+\.\d+$' -and [version]$_.Name -ge [version]'35.0.0'} | Sort-Object {[version]$_.Name} -Descending | ForEach-Object {Join-Path $_.FullName 'zipalign.exe'} | Where-Object {Test-Path -LiteralPath $_} | Select-Object -First 1)
    if(!$zipalign.Count){throw 'zipalign >=35 unavailable'}
    NativeLog $zipalign[0] @('-c','-P','16','-v','4',$apk) 'zipalign.log'
    Write-Host 'ZIPALIGN=PASS'
    $stage='OFFLINE_DEPENDENCY_GRAPH'
    $wrappers=@(Get-CimInstance Win32_Process | Where-Object {($_.Name -eq 'java.exe' -or $_.Name -eq 'javaw.exe') -and $_.CommandLine -match 'org\.gradle\.wrapper\.GradleWrapperMain'})
    if($wrappers.Count){throw 'Active Gradle wrapper; dependency report not started'}
    Push-Location -LiteralPath (Join-Path $probe 'android')
    try {
        NativeLog (Join-Path (Get-Location).Path 'gradlew.bat') @('--offline','--console=plain',':app:dependencies','--configuration','profileRuntimeClasspath') 'profile-runtime-dependencies.log'
    } finally {Pop-Location}
    $graph=Get-Content -LiteralPath (Join-Path $evidence 'profile-runtime-dependencies.log') -Raw
    if($graph -notmatch 'net\.zetetic:sqlcipher-android:4\.20\.0' -or $graph -match 'net\.zetetic:sqlcipher-android:4\.20\.0\s+->\s+(?!4\.20\.0\b)' -or $graph -match 'FAILED'){throw 'Dependency graph requires review'}
    if((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash -ne $expectedApk){throw 'APK modified'}
    Clean
    $result=@('VERDICT=PASS_EVP02A_F3_ARTIFACT_GATE',"HEAD=$TargetSha",'F2=GREEN_REUSED',"F2_RECEIPT_SHA256=$receiptHash","APK_SHA256=$expectedApk","AAR_SHA256=$aarHash",'ZIPALIGN=PASS','ELF_ALIGNMENT=PASS','OFFLINE_GRAPH=CAPTURED','BUILD=NOT_RUN','DEVICE_TEST=NOT_RUN','PRODUCTION=UNCHANGED','ADOPTION=AWAITING_EXPLICIT_GO','RELEASE=NO_GO')+$metrics
    $result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8
    $result | Out-Host
    Write-Host "RESULTADO=$evidence\RESULTADO.txt"
} catch {
    $result=@('VERDICT=NO_GO',"ETAPA=$stage","ERRO=$($_.Exception.Message)","LINHA=$($_.InvocationInfo.ScriptLineNumber)",'NEXT=Send receipt; preserve F2 evidence; no reset/clean/build retry')
    if(Test-Path -LiteralPath $evidence){$result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8}
    $result | Out-Host
    throw
}
