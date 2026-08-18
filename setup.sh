#!/bin/bash

# Dela Agents Setup Script
# Copies agents into your project's .claude/agents/ directory
# Run from the root of your project: bash /path/to/dela-agents/setup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(pwd)/.claude/agents"
AI_DOC_DIR="$(pwd)/.AI-DOC"

echo ""
echo "Dela Agents Setup"
echo "================="
echo "Project directory: $(pwd)"
echo "Agents source:     $SCRIPT_DIR/.claude/agents/"
echo "Target:            $TARGET_DIR"
echo ""

# Confirm target directory is a project root
if [ ! -f "$(pwd)/package.json" ] && [ ! -f "$(pwd)/serverless.yml" ] && [ ! -d "$(pwd)/backend" ] && [ ! -d "$(pwd)/frontend" ]; then
  echo "WARNING: This does not look like a project root directory."
  echo "Make sure you run this script from your project root (e.g., ~/Documents/Dela)."
  read -p "Continue anyway? (y/N): " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Aborted."
    exit 1
  fi
fi

# Create .claude/agents/ if it doesn't exist
mkdir -p "$TARGET_DIR"
echo "Created $TARGET_DIR"

# Copy all agent files
cp "$SCRIPT_DIR/.claude/agents/"*.md "$TARGET_DIR/"
echo "Copied agents:"
for f in "$SCRIPT_DIR/.claude/agents/"*.md; do
  echo "  - $(basename $f)"
done

# Create .AI-DOC structure
mkdir -p "$AI_DOC_DIR/roadmap"
mkdir -p "$AI_DOC_DIR/workflows"
mkdir -p "$AI_DOC_DIR/specs/wireframes"
mkdir -p "$AI_DOC_DIR/tickets"
mkdir -p "$AI_DOC_DIR/qa"
echo ""
echo "Created .AI-DOC/ directory structure:"
echo "  .AI-DOC/roadmap/      ← ROADMAP.md lives here"
echo "  .AI-DOC/workflows/    ← UW docs live here"
echo "  .AI-DOC/specs/        ← TECH and DESIGN docs live here"
echo "  .AI-DOC/specs/wireframes/  ← HTML wireframes live here"
echo "  .AI-DOC/tickets/      ← Ticket docs live here"
echo "  .AI-DOC/qa/           ← QA reports live here"

# Copy ROADMAP template if no ROADMAP exists yet
if [ ! -f "$AI_DOC_DIR/roadmap/ROADMAP.md" ]; then
  cp "$SCRIPT_DIR/templates/ROADMAP-template.md" "$AI_DOC_DIR/roadmap/ROADMAP.md"
  echo ""
  echo "Created initial ROADMAP.md from template."
fi

# --- spec-kit setup ---
echo ""
echo "Setting up spec-kit..."

SPECIFY=$(command -v specify 2>/dev/null)

if [ -z "$SPECIFY" ]; then
  # Try to install uv if missing
  UV=$(command -v uv 2>/dev/null)
  if [ -z "$UV" ]; then
    echo "  Installing uv package manager..."
    curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null
    # Reload PATH to pick up uv
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    UV=$(command -v uv 2>/dev/null)
  fi

  if [ -n "$UV" ]; then
    echo "  Installing specify-cli via uv..."
    uv tool install specify-cli --quiet 2>/dev/null && \
      export PATH="$HOME/.local/bin:$(uv tool dir)/bin:$PATH"
    SPECIFY=$(command -v specify 2>/dev/null)
  fi
fi

if [ -n "$SPECIFY" ]; then
  if [ ! -d "$(pwd)/.specify" ]; then
    echo "  Running: specify init . --integration claude --script py"
    specify init . --integration claude --script py 2>/dev/null && \
      echo "  spec-kit initialized. Commands available: /speckit.specify /speckit.clarify /speckit.converge" || \
      echo "  spec-kit init failed — run manually: specify init . --integration claude --script py"
  else
    echo "  spec-kit already initialized (.specify/ exists). Skipping init."
  fi
else
  echo "  spec-kit not installed (uv unavailable or install failed)."
  echo "  To install manually:"
  echo "    curl -LsSf https://astral.sh/uv/install.sh | sh"
  echo "    uv tool install specify-cli"
  echo "    specify init . --integration claude --script py"
fi

echo ""
echo "Setup complete."
echo ""
echo "Workflow:"
echo "  1. (Optional) /speckit.specify  — create structured spec.md"
echo "  2. (Optional) /speckit.clarify  — clarify ambiguities in spec.md"
echo "  3. @tech-lead                   — investigate sources, UW doc, TECH spec"
echo "  4. @designer                    — wireframes + DESIGN doc (if UI)"
echo "  5. @scrum-master                — tickets with AC + DoD"
echo "  6. @backend / @frontend         — implement"
echo "  7. @qa                          — validate"
echo "  8. (Optional) /speckit.converge — check code against original spec"
echo ""
echo "Full guide: docs/workflow.md"
echo ""
