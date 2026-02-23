import argparse
import hashlib
from pathlib import Path


def sha256_uppercase(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def add_version_for_file(file_path: Path) -> None:
    version_path = file_path.with_suffix(file_path.suffix.split(".")[0] + ".version")
    digest = sha256_uppercase(file_path)
    version_path.write_text(digest + "\n", encoding="utf-8")
    print(f"  {version_path.name} <- {digest[:16]}...")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Add .version files for files"
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("folder", nargs="?", help="Folder to process")
    group.add_argument("--file", metavar="PATH", help="Single file to process")
    parser.add_argument(
        "--exclude-dirs",
        nargs="*",
        default=[".git"],
        help="Directories to skip when walking",
    )
    args = parser.parse_args()

    if args.file:
        path = Path(args.file).resolve()
        if not path.is_file():
            parser.error(f"Not a file: {path}")
        if path.suffix == ".version":
            parser.error("Cannot create .version for a .version file")
        print(f"Processing: {path}")
        add_version_for_file(path)
        return

    folder = Path(args.folder).resolve()
    if not folder.is_dir():
        parser.error(f"Not a directory: {folder}")

    exclude_dirs = set(args.exclude_dirs)

    count = 0
    for p in sorted(folder.rglob("*")):
        if not p.is_file():
            continue
        if any(part in exclude_dirs for part in p.parts):
            continue
        if p.suffix == ".version":
            continue
        print(f"{p.relative_to(folder)}:")
        add_version_for_file(p)
        count += 1

if __name__ == "__main__":
    main()
