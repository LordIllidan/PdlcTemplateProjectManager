param(
    [string]$ChangesDirectory = "docs/changes"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $ChangesDirectory)) {
    throw "Missing change documentation directory: $ChangesDirectory"
}

$errors = New-Object System.Collections.Generic.List[string]
$files = @(Get-ChildItem -LiteralPath $ChangesDirectory -File -Filter "*.md")

if ($files.Count -eq 0) {
    $errors.Add("No Markdown files found in $ChangesDirectory.")
}

foreach ($file in $files) {
    if ($file.Name -ne "README.md" -and $file.Name -notmatch "^\d{4}-\d{2}-\d{2}-[a-z0-9-]+\.md$") {
        $errors.Add("$($file.Name) does not match YYYY-MM-DD-short-name.md.")
    }

    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($section in @("## Summary", "## Verification", "## Context Updates")) {
        if ($file.Name -ne "README.md" -and $content -notmatch [regex]::Escape($section)) {
            $errors.Add("$($file.Name) missing section $section.")
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host "Change docs error: $_" }
    throw "Change documentation validation failed with $($errors.Count) error(s)."
}

Write-Host "Change documentation validation passed."
