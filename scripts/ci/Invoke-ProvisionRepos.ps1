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
            orchestrator   = "https://github.com/$Owner/$Slug-control"
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

function Get-ProvisionTriggerUrl {
    param(
        [Parameter(Mandatory = $true)][string]$EventName,
        [Parameter(Mandatory = $true)]$Event
    )

    $base = if ([string]::IsNullOrWhiteSpace($env:GITHUB_SERVER_URL)) {
        'https://github.com'
    }
    else {
        $env:GITHUB_SERVER_URL.TrimEnd('/')
    }

    if ($EventName -eq 'issues') {
        $issue = $Event.issue
        if ($null -ne $issue.html_url -and -not [string]::IsNullOrWhiteSpace([string]$issue.html_url)) {
            return [string]$issue.html_url
        }

        return "$base/$($env:GITHUB_REPOSITORY)/issues/$($issue.number)"
    }

    $runId = $env:GITHUB_RUN_ID
    if ([string]::IsNullOrWhiteSpace($runId)) {
        return "$base/$($env:GITHUB_REPOSITORY)/actions"
    }

    return "$base/$($env:GITHUB_REPOSITORY)/actions/runs/$runId"
}

function Invoke-GetRepositoryContents {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)]$Headers
    )

    $uri = "https://api.github.com/repos/$Repo/contents/$Path" + "?ref=$([Uri]::EscapeDataString($Branch))"

    try {
        return Invoke-RestMethod -Method Get -Uri $uri -Headers $Headers
    }
    catch {
        $status = $null
        if ($null -ne $_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
        }

        if ($status -eq 404) {
            return $null
        }

        throw
    }
}

function Invoke-PutRepositoryContents {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][string]$Utf8Text,
        [Parameter(Mandatory = $true)]$Headers,
        [string]$Sha = $null
    )

    $putUri = "https://api.github.com/repos/$Repo/contents/$Path"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Utf8Text)
    $b64 = [Convert]::ToBase64String($bytes)

    $body = [ordered]@{
        message = $Message
        content = $b64
        branch  = $Branch
    }

    if (-not [string]::IsNullOrWhiteSpace($Sha)) {
        $body['sha'] = $Sha
    }

    $putBody = ($body | ConvertTo-Json -Compress)
    Invoke-RestMethod -Method Put -Uri $putUri -Headers $Headers -Body $putBody -ContentType 'application/json; charset=utf-8' | Out-Null
}

function Update-ProjectManagerSystemsRegistry {
    param(
        [Parameter(Mandatory = $true)][string]$Owner,
        [Parameter(Mandatory = $true)][string]$Slug,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [Parameter(Mandatory = $true)][string]$Visibility,
        [Parameter(Mandatory = $true)][string]$HubUrl,
        [Parameter(Mandatory = $true)][string]$DocsUrl,
        [Parameter(Mandatory = $true)][string]$EventName,
        [Parameter(Mandatory = $true)]$Event
    )

    $pmRepo = $env:GITHUB_REPOSITORY
    $headers = Get-GitHubRestHeaders
    $branch = [string](Invoke-RestMethod -Method Get -Uri "https://api.github.com/repos/$pmRepo" -Headers $headers).default_branch
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw "Could not read default_branch for $pmRepo."
    }

    $registryPath = 'config/provisioned-systems.json'
    $existing = Invoke-GetRepositoryContents -Repo $pmRepo -Path $registryPath -Branch $branch -Headers $headers

    $systemsList = New-Object System.Collections.Generic.List[object]
    if ($null -ne $existing -and $existing.type -eq 'file' -and -not [string]::IsNullOrWhiteSpace($existing.content)) {
        $raw = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(([string]$existing.content -replace '\s', '')))
        $parsed = $raw | ConvertFrom-Json
        if ($null -ne $parsed.systems) {
            foreach ($s in @($parsed.systems)) {
                if ([string]$s.slug -ne $Slug) {
                    $systemsList.Add($s)
                }
            }
        }
    }

    $triggerUrl = Get-ProvisionTriggerUrl -EventName $EventName -Event $Event
    $iso = [DateTime]::UtcNow.ToString('o')

    $newEntry = [ordered]@{
        slug               = $Slug
        displayName        = $DisplayName
        owner              = $Owner
        visibility         = $Visibility
        hub                = $HubUrl
        docs               = $DocsUrl
        trigger            = $triggerUrl
        provisionedAtUtc   = $iso
    }

    $systemsList.Insert(0, [pscustomobject]$newEntry)

    $registryObject = [ordered]@{ systems = @($systemsList.ToArray()) }
    $registryJson = ($registryObject | ConvertTo-Json -Depth 10 -Compress)

    $registryExisting = Invoke-GetRepositoryContents -Repo $pmRepo -Path $registryPath -Branch $branch -Headers $headers
    $registrySha = $null
    if ($null -ne $registryExisting -and $registryExisting.type -eq 'file') {
        $registrySha = [string]$registryExisting.sha
    }

    Invoke-PutRepositoryContents -Repo $pmRepo -Path $registryPath -Branch $branch `
        -Message "chore: register provisioned system $Slug" `
        -Utf8Text $registryJson `
        -Headers $headers `
        -Sha $registrySha

    $mdPath = 'docs/systems.md'
    $safeName = $DisplayName -replace '\|', '/' -replace "`r?`n", ' '
    if ($safeName.Length -gt 80) {
        $safeName = $safeName.Substring(0, 77) + '...'
    }

    $mdLines = New-Object System.Collections.Generic.List[string]
    $mdLines.Add('# Zainicjowane systemy (PDLC)')
    $mdLines.Add('')
    $mdLines.Add('Ten plik jest **nadpisywany przez CI** po każdym udanym provisioning (`Provision PLDC project repos`).')
    $mdLines.Add('')
    $mdLines.Add('Kanoniczne dane (JSON): [`config/provisioned-systems.json`](../config/provisioned-systems.json).')
    $mdLines.Add('')
    $mdLines.Add('| Slug | Nazwa | Hub | Docs | Widoczność | Ostatni provisioning (UTC) | Źródło |')
    $mdLines.Add('|------|-------|-----|------|------------|----------------------------|--------|')

    foreach ($s in $systemsList) {
        $slugCell = [string]$s.slug
        $nameCell = ([string]$s.displayName) -replace '\|', '/' -replace "`r?`n", ' '
        if ($nameCell.Length -gt 60) {
            $nameCell = $nameCell.Substring(0, 57) + '...'
        }

        $mdLines.Add(("| ``{0}`` | {1} | [hub]({2}) | [docs]({3}) | {4} | {5} | [źródło]({6}) |" -f `
                    $slugCell, $nameCell, [string]$s.hub, [string]$s.docs, [string]$s.visibility, [string]$s.provisionedAtUtc, [string]$s.trigger))
    }

    $mdText = ($mdLines -join "`n") + "`n"

    $mdExisting = Invoke-GetRepositoryContents -Repo $pmRepo -Path $mdPath -Branch $branch -Headers $headers
    $mdSha = $null
    if ($null -ne $mdExisting -and $mdExisting.type -eq 'file') {
        $mdSha = [string]$mdExisting.sha
    }

    Invoke-PutRepositoryContents -Repo $pmRepo -Path $mdPath -Branch $branch `
        -Message "chore: refresh systems list for $Slug" `
        -Utf8Text $mdText `
        -Headers $headers `
        -Sha $mdSha

    return "UPDATED Project Manager registry: $pmRepo ($registryPath, $mdPath)"
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

try {
    $results.Add((Update-ProjectManagerSystemsRegistry -Owner $owner -Slug $slug -DisplayName $displayName -Visibility $visibility -HubUrl $hubUrl -DocsUrl $docsUrl -EventName $eventName -Event $event))
}
catch {
    $results.Add("WARN systems registry update failed: $($_.Exception.Message)")
}

$comment = @()
$comment += '### Provisioning result'
$comment += ''
$comment += $results
$comment += ''
$comment += '### Next steps'
$comment += "- **Lista systemów:** [`docs/systems.md`](https://github.com/$($env:GITHUB_REPOSITORY)/blob/main/docs/systems.md) oraz [`config/provisioned-systems.json`](https://github.com/$($env:GITHUB_REPOSITORY)/blob/main/config/provisioned-systems.json) (aktualizowane przez CI)."
$comment += "- Hub ``$owner/$slug-hub``: profil ``config/solutions/sample.json`` jest nadpisywany przez CI linkami do repo ``$slug-fe|api|db|gitops|control`` (oraz nazwa/kod projektu z provisioning)."
$comment += "- Dokumentacja projektu: ``$owner/$slug-docs``."
$comment += "- Frontend / API / DB / GitOps / Orchestrator: repozytoria z sufiksami ``fe``, ``api``, ``db``, ``gitops``, ``control``."
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
