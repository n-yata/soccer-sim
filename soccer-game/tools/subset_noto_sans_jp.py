#!/usr/bin/env python3
"""Noto Sans JP のサブセットの生成と、サブセットに無い文字の検出（architecture-overview.md のフォントの注記）。

  python tools/subset_noto_sans_jp.py --src <元の OTF があるディレクトリ>   サブセットを作り直す
  python tools/subset_noto_sans_jp.py --check                              サブセットに無い文字が無いかを確かめる

元のファイルは notofonts/noto-cjk のリリース Sans2.004 の 16_NotoSansJP.zip（LICENSES.md の台帳）。
元のファイルは Git に入れない（台帳の注記）ので、zip を展開したディレクトリを --src に渡す。
fontTools と brotli が要る（pip install fonttools brotli）。

収める文字は、ゲームの文言を持つファイル（スクリプト・シーン・リソース・静的データ）に出てくる全文字と、
英数字・記号・かなの全体。文言を変えたら作り直す。--check はサブセットに無い文字を一覧にして終了コード 1 で終わる。
"""

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GAME_DIR = REPO_ROOT / "game"
OUT_DIR = GAME_DIR / "assets" / "fonts" / "noto-sans-jp"
WEIGHTS = ("Regular", "Bold")
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".json"}
# テストとアドオンは画面に出ない。.godot/ と export/ は生成物
EXCLUDED_DIRS = {"tests", "addons", ".godot", "export", "reports"}

# 文言に今は無くても、文言の追加ですぐ要る文字（作り直し忘れで表示が欠けるのを減らす）
BASE_RANGES = (
    (0x0020, 0x007E),  # 英数字・ASCII の記号
    (0x00A0, 0x00FF),  # ラテン1の記号（× ÷ ° など）
    (0x2010, 0x2027),  # ダッシュ・引用符・…
    (0x2190, 0x2199),  # 矢印
    (0x3000, 0x303F),  # 和文の記号・句読点
    (0x3041, 0x309F),  # ひらがな
    (0x30A0, 0x30FF),  # カタカナ
    (0xFF01, 0xFF5E),  # 全角英数字・記号
)


def strip_gd_comments(source: str) -> str:
    r"""GDScript からコメント（# から行末まで）を除く。文字列の中の # は残す。
    複数行の文字列（引用符3つ）は行をまたいで文字列として扱う。
    確かめ方: python -m doctest tools/subset_noto_sans_jp.py

    >>> strip_gd_comments('var a = "x#y" # 注釈')
    'var a = "x#y" '
    >>> strip_gd_comments("var s = '''x\n# 残る\n'''  # 消える\nb")
    "var s = '''x\n# 残る\n'''  \nb"
    >>> strip_gd_comments("var t = '''it's # 残る'''")
    "var t = '''it's # 残る'''"
    >>> strip_gd_comments("x = '\\'#' # c")
    "x = '\\'#' "
    >>> strip_gd_comments('## 説明 ≒\nfunc f():')
    '\nfunc f():'
    """
    out: list[str] = []
    quote = None  # 文字列の中なら、閉じる引用符（" ' \"\"\" '''）
    i = 0
    while i < len(source):
        c = source[i]
        if quote:
            if c == "\\":
                out.append(source[i : i + 2])
                i += 2
                continue
            if source.startswith(quote, i):
                out.append(quote)
                i += len(quote)
                quote = None
                continue
            out.append(c)
            i += 1
        elif c in "\"'":
            quote = c * 3 if source.startswith(c * 3, i) else c
            out.append(quote)
            i += len(quote)
        elif c == "#":
            end = source.find("\n", i)
            i = len(source) if end == -1 else end
        else:
            out.append(c)
            i += 1
    return "".join(out)


def displayable_text(path: Path) -> str:
    """画面に出うる部分だけを返す。コメントは画面に出ないので、フォントに無い文字があっても困らない。"""
    if path.suffix == ".gd":
        return strip_gd_comments(path.read_text(encoding="utf-8"))
    lines = path.read_text(encoding="utf-8").splitlines()
    if path.suffix in {".tscn", ".tres"}:
        return "\n".join(line for line in lines if not line.lstrip().startswith(";"))
    return "\n".join(lines)


def collect_game_text_chars() -> set[str]:
    chars: set[str] = set()
    for path in GAME_DIR.rglob("*"):
        if path.suffix not in TEXT_SUFFIXES or not path.is_file():
            continue
        if EXCLUDED_DIRS.intersection(path.relative_to(GAME_DIR).parts):
            continue
        chars.update(displayable_text(path))
    # 改行・タブなどの制御文字は描かない
    return {c for c in chars if c.isprintable()}


def wanted_chars() -> set[str]:
    chars = collect_game_text_chars()
    for start, end in BASE_RANGES:
        chars.update(chr(cp) for cp in range(start, end + 1))
    return chars


def subset_path(weight: str) -> Path:
    return OUT_DIR / f"NotoSansJP-{weight}.woff2"


def generate(src_dir: Path) -> int:
    from fontTools import subset
    from fontTools.ttLib import TTFont

    chars = wanted_chars()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for weight in WEIGHTS:
        src = src_dir / f"NotoSansJP-{weight}.otf"
        if not src.is_file():
            print(f"元のファイルがありません: {src}", file=sys.stderr)
            return 2
        font = TTFont(src)
        cmap = font.getBestCmap()
        options = subset.Options()
        options.flavor = "woff2"
        options.hinting = False
        options.name_IDs = ["*"]  # 著作権表示・ライセンスの記述を残す（OFL）
        options.name_languages = ["*"]
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(unicodes=[ord(c) for c in chars if ord(c) in cmap])
        subsetter.subset(font)
        out = subset_path(weight)
        font.flavor = "woff2"
        font.save(out)
        print(f"{out.relative_to(REPO_ROOT)}: {out.stat().st_size:,} bytes")
    return check()


def check() -> int:
    from fontTools.ttLib import TTFont

    needed = collect_game_text_chars()
    status = 0
    for weight in WEIGHTS:
        path = subset_path(weight)
        if not path.is_file():
            print(f"サブセットがありません: {path.relative_to(REPO_ROOT)}", file=sys.stderr)
            return 2
        cmap = TTFont(path).getBestCmap()
        # 空白類はフォントに字形が無くても表示に困らない
        missing = sorted(c for c in needed if ord(c) not in cmap and not c.isspace())
        if missing:
            status = 1
            listed = " ".join(f"{c}(U+{ord(c):04X})" for c in missing)
            print(f"{path.name} に無い文字: {listed}", file=sys.stderr)
    if status == 0:
        print("文言の全文字がサブセットにあります")
    return status


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--src", type=Path, help="元の OTF（NotoSansJP-Regular.otf・NotoSansJP-Bold.otf）があるディレクトリ")
    group.add_argument("--check", action="store_true", help="サブセットに無い文字が無いかを確かめる")
    args = parser.parse_args()
    return check() if args.check else generate(args.src)


if __name__ == "__main__":
    sys.exit(main())
