$ErrorActionPreference = 'Stop'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) not found on PATH.'
}

if ([string]::IsNullOrWhiteSpace($env:GITHUB_EVENT_PATH)) {
    throw 'Missing GITHUB_EVENT_PATH (this script is intended to run in GitHub Actions).'
}

if ([string]::IsNullOrWhiteSpace($env:GH_TOKEN)) {
    throw 'Missing GH_TOKEN. Configure repository secret PDLC_REPO_ADMIN_TOKEN with a PAT that can create repositories under this account or organization.'
}

if ([string]::IsNullOrWhiteSpace($env:GITHUB_REPOSITORY)) {
    throw 'Missing GITHUB_REPOSITORY.'
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$templatesPath = Join-Path $repoRoot 'config/templates.json'
if (-not (Test-Path -LiteralPath $templatesPath)) {
    throw "Missing config/templates.json"
}

$cfg = Get-Content -LiteralPath $templatesPath -Raw | ConvertFrom-Json
if ($null -eq $cfg.templates) {
    throw 'config/templates.json: missing templates array'
}

$event = Get-Content -LiteralPath $env:GITHUB_EVENT_PATH -Raw | ConvertFrom-Json
$eventName = $env:GITHUB_EVENT_NAME

$owner = ($env:GITHUB_REPOSITORY -split '/')[0]

function Get-IssueSectionValue {
    param(
        [Parameter(Mandatory = $true)][string]$Body,
        [Parameter(Mandatory = $true)][string]$Heading
    )

    $escaped = [regex]::Escape($Heading)
    $pattern = "(?ms)^###\s*$escaped\s*\r?\n+(.*?)(?=^###|\z)"
    if ($Body -notmatch $pattern) {
        return $null
    }

    return ($Matches[1].Trim())
}

function Get-FirstNonEmptyLine {
    param([Parameter(Mandatory = $true)][string]$Text)
    foreach ($line in ($Text -split "`r?`n")) {
        $t = $line.Trim()
        if ($t.Length -gt 0) {
            return $t
        }
    }

    return ''
}

function Get-GitHubRestHeaders {
    return @{
        Authorization          = "Bearer $($env:GH_TOKEN)"
        Accept                 = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent'           = 'pdlc-project-manager-provision'
    }
}

function Update-HubProvisionedSolutionProfile {
    param(
        [Parameter(Mandatory = $true)][string]$Owner,
        [Parameter(Mandatory = $true)][string]$Slug,
        [Parameter(Mandatory = $true)][string]$DisplayName
    )

    $hubRepo = "$Owner/$Slug-hub"
    gh repo view $hubRepo 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
        return 'SKIP hub profile update (hub repo not found).'
    }

    $headers = Get-GitHubRestHeaders
    $repoApi = "https://api.github.com/repos/$hubRepo"
    $repoInfo = Invoke-RestMethod -Method Get -Uri $repoApi -Headers $headers
    $branch = [string]$repoInfo.default_branch
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw "Could not read default_branch for $hubRepo."
    }

    $path = 'config/solutions/sample.json'
    $getUri = "https://api.github.com/repos/$hubRepo/contents/$path" + "?ref=$([Uri]::EscapeDataString($branch))"
    $existing = Invoke-RestMethod -Method Get -Uri $getUri -Headers $headers
    if ($existing.type -ne 'file' -or [string]::IsNullOrWhiteSpace($existing.sha)) {
        throw "Unexpected GitHub contents payload for $hubRepo/$path (missing sha)."
    }

    $projectCode = ($Slug -replace '-', '').ToUpperInvariant()
    if ($projectCode.Length -gt 32) {
        $projectCode = $projectCode.Substring(0, 32)
    }

    $profile = [ordered]@{
        project = [ordered]@{
            name = $DisplayName
            code = $projectCode
        }
        repos   = [ordered]@{
            frontend       = "https://github.com/$Owner/$Slug-fe"
            backend_dotnet = "https://github.com/$Owner/$Slug-api"
            gitops         = "https://github.com/$Owner/$Slug-gitops"
            liquibase_db   = "https://github.com/$Owner/$Slug-db"
        }
    }

    $json = ($profile | ConvertTo-Json -Depth 10 -Compress)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $b64 = [Convert]::ToBase64String($bytes)

    $putUri = "https://api.github.com/repos/$hubRepo/contents/$path"
    $putBody = @{
        message = 'chore: set PLDC hub profile to provisioned repositories'
        content = $b64
        sha     = [string]$existing.sha
        branch  = $branch
    } | ConvertTo-Json -Compress

    Invoke-RestMethod -Method Put -Uri $putUri -Headers $headers -Body $putBody -ContentType 'application/json; charset=utf-8' | Out-Null

    return "UPDATED hub profile: $hubRepo/$path (branch $branch)"
}

$displayName = $null
$slug = $null
$visibility = 'public'
$longDescription = ''

if ($eventName -eq 'workflow_dispatch') {
    $displayName = [string]$event.inputs.display_name
    $slug = [string]$event.inputs.project_slug
    $visibility = [string]$event.inputs.visibility
}
elseif ($eventName -eq 'issues') {
    if ($event.action -ne 'labeled') {
        throw "Unsupported issues action: $($event.action)"
    }

    $title = [string]$event.issue.title
    if ($title -notmatch '^\s*\[provision\]\s*(.+?)\s*$') {
        throw "Issue title must match: [provision] <display name>. Actual title: $title"
    }

    $displayName = $Matches[1].Trim()
    $body = [string]$event.issue.body

    $slugRaw = Get-IssueSectionValue -Body $body -Heading 'Project slug (ASCII)'
    if ([string]::IsNullOrWhiteSpace($slugRaw)) {
        throw 'Could not parse ### Project slug (ASCII) from issue body. Use the issue template fields.'
    }

    $slug = (Get-FirstNonEmptyLine -Text $slugRaw).Trim().Trim('*').ToLowerInvariant()

    $visBlock = Get-IssueSectionValue -Body $body -Heading 'Visibility'
    if (-not [string]::IsNullOrWhiteSpace($visBlock)) {
        $visLine = (Get-FirstNonEmptyLine -Text $visBlock).Trim().Trim('*').ToLowerInvariant()
        if ($visLine -in @('public', 'private')) {
            $visibility = $visLine
        }
    }

    $descBlock = Get-IssueSectionValue -Body $body -Heading 'Short description'
    if (-not [string]::IsNullOrWhiteSpace($descBlock)) {
        $longDescription = (Get-FirstNonEmptyLine -Text $descBlock).Trim().Trim('*')
    }
}
else {
    throw "Unsupported GITHUB_EVENT_NAME: $eventName"
}

if ([string]::IsNullOrWhiteSpace($displayName)) {
    throw 'Display name is empty.'
}

if ([string]::IsNullOrWhiteSpace($slug)) {
    throw 'Project slug is empty.'
}

if ($slug -notmatch '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$') {
    throw "Invalid project slug '$slug'. Use lowercase letters, digits, hyphens; length 2–63 (GitHub repo name limits)."
}

if ($visibility -notin @('public', 'private')) {
    throw "Invalid visibility '$visibility' (expected public or private)."
}

$baseDesc = "PDLC project: $displayName"
if (-not [string]::IsNullOrWhiteSpace($longDescription)) {
    $baseDesc += " — $longDescription"
}

if ($baseDesc.Length -gt 340) {
    $baseDesc = $baseDesc.Substring(0, 337) + '...'
}

$results = New-Object System.Collections.Generic.List[string]

$visArg = if ($visibility -eq 'private') { '--private' } else { '--public' }

foreach ($t in @($cfg.templates)) {
    $templateRepo = [string]$t.template_repo
    $suffix = [string]$t.repo_suffix
    $suffixLabel = [string]$t.description_suffix

    if ([string]::IsNullOrWhiteSpace($templateRepo) -or [string]::IsNullOrWhiteSpace($suffix)) {
        throw 'Invalid templates.json entry (template_repo / repo_suffix required).'
    }

    $target = "$owner/$slug-$suffix"
    $desc = "$suffixLabel | $baseDesc"
    if ($desc.Length -gt 350) {
        $desc = $desc.Substring(0, 347) + '...'
    }

    gh repo view $target 1>$null 2>$null
    if ($LASTEXITCODE -eq 0) {
        $results.Add("SKIP (exists): https://github.com/$target")
        continue
    }

    Write-Host "Creating $target from $templateRepo ..."
    gh repo create $target --template $templateRepo $visArg --description $desc
    if ($LASTEXITCODE -ne 0) {
        throw "gh repo create failed for $target (exit code $LASTEXITCODE)."
    }

    $results.Add("CREATED: https://github.com/$target")
}

try {
    $results.Add((Update-HubProvisionedSolutionProfile -Owner $owner -Slug $slug -DisplayName $displayName))
}
catch {
    $results.Add("WARN hub profile update failed: $($_.Exception.Message)")
}

$hubUrl = "https://github.com/$owner/$slug-hub"
$docsUrl = "https://github.com/$owner/$slug-docs"

$comment = @()
$comment += '### Provisioning result'
$comment += ''
$comment += $results
$comment += ''
$comment += '### Next steps'
$comment += "- Hub ``$owner/$slug-hub``: profil ``config/solutions/sample.json`` jest nadpisywany przez CI linkami do repo ``$slug-fe|api|db|gitops`` (oraz nazwa/kod projektu z provisioning)."
$comment += "- Dokumentacja projektu: ``$owner/$slug-docs``."
$comment += "- Frontend / API / DB / GitOps: repozytoria z sufiksami ``fe``, ``api``, ``db``, ``gitops``."
$comment += ''
$comment += "Hub: $hubUrl"
$comment += "Docs: $docsUrl"

$commentText = ($comment -join "`n")

Write-Host $commentText

if ($eventName -eq 'issues') {
    $issueNumber = [int]$event.issue.number
    if ($issueNumber -le 0) {
        throw 'Invalid issue.number in event payload.'
    }

    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tmp, $commentText, [System.Text.UTF8Encoding]::new($false))
        gh issue comment $issueNumber --repo $env:GITHUB_REPOSITORY --body-file $tmp
        if ($LASTEXITCODE -ne 0) {
            throw "gh issue comment failed (exit code $LASTEXITCODE)."
        }
    }
    finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

Write-Host 'Provisioning finished.'
