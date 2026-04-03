#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path


EXPECTED_MATRIX = {
    ("windows", "debug"),
    ("windows", "release"),
    ("linux", "debug"),
    ("linux", "release"),
    ("macos", "debug"),
    ("macos", "release"),
}

EXPECTED_XMAKE_ACTION = "xmake-io/github-action-setup-xmake@v1"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"[validate_release_workflow] {message}")


def extract_matrix_entries(text: str) -> set[tuple[str, str]]:
    pattern = re.compile(
        r"-\s+runner:\s+[^\n]+\s+"
        r"platform:\s+(?P<platform>[^\s]+)\s+"
        r"arch:\s+(?P<arch>[^\s]+)\s+"
        r"mode:\s+(?P<mode>[^\s]+)",
        re.MULTILINE,
    )
    return {
        (match.group("platform"), match.group("mode"))
        for match in pattern.finditer(text)
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workflow", required=True)
    args = parser.parse_args()

    workflow_path = Path(args.workflow).resolve()
    text = workflow_path.read_text(encoding="utf-8")

    require(
        EXPECTED_XMAKE_ACTION in text,
        f"expected xmake action ref {EXPECTED_XMAKE_ACTION!r}",
    )
    require(
        "xmake-io/github-action-setup-xmake@v2" not in text,
        "unexpected invalid xmake action ref '@v2' still present",
    )

    matrix_entries = extract_matrix_entries(text)
    require(
        matrix_entries == EXPECTED_MATRIX,
        f"unexpected build matrix entries: {sorted(matrix_entries)!r}",
    )

    require(
        "python scripts/ci/build_prebuilt_packages.py" in text,
        "missing build_prebuilt_packages.py step",
    )
    require(
        "python scripts/ci/generate_release_notes.py" in text,
        "missing generate_release_notes.py step",
    )
    require(
        "gh release create" in text,
        "missing GitHub release publish step",
    )

    print(f"[validate_release_workflow] OK: {workflow_path}")
    print(f"[validate_release_workflow] xmake action: {EXPECTED_XMAKE_ACTION}")
    print(
        "[validate_release_workflow] matrix: "
        + ", ".join(f"{platform}/{mode}" for platform, mode in sorted(matrix_entries))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
