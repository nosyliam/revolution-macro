import json
from pathlib import Path


def main() -> None:
    repo_root = Path(__file__).resolve().parent
    hashes: dict[str, str] = {}
    versions: dict[str, str] = {}

    for p in sorted(repo_root.rglob("*.version")):
        if ".git" in p.parts:
            continue
        rel = p.relative_to(repo_root)
        key = str(rel).removesuffix(".version").replace("\\", "/")
        content = p.read_text(encoding="utf-8-sig").strip()
        if content:
            hashes[key] = content.split()[0]

    versions_dir = repo_root / "versions"
    if versions_dir.is_dir():
        for p in sorted(versions_dir.rglob("*")):
            if ".git" in p.parts:
                continue
            if not p.is_file():
                continue
            rel = p.relative_to(versions_dir)
            key = str(rel).replace("\\", "/")
            versions[key] = p.read_text(encoding="utf-8-sig").strip()

    manifest = {"hashes": hashes, "versions": versions}
    out_path = repo_root / "versions.manifest"
    out_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Wrote {out_path} ({len(hashes)} hashes, {len(versions)} versions)")


if __name__ == "__main__":
    main()
