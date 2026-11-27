param(
    [string]$Root = (Join-Path $HOME 'Desktop\Zenith IT\Evolua')
)
$ErrorActionPreference = 'Stop'
$stage = 'PREFLIGHT'
$base = '5ec9ca9ca59f3440b164c356f3ab6fa9d481f409'
$branch = 'release/production-v43-billing8'
$source = Join-Path $Root 'evolua-billing8-v40'
$target = Join-Path $Root 'evolua-production-v43-recovered'
$audit = Join-Path $Root 'hotfix-billing8-audit-20261023'
$expected = [ordered]@{
    'pubspec.yaml' = '4993C86BF84559CE15AD994A6DD12B16195A9353F927345CB409C3B2688D90A8'
    'pubspec.lock' = '4F24CFB40C39550B4E73FDFD13A11E9F4E435E7B9703F4333939CA6D857171DB'
    'test/care/care_recommendation_realtime_test.dart' = '5F670ED0A5780705322E3513C54261797BF5851D8637EB7B0A722196BCE3A3A5'
    'test/care/care_share_controller_test.dart' = '2F3443C559A53343ECA06729C40F5364A9F804B7986D6D124F741FF3C6897A04'
    'docs/hotfix-play-billing-8-v43.md' = '0C3DCDBBBE3796F105B7FB6B9CF985499F75AEC1AC6482DE8C27E50F37480B86'
    'test/subscription/google_play_billing_service_test.dart' = '386F9BD35208CF8C577C8E5A1FEBC17BD196AD83B59A94F876267321E9C7386A'
}
function Git-Checked {
    param([string]$Repo, [string[]]$Arguments)
    $output = & git -C $Repo @Arguments
    if ($LASTEXITCODE -ne 0) { throw "git failed (exit $LASTEXITCODE): $($Arguments[0])" }
    return $output
}
function Assert-Paths {
    param([string[]]$Actual)
    $difference = @(Compare-Object @($expected.Keys | Sort-Object) @($Actual | Sort-Object))
    if ($difference.Count -ne 0) { throw "Unexpected path set: $($difference | Out-String)" }
}
try {
    if (!(Test-Path -LiteralPath $source -PathType Container)) { throw 'Missing original hotfix worktree' }
    if (Test-Path -LiteralPath $target) { throw 'Recovery target already exists; preserve and inspect it, do not rerun blindly' }
    if ((Git-Checked $source @('rev-parse','HEAD')) -ne $base) { throw 'Unexpected original HEAD' }
    if ((Git-Checked $source @('branch','--show-current')) -ne 'hotfix/play-billing-8-from-v40-20261023') { throw 'Unexpected original branch' }
    $remote = Git-Checked $source @('remote','get-url','origin')
    if ($remote -notmatch '^(https://github\.com/|git@github\.com:)allandesenv/evolua-frontend(\.git)?$') { throw 'Unexpected origin' }
    $localBranch = @(Git-Checked $source @('branch','--list',$branch))
    if ($localBranch.Count -gt 0) { throw 'Recovery branch already exists locally' }
    $remoteBranch = @(Git-Checked $source @('ls-remote','--heads','origin',"refs/heads/$branch"))
    if ($remoteBranch.Count -gt 0) { throw 'Recovery branch already exists remotely' }

    $stage = 'VERIFY_ORIGINAL'
    $status = @(Git-Checked $source @('status','--porcelain=v1','--untracked-files=all'))
    foreach ($line in $status) {
        if (!$line.StartsWith(' M ') -and !$line.StartsWith('?? ')) { throw 'Unexpected staged or nonstandard source change' }
    }
    Assert-Paths @($status | ForEach-Object { $_.Substring(3) })
    $receipt = @(Get-Content -Raw -LiteralPath (Join-Path $audit 'source-hashes.json') | ConvertFrom-Json)
    Assert-Paths @($receipt | ForEach-Object { $_.file })
    foreach ($rel in $expected.Keys) {
        $record = @($receipt | Where-Object { $_.file -ceq $rel })
        if ($record.Count -ne 1 -or $record[0].sha256 -ne $expected[$rel]) { throw "Receipt mismatch: $rel" }
        $actual = (Get-FileHash -LiteralPath (Join-Path $source $rel) -Algorithm SHA256).Hash
        if ($actual -ne $expected[$rel]) { throw "Source hash mismatch: $rel" }
    }
    $aabHash = '00737646E6C0B89F6A8DDE03607B71BAB748683EF9BFF18F2EBB8B95E567EDD7'
    foreach ($aab in @((Join-Path $audit 'evolua-1.0.2-43-billing8.aab'),(Join-Path $source 'build\app\outputs\bundle\release\app-release.aab'))) {
        if ((Get-FileHash -LiteralPath $aab -Algorithm SHA256).Hash -ne $aabHash) { throw 'AAB hash mismatch' }
    }
    Write-Host 'ORIGINAL_HASHES=6/6'
    Write-Host 'AAB_HASHES=2/2'
    $stage = 'CREATE_ISOLATED_WORKTREE'
    Git-Checked $source @('worktree','add','-b',$branch,$target,$base) | Out-Host
    $stage = 'COPY_AND_STAGE_ALLOWLIST'
    foreach ($rel in $expected.Keys) {
        $from = Join-Path $source $rel
        $to = Join-Path $target $rel
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to)) | Out-Null
        [IO.File]::Copy($from,$to,$true)
        if ((Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash -ne $expected[$rel]) { throw "Copied hash mismatch: $rel" }
        Git-Checked $target @('add','--',$rel) | Out-Host
        $blob = Git-Checked $target @('hash-object',"--path=$rel",$from)
        $staged = Git-Checked $target @('rev-parse',":$rel")
        if ($blob -ne $staged) { throw "Staged blob mismatch: $rel" }
    }
    Assert-Paths @(Git-Checked $target @('diff','--cached','--name-only'))
    $stage = 'LOCAL_COMMIT'
    Git-Checked $target @('commit','-m','chore(release): preserve verified local v43 Billing 8 hotfix') | Out-Host
    $head = Git-Checked $target @('rev-parse','HEAD')
    if ((Git-Checked $target @('rev-parse','HEAD^')) -ne $base) { throw 'Unexpected parent' }
    Assert-Paths @(Git-Checked $target @('diff','--name-only',$base,$head))
    if (@(Git-Checked $target @('status','--porcelain=v1','--untracked-files=all')).Count -ne 0) { throw 'Recovery worktree is not clean' }
    if ((Git-Checked $source @('rev-parse','HEAD')) -ne $base) { throw 'Original HEAD changed' }
    foreach ($rel in $expected.Keys) {
        if ((Get-FileHash -LiteralPath (Join-Path $source $rel) -Algorithm SHA256).Hash -ne $expected[$rel]) { throw "Original source changed: $rel" }
    }
    Write-Host "HEAD=$head"
    Write-Host "BASE=$base"
    Write-Host "BRANCH=$branch"
    Write-Host "WORKTREE=$target"
    Git-Checked $target @('diff','--stat',$base,$head) | Out-Host
    Write-Host 'VERDICT=PASS_V43_LOCAL_RECOVERY'
    Write-Host 'PUSH=NOT_RUN; PUBLIC_CONTENT_REVIEW=REQUIRED; BUILD=NOT_RUN; TESTS=HISTORICAL_ONLY; RELEASE=NO_GO'
    Write-Host 'NEXT=Review all six changed files for secrets/private information before explicit push. Do not clean/reset/rebuild.'
} catch {
    Write-Host 'VERDICT=NO_GO'
    Write-Host "ETAPA=$stage"
    Write-Host "ERRO=$($_.Exception.Message)"
    Write-Host "LINHA=$($_.InvocationInfo.ScriptLineNumber)"
    Write-Host 'NEXT=Send output; preserve all worktrees and artifacts; do not rerun blindly.'
    throw
}
