import argparse
import shutil
from pathlib import Path
from load_conf import load_conf, parse_csv, parse_mapping


def main(conf_path: str) -> None:
    cfg = load_conf(conf_path)

    source_root = Path(cfg["source_root"])
    posts_dir = Path(cfg["posts_dir"])
    exclude_keywords = parse_csv(cfg.get("exclude_keywords"))
    category_mapping = parse_mapping(cfg.get("category_mapping"))

    if posts_dir.exists():
        print(f"🧹 Cleaning up old files in {posts_dir}...")
        shutil.rmtree(posts_dir)
    posts_dir.mkdir(parents=True, exist_ok=True)

    for md_file in source_root.rglob("*.md"):
        if any(k in md_file.parts or k in md_file.name for k in exclude_keywords):
            continue

        category = category_mapping.get(md_file.parent.name)
        if not category:
            continue

        dst_dir = posts_dir / category
        dst_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(md_file, dst_dir / md_file.name)
        print(f"Copied {md_file.name} to {dst_dir}")

    print("✅ Posts directory is now a clean reflection of your source files.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="blog.conf", help="Path to .conf file")
    args = parser.parse_args()
    main(args.config)