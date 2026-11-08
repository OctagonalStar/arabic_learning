#!/usr/bin/env python3
"""从 CHANGELOG.md 摘取某个 Release 的正文。

用法：changelog_notes.py <tag>

- tag 含 `-`（预发布，如 `v1.2.1-alpha.37`）→ 取 `## Unreleased` 段。
- 否则按 tag 的 major.minor.patch 找 `## V1.2.0 ...` 段（容忍方括号、大小写与
  日期/构建号后缀）。

找不到对应段落时输出一句占位说明而不是报错：发布不应因为忘了写 CHANGELOG 而
失败。
"""

import re
import sys
from pathlib import Path

CHANGELOG = Path(__file__).resolve().parents[2] / "CHANGELOG.md"
HEADING = re.compile(r"^(#{1,4})\s+(.*)$")
VERSION = re.compile(r"^\[?[Vv]?(\d+\.\d+\.\d+)")


def find_section(text, match):
    """返回满足 match(title) 的标题下的正文（到同级或更高级标题为止）。"""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        heading = HEADING.match(line)
        if not heading or not match(heading.group(2).strip()):
            continue
        level = len(heading.group(1))
        body = []
        for following in lines[index + 1 :]:
            next_heading = HEADING.match(following)
            if next_heading and len(next_heading.group(1)) <= level:
                break
            body.append(following)
        return "\n".join(body).strip()
    return None


def main():
    if len(sys.argv) != 2:
        sys.exit("用法: changelog_notes.py <tag>")
    tag = sys.argv[1].strip()

    text = CHANGELOG.read_text(encoding="utf-8")
    if "-" in tag:
        body = find_section(text, lambda title: title.lower().startswith("unreleased"))
    else:
        version = VERSION.match(tag.lstrip("vV"))
        if not version:
            sys.exit(f"无法从 tag 解析版本号: {tag}")
        wanted = version.group(1)
        body = find_section(
            text,
            lambda title: bool(VERSION.match(title)) and VERSION.match(title).group(1) == wanted,
        )

    print(body if body else "该版本暂无变更记录，详见仓库 CHANGELOG.md。")


if __name__ == "__main__":
    main()
