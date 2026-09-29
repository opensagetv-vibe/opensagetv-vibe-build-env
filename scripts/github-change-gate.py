#!/usr/bin/env python3
"""Fail-closed GitHub update gate for the OpenSageTV Vibe workspace."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tomllib
from pathlib import Path
from typing import Any


SCRIPT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = SCRIPT_ROOT / "config" / "github-projects.toml"


class GateError(RuntimeError):
    pass


def run(cwd: Path, *args: str) -> str:
    result = subprocess.run(
        args,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise GateError(f"command failed ({' '.join(args)}): {detail}")
    return result.stdout.strip()


def git(path: Path, *args: str) -> str:
    return run(path, "git", *args)


def gh_json(path: Path, *args: str) -> Any:
    output = run(path, "gh", *args)
    return json.loads(output) if output else None


def require(value: bool, message: str) -> None:
    if not value:
        raise GateError(message)


def load_config(path: Path) -> dict[str, Any]:
    with path.open("rb") as handle:
        return tomllib.load(handle)


def project_map(config: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {item["name"]: item for item in config["projects"]}


def selected_projects(config: dict[str, Any], names: list[str]) -> list[dict[str, Any]]:
    projects = project_map(config)
    if not names:
        return list(config["projects"])
    missing = [name for name in names if name not in projects]
    require(not missing, f"unknown project(s): {', '.join(missing)}")
    return [projects[name] for name in names]


def repository_name(config: dict[str, Any], project: dict[str, Any]) -> str:
    return f"{config['workspace']['owner']}/{project['name']}"


def project_path(workspace: Path, project: dict[str, Any]) -> Path:
    return workspace / "projects" / project["name"]


def audit_project(
    config: dict[str, Any], workspace: Path, project: dict[str, Any], fetch: bool
) -> dict[str, Any]:
    path = project_path(workspace, project)
    require(path.is_dir(), f"{project['name']}: project directory is missing")
    if not project.get("publish", True):
        return {
            "project": project["name"],
            "status": "SKIPPED",
            "reason": project["reason"],
        }

    settings = config["workspace"]
    branch = settings["default_branch"]
    repo = repository_name(config, project)
    expected_origin = f"https://github.com/{repo}.git"
    require(git(path, "remote", "get-url", "origin") == expected_origin, f"{project['name']}: wrong origin")
    require(git(path, "branch", "--show-current") == branch, f"{project['name']}: not on {branch}")
    require(not git(path, "status", "--porcelain"), f"{project['name']}: worktree is dirty")
    require((path / ".github" / "workflows" / "repository-checks.yml").is_file(), f"{project['name']}: repository checks workflow is missing")
    if fetch:
        git(path, "fetch", "origin", branch, "--quiet")

    origin_ref = f"origin/{branch}"
    behind, ahead = (int(value) for value in git(
        path, "rev-list", "--left-right", "--count", f"{origin_ref}...HEAD"
    ).split())
    require(behind == 0, f"{project['name']}: local {branch} is {behind} commit(s) behind origin")
    require(not git(path, "diff", "--check", f"{origin_ref}..HEAD"), f"{project['name']}: outgoing diff fails git diff --check")

    expected_identity = (
        f"{settings['author_name']}|{settings['author_email']}|"
        f"{settings['author_name']}|{settings['author_email']}"
    )
    identities = git(path, "log", "--format=%an|%ae|%cn|%ce", f"{origin_ref}..HEAD").splitlines()
    wrong = [identity for identity in identities if identity != expected_identity]
    require(not wrong, f"{project['name']}: outgoing contributor identity mismatch: {wrong}")

    remote = gh_json(path, "repo", "view", repo, "--json", "nameWithOwner,defaultBranchRef,url")
    require(remote["nameWithOwner"] == repo, f"{project['name']}: GitHub repository identity mismatch")
    require(remote["defaultBranchRef"]["name"] == branch, f"{project['name']}: wrong GitHub default branch")
    return {
        "project": project["name"],
        "repository": repo,
        "head": git(path, "rev-parse", "HEAD"),
        "ahead": ahead,
        "status": "PASS",
    }


def verify_head(config: dict[str, Any], workspace: Path, project: dict[str, Any]) -> dict[str, Any]:
    require(project.get("publish", True), f"{project['name']}: project is not publishable")
    path = project_path(workspace, project)
    settings = config["workspace"]
    branch = settings["default_branch"]
    repo = repository_name(config, project)
    git(path, "fetch", "origin", branch, "--quiet")
    head = git(path, "rev-parse", "HEAD")
    require(head == git(path, "rev-parse", f"origin/{branch}"), f"{project['name']}: HEAD is not origin/{branch}")
    runs = gh_json(
        path, "run", "list", "--repo", repo, "--branch", branch, "--limit", "20",
        "--json", "headSha,status,conclusion,workflowName,url",
    )
    matches = [
        item for item in runs
        if item["headSha"] == head and item["workflowName"] == project["workflow"]
    ]
    require(matches, f"{project['name']}: required workflow has not run on {head[:8]}")
    current = matches[0]
    require(
        current["status"] == "completed" and current["conclusion"] == "success",
        f"{project['name']}: {project['workflow']} is {current['status']}/{current['conclusion']}",
    )
    return {
        "project": project["name"],
        "head": head,
        "workflow": project["workflow"],
        "url": current["url"],
        "status": "PASS",
    }


def verify_pr(path: Path, repository: str, number: int, checks: list[str]) -> dict[str, Any]:
    pull = gh_json(
        path, "pr", "view", str(number), "--repo", repository,
        "--json", "state,mergeable,statusCheckRollup,url",
    )
    require(pull["state"] == "OPEN", f"{repository}#{number}: PR is not open")
    require(pull["mergeable"] == "MERGEABLE", f"{repository}#{number}: PR is not mergeable")
    found = {item.get("name"): item for item in pull["statusCheckRollup"]}
    states: dict[str, str] = {}
    for name in checks:
        require(name in found, f"{repository}#{number}: required check {name} is missing")
        item = found[name]
        state = f"{item.get('status')}/{item.get('conclusion')}"
        states[name] = state
        require(
            item.get("status") == "COMPLETED" and item.get("conclusion") == "SUCCESS",
            f"{repository}#{number}: required check {name} is {state}",
        )
    return {"repository": repository, "pr": number, "checks": states, "url": pull["url"], "status": "PASS"}


def verify_release(
    config: dict[str, Any], workspace: Path, project: dict[str, Any], tag: str
) -> dict[str, Any]:
    path = project_path(workspace, project)
    repo = repository_name(config, project)
    release = gh_json(
        path, "release", "view", tag, "--repo", repo,
        "--json", "tagName,targetCommitish,isDraft,assets,url",
    )
    require(not release["isDraft"], f"{repo} {tag}: release is still a draft")
    git(path, "fetch", "origin", "--tags", "--quiet")
    tag_commit = git(path, "rev-list", "-n", "1", tag)
    head = git(path, "rev-parse", "HEAD")
    require(tag_commit == head, f"{repo} {tag}: tag does not identify current HEAD")
    require(release["assets"], f"{repo} {tag}: release has no assets")
    missing = [asset["name"] for asset in release["assets"] if not asset.get("digest")]
    require(not missing, f"{repo} {tag}: assets have no recorded digest: {missing}")
    return {
        "project": project["name"],
        "tag": tag,
        "head": head,
        "assets": len(release["assets"]),
        "url": release["url"],
        "status": "PASS",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--workspace-root", type=Path)
    subparsers = parser.add_subparsers(dest="command", required=True)

    audit = subparsers.add_parser("audit")
    audit.add_argument("--project", action="append", default=[])
    audit.add_argument("--skip-fetch", action="store_true")

    head = subparsers.add_parser("verify-head")
    head.add_argument("--project", action="append", required=True)

    pull = subparsers.add_parser("verify-pr")
    pull.add_argument("--repository", required=True)
    pull.add_argument("--number", required=True, type=int)
    pull.add_argument("--required-check", action="append", required=True)

    release = subparsers.add_parser("verify-release")
    release.add_argument("--project", required=True)
    release.add_argument("--tag", required=True)

    args = parser.parse_args()
    config_path = args.config.resolve()
    config = load_config(config_path)
    workspace = (args.workspace_root or SCRIPT_ROOT.parents[1]).resolve()
    projects = project_map(config)
    report: dict[str, Any] = {"command": args.command, "config": str(config_path)}
    try:
        if args.command == "audit":
            chosen = selected_projects(config, args.project)
            report["projects"] = [
                audit_project(config, workspace, project, not args.skip_fetch)
                for project in chosen
            ]
        elif args.command == "verify-head":
            chosen = selected_projects(config, args.project)
            report["projects"] = [verify_head(config, workspace, project) for project in chosen]
        elif args.command == "verify-pr":
            report["pull_request"] = verify_pr(
                SCRIPT_ROOT, args.repository, args.number, args.required_check
            )
        elif args.command == "verify-release":
            require(args.project in projects, f"unknown project: {args.project}")
            report["release"] = verify_release(
                config, workspace, projects[args.project], args.tag
            )
        report["status"] = "PASS"
        print(json.dumps(report, indent=2, sort_keys=True))
        return 0
    except (GateError, KeyError, TypeError, ValueError) as error:
        report["status"] = "FAIL"
        report["error"] = str(error)
        print(json.dumps(report, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    sys.exit(main())
