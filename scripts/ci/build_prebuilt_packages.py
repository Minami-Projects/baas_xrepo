#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
from zipfile import ZIP_DEFLATED, ZipFile
from datetime import datetime, timezone


REPO_ROOT = Path(__file__).resolve().parents[2]


def run(cmd: list[str], *, capture: bool = False) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(cmd))
    return subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        text=True,
        check=True,
        capture_output=capture,
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def archive_install_tree(install_dir: Path, archive_path: Path, platform_name: str) -> None:
    if archive_path.suffix == ".zip":
        with ZipFile(archive_path, "w", compression=ZIP_DEFLATED) as bundle:
            for file_path in sorted(install_dir.rglob("*")):
                if file_path.is_file():
                    bundle.write(file_path, file_path.relative_to(install_dir))
        return

    with tarfile.open(archive_path, "w:gz") as bundle:
        for file_path in sorted(install_dir.rglob("*")):
            bundle.add(file_path, arcname=file_path.relative_to(install_dir), recursive=False)


def normalize_version(version: str) -> str:
    return version.lstrip("v")


def package_matrix(platform_name: str) -> list[dict[str, object]]:
    packages: list[dict[str, object]] = [
        {
            "name": "pybind11-fix",
            "variant": "default",
            "configs": {"source": "y"},
        },
        {
            "name": "opencv-fix",
            "variant": "default",
            "configs": {"source": "y"},
        },
        {
            "name": "baas-onnxruntime",
            "variant": "directml" if platform_name == "windows" else "cpu",
            "configs": {
                "source": "y",
                "cuda": "n",
                "tensorrt": "n",
                "directml": "y" if platform_name == "windows" else "n",
            },
        },
    ]
    if platform_name == "windows":
        packages.insert(
            2,
            {
                "name": "directml-bin",
                "variant": "default",
                "configs": {"source": "y"},
            },
        )
    return packages


def config_arg(configs: dict[str, str]) -> str:
    return "--configs=" + ",".join(f"{key}={value}" for key, value in configs.items())


def resolve_info_payload(raw: str) -> dict[str, object]:
    payload = json.loads(raw)
    if isinstance(payload, list):
        if len(payload) != 1:
            raise RuntimeError(f"expected exactly one package info payload, got {len(payload)}")
        payload = payload[0]
    if not isinstance(payload, dict):
        raise RuntimeError("unexpected xrepo info payload shape")
    return payload


def asset_suffix(platform_name: str) -> str:
    return "zip" if platform_name == "windows" else "tar.gz"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", required=True, choices=["windows", "linux", "macos"])
    parser.add_argument("--arch", default="x64")
    parser.add_argument("--mode", required=True, choices=["debug", "release"])
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()

    output_dir = (REPO_ROOT / args.output_dir).resolve()
    manifests_dir = output_dir / "manifests"
    output_dir.mkdir(parents=True, exist_ok=True)
    manifests_dir.mkdir(parents=True, exist_ok=True)

    repo_name = f"baas-xrepo-ci-{os.environ.get('GITHUB_RUN_ID', 'local')}-{args.platform}-{args.mode}"
    run(["xrepo", "add-repo", repo_name, str(REPO_ROOT)])

    built_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    commit = os.environ.get("GITHUB_SHA", "local")
    ext = asset_suffix(args.platform)

    results: list[dict[str, object]] = []

    for package in package_matrix(args.platform):
        package_name = str(package["name"])
        variant = str(package["variant"])
        configs = dict(package["configs"])
        repo_package = f"{repo_name}::{package_name}"
        cfg_arg = config_arg(configs)

        run(["xrepo", "install", "-y", "-m", args.mode, repo_package, cfg_arg])
        info = resolve_info_payload(
            run(["xrepo", "info", "--json", "-m", args.mode, repo_package, cfg_arg], capture=True).stdout
        )

        install_dir = Path(str(info["installdir"])).resolve()
        version = normalize_version(str(info.get("version") or package.get("version") or "unknown"))

        asset_name = f"{package_name}-{version}-{args.platform}-{args.arch}-{args.mode}"
        if package_name == "baas-onnxruntime":
            asset_name += f"-{variant}"
        asset_name += f".{ext}"

        archive_path = output_dir / asset_name
        archive_install_tree(install_dir, archive_path, args.platform)

        manifest = {
            "package": package_name,
            "version": version,
            "platform": args.platform,
            "arch": args.arch,
            "mode": args.mode,
            "variant": variant,
            "asset_name": archive_path.name,
            "sha256": sha256_file(archive_path),
            "size_bytes": archive_path.stat().st_size,
            "built_at_utc": built_at,
            "source_commit": commit,
            "repo_name": repo_name,
            "configs": configs,
            "installdir": str(install_dir),
        }
        manifest_path = manifests_dir / f"{archive_path.stem}.json"
        manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        results.append(manifest)

    summary_path = output_dir / f"build-results-{args.platform}-{args.arch}-{args.mode}.json"
    summary_path.write_text(json.dumps(results, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
