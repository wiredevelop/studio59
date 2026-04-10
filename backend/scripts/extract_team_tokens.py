import csv
import re
from collections import defaultdict
from pathlib import Path

import pandas as pd

EXCEL_PATH = Path(__file__).resolve().parents[1].parent / 'docs' / 'Studio.xlsx'
OUT_PATH = Path(__file__).resolve().parents[1].parent / 'docs' / 'equipa_trabalho_tokens.csv'


def split_team(raw: str):
    if not raw:
        return []
    text = str(raw).replace('\n', ' ').strip()
    text = re.sub(r'\s*[+/&;,]\s*', ',', text)
    text = re.sub(r'\s+e\s+', ',', text, flags=re.IGNORECASE)
    text = re.sub(r'\s+and\s+', ',', text, flags=re.IGNORECASE)
    parts = [p.strip() for p in text.split(',') if p.strip()]
    return parts


def normalize_token(raw: str) -> str:
    text = re.sub(r'\(.*?\)', '', raw).strip()
    text = text.replace('"', '').replace("'", '')
    text = re.sub(r'[^A-Za-zÀ-ÿ0-9]+', ' ', text).strip()
    if not text:
        return ''
    return text.split()[0]


def main():
    if not EXCEL_PATH.exists():
        raise SystemExit(f"Missing {EXCEL_PATH}")

    df = pd.read_excel(EXCEL_PATH)
    col = 'EQUIPA DE TRABALHO'
    if col not in df.columns:
        raise SystemExit("Column 'EQUIPA DE TRABALHO' not found")

    counts = defaultdict(int)
    examples = defaultdict(list)

    for raw in df[col].dropna().astype(str):
        for part in split_team(raw):
            token = normalize_token(part)
            if not token:
                continue
            key = token.lower()
            counts[key] += 1
            if len(examples[key]) < 5:
                examples[key].append(part)

    rows = []
    for key, count in sorted(counts.items(), key=lambda x: (-x[1], x[0])):
        token = examples[key][0]
        rows.append({
            'token': token,
            'token_lower': key,
            'count': count,
            'examples': ' | '.join(examples[key]),
        })

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=['token', 'token_lower', 'count', 'examples'])
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {len(rows)} tokens to {OUT_PATH}")


if __name__ == '__main__':
    main()
