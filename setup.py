#!/usr/bin/env python3
"""
Dela Agents Setup Script — cross-platform (Windows, macOS, Linux)
Run from your project root: python /path/to/dela-agents/setup.py
Requires Python 3.8+. No external dependencies.
"""

import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
AGENTS_SOURCE = SCRIPT_DIR / ".claude" / "agents"
TEMPLATES_SOURCE = SCRIPT_DIR / "templates"


def print_header():
    print()
    print("Dela Agents Setup")
    print("=" * 40)
    print(f"Platform:          {platform.system()} {platform.release()}")
    print(f"Python:            {sys.version.split()[0]}")
    print(f"Project directory: {Path.cwd()}")
    print(f"Agents source:     {AGENTS_SOURCE}")
    print()


def looks_like_project_root(cwd: Path) -> bool:
    indicators = [
        cwd / "backend",
        cwd / "frontend",
        cwd / "package.json",
        cwd / "serverless.yml",
        cwd / "pyproject.toml",
        cwd / ".git",
    ]
    return any(p.exists() for p in indicators)


def confirm(prompt: str) -> bool:
    try:
        answer = input(f"{prompt} (y/N): ").strip().lower()
        return answer in ("y", "yes")
    except (KeyboardInterrupt, EOFError):
        print()
        return False


def setup_agents(cwd: Path):
    target = cwd / ".claude" / "agents"
    target.mkdir(parents=True, exist_ok=True)
    print(f"Installing agents to: {target}")

    for agent_file in sorted(AGENTS_SOURCE.glob("*.md")):
        dest = target / agent_file.name
        shutil.copy2(agent_file, dest)
        print(f"  + {agent_file.name}")

    print()


def setup_ai_doc(cwd: Path):
    ai_doc = cwd / ".AI-DOC"
    dirs = [
        ai_doc / "roadmap",
        ai_doc / "workflows",
        ai_doc / "specs" / "wireframes",
        ai_doc / "tickets",
        ai_doc / "qa",
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)

    print("Created .AI-DOC/ structure:")
    print("  .AI-DOC/roadmap/           <- ROADMAP.md lives here")
    print("  .AI-DOC/workflows/         <- UW docs live here")
    print("  .AI-DOC/specs/             <- TECH and DESIGN docs live here")
    print("  .AI-DOC/specs/wireframes/  <- HTML wireframes live here")
    print("  .AI-DOC/tickets/           <- Ticket docs live here")
    print("  .AI-DOC/qa/                <- QA reports live here")
    print()

    roadmap_dest = ai_doc / "roadmap" / "ROADMAP.md"
    if not roadmap_dest.exists():
        roadmap_src = TEMPLATES_SOURCE / "ROADMAP-template.md"
        if roadmap_src.exists():
            shutil.copy2(roadmap_src, roadmap_dest)
            print("Created initial ROADMAP.md from template.")
            print()


def install_uv() -> bool:
    """Attempt to install uv. Returns True if uv is available afterwards."""
    if shutil.which("uv"):
        return True
    system = platform.system()
    print("  uv not found — attempting install...")
    try:
        if system == "Windows":
            subprocess.run(
                ["powershell", "-c", "irm https://astral.sh/uv/install.ps1 | iex"],
                check=True, capture_output=True,
            )
        else:
            subprocess.run(
                "curl -LsSf https://astral.sh/uv/install.sh | sh",
                shell=True, check=True, capture_output=True,
            )
        # Reload PATH
        home = Path.home()
        for candidate in [home / ".local" / "bin", home / ".cargo" / "bin"]:
            if candidate.exists():
                os.environ["PATH"] = str(candidate) + os.pathsep + os.environ.get("PATH", "")
        return bool(shutil.which("uv"))
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def setup_spec_kit(cwd: Path):
    """Auto-install specify-cli and initialize spec-kit in the project."""
    print("Setting up spec-kit...")

    specify = shutil.which("specify")

    if not specify:
        uv_available = install_uv()
        if uv_available:
            print("  Installing specify-cli via uv...")
            try:
                subprocess.run(
                    ["uv", "tool", "install", "specify-cli", "--quiet"],
                    check=True, capture_output=True,
                )
                # Try to find newly installed specify
                try:
                    result = subprocess.run(
                        ["uv", "tool", "dir"], capture_output=True, text=True
                    )
                    tool_bin = Path(result.stdout.strip()) / "bin"
                    if tool_bin.exists():
                        os.environ["PATH"] = str(tool_bin) + os.pathsep + os.environ.get("PATH", "")
                except Exception:
                    pass
                specify = shutil.which("specify")
            except (subprocess.CalledProcessError, FileNotFoundError):
                pass

    if specify:
        specify_dir = cwd / ".specify"
        if not specify_dir.exists():
            print("  Running: specify init . --integration claude --script py")
            try:
                subprocess.run(
                    [specify, "init", ".", "--integration", "claude", "--script", "py"],
                    cwd=cwd, check=True, capture_output=True,
                )
                print("  spec-kit initialized.")
                print("  Commands available: /speckit.specify  /speckit.clarify  /speckit.converge")
            except subprocess.CalledProcessError:
                print("  spec-kit init failed — run manually:")
                print("    specify init . --integration claude --script py")
        else:
            print("  spec-kit already initialized (.specify/ exists). Skipping init.")
    else:
        print("  spec-kit could not be installed automatically.")
        print("  To install manually:")
        if platform.system() == "Windows":
            print("    powershell -c \"irm https://astral.sh/uv/install.ps1 | iex\"")
        else:
            print("    curl -LsSf https://astral.sh/uv/install.sh | sh")
        print("    uv tool install specify-cli")
        print("    specify init . --integration claude --script py")
    print()


def write_vscode_settings(cwd: Path):
    """Write .vscode/settings.json hint for Windows users if VS Code is present."""
    vscode = cwd / ".vscode"
    settings_path = vscode / "settings.json"
    if not vscode.exists():
        return

    existing = {}
    if settings_path.exists():
        try:
            existing = json.loads(settings_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, IOError):
            pass

    # Only add if not already configured
    if "files.eol" not in existing:
        existing["files.eol"] = "\n"
        vscode.mkdir(exist_ok=True)
        settings_path.write_text(
            json.dumps(existing, indent=2) + "\n", encoding="utf-8"
        )
        print("Added files.eol LF setting to .vscode/settings.json")
        print()


def main():
    print_header()

    cwd = Path.cwd()

    if not looks_like_project_root(cwd):
        print("WARNING: This does not look like a project root.")
        print("Make sure you run this script from your project root (e.g., ~/Documents/Dela).")
        print()
        if not confirm("Continue anyway?"):
            print("Aborted.")
            sys.exit(1)
        print()

    setup_agents(cwd)
    setup_ai_doc(cwd)
    setup_spec_kit(cwd)

    if platform.system() == "Windows":
        write_vscode_settings(cwd)

    print("Setup complete.")
    print()
    print("Workflow:")
    print("  1. (Optional) /speckit.specify  — create structured spec.md")
    print("  2. (Optional) /speckit.clarify  — clarify ambiguities in spec.md")
    print("  3. @tech-lead                   — investigate sources, UW doc, TECH spec")
    print("  4. @designer                    — wireframes + DESIGN doc (if UI)")
    print("  5. @scrum-master                — tickets with AC + DoD")
    print("  6. @backend / @frontend         — implement")
    print("  7. @qa                          — validate")
    print("  8. (Optional) /speckit.converge — check code against original spec")
    print()
    print("Full guide: docs/workflow.md")
    print()


if __name__ == "__main__":
    main()
