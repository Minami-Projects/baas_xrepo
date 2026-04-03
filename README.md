# BAAS xrepo packages

This repository hosts the custom xrepo package definitions used by
`blue_archive_auto_script/core/external_tools`.

## What it builds

GitHub Actions produces prebuilt package archives for:

- `windows` / `linux` / `macos`
- `Debug` and `Release`
- baseline package variants used by the main project

The workflow publishes one GitHub Release per CI run and attaches:

- packaged install-tree archives
- per-asset manifest JSON files
- an aggregated `release-index.json`
- a detailed Markdown release body covering every build result

## Package naming

Assets follow a stable naming convention so package recipes can consume them:

- `pybind11-fix-<version>-<platform>-<arch>-<mode>.<ext>`
- `opencv-fix-<version>-<platform>-<arch>-<mode>.<ext>`
- `directml-bin-<version>-windows-<arch>-<mode>.zip`
- `baas-onnxruntime-<version>-<platform>-<arch>-<mode>-<variant>.<ext>`

Where:

- `<platform>` is one of `windows`, `linux`, `macos`
- `<arch>` is currently `x64`
- `<mode>` is `debug` or `release`
- `<variant>` is `directml` on Windows and `cpu` elsewhere

## Local use

The main project adds this repository as a local xrepo source repository, but
the package recipes prefer GitHub Release assets by default. To force a source
build, pass `source=true` in the package configs.
