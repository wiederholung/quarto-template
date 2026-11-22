"""Check the vendored CSL styles against Zotero. Use --apply to update the snapshot."""
import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
from urllib.request import urlopen
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "styles/manifest.json"
CSL = "{http://purl.org/net/xbiblio/csl}"
SAMPLE = """---
lang: en
references:
  - id: example-web
    type: webpage
    title: Research project overview
    author: [{literal: Example Laboratory}]
    URL: https://example.org/research
---

Two articles [@knuth1984; @shannon1948]. Project website [@example-web].
"""


def render(style, directory):
    path = directory / "sample.csl"
    path.write_bytes(style)
    result = subprocess.run(
        ["quarto", "pandoc", "--sandbox", "--fail-if-warnings", "--citeproc",
         "--from=markdown", "--to=html", "--wrap=none", "--csl", str(path),
         "--bibliography", str(ROOT / "bibliography/references.bib")],
        input=SAMPLE, capture_output=True, encoding="utf-8", cwd=directory,
    )
    if result.returncode:
        raise ValueError(result.stderr.strip())
    for key in ("knuth1984", "shannon1948", "example-web"):
        if f'id="ref-{key}"' not in result.stdout:
            raise ValueError(f"Missing rendered reference: {key}")
    return result.stdout.splitlines()


def install(changes):
    # Stage on the same filesystem. Publish the manifest last and roll back
    # earlier replacements if a later file has changed or cannot be replaced.
    with TemporaryDirectory(dir=MANIFEST.parent) as folder:
        staged = Path(folder)
        for target, (before, after) in changes.items():
            (staged / target.name).write_bytes(after)
            (staged / (target.name + ".bak")).write_bytes(before)
        replaced = []
        try:
            for target, (before, _) in changes.items():
                if target.read_bytes() != before:
                    raise ValueError(f"File changed during check: {target}")
                os.replace(staged / target.name, target)
                replaced.append(target)
        except BaseException:
            for target in reversed(replaced):
                os.replace(staged / (target.name + ".bak"), target)
            raise


def main():
    options = argparse.ArgumentParser(description=__doc__)
    options.add_argument("--apply", action="store_true", help="install validated updates")
    args = options.parse_args()
    original = MANIFEST.read_bytes()
    snapshot = json.loads(original)
    urls = snapshot["csl"]["urls"]
    files = {p.name for p in (ROOT / "styles/csl").glob("*.csl")}
    hashes = snapshot["sha256"]
    recorded = {p.removeprefix("styles/csl/") for p in hashes if p.startswith("styles/csl/")}
    if files != set(urls) or files != recorded:
        raise ValueError("CSL files, source URLs and SHA-256 entries differ; inspect the snapshot.")
    changes = {}
    failed = False
    print("## Zotero CSL update check\n")
    with TemporaryDirectory() as folder:
        for name, url in urls.items():
            relative = f"styles/csl/{name}"
            target = ROOT / relative
            try:
                before = target.read_bytes()
                if hashlib.sha256(before).hexdigest() != hashes[relative]:
                    raise ValueError("locally modified; compare with the recorded snapshot")
                with urlopen(url, timeout=30) as response:
                    after = response.read()
                root = ET.fromstring(after)
                if (root.tag != CSL + "style" or root.find(CSL + "citation") is None
                        or root.find(CSL + "bibliography") is None):
                    raise ValueError("expected an independent CSL style with a bibliography")
                if after == before:
                    print(f"- {name}: up to date")
                    continue
                old = render(before, Path(folder))
                new = render(after, Path(folder))
                print(f"\n### {name}\n\nUpstream changed.")
                if old == new:
                    print("The citation and bibliography sample renders identically.\n")
                else:
                    print("\n```diff")
                    print("\n".join(difflib.unified_diff(old, new, "installed", "Zotero", lineterm="")))
                    print("```\n")
                changes[target] = (before, after)
                hashes[relative] = hashlib.sha256(after).hexdigest()
            except (OSError, ValueError, ET.ParseError) as err:
                failed = True
                print(f"- {name}: check failed ({err})", file=sys.stderr)
    if failed:
        return 1
    if args.apply and changes:
        updated = (json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n").encode()
        if b"\r\n" in original:
            updated = updated.replace(b"\n", b"\r\n")
        changes[MANIFEST] = (original, updated)
        install(changes)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        sys.exit(str(error))
