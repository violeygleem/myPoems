import argparse
import os
import re
import shutil
from datetime import datetime
from pathlib import Path
from load_conf import load_conf, parse_csv, parse_mapping


def parse_front_matter(md_text: str) -> tuple[str, str]:
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", md_text, re.S)
    if match:
        return match.group(1), match.group(2)
    return "", md_text


def update_front_matter(front_matter: str, title: str, date_str: str | None = None) -> str:
    fm_lines = front_matter.split("\n") if front_matter else []
    fm_dict = {
        line.split(":", 1)[0].strip(): line.split(":", 1)[1].strip()
        for line in fm_lines
        if ":" in line
    }

    fm_dict.update({
        "title": title,
        "layout": "single",
        "type": "docs",
        "sidebar": "true",
        "bookCollapseSection": "true",
    })

    if date_str:
        fm_dict["date"] = date_str

    fm_new_lines = ["---"]
    for k, v in fm_dict.items():
        if k == "date":
            fm_new_lines.append(f'{k}: "{v}"')
        else:
            fm_new_lines.append(f"{k}: {v}")
    fm_new_lines.append("---")
    return "\n".join(fm_new_lines)


def main(conf_path: str) -> None:
    cfg = load_conf(conf_path)

    posts_dir = Path(cfg["posts_dir"])
    attachments_dir = Path(cfg["attachments_dir"])
    hugo_content_dir = Path(cfg["hugo_content_dir"])
    static_images_dir = Path(cfg["static_images_dir"])

    start_year = int(cfg.get("copyright_start_year", "2025"))
    holder = cfg.get("copyright_holder", "Violey Gleem")
    license_name = cfg.get("copyright_license", "CC BY-NC-ND 4.0")

    current_year = datetime.now().year
    year_range = f"{start_year}-{current_year}" if current_year > start_year else str(start_year)
    copyright_line = f"© {year_range} [{holder}]. Licensed under {license_name}"

    allowed_categories = set(parse_csv(cfg.get("allowed_categories")))
    category_mapping = parse_mapping(cfg.get("category_mapping"))

    if hugo_content_dir.exists():
        print(f"🧹 Cleaning up Hugo content directory: {hugo_content_dir}")
        shutil.rmtree(hugo_content_dir)

    if static_images_dir.exists():
        print(f"🖼️ Cleaning up Hugo static images: {static_images_dir}")
        shutil.rmtree(static_images_dir)

    hugo_content_dir.mkdir(parents=True, exist_ok=True)
    static_images_dir.mkdir(parents=True, exist_ok=True)

    def copy_images_and_update_paths(md_content: str) -> str:
        def repl_md(match):
            img_name = Path(match.group(1)).name
            src = attachments_dir / img_name
            if src.exists():
                shutil.copy2(src, static_images_dir / img_name)
            return f"![](../../images/{img_name.replace(' ', '%20')})"

        md_content = re.sub(r"!\[.*?\]\((.*?)\)", repl_md, md_content)
        md_content = re.sub(r"!\[\[(.*?)\]\]", repl_md, md_content)
        return md_content

    def process_md(md_path: Path, dst_dir: Path) -> None:
        text = md_path.read_text(encoding="utf-8")
        front, content = parse_front_matter(text)

        date_str = None
        date_match = re.search(r"^date:\s*(.+)$", front, re.M)
        if date_match:
            raw_date = date_match.group(1).strip().replace('"', "")
            try:
                dt = (
                    datetime.strptime(raw_date, "%Y-%m-%d %H:%M")
                    if " " in raw_date
                    else datetime.strptime(raw_date, "%Y-%m-%d")
                )
                date_str = dt.isoformat()
            except ValueError:
                date_str = raw_date
        else:
            mtime = os.path.getmtime(md_path)
            date_str = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d")

        fm_new = update_front_matter(front, md_path.stem, date_str)
        content = copy_images_and_update_paths(content)
        content = re.sub(r"© \d{4}.*?CC BY-NC-ND 4.0", "", content).strip()
        content += "\n\n" + copyright_line

        dst_file = dst_dir / md_path.name
        dst_file.write_text(fm_new + "\n" + content, encoding="utf-8")

    print(f"🚀 Starting to process files from {posts_dir}...")
    for md_file in posts_dir.rglob("*.md"):
        if md_file.name == "_index.md":
            continue
        hugo_subdir = category_mapping.get(md_file.parent.name, md_file.parent.name.lower())
        if hugo_subdir not in allowed_categories:
            continue
        hugo_target_dir = hugo_content_dir / hugo_subdir
        hugo_target_dir.mkdir(parents=True, exist_ok=True)
        process_md(md_file, hugo_target_dir)

    index_template = """---
title: {title}
type: docs
sidebar: true
bookCollapseSection: true
---
"""
    for category in allowed_categories:
        cat_dir = hugo_content_dir / category
        cat_dir.mkdir(parents=True, exist_ok=True)
        index_file = cat_dir / "_index.md"
        index_file.write_text(index_template.format(title=category.capitalize()), encoding="utf-8")
        print(f"📄 Generated/Reset _index.md for {category}")

    print("\n✨ All posts and Sidebars are refreshed successfully.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="blog.conf", help="Path to .conf file")
    args = parser.parse_args()
    main(args.config)