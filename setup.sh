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

echo ""
echo "Setup complete."
echo ""
echo "Next steps:"
echo "  1. Open Claude Code in your project directory"
echo "  2. Start any request with: @tech-lead {your request}"
echo "  3. Follow the workflow in dela-agents/docs/workflow.md"
echo ""
echo "Agent order: tech-lead → designer (if UI) → scrum-master → backend/frontend → qa"
echo ""
