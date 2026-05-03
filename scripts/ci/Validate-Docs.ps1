$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

$contextPath = Join-Path $repoRoot 'context.md'
if (-not (Test-Path -LiteralPath $contextPath)) {
    throw 'Missing context.md'
}

$contextText = Get-Content -LiteralPath $contextPath -Raw
if ([string]::IsNullOrWhiteSpace($contextText)) {
    throw 'context.md is empty'
}

$changesDir = Join-Path $repoRoot 'docs/changes'
if (-not (Test-Path -LiteralPath $changesDir)) {
    throw 'Missing docs/changes/'
}

if ($env:GITHUB_EVENT_NAME -eq 'pull_request') {
    $base = $env:PR_BASE_SHA
    $head = $env:PR_HEAD_SHA
    if ([string]::IsNullOrWhiteSpace($base) -or [string]::IsNullOrWhiteSpace($head)) {
        throw 'Missing PR_BASE_SHA / PR_HEAD_SHA for pull_request validation'
    }

    $diff = git -C $repoRoot diff --name-only ("{0}...{1}" -f $base, $head)
    if ($LASTEXITCODE -ne 0) {
        throw "git diff failed: $LASTEXITCODE"
    }

    $changed = @($diff | Where-Object { $_ -like 'docs/changes/*.md' })
    if ($changed.Count -eq 0) {
        throw 'PR must include a new/updated markdown file under docs/changes/'
    }
}

Write-Host 'OK: documentation gates'
