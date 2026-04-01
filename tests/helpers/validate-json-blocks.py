#!/usr/bin/env python3
"""Validate JSON blocks extracted from mysk markdown files.

These blocks contain placeholder text (Japanese descriptions, template
variables, ellipsis) that must be replaced before JSON parsing.
Reads from stdin, exits 0 on success, 1 on failure.
"""
import json
import re
import sys

REPLACEMENTS = [
    # Template variables like {RUN_ID}, {TOPIC}, etc.
    (r'"\{[A-Z_]+\}"', '"placeholder"'),
    (r"\{[A-Z_]+\}", '"placeholder"'),
    # Timestamps and dates
    (r"UTC\xe3\x82\xbf\xe3\x82\xa4\xe3\x83\xa0\xe3\x82\xb9\xe3\x82\xbf\xe3\x83\xb3\xe3\x83\x97", "2026-01-01T00:00:00Z"),  # UTCタイムスタンプ
    (r"\xe7\x8f\xbe\xe5\x9c\xa8\xe3\x81\xaeUTC\xe6\x99\x82\xe5\x88\xbb", "2026-01-01T00:00:00Z"),  # 現在のUTC時刻
    (r"YYYYMMDD-HHMMSSZ-[a-z-]+", "20260101-000000Z-example"),
    # Path placeholders
    (r"\xe3\x83\x97\xe3\x83\xad\xe3\x82\xb8\xe3\x82\xa7\xe3\x82\xaf\xe3\x83\x88\xe3\x83\xab\xe3\x83\xbc\xe3\x83\x88\xe3\x81\xb8\xe3\x81\xae\xe7\xb5\xb6\xe5\xaf\xbe\xe3\x83\x91\xe3\x82\xb9", "/tmp/project"),  # プロジェクトルートへの絶対パス
    (r"\xe3\x83\x97\xe3\x83\xad\xe3\x82\xb8\xe3\x82\xa7\xe3\x82\xaf\xe3\x83\x88\xe3\x83\xab\xe3\x83\xbc\xe3\x83\x88\xe3\x81\xae\xe7\xb5\xb6\xe5\xaf\xbe\xe3\x83\x91\xe3\x82\xb9", "/tmp/project"),  # プロジェクトルートの絶対パス
    (r"relative/path/to/file", "src/main.ts"),
    # Progress messages
    (r"\xe3\x83\x95\xe3\x82\xa7\xe3\x83\xbc\xe3\x82\xba \d+/\d+ \xe5\xae\x8c\xe4\x86\x82", "phase completed"),  # フェーズ N/N 完了
    (r"\xe3\x83\x95\xe3\x82\xa7\xe3\x83\xbc\xe3\x82\xba \d+/\d+ \xe3\x81\xa7\xe3\x82\xa8\xe3\x83\xa9\xe3\x83\xbc: [^\"]*", "phase error"),  # フェーズ N/N でエラー
    (r"\xe5\xae\x9f\xe8\xa3\x85\xe5\xae\x8c\xe4\x86\x82\xef\xbc\x88\xe5\x85\xa8\xe3\x83\x95\xe3\x82\xa7\xe3\x83\xbc\xe3\x82\xba\xe5\xae\x8c\xe4\x86\x82\xef\xbc\x89", "completed"),  # 実装完了（全フェーズ完了）
    (r"\xe4\xbb\x95\xe6\xa7\x98\xe6\x9b\xb8\xe3\x81\xae\xe3\x83\xac\xe3\x83\x93\xe3\x83\xa5\xe3\x83\xbc\xe3\x82\x92\xe9\x96\x8b\xe5\xa7\x8b", "review started"),  # 仕様書のレビューを開始
    (r"\xe4\xbb\x95\xe6\xa7\x98\xe6\x9b\xb8\xe3\x83\xac\xe3\x83\x93\xe3\x83\xa5\xe3\x83\xbc\xe5\xae\x8c\xe4\x86\x82", "review completed"),  # 仕様書レビュー完了
    (r"\xe3\x83\xac\xe3\x83\x93\xe3\x83\xa5\xe3\x83\xbc\xe9\x96\x8b\xe5\xa7\x8b", "review started"),  # レビュー開始
    (r"\xe3\x83\xac\xe3\x83\x93\xe3\x83\xa5\xe3\x83\xbc\xe5\xae\x8c\xe4\x86\x82", "review completed"),  # レビュー完了
    (r"\xe6\xa4\x9c\xe8\xa8\xbc\xe9\x96\x8b\xe5\xa7\x8b", "verification started"),  # 検証開始
    (r"\xe6\xa4\x9c\xe8\xa8\xbc\xe5\xae\x8c\xe4\x86\x82", "verification completed"),  # 検証完了
    # Description placeholders
    (r"\xe7\xb0\xa1\xe6\xbd\x94\xe3\x81\xaa\xe3\x82\xbf\xe3\x82\xa4\xe3\x83\x88\xe3\x83\xab", "title"),  # 簡潔なタイトル
    (r"\xe8\xa9\xb3\xe7\xb4\xb0\xe3\x81\xaa\xe8\xaa\xac\xe6\x98\x8e", "detail"),  # 詳細な説明
    (r"\xe8\xa9\xb3\xe7\xb4\xb0\xe3\x81\xaa\xe6\xa4\x9c\xe8\xa8\xbc\xe7\xb5\x90\xe6\x9e\x9c", "verification detail"),  # 詳細な検証結果
    (r"\xe4\xbf\xae\xe6\xad\xa3\xe6\x8f\x90\xe6\xa1\x88", "fix"),  # 修正提案
    (r"\xe6\x94\xb9\xe5\x96\x84\xe6\x8f\x90\xe6\xa1\x88", "suggestion"),  # 改善提案
    (r"\xe6\x8c\x87\xe6\x91\x98\xe3\x82\xbf\xe3\x82\xa4\xe3\x83\x88\xe3\x83\xab", "finding title"),  # 指摘タイトル
    (r"\xe4\xbb\x95\xe6\xa7\x98\xe6\x9b\xb8\xe3\x82\xbf\xe3\x82\xa4\xe3\x83\x88\xe3\x83\xab", "spec title"),  # 仕様書タイトル
    (r"\xe5\xaf\xbe\xe8\xb1\xa1\xe3\x83\x91\xe3\x82\xb9", "target path"),  # 対象パス
    # Headlines
    (r"\xe9\xab\x98\xe5\x84\xaa\xe5\x85\x88\xe5\xba\xa6X\xe4\xbb\xb6\xe3\x80\x81\xe4\xb8\xad\xe5\x84\xaa\xe5\x85\x88\xe5\xba\xa6Y\xe4\xbb\xb6", "headline"),  # 高優先度X件、中優先度Y件
    (r"\xe9\xab\x98\xe9\x87\x8d\xe8\xa6\x81\xe5\xba\xa6 X \xe4\xbb\xb6\xe3\x80\x81\xe4\xb8\xad\xe9\x87\x8d\xe8\xa6\x81\xe5\xba\xa6 Y \xe4\xbb\xb6", "headline"),  # 高重要度 X 件、中重要度 Y 件
    # Misc Japanese
    (r"\xe5\x82\x99\xe8\x80\x83", "note"),  # 備考
    (r"\xe3\x82\xa8\xe3\x83\xa9\xe3\x83\xbc\xe5\x86\x85\xe5\xae\xb9", "error"),  # エラー内容
    (r"\xe4\xbb\x95\xe6\xa7\x98\xe6\x9b\xb8\xe4\xb8\x8b\xe6\x9b\xb8\xe3\x81\x8d\xe4\xbd\x9c\xe6\x88\x90\xe5\xae\x8c\xe4\x86\x82", "completed"),  # 仕様書下書き作成完了
    (r"\xe3\x83\xa6\xe3\x83\xbc\xe3\x82\xb6\xe3\x83\xbc\xe3\x81\xae\xe5\x9b\x9e\xe7\xad\x94\xe5\xbe\x85\xe3\x81\xa1\xef\xbc\x88\xe8\xb3\xaa\xe5\x95\x8fN\xef\xbc\x89", "waiting"),  # ユーザーの回答待ち（質問N）
]

# Universal Japanese fallback: replace any remaining Japanese in strings
# with "text" if direct parse still fails
JP_CHAR_PATTERN = re.compile(r'[\u3000-\u9fff\u4e00-\u9fff\uff00-\uffef]+')


def clean_for_validation(text: str) -> str:
    """Apply all placeholder replacements and validate."""
    for pattern, replacement in REPLACEMENTS:
        text = re.sub(pattern, replacement, text)

    # Replace ellipsis "..." inside string values
    text = re.sub(r'"\.\.\."', '"placeholder"', text)

    # Replace standalone ... as JSON values
    text = re.sub(r':\s*\.\.\.\s*([,}\]])', r': "placeholder"\1', text)

    # Replace "N" (numeric placeholder in prose) with 0
    text = re.sub(r'"N"', '0', text)

    # Replace bare N/Z (schema placeholders) with 0
    text = re.sub(r':\s*N\s*([,}\]])', r': 0\1', text)
    text = re.sub(r':\s*Z\s*([,}\]])', r': 0\1', text)

    # Replace pipe-separated option strings like "high|medium|low"
    text = re.sub(r'"[^"]*\|[^"]*"', '"placeholder"', text)

    return text


def aggressive_clean(text: str) -> str:
    """Last-resort: replace any Japanese text in JSON strings."""
    def replacer(m):
        s = m.group(0)
        # Only replace if it contains Japanese characters
        if JP_CHAR_PATTERN.search(s):
            return '"text"'
        return s
    # Match quoted strings (simplified but good enough for our markdown JSON)
    return re.sub(r'"[^"]*"', replacer, text)


def validate_block(text: str) -> bool:
    """Validate a JSON block. Returns True if valid after substitutions."""
    text = clean_for_validation(text)
    try:
        json.loads(text)
        return True
    except json.JSONDecodeError:
        pass

    # Aggressive fallback
    text = aggressive_clean(text)
    try:
        json.loads(text)
        return True
    except json.JSONDecodeError:
        return False


if __name__ == "__main__":
    data = sys.stdin.read()
    if validate_block(data):
        sys.exit(0)
    else:
        sys.exit(1)
