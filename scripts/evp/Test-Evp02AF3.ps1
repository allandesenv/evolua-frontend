param([Parameter(Mandatory=$true)][string]$TargetSha,[string]$Root=(Join-Path $HOME 'Desktop\Zenith IT\Evolua'))
$ErrorActionPreference='Stop'
$stage='PREFLIGHT'
$repo=Join-Path $Root 'evolua-private-core'
$base='b1e1eb9219361412f05cfb59f199f6e4a6a0f016'
$f3='0377de61c2f77490485dbaebb35a6d28e39b9759'
$branch='feat/evp-private-core'
$prior=Join-Path $Root '_evidence\evp02a-f2-20261127-235902-332'
$probe=Join-Path $prior 'evp_native_db_probe'
$evidence=Join-Path $Root ('_evidence\evp02a-f3-r1-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$expectedApk='5A034F976A0B9D5A4D0F15C039EE4754E051F6B8A311193BD03FBC5ACCEA3678'
$paths=@('docs/engineering/EVP-02A_F3_R1_GRAPH_REVIEW.md','scripts/evp/Test-Evp02AF3.ps1')
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
    if($before -ne $f3 -and $before -ne $TargetSha){throw 'Unexpected local HEAD'}
    New-Item -ItemType Directory -Path $evidence -Force | Out-Null
    $stage='FETCH_AND_ALLOWLIST'
    GitChecked @('fetch','origin',"refs/heads/$branch") | Out-Host
    if((GitChecked @('rev-parse','FETCH_HEAD')) -ne $TargetSha){throw 'Remote HEAD differs from target'}
    if((GitChecked @('rev-parse',($TargetSha+'^'))) -ne $f3){throw 'Unexpected parent'}
    if(@(Compare-Object @($paths|Sort-Object) @(GitChecked @('diff','--name-only',$f3,$TargetSha)|Sort-Object)).Count){throw 'Allowlist mismatch'}
    if($before -ne $TargetSha){GitChecked @('merge','--ff-only',$TargetSha) | Out-Host}
    Clean
    $stage='PRIOR_F3_EVIDENCE'
    $previous=@(Get-ChildItem -LiteralPath (Join-Path $Root '_evidence') -Directory -Filter 'evp02a-f3-*' | Where-Object {$_.Name -match '^evp02a-f3-\d{8}-\d{6}-\d{3}$'} | Sort-Object Name -Descending | Select-Object -First 1)
    if($previous.Count -ne 1){throw 'Original F3 evidence directory not found'}
    $oldFolder=$previous[0].FullName
    $oldReceipt=@(Get-Content -LiteralPath (Join-Path $oldFolder 'RESULTADO.txt'))
    if($oldReceipt -notcontains 'ETAPA=OFFLINE_DEPENDENCY_GRAPH' -or $oldReceipt -notcontains 'ERRO=Dependency graph requires review'){throw 'Original F3 receipt does not match the reported failure'}
    $graphFile=Join-Path $oldFolder 'profile-runtime-dependencies.log'
    $elfFile=Join-Path $oldFolder 'elf-alignment.log'
    $zipFile=Join-Path $oldFolder 'zipalign.log'
    $graphHash=(Get-FileHash -LiteralPath $graphFile -Algorithm SHA256).Hash
    $elfHash=(Get-FileHash -LiteralPath $elfFile -Algorithm SHA256).Hash
    $zipHash=(Get-FileHash -LiteralPath $zipFile -Algorithm SHA256).Hash
    Write-Host "PRIOR_F3=$($previous[0].Name)"
    Write-Host "GRAPH_SHA256=$graphHash"
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
        $elfLines=@(Get-Content -LiteralPath $elfFile)
        if(!$libs.Count -or $elfLines.Count -ne $libs.Count){throw 'Prior ELF evidence count mismatch'}
        foreach($lib in $libs){
            $pattern='^ELF='+[regex]::Escape($lib.FullName)+' LOADS=[1-9]\d* MIN_ALIGN=\d+ STATUS=PASS$'
            $matched=@($elfLines | Where-Object {$_ -match $pattern})
            if($matched.Count -ne 1){throw "Prior ELF PASS missing for $($lib.FullName)"}
            $metrics+=$matched[0]
        }
    } finally {$archive.Dispose();$aarArchive.Dispose()}
    $stage='REUSE_ZIP_ALIGNMENT'
    if(!(Select-String -LiteralPath $zipFile -SimpleMatch 'Verification successful')){throw 'Prior zipalign success marker not found'}
    Write-Host 'ELF_ALIGNMENT=GREEN_REUSED'
    Write-Host 'ZIPALIGN=GREEN_REUSED'
    $stage='OFFLINE_DEPENDENCY_GRAPH_REVIEW'
    $graphLines=@(Get-Content -LiteralPath $graphFile)
    if(!@($graphLines | Where-Object {$_ -match '^\s*BUILD SUCCESSFUL\b'}).Count){throw 'Prior Gradle success marker missing'}
    $vendorLines=@($graphLines | Where-Object {$_ -match 'net\.zetetic:sqlcipher-android(?=[:\s]|$)'})
    $unresolved=@($graphLines | Where-Object {$_ -match '\bFAILED\b'})
    $androidxLines=@($graphLines | Where-Object {$_ -match 'androidx\.sqlite:sqlite(?=[:\s]|$)'})
    $versions=@()
    $issues=@()
    Write-Host 'SQLCIPHER_GRAPH_LINES_BEGIN'
    $vendorLines | Out-Host
    Write-Host 'SQLCIPHER_GRAPH_LINES_END'
    Write-Host 'ANDROIDX_SQLITE_GRAPH_LINES_BEGIN'
    $androidxLines | Out-Host
    Write-Host 'ANDROIDX_SQLITE_GRAPH_LINES_END'
    Write-Host "FAILED_WORD_LINES=$($unresolved.Count)"
    $unresolved | Out-Host
    # Only ignore clearly non-dependency informational lines. Unclassified
    # FAILED text is blocked rather than silently discarded.
    $failedDependencies=@($unresolved | Where-Object {$_ -match '^\s*[|\\+ ]*[-]+\s+\S.*\bFAILED\b'})
    $unclassified=@($unresolved | Where-Object {$_ -notmatch '^\s*[|\\+ ]*[-]+\s+\S.*\bFAILED\b'})
    foreach($line in $vendorLines){
        if($line -match '\(c\)\s*(\(\*\))?\s*$'){continue}
        if($line -match 'net\.zetetic:sqlcipher-android:(?<requested>[^\s]+)(?:\s+->\s+(?<selected>[^\s]+))?'){
            $selected=if($Matches['selected']){$Matches['selected']}else{$Matches['requested']}
            $versions+=$selected
        } else {$issues+='SQLCIPHER_COORDINATE_UNPARSED'}
    }
    $versions=@($versions | Sort-Object -Unique)
    Write-Host "SQLCIPHER_SELECTED_VERSIONS=$($versions -join ',')"
    Write-Host "UNRESOLVED_DEPENDENCIES=$($failedDependencies.Count)"
    Write-Host "UNCLASSIFIED_FAILED_LINES=$($unclassified.Count)"
    if($versions.Count -ne 1 -or $versions[0] -ne '4.20.0'){$issues+='SQLCIPHER_VERSION_NOT_CONFIRMED'}
    if($failedDependencies.Count){$issues+='UNRESOLVED_DEPENDENCIES'}
    if($unclassified.Count){$issues+='UNCLASSIFIED_FAILED_TEXT'}
    if($issues.Count){
        $issues=@($issues|Sort-Object -Unique)
        Write-Host "GRAPH_REVIEW_REASONS=$($issues -join ',')"
        @('GRAPH_REVIEW_REASONS='+($issues -join ','),'SQLCIPHER_SELECTED_VERSIONS='+($versions -join ','),'UNRESOLVED_DEPENDENCIES='+$failedDependencies.Count,'UNCLASSIFIED_FAILED_LINES='+$unclassified.Count)+$vendorLines+$androidxLines+$unresolved | Set-Content -LiteralPath (Join-Path $evidence 'graph-diagnostics.log') -Encoding UTF8
        throw ('Dependency graph requires review: '+($issues -join ','))
    }
    Write-Host 'OFFLINE_GRAPH=GREEN_REUSED_REVIEWED'
    if((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash -ne $expectedApk){throw 'APK modified'}
    Clean
    $result=@('VERDICT=PASS_EVP02A_F3_ARTIFACT_GATE',"HEAD=$TargetSha",'F2=GREEN_REUSED',"F2_RECEIPT_SHA256=$receiptHash","APK_SHA256=$expectedApk","AAR_SHA256=$aarHash",'ZIPALIGN=GREEN_REUSED','ELF_ALIGNMENT=GREEN_REUSED','OFFLINE_GRAPH=GREEN_REUSED_REVIEWED',"GRAPH_SHA256=$graphHash","ELF_LOG_SHA256=$elfHash","ZIP_LOG_SHA256=$zipHash",'SQLCIPHER_SELECTED_VERSION=4.20.0','GRADLE=NOT_RUN','BUILD=NOT_RUN','DEVICE_TEST=NOT_RUN','PRODUCTION=UNCHANGED','ADOPTION=AWAITING_EXPLICIT_GO','RELEASE=NO_GO')+$metrics
    $result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8
    $result | Out-Host
    Write-Host "RESULTADO=$evidence\RESULTADO.txt"
} catch {
    $result=@('VERDICT=NO_GO',"ETAPA=$stage","ERRO=$($_.Exception.Message)","LINHA=$($_.InvocationInfo.ScriptLineNumber)",'NEXT=Send receipt; preserve F2 evidence; no reset/clean/build retry')
    if(Test-Path -LiteralPath $evidence){$result | Set-Content -LiteralPath (Join-Path $evidence 'RESULTADO.txt') -Encoding UTF8}
    $result | Out-Host
    Write-Host "RESULTADO=$evidence\RESULTADO.txt"
    throw
}
