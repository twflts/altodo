"""test/*.el から、テストの一覧（test/INDEX.md）を生成する。

Claude がテストを探すときの読み込み量を減らし、対象の関数に対応する
テストファイルを確実に見つけられるようにするための一覧である。

使い方:
    python3 scripts/gen-test-map.py           # test/INDEX.md を書き換える
    python3 scripts/gen-test-map.py --check   # 最新でなければ終了コード 1
"""

import argparse
import re
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEST_DIR = ROOT / "test"
INDEX_FILE = TEST_DIR / "INDEX.md"
BASELINE_FILE = ROOT / "scripts" / "test-baseline.txt"
SOURCE_FILES = [ROOT / "altodo.el", ROOT / "altodo-calendar.el",
                ROOT / "altodo-debug.el"]

# (区分名, 区分の判定に使う名前の断片)。上から順に最初に一致した区分にする。
AREAS: list[tuple[str, tuple[str, ...]]] = [
    ("サイドバー", ("sidebar",)),
    ("font-lock・face", ("fontlock", "face", "codeblock")),
    ("複数行コメント", ("multiline", "comment")),
    ("インデント・TAB", ("indent", "enter", "input")),
    ("日付", ("date",)),
    ("完了タスクの移動", ("move", "done-file")),
    ("ID・依存・seq-tasks", ("id-", "-id", "dependency", "goto-dep", "seq")),
    ("見出し・表示コンテキスト", ("heading", "display-context", "blank-line",
                        "setext", "normal-text")),
    ("フィルタ・DSL", ("filter", "dsl", "predicate", "parent-task",
                    "dynamic", "person", "tag", "heading")),
]
OTHER_AREA = "その他（コマンド・ユーティリティ・デバッグ）"

DEFTEST_RE = re.compile(r"^\((?:ert-deftest|[\w-]+--case)\s+(\S+)",
                        re.MULTILINE)
ASSERT_RE = re.compile(r"\((?:should|should-not|should-error|error)\s")
HEADER_RE = re.compile(r"^;;; \S+ --- (.+?)(?:\s+-\*-.*)?$", re.MULTILINE)
SYMBOL_RE = re.compile(r"\b((?:altodo|sidebar)[-\w]*)")
DEFINITION_RE = re.compile(
    r"^\((?:defun|cl-defun|defmacro|defvar|defvar-local|defcustom|defconst)"
    r"\s+(\S+)",
    re.MULTILINE,
)


@dataclass
class TestFile:
    """1 つのテストファイルの集計結果。

    Attributes:
        name: 拡張子なしのファイル名。
        description: ファイル先頭の説明。
        test_count: ERT のテスト数。
        expected_failures: 失敗を期待するテスト数。
        assertion_count: アサーション（should など）の数。
        targets: 主に使っている altodo の関数・変数。
        known_failures: ベースラインに記録された失敗の数。
        area: 区分名。
    """

    name: str
    description: str
    test_count: int
    expected_failures: int
    assertion_count: int
    targets: list[str] = field(default_factory=list)
    known_failures: int = 0
    area: str = OTHER_AREA


def load_definitions() -> set[str]:
    """altodo.el、altodo-calendar.el、altodo-debug.el で定義された名前の集合を返す。"""
    names: set[str] = set()
    for source in SOURCE_FILES:
        names.update(DEFINITION_RE.findall(source.read_text(encoding="utf-8")))
    return names


def classify(name: str, targets: list[str]) -> str:
    """ファイル名と対象の関数から区分名を決める。"""
    for area, fragments in AREAS:
        if any(fragment in name for fragment in fragments):
            return area
    joined = " ".join(targets)
    for area, fragments in AREAS:
        if any(fragment in joined for fragment in fragments):
            return area
    return OTHER_AREA


def load_known_failures() -> Counter[str]:
    """ベースラインの失敗数をファイルごとに数える。"""
    counts: Counter[str] = Counter()
    if BASELINE_FILE.exists():
        for line in BASELINE_FILE.read_text(encoding="utf-8").splitlines():
            if ":" in line:
                counts[line.split(":", 1)[0]] += 1
    return counts


def describe(text: str, name: str) -> str:
    """ファイル先頭の説明を返す。なければ最初のテストの docstring を返す。"""
    header = HEADER_RE.search(text)
    if header:
        return header.group(1).strip()
    doc = re.search(r'^\(ert-deftest\s+\S+\s+\(\)\s*\n?\s*"([^"\n]+)', text,
                    re.MULTILINE)
    return doc.group(1) if doc else name


def analyze(path: Path, definitions: set[str],
            known: Counter[str]) -> TestFile:
    """1 つのテストファイルを解析する。"""
    text = path.read_text(encoding="utf-8")
    symbols = Counter(s for s in SYMBOL_RE.findall(text) if s in definitions)
    targets = [symbol for symbol, _ in symbols.most_common(3)]
    name = path.stem
    return TestFile(
        name=name,
        description=describe(text, name),
        test_count=len(DEFTEST_RE.findall(text)),
        expected_failures=text.count(":expected-result :failed"),
        assertion_count=len(ASSERT_RE.findall(text)),
        targets=targets,
        known_failures=known[name],
        area=classify(name, targets),
    )


def render_row(item: TestFile) -> str:
    """表の 1 行を作る。"""
    notes = []
    if item.known_failures:
        notes.append(f"失敗 {item.known_failures}")
    if item.expected_failures:
        notes.append(f"既知の不具合 {item.expected_failures}")
    if item.test_count and item.assertion_count == 0:
        notes.append("アサーションなし")
    targets = "、".join(f"`{t}`" for t in item.targets)
    return (f"| `{item.name}` | {item.test_count} | {item.description} "
            f"| {targets} | {'、'.join(notes)} |")


def render(items: list[TestFile], archived: list[str]) -> str:
    """test/INDEX.md の内容を作る。"""
    total = sum(item.test_count for item in items)
    lines = [
        "# テスト一覧",
        "",
        "`scripts/gen-test-map.py` が生成する。手で編集しない（`scripts/ci.sh` "
        "が最新かを確認する）。",
        "",
        "## 使い方",
        "",
        f"- 全体: {len(items)} ファイル、{total} テスト",
        "- 実行: `scripts/run-tests.sh [test/NAME.el]`。ベースラインとの差分だけを"
        "報告する",
        "- 関数に対応するテストを探す: `grep -l 'altodo--関数名' test/*.el`",
        "- 共通の道具: `test/altodo-test-helper.el`"
        "（`altodo-test-with-buffer`、`-with-temp-dir`、`-with-locals`、"
        "`-with-today`、`altodo-test-file`）",
        "- 新しいテストは、ヘルパーを使い、日付は `altodo-test-with-today` で"
        "固定し、サンプルは一時ディレクトリに作る。`(should t)` のような"
        "アサーションを書かない",
        "- 仕様に基づくケース表: `multiline-comment-spec-test.el`。"
        "サンプルファイルの検証: `testfiles-test.el`",
        "- 「既知の不具合」は `:expected-result :failed` のテスト"
        "（修正すると想定外の成功として報告される）",
        "",
    ]
    for area in [name for name, _ in AREAS] + [OTHER_AREA]:
        group = [item for item in items if item.area == area]
        if not group:
            continue
        lines += [f"## {area}", "",
                  "| ファイル | 件数 | 内容 | 主な対象 | 備考 |",
                  "|---|---|---|---|---|"]
        lines += [render_row(item) for item in group]
        lines.append("")
    if archived:
        lines += ["## test/archive", "",
                  "実行しない（アサーションを持たない調査用のスクリプトなど）。"
                  "`test/archive/README.md` を参照する。", "",
                  "、".join(f"`{name}`" for name in archived), ""]
    return "\n".join(lines)


def main() -> int:
    """一覧を生成して書き込む。--check では差分の有無だけを調べる。"""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="test/INDEX.md が最新でなければ 1 を返す")
    args = parser.parse_args()

    definitions = load_definitions()
    known = load_known_failures()
    paths = sorted(p for p in TEST_DIR.glob("*.el")
                   if p.stem != "altodo-test-helper")
    items = [analyze(path, definitions, known) for path in paths]
    archived = sorted(p.stem for p in (TEST_DIR / "archive").glob("*.el"))
    content = render(items, archived)

    if args.check:
        current = INDEX_FILE.read_text(encoding="utf-8") if (
            INDEX_FILE.exists()) else ""
        if current != content:
            print("test/INDEX.md is stale: run scripts/gen-test-map.py",
                  file=sys.stderr)
            return 1
        print("test/INDEX.md is up to date")
        return 0
    INDEX_FILE.write_text(content, encoding="utf-8")
    print(f"wrote {INDEX_FILE.relative_to(ROOT)} ({len(items)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
