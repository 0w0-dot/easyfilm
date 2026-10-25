#!/usr/bin/env python3 -I
"""코드에 쓴 한국어 화면 글이 영어, 일본어 번역 파일에 모두 있는지 확인한다.

사용: python3 -I tools/check_localization.py
빠진 번역이 있으면 목록을 보여 주고 1을 돌려준다.
"""
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HANGUL = re.compile(r"[가-힣]")
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
# 화면 글이 아닌 한국어(파일 경로 등)는 여기에 둔다.
NOT_UI = set()


def code_keys():
    keys = set()
    for path in (ROOT / "Sources").rglob("*.swift"):
        for line in path.read_text(encoding="utf-8").splitlines():
            code = line.split("//", 1)[0]
            for text in LITERAL.findall(code):
                if HANGUL.search(text) and text not in NOT_UI:
                    keys.add(text.replace("\\n", "\n"))
    return keys


def strings_keys(lang):
    path = ROOT / "Resources" / f"{lang}.lproj" / "Localizable.strings"
    data = subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", str(path)],
        capture_output=True, text=True, check=True,
    ).stdout
    return set(json.loads(data or "{}"))


def main():
    used = code_keys()
    failed = False
    for lang in ("en", "ja"):
        have = strings_keys(lang)
        missing = sorted(used - have)
        unused = sorted(have - used)
        if missing:
            failed = True
            print(f"[{lang}] 번역이 빠진 글:")
            for key in missing:
                print("   ", key.replace("\n", "\\n"))
        if unused:
            print(f"[{lang}] 코드에서 쓰지 않는 번역:")
            for key in unused:
                print("   ", key.replace("\n", "\\n"))
    if not failed:
        print(f"번역 확인 완료: 화면 글 {len(used)}개, 영어와 일본어 모두 빠짐없음")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
