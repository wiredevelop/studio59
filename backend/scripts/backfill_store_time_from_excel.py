import json
import re
from pathlib import Path

import mysql.connector
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / '.env'
EXCEL_PATH = Path('/var/www/wiredevelop/studio59/docs/Studio.xlsx')


def load_env(path: Path):
    env = {}
    if not path.exists():
        return env
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, val = line.split('=', 1)
        key = key.strip()
        val = val.strip()
        if val.startswith('"') and val.endswith('"'):
            val = val[1:-1]
        env[key] = val
    return env


def normalize_report_number(value):
    if value is None:
        return None
    if isinstance(value, (int, float)):
        if value != value:
            return None
        return int(value)
    text = str(value).strip()
    if not text:
        return None
    digits = re.sub(r'\D+', '', text)
    if not digits:
        return None
    return int(digits)


def normalize_time(value):
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    text = re.sub(r'\s+', '', text.lower())
    text = text.replace('h', ':')
    text = text.replace(',', ':').replace('.', ':')
    if re.fullmatch(r'\d{1,2}:', text):
        text = text + '00'
    if re.fullmatch(r'\d{1,2}$', text):
        hour = int(text)
        if 0 <= hour <= 23:
            return f"{hour:02d}:00"
    m = re.fullmatch(r'(\d{1,2}):(\d{2})', text)
    if m:
        hour = int(m.group(1))
        minute = int(m.group(2))
        if 0 <= hour <= 23 and 0 <= minute <= 59:
            return f"{hour:02d}:{minute:02d}"
    return None


def clip(value, limit=20):
    if value is None:
        return None
    text = str(value)
    if len(text) <= limit:
        return text
    return text[:limit]


def main():
    if not EXCEL_PATH.exists():
        raise SystemExit(f"Excel not found: {EXCEL_PATH}")

    df = pd.read_excel(EXCEL_PATH, sheet_name=0)
    if 'REPORTAGEM Nº' not in df.columns or 'Estar na Loja ás:' not in df.columns:
        raise SystemExit("Missing expected columns in Excel.")

    store_times = {}
    for _, row in df.iterrows():
        report = normalize_report_number(row.get('REPORTAGEM Nº'))
        if report is None:
            continue
        raw = row.get('Estar na Loja ás:')
        if pd.isna(raw) or raw == '':
            continue
        raw_str = clip(str(raw).strip(), 20)
        if not raw_str:
            continue
        if report not in store_times:
            store_times[report] = raw_str

    if not store_times:
        print("No store time values found in Excel.")
        return

    env = load_env(ENV_PATH)
    db_config = {
        'host': env.get('DB_HOST', '127.0.0.1'),
        'port': int(env.get('DB_PORT', '3306')),
        'user': env.get('DB_USERNAME', 'root'),
        'password': env.get('DB_PASSWORD', ''),
        'database': env.get('DB_DATABASE', 'studio59'),
    }

    conn = mysql.connector.connect(**db_config)
    cur = conn.cursor()

    cur.execute(
        "SELECT id, internal_code, legacy_report_number, event_meta, store_time_raw "
        "FROM events WHERE internal_code IS NOT NULL OR legacy_report_number IS NOT NULL"
    )

    updates = []
    matched = 0
    for event_id, internal_code, legacy_report_number, event_meta, store_time_raw in cur.fetchall():
        report = normalize_report_number(internal_code) or normalize_report_number(legacy_report_number)
        if report is None:
            continue
        raw = store_times.get(report)
        if not raw:
            continue
        matched += 1
        meta = {}
        if event_meta:
            try:
                meta = json.loads(event_meta)
                if not isinstance(meta, dict):
                    meta = {}
            except Exception:
                meta = {}
        meta['ESTAR_NA_LOJA_raw'] = raw
        meta['Estar na Loja ás:'] = raw
        norm = normalize_time(raw)
        if norm:
            meta['estar_na_loja_as'] = norm
        updates.append((raw, json.dumps(meta, ensure_ascii=False), event_id))

    if updates:
        cur.executemany(
            "UPDATE events SET store_time_raw=%s, event_meta=%s WHERE id=%s",
            updates
        )
        conn.commit()

    print(f"Matched events: {matched}")
    print(f"Updated events: {len(updates)}")

    cur.close()
    conn.close()


if __name__ == '__main__':
    main()
