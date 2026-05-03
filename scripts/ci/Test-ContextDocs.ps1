param(
    [string]$RepositoryRoot = "."
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$errors = New-Object System.Collections.Generic.List[string]

function Add-Error {
    param([Parameter(Mandatory = $true)][string]$Message)
    $errors.Add($Message)
}

function Get-RelativePathFromRoot {
    param([Parameter(Mandatory = $true)][string]$Path)
    $rootFull = [System.IO.Path]::GetFullPath($root)
    $absFull = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
    if (-not $absFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is not under repository root: $Path"
    }
    $rel = $absFull.Substring($rootFull.Length).TrimStart([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar))
    return ($rel -replace "\\", "/")
}

$rootContext = Join-Path $root "context.md"
if (-not (Test-Path -LiteralPath $rootContext)) {
    Add-Error "Missing root context.md."
}

$requiredDirectories = @(
    ".",
    "docs"
)

foreach ($directory in $requiredDirectories) {
    $contextPath = Join-Path $root "$directory/context.md"
    if (-not (Test-Path -LiteralPath $contextPath)) {
        Add-Error "Missing context.md in $directory."
    }
}

$contextFiles = Get-ChildItem -LiteralPath $root -Recurse -File -Filter "context.md" |
    Where-Object { $_.FullName -notlike "*\.git\*" }

foreach ($context in $contextFiles) {
    $content = Get-Content -LiteralPath $context.FullName -Raw
    foreach ($section in @("## Purpose", "## Boundaries", "## Important Files", "## Local Commands", "## Decisions", "## Child Contexts")) {
        if ($content -notmatch [regex]::Escape($section)) {
            Add-Error "$((Get-RelativePathFromRoot -Path $context.FullName)) missing section $section."
        }
    }

    $contextDirectory = Split-Path -Parent $context.FullName
    $childContexts = Get-ChildItem -LiteralPath $contextDirectory -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "context.md") }

    foreach ($child in $childContexts) {
        $relativeChild = "$($child.Name)/context.md"
        if ($content -notmatch [regex]::Escape($relativeChild)) {
            Add-Error "$((Get-RelativePathFromRoot -Path $context.FullName)) does not reference child context $relativeChild."
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host "Context docs error: $_" }
    throw "Context documentation validation failed with $($errors.Count) error(s)."
}

Write-Host "Context documentation validation passed."
