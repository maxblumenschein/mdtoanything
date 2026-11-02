#!/usr/bin/env python3
"""Add or remove the mdtoanything template snippets in Zed's config.

    zed_config.py install <templates dir>
    zed_config.py uninstall

Snippets go to ~/.config/zed/snippets/snippets.json (all languages, so they
also expand in untitled buffers). Only entries named "tpl-*" are touched; the
existing file is backed up to *.bak before it is rewritten. Tasks named
"template *" left in ~/.config/zed/tasks.json by older versions are removed.
"""

import json
import re
import shutil
import sys
from pathlib import Path

ZED_DIR = Path.home() / ".config" / "zed"
SNIPPETS = ZED_DIR / "snippets" / "snippets.json"
TASKS = ZED_DIR / "tasks.json"

SNIPPET_PREFIX = "tpl-"
TASK_PREFIX = "template "


def load(path, empty):
    """Read a Zed JSON file, allowing // comments and trailing commas."""
    if not path.exists():
        return empty
    text = path.read_text()
    # Drop // comments outside strings, then trailing commas
    text = re.sub(r'("(?:\\.|[^"\\])*")|//[^\n]*', lambda m: m.group(1) or "", text)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    try:
        return json.loads(text) if text.strip() else empty
    except json.JSONDecodeError as e:
        sys.exit(f"Could not read {path}: {e}\nFix or move the file and run again.")


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        shutil.copy2(path, path.with_name(path.name + ".bak"))
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def snippet_body(template):
    # Templates are snippet syntax with literal backslashes; date
    # placeholders get LaTeX/neutral defaults.
    text = template.replace("\\", "\\\\")
    text = text.replace("{{date}}", "\\\\today").replace("{{year}}", "YYYY")
    return text.rstrip("\n").split("\n")


def without_snippets():
    return {k: v for k, v in load(SNIPPETS, {}).items()
            if not v.get("prefix", "").startswith(SNIPPET_PREFIX)}


def remove_old_tasks():
    if not TASKS.exists():
        return
    tasks = load(TASKS, [])
    kept = [t for t in tasks if not t.get("label", "").startswith(TASK_PREFIX)]
    if len(kept) != len(tasks):
        save(TASKS, kept)


def install(templates_dir):
    snippets = without_snippets()
    for template in sorted(Path(templates_dir).glob("*.md")):
        name = template.stem
        snippets[f"mdtoanything {name}"] = {
            "prefix": SNIPPET_PREFIX + name,
            "body": snippet_body(template.read_text()),
            "description": f"mdtoanything {name} template",
        }
        print(f"  {SNIPPET_PREFIX + name}")

    save(SNIPPETS, snippets)
    remove_old_tasks()


def uninstall():
    if SNIPPETS.exists():
        save(SNIPPETS, without_snippets())
    remove_old_tasks()


if __name__ == "__main__":
    if sys.argv[1:2] == ["install"] and len(sys.argv) == 3:
        install(sys.argv[2])
    elif sys.argv[1:] == ["uninstall"]:
        uninstall()
    else:
        sys.exit(__doc__)
