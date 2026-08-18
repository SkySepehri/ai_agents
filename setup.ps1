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

# --- Check spec-kit ---
$specify = Get-Command specify -ErrorAction SilentlyContinue
if ($specify) {
    Write-Host "spec-kit (specify CLI) found at: $($specify.Source)"
    Write-Host "  Run: specify init . --integration claude --script py"
} else {
    Write-Host "spec-kit (optional): not installed."
    Write-Host "  To install: pip install uv; uv tool install specify-cli"
    Write-Host "  Then run:   specify init . --integration claude --script py"
}
Write-Host ""

# --- Done ---
Write-Host "Setup complete."
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Open Claude Code in your project directory"
Write-Host "  2. Start any request with: @tech-lead <your request>"
Write-Host "  3. Follow the workflow in docs\workflow.md"
Write-Host ""
Write-Host "Agent order: tech-lead -> designer (if UI) -> scrum-master -> backend/frontend -> qa"
Write-Host ""
