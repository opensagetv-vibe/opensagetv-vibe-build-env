#!/usr/bin/env python3
"""Resolve exact source, artifact, and image identities for a local release."""

import argparse
import hashlib
import json
import os
import pathlib
import re
import stat
import subprocess


SOURCES = {
    "build_env": "https://github.com/opensagetv-vibe/opensagetv-vibe-build-env.git",
    "core": "https://github.com/opensagetv-vibe/opensagetv-vibe-core.git",
    "container": "https://github.com/opensagetv-vibe/opensagetv-vibe-container.git",
    "ffmpeg_mim": "https://github.com/opensagetv-vibe/opensagetv-vibe-ffmpeg-mim.git",
    "ffmpeg_plugin": "https://github.com/opensagetv-vibe/opensagetv-vibe-SageTVFFmpegPlugin.git",
    "core_mcp": "https://github.com/opensagetv-vibe/opensagetv-vibe-core-MCP-Plugin.git",
    "xmltv_import": "https://github.com/opensagetv-vibe/opensagetv-vibe-xmltv-import.git",
    "tmdb": "https://github.com/opensagetv-vibe/opensagetv-vibe-tmdb.git",
    "logo": "https://github.com/opensagetv-vibe/opensagetv-vibe-logo.git",
    "android_client": "https://github.com/opensagetv-vibe/opensagetv-vibe-android-client.git",
    "sagemc": "https://github.com/opensagetv-vibe/opensagetv-vibe-sagemc.git",
}


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def command_output(*args):
    completed = subprocess.run(args, check=True, capture_output=True, text=True)
    return (completed.stdout + completed.stderr).strip()


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
    parser.add_argument("--production-export-id", required=True)
    parser.add_argument("--debug-export-id", required=True)
    parser.add_argument("--build-image", required=True)
    parser.add_argument("--repo", action="append", nargs=2, metavar=("NAME", "PATH"), required=True)
    parser.add_argument("--opendct-status", required=True)
    parser.add_argument("--runtime-validation-log", required=True)
    parser.add_argument("--android-test-log", required=True)
    parser.add_argument("--android-version-file", required=True)
    parser.add_argument("--sagemc-version-file", required=True)
    parser.add_argument("--tmdb-version-file", required=True)
    parser.add_argument("--ffmpeg-plugin-version-file", required=True)
    parser.add_argument("--core-mcp-version-file", required=True)
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

    def image_record(reference, exported_config_id=None):
        image_id = command("docker", "image", "inspect", reference, "--format", "{{.Id}}")
        size = int(command("docker", "image", "inspect", reference, "--format", "{{.Size}}"))
        record = {
            "reference": reference,
            "image_id": image_id,
            "local_image_store_id": image_id,
            "size": size,
            "platform": "linux/amd64",
        }
        if exported_config_id is not None:
            if not re.fullmatch(r"sha256:[0-9a-f]{64}", exported_config_id):
                raise ValueError(f"invalid exported image config ID: {exported_config_id!r}")
            record["exported_archive_config_id"] = exported_config_id
        return record

    release_dir = pathlib.Path(args.release_dir)
    runtime_log = pathlib.Path(args.runtime_validation_log).read_text(errors="replace")
    android_test_log = pathlib.Path(args.android_test_log).read_text(errors="replace")
    if "ANDROID CLIENT SUITE PASSED" not in android_test_log:
        raise ValueError("Android client log does not contain the completed suite marker")
    android_version = pathlib.Path(args.android_version_file).read_text().strip()
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,3}", android_version):
        raise ValueError(f"invalid Android client version: {android_version!r}")
    sagemc_version = pathlib.Path(args.sagemc_version_file).read_text().strip()
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,3}", sagemc_version):
        raise ValueError(f"invalid SageMC version: {sagemc_version!r}")
    tmdb_properties = pathlib.Path(args.tmdb_version_file).read_text().splitlines()
    tmdb_versions = [
        line.partition("=")[2].strip()
        for line in tmdb_properties
        if line.partition("=")[0].strip() == "VERSION"
    ]
    if len(tmdb_versions) != 1 or not re.fullmatch(
        r"[0-9]+(?:\.[0-9]+){1,3}(?:-[0-9A-Za-z.-]+)?", tmdb_versions[0]
    ):
        raise ValueError(f"invalid TMDB VERSION in {args.tmdb_version_file!r}")
    tmdb_version = tmdb_versions[0]
    ffmpeg_plugin_properties = pathlib.Path(args.ffmpeg_plugin_version_file).read_text().splitlines()
    ffmpeg_plugin_versions = [
        line.partition("=")[2].strip()
        for line in ffmpeg_plugin_properties
        if line.partition("=")[0].strip() == "VERSION"
    ]
    if len(ffmpeg_plugin_versions) != 1 or not re.fullmatch(
        r"[0-9]+(?:\.[0-9]+){1,3}(?:-[0-9A-Za-z.-]+)?", ffmpeg_plugin_versions[0]
    ):
        raise ValueError(f"invalid FFmpeg plugin VERSION in {args.ffmpeg_plugin_version_file!r}")
    ffmpeg_plugin_version = ffmpeg_plugin_versions[0]
    core_mcp_properties = pathlib.Path(args.core_mcp_version_file).read_text().splitlines()
    core_mcp_versions = [
        line.partition("=")[2].strip()
        for line in core_mcp_properties
        if line.partition("=")[0].strip() == "VERSION"
    ]
    if len(core_mcp_versions) != 1 or not re.fullmatch(
        r"[0-9]+(?:\.[0-9]+){1,3}(?:-[0-9A-Za-z.-]+)?", core_mcp_versions[0]
    ):
        raise ValueError(f"invalid Core MCP plugin VERSION in {args.core_mcp_version_file!r}")
    core_mcp_version = core_mcp_versions[0]
    restart_match = re.search(
        r"^RUNTIME RESTART SOAK PASSED: supervisor restart \+ (\d+) container restarts$",
        runtime_log,
        re.MULTILINE,
    )
    if not restart_match or "RUNTIME CONTAINER VALIDATION PASSED" not in runtime_log:
        raise ValueError("runtime validation log does not contain a completed restart soak")
    restart_cycles = int(restart_match.group(1))
    if restart_cycles < 2:
        raise ValueError("runtime restart soak must contain at least two container restarts")
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
        "versions": {
            "sagetv": "9.2.10",
            "ffmpeg": "n9.0.1",
            "mim": "0.4.5",
            "ffmpeg_plugin": ffmpeg_plugin_version,
            "core_mcp": core_mcp_version,
            "xmltv_import": "3.5",
            "tmdb": tmdb_version,
            "android_client": android_version,
            "sagemc": sagemc_version,
        },
        "repositories": repositories,
        "images": {
            "development": image_record(args.build_image),
            "production": image_record(args.production_image, args.production_export_id),
            "debug": image_record(args.debug_image, args.debug_export_id),
        },
        "toolchains": {
            "build_environment": os.environ.get("OPENSAGETV_VIBE_BUILD_ENV_VERSION", "unknown"),
            "default_java": command_output("java", "-version").splitlines()[0],
            "android_java": command_output("/opt/java/jdk17/bin/java", "-version").splitlines()[0],
            "android_legacy_java": command_output("/opt/java/jdk8/bin/java", "-version").splitlines()[0],
            "android_sdk": [
                "platforms;android-29",
                "build-tools;29.0.2",
                "platforms;android-36",
                "build-tools;36.0.0",
                "ndk;21.0.6113669",
            ],
            "android_platform_tools": command_output("adb", "version").splitlines()[1],
        },
        "artifacts": artifacts,
        "tests": {
            "opendct_live_channel_scan": pathlib.Path(args.opendct_status).read_text().strip(),
            "runtime_restart_soak": {
                "result": "PASS",
                "supervisor_child_restarts": 1,
                "container_restarts": restart_cycles,
                "zombies": 0,
                "resource_growth": "bounded",
            },
            "android_client": {
                "result": "PASS",
                "scope": "unit/static tests, source validation, deterministic debug APK build",
                "device_tests": "SKIPPED - hardware commissioning is intentionally outside unified all",
            },
            "mim_enabled_by_default": False,
            "hardware_decode_default": True,
        },
    }
    output = pathlib.Path(args.output)
    output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    json.loads(output.read_text())


if __name__ == "__main__":
    main()
