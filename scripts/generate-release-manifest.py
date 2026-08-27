#!/usr/bin/env python3
"""Resolve exact source, artifact, and image identities for a local release."""

import argparse
import hashlib
import json
import os
import pathlib
import stat
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


def normalized_checkout_bytes(data):
    """Ignore only host checkout CRLF conversion when testing source dirt."""
    return data.replace(b"\r\n", b"\n")


def repository_is_dirty(path):
    """Report semantic Git changes without Windows/Linux EOL false positives."""
    status_output = subprocess.check_output(
        ["git", "-C", str(path), "status", "--porcelain=v1", "-z"]
    )
    for record in status_output.split(b"\0"):
        if not record:
            continue
        index_state = chr(record[0])
        worktree_state = chr(record[1])
        if index_state != " ":
            return True
        if worktree_state == " ":
            continue
        if worktree_state != "M":
            return True

        relative = os.fsdecode(record[3:])
        index_entry = subprocess.check_output(
            ["git", "-C", str(path), "ls-files", "-s", "--", relative],
            text=True,
        ).strip()
        if not index_entry:
            return True
        mode, object_id, _stage_and_path = index_entry.split(maxsplit=2)
        if mode == "160000":
            return True

        index_bytes = subprocess.check_output(
            ["git", "-C", str(path), "cat-file", "blob", object_id]
        )
        worktree_path = path / relative
        if mode == "120000":
            worktree_bytes = os.readlink(worktree_path).encode()
        else:
            worktree_bytes = worktree_path.read_bytes()
        if normalized_checkout_bytes(index_bytes) != normalized_checkout_bytes(worktree_bytes):
            return True

        filemode = subprocess.run(
            ["git", "-C", str(path), "config", "--bool", "core.filemode"],
            check=False,
            capture_output=True,
            text=True,
        ).stdout.strip()
        if filemode == "true" and mode in {"100644", "100755"}:
            worktree_executable = bool(worktree_path.stat().st_mode & stat.S_IXUSR)
            if worktree_executable != (mode == "100755"):
                return True
    return False


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
            "dirty": repository_is_dirty(path),
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
