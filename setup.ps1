# Dela Agents Setup Script — Windows PowerShell
# Run from your project root:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   & "C:\path\to\dela-agents\setup.ps1"

param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Force
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AgentsSource = Join-Path $ScriptDir ".claude\agents"
$TemplatesSource = Join-Path $ScriptDir "templates"

Write-Host ""
Write-Host "Dela Agents Setup"
Write-Host "=" * 40
Write-Host "Platform:          Windows PowerShell $($PSVersionTable.PSVersion)"
Write-Host "Project directory: $ProjectRoot"
Write-Host "Agents source:     $AgentsSource"
Write-Host ""

# --- Validate project root ---
$indicators = @("backend", "frontend", "package.json", "serverless.yml", ".git")
$looksLikeProject = $indicators | Where-Object { Test-Path (Join-Path $ProjectRoot $_) }

if (-not $looksLikeProject -and -not $Force) {
    Write-Warning "This does not look like a project root directory."
    Write-Host "Make sure you run this from your project root (e.g., C:\Users\you\Documents\Dela)."
    Write-Host ""
    $answer = Read-Host "Continue anyway? (y/N)"
    if ($answer -notmatch "^[Yy]") {
        Write-Host "Aborted."
        exit 1
    }
    Write-Host ""
}

# --- Install agents ---
$targetAgents = Join-Path $ProjectRoot ".claude\agents"
New-Item -ItemType Directory -Force -Path $targetAgents | Out-Null
Write-Host "Installing agents to: $targetAgents"

Get-ChildItem -Path $AgentsSource -Filter "*.md" | Sort-Object Name | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination (Join-Path $targetAgents $_.Name) -Force
    Write-Host "  + $($_.Name)"
}
Write-Host ""

# --- Create .AI-DOC structure ---
$aiDoc = Join-Path $ProjectRoot ".AI-DOC"
$dirs = @(
    "$aiDoc\roadmap",
    "$aiDoc\workflows",
    "$aiDoc\specs\wireframes",
    "$aiDoc\tickets",
    "$aiDoc\qa"
)
foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

Write-Host "Created .AI-DOC\ structure:"
Write-Host "  .AI-DOC\roadmap\           <- ROADMAP.md lives here"
Write-Host "  .AI-DOC\workflows\         <- UW docs live here"
Write-Host "  .AI-DOC\specs\             <- TECH and DESIGN docs live here"
Write-Host "  .AI-DOC\specs\wireframes\  <- HTML wireframes live here"
Write-Host "  .AI-DOC\tickets\           <- Ticket docs live here"
Write-Host "  .AI-DOC\qa\                <- QA reports live here"
Write-Host ""

$roadmapDest = "$aiDoc\roadmap\ROADMAP.md"
$roadmapSrc = "$TemplatesSource\ROADMAP-template.md"
if (-not (Test-Path $roadmapDest) -and (Test-Path $roadmapSrc)) {
    Copy-Item -Path $roadmapSrc -Destination $roadmapDest
    Write-Host "Created initial ROADMAP.md from template."
    Write-Host ""
}

# --- spec-kit setup ---
Write-Host "Setting up spec-kit..."

$specify = Get-Command specify -ErrorAction SilentlyContinue

if (-not $specify) {
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uv) {
        Write-Host "  Installing uv package manager..."
        try {
            powershell -c "irm https://astral.sh/uv/install.ps1 | iex" 2>$null
            # Reload PATH
            $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
            $uv = Get-Command uv -ErrorAction SilentlyContinue
        } catch {
            Write-Host "  uv install failed."
        }
    }

    if ($uv) {
        Write-Host "  Installing specify-cli via uv..."
        try {
            & uv tool install specify-cli --quiet 2>$null
            $toolDir = (& uv tool dir 2>$null).Trim()
            if ($toolDir) { $env:PATH = "$toolDir\bin;$env:PATH" }
            $specify = Get-Command specify -ErrorAction SilentlyContinue
        } catch {
            Write-Host "  specify-cli install failed."
        }
    }
}

if ($specify) {
    $specifyDir = Join-Path $ProjectRoot ".specify"
    if (-not (Test-Path $specifyDir)) {
        Write-Host "  Running: specify init . --integration claude --script py"
        try {
            & specify init . --integration claude --script py 2>$null
            Write-Host "  spec-kit initialized."
            Write-Host "  Commands available: /speckit.specify  /speckit.clarify  /speckit.converge"
        } catch {
            Write-Host "  spec-kit init failed — run manually:"
            Write-Host "    specify init . --integration claude --script py"
        }
    } else {
        Write-Host "  spec-kit already initialized (.specify\ exists). Skipping init."
    }
} else {
    Write-Host "  spec-kit could not be installed automatically."
    Write-Host "  To install manually:"
    Write-Host "    powershell -c `"irm https://astral.sh/uv/install.ps1 | iex`""
    Write-Host "    uv tool install specify-cli"
    Write-Host "    specify init . --integration claude --script py"
}
Write-Host ""

# --- Done ---
Write-Host "Setup complete."
Write-Host ""
Write-Host "Workflow:"
Write-Host "  1. (Optional) /speckit.specify  -- create structured spec.md"
Write-Host "  2. (Optional) /speckit.clarify  -- clarify ambiguities in spec.md"
Write-Host "  3. @tech-lead                   -- investigate sources, UW doc, TECH spec"
Write-Host "  4. @designer                    -- wireframes + DESIGN doc (if UI)"
Write-Host "  5. @scrum-master                -- tickets with AC + DoD"
Write-Host "  6. @backend / @frontend         -- implement"
Write-Host "  7. @qa                          -- validate"
Write-Host "  8. (Optional) /speckit.converge -- check code against original spec"
Write-Host ""
Write-Host "Full guide: docs\workflow.md"
Write-Host ""
