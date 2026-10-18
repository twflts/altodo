"""旧い記法の altodo ファイルの説明を、現在の仕様の複数行コメントに変換する。

変換の内容:
  1. `/// 文` の行を、`///` を除いた通常の行（複数行コメント）にする。
  2. 子タスクの後ろに書かれた、親タスクの説明の行（親のインデント + 4 スペース）を、
     親タスクの直後（既存の説明の後ろ）へ移す。複数行コメントは、前行の
     インデント + 4 スペースの行だけが続くため、子タスクの後ろの行は、
     複数行コメントにならないためである。
  3. 移す行は、先頭の行のインデントに揃える。空行は、スペースだけの行にする。

使い方:
    python3 scripts/migrate-altodo-comments.py FILE [--write]

--write を付けないときは、変換後の内容を標準出力に出す。
親が見つからない行は、元の位置に残し、標準エラー出力に出す。
"""

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

TASK_RE = re.compile(r"^( *)\[[ x@w~]\](?: |$)")
NOTE_RE = re.compile(r"^( *)///(?: (.*))?$")
FENCE_RE = re.compile(r"^ *(```|~~~)")
INDENT_STEP = 4


@dataclass
class OpenTask:
    """走査中のタスク。

    Attributes:
        index: タスク行の行番号（0 始まり）。
        indent: タスク行のインデント。
        last_description: 直後の説明の最後の行番号。説明がなければ index。
        has_child: 子タスクを見たか。
    """

    index: int
    indent: int
    last_description: int
    has_child: bool = False


@dataclass
class Plan:
    """変換の計画。

    Attributes:
        removed: 元の位置から取り除く行番号。
        moves: 説明の最後の行番号から、その直後へ移す行の一覧。
        left: 親が見つからず、元の位置に残す行番号。
    """

    removed: set[int]
    moves: dict[int, list[str]]
    left: list[int]


def indent_of(line: str) -> int:
    """行頭のスペースの数を返す。"""
    return len(line) - len(line.lstrip(" "))


def convert_notes(lines: list[str]) -> list[str]:
    """コードブロックの外の `///` の行を、通常の行にする。"""
    result: list[str] = []
    in_fence = False
    for line in lines:
        if FENCE_RE.match(line):
            in_fence = not in_fence
        note = None if in_fence else NOTE_RE.match(line)
        result.append(note.group(1) + (note.group(2) or "") if note else line)
    return result


def block_end(lines: list[str], start: int, indent: int) -> int:
    """start から続く説明の行の、最後の次の行番号を返す。

    タスク行、見出し、インデントが浅い行で終わる。途中の空行は含め、
    末尾の空行は含めない。
    """
    end = start
    for position in range(start, len(lines)):
        line = lines[position]
        if TASK_RE.match(line) or line.startswith("#"):
            break
        if line != "" and indent_of(line) < indent:
            break
        if line != "":
            end = position + 1
    return end


def analyze(lines: list[str]) -> Plan:
    """子タスクの後ろにある説明の行を見つけ、移す計画を作る。"""
    plan = Plan(removed=set(), moves={}, left=[])
    stack: list[OpenTask] = []
    in_fence = False
    position = 0
    while position < len(lines):
        line = lines[position]
        fence = FENCE_RE.match(line)
        if fence:
            in_fence = not in_fence
        if in_fence or fence or line == "":
            position += 1
            continue
        indent = indent_of(line)
        if indent == 0 and not TASK_RE.match(line):
            stack.clear()
        elif TASK_RE.match(line):
            while stack and stack[-1].indent >= indent:
                stack.pop()
            if stack:
                stack[-1].has_child = True
            stack.append(OpenTask(position, indent, position))
        else:
            position = place_text(lines, position, stack, plan)
            continue
        position += 1
    return plan


def place_text(lines: list[str], position: int, stack: list[OpenTask],
               plan: Plan) -> int:
    """説明の行を調べ、必要なら移す計画に加える。次の行番号を返す。"""
    indent = indent_of(lines[position])
    owners = [task for task in stack if task.indent == indent - INDENT_STEP]
    owner = owners[0] if owners else None
    if owner and not owner.has_child and stack[-1] is owner:
        owner.last_description = position
        return position + 1
    end = block_end(lines, position, indent)
    if owner is None:
        plan.left.extend(range(position, end))
        return end
    moved = [" " * indent + lines[n].strip() for n in range(position, end)]
    if owner.last_description != owner.index:
        moved.insert(0, " " * indent)
    # 親タスクの説明の最後の行の直後に、後から見つけた行を順に加える。
    plan.moves.setdefault(owner.last_description, []).extend(moved)
    plan.removed.update(range(position, end))
    return end


def apply_plan(lines: list[str], plan: Plan) -> list[str]:
    """計画に従って、行を並べ替える。"""
    result: list[str] = []
    for position, line in enumerate(lines):
        if position not in plan.removed:
            result.append(line)
            result.extend(plan.moves.get(position, []))
    return result


def main() -> int:
    """ファイルを変換する。"""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("file", type=Path)
    parser.add_argument("--write", action="store_true",
                        help="ファイルを書き換える")
    args = parser.parse_args()

    lines = convert_notes(args.file.read_text(encoding="utf-8").split("\n"))
    plan = analyze(lines)
    output = "\n".join(apply_plan(lines, plan))
    for position in plan.left:
        print(f"left: line {position + 1}: {lines[position][:60]}",
              file=sys.stderr)
    if args.write:
        args.file.write_text(output, encoding="utf-8")
        moved = len(plan.removed)
        print(f"wrote {args.file}: moved {moved} lines, "
              f"left {len(plan.left)}")
    else:
        sys.stdout.write(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
