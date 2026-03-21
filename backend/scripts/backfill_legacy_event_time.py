import re
from pathlib import Path

import mysql.connector

ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / '.env'


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
    if re.fullmatch(r'\d{1,2}', text):
        hour = int(text)
        if 0 <= hour <= 23:
            return f"{hour:02d}:00:00"
    m = re.fullmatch(r'(\d{1,2}):(\d{2})', text)
    if m:
        hour = int(m.group(1))
        minute = int(m.group(2))
        if 0 <= hour <= 23 and 0 <= minute <= 59:
            return f"{hour:02d}:{minute:02d}:00"
    return None


def main():
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
        "SELECT id, mass_time_raw, event_time FROM events "
        "WHERE legacy_report_number IS NOT NULL AND mass_time_raw IS NOT NULL"
    )

    updates = []
    for event_id, mass_time_raw, event_time in cur.fetchall():
        parsed = normalize_time(mass_time_raw)
        if not parsed:
            continue
        if event_time is not None and str(event_time).startswith(parsed[:5]):
            continue
        updates.append((parsed, event_id))

    if updates:
        cur.executemany("UPDATE events SET event_time=%s WHERE id=%s", updates)
        conn.commit()

    print(f"Updated event_time: {len(updates)}")

    cur.close()
    conn.close()


if __name__ == '__main__':
    main()
