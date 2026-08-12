#!/usr/bin/env python3
"""Agent Harness 手册保鲜巡检。

两项检查：
1. dataAsOf 超期：frontmatter 中 dataAsOf 早于 --stale-days（默认 45 天）的页面
2. 链接失效：时效性页面（含 dataAsOf）中的外链可用性，分 失效 / 疑似（反爬拦截）两档

产物：freshness-report.md（供 CI 发布为 Issue）；退出码恒为 0（巡检不阻断流水线）。
仅依赖标准库。本地调试：python3 scripts/freshness_check.py --max-links 20
"""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import re
import ssl
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
REPORT = ROOT / "freshness-report.md"

FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---\n", re.S)
DATA_AS_OF_RE = re.compile(r"^dataAsOf:\s*([0-9]{4}-[0-9]{2})\s*$", re.M)
LINK_RE = re.compile(r"\[[^\]]*\]\(<(https?://[^>]+)>\)|\[[^\]]*\]\((https?://[^)\s]+)\)|(https?://[^\s)\]>\"']+)")

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
CTX = ssl.create_default_context()


def find_dated_pages() -> dict[Path, dt.date]:
    """返回 {页面: dataAsOf 日期}。"""
    pages = {}
    for md in sorted(DOCS.rglob("*.md")):
        text = md.read_text(encoding="utf-8")
        m = FRONTMATTER_RE.match(text)
        if not m:
            continue
        d = DATA_AS_OF_RE.search(m.group(1))
        if d:
            pages[md] = dt.date.fromisoformat(d.group(1) + "-01")
    return pages


def extract_links(md: Path) -> list[str]:
    text = md.read_text(encoding="utf-8")
    links = []
    for m in LINK_RE.finditer(text):
        url = next(g for g in m.groups() if g).rstrip(".,;:")
        if "localhost" not in url:
            links.append(url)
    return sorted(set(links))


def check_url(url: str) -> tuple[str, str]:
    """返回 (url, 状态)：ok / dead / blocked。"""
    req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": UA})
    for attempt in ("HEAD", "GET"):  # 有的站不支持 HEAD
        try:
            with urllib.request.urlopen(req, timeout=15, context=CTX) as r:
                code = r.status
            if code in (403, 429):
                return url, "blocked"
            return url, "ok" if code < 400 else "dead"
        except urllib.error.HTTPError as e:
            if e.code in (403, 429):
                return url, "blocked"
            if e.code in (404, 410):
                return url, "dead"
            if e.code == 405 and attempt == "HEAD":
                req = urllib.request.Request(url, headers={"User-Agent": UA})
                continue
            return url, "dead" if e.code >= 500 else "blocked"
        except Exception:
            return url, "dead" if attempt == "GET" else "blocked"
    return url, "dead"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stale-days", type=int, default=45)
    ap.add_argument("--max-links", type=int, default=0, help="调试用：只检查前 N 条链接")
    args = ap.parse_args()

    today = dt.date.today()
    pages = find_dated_pages()

    stale = [(p, d) for p, d in pages.items() if (today - d).days > args.stale_days]

    link_sources = {p: extract_links(p) for p in pages}
    all_links = sorted({u for urls in link_sources.values() for u in urls})
    if args.max_links:
        all_links = all_links[: args.max_links]

    results: dict[str, str] = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as ex:
        for url, status in ex.map(check_url, all_links):
            results[url] = status

    dead = sorted(u for u, s in results.items() if s == "dead")
    blocked = sorted(u for u, s in results.items() if s == "blocked")

    def pages_of(url: str) -> str:
        rels = [str(p.relative_to(DOCS)) for p, urls in link_sources.items() if url in urls]
        return ", ".join(f"`{r}`" for r in rels[:3])

    lines = [
        f"## 保鲜巡检报告（{today.isoformat()}）",
        "",
        f"- 时效性页面：{len(pages)} 个（按 `dataAsOf` 标记）",
        f"- dataAsOf 超过 {args.stale_days} 天未更新：**{len(stale)} 个**",
        f"- 外链检查：{len(results)} 条，失效 **{len(dead)}** 条，疑似（反爬/限流）**{len(blocked)}** 条",
        "",
    ]
    if stale:
        lines += ["### dataAsOf 超期页面", ""]
        lines += [f"- `{p.relative_to(DOCS)}`（数据截止 {d:%Y-%m}，已 {(today - d).days} 天）" for p, d in sorted(stale, key=lambda x: x[1])]
        lines.append("")
    if dead:
        lines += ["### 失效链接（需人工核对替换）", ""]
        lines += [f"- {u}  \n  出现于：{pages_of(u)}" for u in dead]
        lines.append("")
    if blocked:
        lines += ["### 疑似失效（被反爬/限流拦截，建议人工抽查）", ""]
        lines += [f"- {u}  \n  出现于：{pages_of(u)}" for u in blocked]
        lines.append("")
    if not (stale or dead or blocked):
        lines += ["一切新鲜，无需处理。", ""]

    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(f"pages={len(pages)} stale={len(stale)} links={len(results)} dead={len(dead)} blocked={len(blocked)}")


if __name__ == "__main__":
    main()
