#!/usr/bin/env python3
"""Resolve exact source, artifact, and image identities for a local release."""

import argparse
import hashlib
import json
import pathlib
import subprocess


SOURCES = {
    "build_env": "https://github.com/opensagetv-vibe/opensagetv-vibe-build-env.git",
    "core": "https://github.com/opensagetv-vibe/opensagetv-vibe-core.git",
    "container": "https://github.com/opensagetv-vibe/opensagetv-vibe-container.git",
    "ffmpeg_mim": "https://github.com/opensagetv-vibe/opensagetv-vibe-ffmpeg-mim.git",
    "xmltv_import": "https://github.com/opensagetv-vibe/opensagetv-vibe-xmltv-import.git",
}


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-id", required=True)
    parser.add_argument("--release-dir", required=True)
    parser.add_argument("--production-image", required=True)
    parser.add_argument("--debug-image", required=True)
    parser.add_argument("--repo", action="append", nargs=2, metavar=("NAME", "PATH"), required=True)
    parser.add_argument("--opendct-status", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    repositories = {}
    for name, path_value in args.repo:
        path = pathlib.Path(path_value)
        repositories[name] = {
            "repository": SOURCES[name],
            "commit": command("git", "-C", str(path), "rev-parse", "HEAD"),
            "dirty": bool(command("git", "-C", str(path), "status", "--porcelain")),
        }

    def image_record(reference):
        image_id = command("docker", "image", "inspect", reference, "--format", "{{.Id}}")
        size = int(command("docker", "image", "inspect", reference, "--format", "{{.Size}}"))
        return {"reference": reference, "image_id": image_id, "size": size, "platform": "linux/amd64"}

    release_dir = pathlib.Path(args.release_dir)
    artifacts = {}
    for path in sorted(item for item in release_dir.rglob("*") if item.is_file()):
        relative = path.relative_to(release_dir).as_posix()
        if relative in {"release-manifest.json", "SHA256SUMS"}:
            continue
        artifacts[relative] = {"sha256": sha256(path), "size": path.stat().st_size}

    manifest = {
        "schema": 2,
        "release_id": args.release_id,
        "platform": "linux/amd64",
        "ubuntu": "26.04",
        "java": "11",
        "versions": {"sagetv": "9.2.10", "ffmpeg": "n9.0.1", "mim": "0.4.5", "xmltv_import": "3.5"},
        "repositories": repositories,
        "images": {
            "production": image_record(args.production_image),
            "debug": image_record(args.debug_image),
        },
        "artifacts": artifacts,
        "tests": {
            "opendct_live_channel_scan": pathlib.Path(args.opendct_status).read_text().strip(),
            "mim_enabled_by_default": False,
            "hardware_decode_default": True,
        },
    }
    output = pathlib.Path(args.output)
    output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    json.loads(output.read_text())


if __name__ == "__main__":
    main()
