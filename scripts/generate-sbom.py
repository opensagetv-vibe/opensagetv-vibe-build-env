#!/usr/bin/env python3
"""Generate small SPDX 2.3 JSON SBOMs without an external scanner image."""

import argparse
import datetime
import hashlib
import json
import pathlib
import re


def spdx_id(value):
    safe = re.sub(r"[^A-Za-z0-9.-]", "-", value)
    return "SPDXRef-" + safe.strip("-")


def checksum(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--root")
    parser.add_argument("--image-id")
    parser.add_argument("--packages")
    args = parser.parse_args()

    document_id = spdx_id(args.name)
    packages = [{
        "SPDXID": document_id,
        "name": args.name,
        "versionInfo": args.version,
        "downloadLocation": "NOASSERTION",
        "filesAnalyzed": bool(args.root),
        "licenseConcluded": "NOASSERTION",
        "licenseDeclared": "NOASSERTION",
        "copyrightText": "NOASSERTION",
    }]
    if args.image_id:
        packages[0]["checksums"] = [{"algorithm": "SHA256", "checksumValue": args.image_id.removeprefix("sha256:")}]

    files = []
    relationships = []
    if args.root:
        root = pathlib.Path(args.root).resolve()
        for path in sorted(item for item in root.rglob("*") if item.is_file()):
            relative = path.relative_to(root).as_posix()
            file_id = spdx_id("File-" + relative + "-" + hashlib.sha1(relative.encode()).hexdigest()[:10])
            files.append({
                "SPDXID": file_id,
                "fileName": "./" + relative,
                "checksums": [{"algorithm": "SHA256", "checksumValue": checksum(path)}],
                "licenseConcluded": "NOASSERTION",
                "copyrightText": "NOASSERTION",
            })
            relationships.append({
                "spdxElementId": document_id,
                "relationshipType": "CONTAINS",
                "relatedSpdxElement": file_id,
            })

    if args.packages:
        for index, line in enumerate(pathlib.Path(args.packages).read_text().splitlines()):
            if not line.strip():
                continue
            name, version, architecture = line.split("\t")
            package_id = spdx_id("Dpkg-{}-{}".format(name, index))
            packages.append({
                "SPDXID": package_id,
                "name": name,
                "versionInfo": version,
                "downloadLocation": "NOASSERTION",
                "filesAnalyzed": False,
                "licenseConcluded": "NOASSERTION",
                "licenseDeclared": "NOASSERTION",
                "copyrightText": "NOASSERTION",
                "primaryPackagePurpose": "LIBRARY",
                "externalRefs": [{
                    "referenceCategory": "PACKAGE-MANAGER",
                    "referenceType": "purl",
                    "referenceLocator": "pkg:deb/ubuntu/{}@{}?arch={}".format(name, version, architecture),
                }],
            })
            relationships.append({
                "spdxElementId": document_id,
                "relationshipType": "CONTAINS",
                "relatedSpdxElement": package_id,
            })

    now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    document = {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": args.name,
        "documentNamespace": "https://github.com/opensagetv-vibe/opensagetv-vibe-build-env/releases/{}/{}".format(args.version, args.name),
        "creationInfo": {"created": now, "creators": ["Tool: opensagetv-vibe-generate-sbom/1"]},
        "documentDescribes": [document_id],
        "packages": packages,
        "files": files,
        "relationships": relationships,
    }
    output = pathlib.Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")
    json.loads(output.read_text())


if __name__ == "__main__":
    main()
