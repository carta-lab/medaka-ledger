#!/usr/bin/env python3
"""MedakaLedger/ のソースから画面の文言を集め、Localizable.xcstrings を作る（DECISIONS.md H）。

XcodeのないLinuxで作業するため、Xcodeの自動抽出の代わりに使う。
- 日本語を含む文字列リテラルを集める。キーは文言そのもの（CLAUDE.md）。
- Text(verbatim:) など表示用でない文字列、コメント、Domain/ と Models/SchemaV1.swift は対象外。
- 文言に埋め込む値は文字列にしてから渡す決まりなので、\\(...) は %@ に置き換える。
使い方: python3 scripts/gen-xcstrings.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "MedakaLedger"
OUTPUT = SOURCE_DIR / "Resources" / "Localizable.xcstrings"
EXCLUDED = [SOURCE_DIR / "Domain", SOURCE_DIR / "Models" / "SchemaV1.swift"]

JAPANESE = re.compile(r"[぀-ヿ㐀-鿿！-｠　-〿]")
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
SKIP_BEFORE = re.compile(r"(verbatim:\s*|accessibilityIdentifier\(\s*|#Predicate.*)$")


def interpolation_to_format(text: str) -> str:
    result = []
    i = 0
    while i < len(text):
        if text.startswith("\\(", i):
            depth = 0
            j = i + 1
            while j < len(text):
                if text[j] == "(":
                    depth += 1
                elif text[j] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            result.append("%@")
            i = j + 1
        else:
            result.append(text[i])
            i += 1
    return "".join(result)


ESCAPE = re.compile(r'\\[ntr"\\]')


def collect(problems: list[str]) -> set[str]:
    keys: set[str] = set()
    for path in sorted(SOURCE_DIR.rglob("*.swift")):
        if any(path == ex or ex in path.parents for ex in EXCLUDED):
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            stripped = line.strip()
            if stripped.startswith("//"):
                continue
            # 複数行リテラルは解釈しない。日本語の文言のある行で使われたら失敗させる
            if JAPANESE.search(line) and '"""' in line:
                problems.append(f"{path.relative_to(ROOT)}:{number}: 複数行の文字列には対応していません: {stripped}")
                continue
            code = line.split("//")[0] if '"' not in line.split("//")[0] or line.count('"') % 2 == 0 else line
            for match in LITERAL.finditer(code):
                literal = match.group(1)
                if not JAPANESE.search(literal):
                    continue
                if SKIP_BEFORE.search(code[: match.start()]):
                    continue
                # エスケープは解釈しない。キーが実際の文字列と合わなくなるので失敗させる
                if ESCAPE.search(literal):
                    problems.append(f"{path.relative_to(ROOT)}:{number}: エスケープを含む文言には対応していません: {stripped}")
                    continue
                keys.add(interpolation_to_format(literal))
    return keys


def main() -> int:
    problems: list[str] = []
    keys = collect(problems)
    if problems:
        print("\n".join(problems), file=sys.stderr)
        print("Localizable.xcstrings を作れません。文言の書き方を直してください。", file=sys.stderr)
        return 1
    catalog = {
        "sourceLanguage": "ja",
        "strings": {key: {"extractionState": "manual"} for key in sorted(keys)},
        "version": "1.0",
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    print(f"{len(keys)} strings -> {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
