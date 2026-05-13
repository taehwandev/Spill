#!/usr/bin/env python3
"""
Spill agent workflow helper.

Uses only the Python standard library.

Commands:
  python3 .agents/scripts/workflow.py verify
  python3 .agents/scripts/workflow.py docs
  python3 .agents/scripts/workflow.py run-gates
  python3 .agents/scripts/workflow.py language-gates
  python3 .agents/scripts/workflow.py code-gates
  python3 .agents/scripts/workflow.py build
  python3 .agents/scripts/workflow.py new-run <feature-id>
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AGENTS = ROOT / ".agents"
TEMPLATES = AGENTS / "templates"
RUNS = AGENTS / "runs"
WORKFLOW_JSON = AGENTS / "workflows" / "workflow.json"
TEXT_SUFFIXES = {
    ".md",
    ".swift",
    ".py",
    ".mjs",
    ".json",
    ".yml",
    ".yaml",
    ".sh",
    ".txt",
}
TEXT_FILENAMES = {"Package.swift", ".gitignore"}
EXCLUDED_DIRS = {".git", ".build", ".swiftpm", "DerivedData"}


class Result:
    def __init__(self) -> None:
        self.failures: list[str] = []

    def ok(self, message: str) -> None:
        print(f"OK: {message}")

    def fail(self, message: str) -> None:
        print(f"FAIL: {message}")
        self.failures.append(message)

    def finish(self) -> None:
        if self.failures:
            print(f"\n{len(self.failures)} failure(s)")
            raise SystemExit(1)
        print("\nAll checks passed.")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def repository_text_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        parts = path.relative_to(ROOT).parts
        if any(part in EXCLUDED_DIRS for part in parts):
            continue
        if path.suffix in TEXT_SUFFIXES or path.name in TEXT_FILENAMES:
            files.append(path)
    return files


def run_files() -> list[str]:
    return [
        "00-intake.md",
        "01-prd.md",
        "02-ard.md",
        "03-task-breakdown.yml",
        "04-agent-briefs.md",
        "05-verification.md",
        "06-closeout.md",
    ]


def verify_docs() -> None:
    result = Result()

    if not WORKFLOW_JSON.exists():
        result.fail("missing .agents/workflows/workflow.json")
        result.finish()

    workflow = json.loads(read(WORKFLOW_JSON))
    for doc in workflow.get("requiredDocs", []):
        path = ROOT / doc
        if path.exists():
            result.ok(f"found {doc}")
        else:
            result.fail(f"missing {doc}")

    for run_dir in sorted(RUNS.glob("*")):
        if not run_dir.is_dir():
            continue
        for name in run_files():
            path = run_dir / name
            if path.exists():
                result.ok(f"run {run_dir.name} has {name}")
            else:
                result.fail(f"run {run_dir.name} missing {name}")

    rule_docs = [
        AGENTS / "specs" / "prd.md",
        AGENTS / "specs" / "ard.md",
        AGENTS / "workflows" / "implementation.md",
        AGENTS / "workflows" / "multi-agent.md",
    ]
    for path in rule_docs:
        if not path.exists():
            result.fail(f"missing {path.relative_to(ROOT)}")
            continue
        text = read(path).lower()
        for token in ["spacer", "private api"]:
            if token not in text:
                result.fail(f"{path.relative_to(ROOT)} should mention {token!r}")

    result.finish()


def run_gates() -> None:
    result = Result()
    placeholder_patterns = [
        r"<[^>\n]+>",
        r"Summarize the user request",
        r"What pain does this solve",
        r"Is this feature necessary for current product direction",
        r"Is it better solved by Spill",
        r"What happens if we do not build it\?",
        r"Decision:\s*`build \| defer \| reject \| needs-clarification`",
        r"decision:\s*build \| defer \| reject \| needs-clarification",
        r"clarification_required:\s*true",
        r"What should the user see or do",
        r"One paragraph describing",
        r"Sketch only",
        r"<task title>",
    ]

    for run_dir in sorted(RUNS.glob("*")):
        if not run_dir.is_dir():
            continue

        task_breakdown = run_dir / "03-task-breakdown.yml"
        if task_breakdown.exists() and re.search(r"(?m)^status:\s*draft\s*$", read(task_breakdown)):
            result.ok(f"run {run_dir.name} is draft; skipping readiness gates")
            continue

        for name in run_files():
            path = run_dir / name
            if not path.exists():
                result.fail(f"run {run_dir.name} missing {name}")
                continue

            text = read(path)
            if name == "00-intake.md":
                if re.search(r"Decision:\s*`build`", text):
                    result.ok(f"run {run_dir.name} has an implementation-ready necessity decision")
                else:
                    result.fail(f"run {run_dir.name} does not have a `build` necessity decision")

            if name == "03-task-breakdown.yml":
                if not re.search(r"(?m)^necessity:\s*$", text):
                    result.fail(f"run {run_dir.name} missing task breakdown necessity block")
                elif not re.search(r"(?m)^\s+decision:\s*build\s*$", text):
                    result.fail(f"run {run_dir.name} task breakdown is not approved for build")
                elif re.search(r"(?m)^\s+clarification_required:\s*true\s*$", text):
                    result.fail(f"run {run_dir.name} still requires clarification")
                else:
                    result.ok(f"run {run_dir.name} task breakdown has resolved necessity gate")

            for pattern in placeholder_patterns:
                if re.search(pattern, text):
                    result.fail(f"run {run_dir.name} has placeholder content in {name}: {pattern}")
                    break
            else:
                result.ok(f"run {run_dir.name} has completed {name}")

    result.finish()


def language_gates() -> None:
    result = Result()
    korean_pattern = re.compile(r"[\uac00-\ud7a3]")
    scanned = 0

    for path in repository_text_files():
        try:
            text = read(path)
        except UnicodeDecodeError:
            continue

        scanned += 1
        for line_number, line in enumerate(text.splitlines(), start=1):
            if korean_pattern.search(line):
                result.fail(f"{path.relative_to(ROOT)}:{line_number} contains Korean text")
                break

    if not result.failures:
        result.ok(f"language gate scanned {scanned} text files")

    result.finish()


def new_run(feature_id: str) -> None:
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", feature_id):
        raise SystemExit("feature-id must be kebab-case")

    target = RUNS / feature_id
    if target.exists():
        raise SystemExit(f"run already exists: {target.relative_to(ROOT)}")

    target.mkdir(parents=True)
    for name in run_files():
        source = TEMPLATES / name
        if not source.exists():
            raise SystemExit(f"missing template: {source.relative_to(ROOT)}")
        text = read(source).replace("<feature-id>", feature_id)
        (target / name).write_text(text, encoding="utf-8")

    print(f"Created {target.relative_to(ROOT)}")


def code_gates() -> None:
    result = Result()
    sources = list((ROOT / "Sources").rglob("*.swift"))
    all_source = "\n".join(read(path) for path in sources)

    forbidden = [
        (r"\bSkyLight\b", "private SkyLight API"),
        (r"\bCGS(?!ize\b)[A-Za-z0-9_]*\b", "private CoreGraphics Services API"),
        (r"statusItemReserveLength", "status item spacer reserve length"),
    ]
    for pattern, label in forbidden:
        if re.search(pattern, all_source):
            result.fail(f"forbidden pattern found: {label}")
        else:
            result.ok(f"no {label}")

    status_controller = ROOT / "Sources" / "Spill" / "StatusItemController.swift"
    if not status_controller.exists():
        result.fail("missing StatusItemController.swift")
    else:
        text = read(status_controller)
        created_items = len(re.findall(r"NSStatusBar\.system\.statusItem", text))
        if created_items == 1:
            result.ok("StatusItemController creates one NSStatusItem")
        else:
            result.fail(f"StatusItemController creates {created_items} NSStatusItems; expected 1")

        if re.search(r"\bspacer(Item)?\b", text, re.IGNORECASE):
            result.fail("StatusItemController still contains spacer logic")
        else:
            result.ok("StatusItemController has no spacer logic")

    result.finish()


def build() -> None:
    subprocess.run(["swift", "build"], cwd=ROOT, check=True)


def verify_all() -> None:
    verify_docs()
    run_gates()
    language_gates()
    code_gates()
    build()


def main() -> None:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("verify")
    commands.add_parser("docs")
    commands.add_parser("run-gates")
    commands.add_parser("language-gates")
    commands.add_parser("code-gates")
    commands.add_parser("build")
    new_run_parser = commands.add_parser("new-run")
    new_run_parser.add_argument("feature_id")
    args = parser.parse_args()

    if args.command == "verify":
        verify_all()
    elif args.command == "docs":
        verify_docs()
    elif args.command == "run-gates":
        run_gates()
    elif args.command == "language-gates":
        language_gates()
    elif args.command == "code-gates":
        code_gates()
    elif args.command == "build":
        build()
    elif args.command == "new-run":
        new_run(args.feature_id)


if __name__ == "__main__":
    main()
