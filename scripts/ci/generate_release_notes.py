#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from collections import defaultdict


def load_manifests(artifacts_dir: Path) -> list[dict[str, object]]:
    manifests: list[dict[str, object]] = []
    for path in sorted((artifacts_dir / "manifests").glob("*.json")):
        manifests.append(json.loads(path.read_text(encoding="utf-8")))
    return manifests


def group_key(manifest: dict[str, object]) -> tuple[str, str]:
    return str(manifest["platform"]), str(manifest["mode"])


def render_notes(manifests: list[dict[str, object]]) -> str:
    if not manifests:
        return "# BAAS xrepo prebuilt packages\n\nNo build manifests were found.\n"

    grouped: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for manifest in manifests:
        grouped[group_key(manifest)].append(manifest)

    source_commit = str(manifests[0].get("source_commit", "unknown"))
    built_at = max(str(m.get("built_at_utc", "")) for m in manifests)

    lines = [
        "# BAAS xrepo prebuilt packages",
        "",
        f"- Source commit: `{source_commit}`",
        f"- Generated at (UTC): `{built_at}`",
        f"- Asset count: `{len(manifests)}`",
        "",
        "## Build matrix summary",
        "",
        "| Platform | Mode | Packages |",
        "| --- | --- | --- |",
    ]

    for key in sorted(grouped.keys()):
        manifests_for_key = sorted(grouped[key], key=lambda item: str(item["package"]))
        package_names = ", ".join(str(item["package"]) for item in manifests_for_key)
        lines.append(f"| {key[0]} | {key[1]} | {package_names} |")

    for key in sorted(grouped.keys()):
        lines.extend(
            [
                "",
                f"## {key[0]} / {key[1]}",
                "",
                "| Package | Version | Variant | Archive | SHA256 | Size (bytes) | Built at (UTC) |",
                "| --- | --- | --- | --- | --- | ---: | --- |",
            ]
        )
        for manifest in sorted(grouped[key], key=lambda item: str(item["package"])):
            lines.append(
                "| {package} | {version} | {variant} | `{asset}` | `{sha}` | {size} | `{built}` |".format(
                    package=manifest["package"],
                    version=manifest["version"],
                    variant=manifest["variant"],
                    asset=manifest["asset_name"],
                    sha=manifest["sha256"],
                    size=manifest["size_bytes"],
                    built=manifest["built_at_utc"],
                )
            )

    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--index-output", required=True)
    args = parser.parse_args()

    artifacts_dir = Path(args.artifacts_dir).resolve()
    manifests = load_manifests(artifacts_dir)

    notes = render_notes(manifests)
    Path(args.output).write_text(notes, encoding="utf-8")

    index_payload = {
        "generated_from": str(artifacts_dir),
        "asset_count": len(manifests),
        "builds": manifests,
    }
    Path(args.index_output).write_text(
        json.dumps(index_payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
