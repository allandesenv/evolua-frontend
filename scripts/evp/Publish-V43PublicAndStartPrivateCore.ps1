param([string]$Root = (Join-Path $HOME 'Desktop\Zenith IT\Evolua'))
$ErrorActionPreference = 'Stop'
$stage = 'PREFLIGHT'
$base = '5ec9ca9ca59f3440b164c356f3ab6fa9d481f409'
$exact = 'ef038e05d6e3625b516dd40e29f9fd7151bac16b'
$docCommit = '53e7db31328ef6f8bfbc6a705399aa1ac7fda00a'
$docBlob = '4d386ae6f9ee13e3a58bab32def1370587f347c4'
$source = Join-Path $Root 'evolua-production-v43-recovered'
$public = Join-Path $Root 'evolua-production-v43-public'
$feature = Join-Path $Root 'evolua-private-core'
$publicBranch = 'release/production-v43-billing8-public'
$featureBranch = 'feat/evp-private-core'
$report = 'docs/hotfix-play-billing-8-v43.md'
$architecture = 'docs/architecture/EVP-01_PRIVATE_CORE.md'
$paths = @('pubspec.yaml','pubspec.lock','test/care/care_recommendation_realtime_test.dart','test/care/care_share_controller_test.dart','test/subscription/google_play_billing_service_test.dart')
function Invoke-GitChecked {
    param([string]$Repo,[string[]]$Arguments)
    $result = & git -C $Repo @Arguments
    if ($LASTEXITCODE -ne 0) { throw "git failed ($LASTEXITCODE): $($Arguments[0])" }
    return $result
}
function Assert-Paths {
    param([string[]]$Expected,[string[]]$Actual)
    if (@(Compare-Object @($Expected | Sort-Object) @($Actual | Sort-Object)).Count) { throw 'Unexpected diff path set' }
}
function Assert-Clean {
    param([string]$Repo)
    if (@(Invoke-GitChecked $Repo @('status','--porcelain=v1','--untracked-files=all')).Count) { throw "Worktree not clean: $Repo" }
}
try {
    if (!(Test-Path -LiteralPath $source -PathType Container)) { throw 'Missing recovered local authority' }
    if ((Invoke-GitChecked $source @('rev-parse','HEAD')) -ne $exact) { throw 'Recovered HEAD mismatch' }
    if ((Invoke-GitChecked $source @('rev-parse','HEAD^')) -ne $base) { throw 'Recovered parent mismatch' }
    Assert-Clean $source
    Assert-Paths ($paths + @($report)) @(Invoke-GitChecked $source @('diff','--name-only',$base,$exact))
    if ((Invoke-GitChecked $source @('rev-parse',($docCommit+':'+$architecture))) -ne $docBlob) { throw 'Architecture blob mismatch' }
    if ((Invoke-GitChecked $source @('remote','get-url','origin')) -notmatch '^(https://github\.com/|git@github\.com:)allandesenv/evolua-frontend(\.git)?$') { throw 'Unexpected fetch origin' }
    if ((Invoke-GitChecked $source @('remote','get-url','--push','origin')) -notmatch '^(https://github\.com/|git@github\.com:)allandesenv/evolua-frontend(\.git)?$') { throw 'Unexpected push origin' }
    foreach ($dir in @($public,$feature)) { if (Test-Path -LiteralPath $dir) { throw "Destination exists: $dir" } }
    foreach ($branch in @($publicBranch,$featureBranch,'release/production-v43-billing8')) {
        if (@(Invoke-GitChecked $source @('ls-remote','--heads','origin',"refs/heads/$branch")).Count) { throw "Remote branch exists: $branch" }
    }
    foreach ($branch in @($publicBranch,$featureBranch)) {
        if (@(Invoke-GitChecked $source @('branch','--list',$branch)).Count) { throw "Local branch exists: $branch" }
    }
    $stage = 'PUBLIC_SIBLING'
    Invoke-GitChecked $source @('worktree','add','-b',$publicBranch,$public,$base) | Out-Host
    foreach ($rel in $paths) {
        Invoke-GitChecked $public @('restore',"--source=$exact",'--staged','--worktree','--',$rel) | Out-Host
        if ((Invoke-GitChecked $public @('rev-parse',":$rel")) -ne (Invoke-GitChecked $source @('rev-parse',($exact+':'+$rel)))) { throw "Public source blob mismatch: $rel" }
    }
    $safeReport = @'
# Hotfix Google Play Billing - v43 (public summary)

- Historical source base: 5ec9ca9ca59f3440b164c356f3ab6fa9d481f409.
- Android application version: 1.0.2 (43).
- Flutter dependencies: in_app_purchase 3.3.0; in_app_purchase_android 0.5.0.
- Historical packaged Billing library: 8.0.0.
- Historical October 23 local evidence: Flutter analyze without issues; 586 passing tests; Android AAB built and locally validated.
- Recovery evidence: six original source file hashes and two local AAB hashes matched original receipts.
- The five non-documentation files are preserved as identical Git blobs; this public report replaces only the detailed internal report.
- Full original evidence is retained locally. Real purchase validation and binary identity with the Play upload were not independently verified.
- This recovered baseline does not authorize a release, deployment or change to production services.
'@
    $reportPath = Join-Path $public $report
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($reportPath)) | Out-Null
    [IO.File]::WriteAllText($reportPath,$safeReport,[Text.UTF8Encoding]::new($false))
    Invoke-GitChecked $public @('add','--',$report) | Out-Host
    Assert-Paths ($paths + @($report)) @(Invoke-GitChecked $public @('diff','--cached','--name-only'))
    Invoke-GitChecked $public @('commit','-m','chore(release): preserve v43 code with public-safe report') | Out-Host
    $publicHead = Invoke-GitChecked $public @('rev-parse','HEAD')
    if ((Invoke-GitChecked $public @('rev-parse','HEAD^')) -ne $base) { throw 'Public parent mismatch' }
    Assert-Clean $public
    Assert-Paths ($paths + @($report)) @(Invoke-GitChecked $public @('diff','--name-only',$base,$publicHead))
    foreach ($rel in $paths) {
        if ((Invoke-GitChecked $public @('rev-parse',($publicHead+':'+$rel))) -ne (Invoke-GitChecked $source @('rev-parse',($exact+':'+$rel)))) { throw "Committed source blob mismatch: $rel" }
    }
    Assert-Paths @($report) @(Invoke-GitChecked $public @('diff','--name-only',$exact,$publicHead))
    $stage = 'FEATURE_WORKTREE'
    Invoke-GitChecked $public @('worktree','add','-b',$featureBranch,$feature,$publicHead) | Out-Host
    Invoke-GitChecked $feature @('restore',"--source=$docCommit",'--staged','--worktree','--',$architecture) | Out-Host
    if ((Invoke-GitChecked $feature @('rev-parse',":$architecture")) -ne $docBlob) { throw 'Staged architecture mismatch' }
    Assert-Paths @($architecture) @(Invoke-GitChecked $feature @('diff','--cached','--name-only'))
    Invoke-GitChecked $feature @('commit','-m','docs(evp): adopt approved Private Core architecture on recovered v43 base') | Out-Host
    $featureHead = Invoke-GitChecked $feature @('rev-parse','HEAD')
    if ((Invoke-GitChecked $feature @('rev-parse','HEAD^')) -ne $publicHead) { throw 'Feature parent mismatch' }
    if ((Invoke-GitChecked $feature @('rev-parse',($featureHead+':'+$architecture))) -ne $docBlob) { throw 'Committed architecture mismatch' }
    Assert-Paths @($architecture) @(Invoke-GitChecked $feature @('diff','--name-only',$publicHead,$featureHead))
    Assert-Clean $feature
    Assert-Clean $source
    if ((Invoke-GitChecked $source @('rev-parse','HEAD')) -ne $exact) { throw 'Original authority changed' }
    foreach ($head in @($publicHead,$featureHead)) {
        & git -C $source merge-base --is-ancestor $exact $head
        if ($LASTEXITCODE -ne 1) { throw 'Private exact commit must not be an ancestor of public refs' }
    }
    Write-Host "LOCAL_EXACT=$exact"
    Write-Host "PUBLIC_HEAD=$publicHead"
    Write-Host "FEATURE_HEAD=$featureHead"
    Write-Host 'SOURCE_BLOBS=5/5; PUBLIC_DIFF_FROM_EXACT=REPORT_ONLY; PRIVATE_ANCESTRY=EXCLUDED'
    $stage = 'PUSH_EXPLICIT_ATOMIC'
    Invoke-GitChecked $source @('-c','push.followTags=false','push','--atomic','origin',('refs/heads/'+$publicBranch+':refs/heads/'+$publicBranch),('refs/heads/'+$featureBranch+':refs/heads/'+$featureBranch)) | Out-Host
    $stage = 'REMOTE_VERIFY'
    foreach ($pair in @(@{Branch=$publicBranch;Head=$publicHead},@{Branch=$featureBranch;Head=$featureHead})) {
        $remote = @(Invoke-GitChecked $source @('ls-remote','--heads','origin',"refs/heads/$($pair.Branch)"))
        if ($remote.Count -ne 1 -or ($remote[0] -split '\s+')[0] -ne $pair.Head) { throw "Remote SHA mismatch: $($pair.Branch)" }
    }
    if (@(Invoke-GitChecked $source @('ls-remote','--heads','origin','refs/heads/release/production-v43-billing8')).Count) { throw 'Unexpected original local branch on remote' }
    Write-Host "PUBLIC_BRANCH=$publicBranch"
    Write-Host "FEATURE_BRANCH=$featureBranch"
    Write-Host "FEATURE_WORKTREE=$feature"
    Write-Host 'VERDICT=PASS_V43_PUBLIC_AUTHORITY_AND_EVP_BRANCH'
    Write-Host 'BUILD=NOT_RUN; TESTS=HISTORICAL_ONLY; RELEASE=NO_GO; BACKEND_SHUTDOWN=NO_GO'
} catch {
    Write-Host 'VERDICT=NO_GO'
    Write-Host "ETAPA=$stage"
    Write-Host "ERRO=$($_.Exception.Message)"
    Write-Host "LINHA=$($_.InvocationInfo.ScriptLineNumber)"
    Write-Host 'NEXT=Send output. Preserve all refs/worktrees; do not rerun, reset, clean or force-push.'
    throw
}
