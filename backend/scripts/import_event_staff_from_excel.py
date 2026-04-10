import json
import re
import secrets
import unicodedata
from pathlib import Path

import bcrypt
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


def slugify(text: str) -> str:
    normalized = unicodedata.normalize('NFKD', text)
    normalized = normalized.encode('ascii', 'ignore').decode('ascii')
    normalized = normalized.lower()
    normalized = re.sub(r'[^a-z0-9]+', '.', normalized).strip('.')
    return normalized


def split_team(raw: str):
    if not raw:
        return []
    text = str(raw).replace('\n', ' ').strip()
    text = re.sub(r'\s*[+/&;,]\s*', ',', text)
    text = re.sub(r'\s+e\s+', ',', text, flags=re.IGNORECASE)
    text = re.sub(r'\s+and\s+', ',', text, flags=re.IGNORECASE)
    parts = [p.strip() for p in text.split(',') if p.strip()]
    return parts


def hash_placeholder() -> str:
    raw = secrets.token_urlsafe(16).encode('utf-8')
    hashed = bcrypt.hashpw(raw, bcrypt.gensalt(rounds=10)).decode('utf-8')
    if hashed.startswith('$2b$'):
        hashed = '$2y$' + hashed[4:]
    return hashed


def get_or_create_user(cur, name: str, password_hash: str) -> int:
    cur.execute("SELECT id FROM users WHERE LOWER(name)=LOWER(%s) LIMIT 1", (name,))
    row = cur.fetchone()
    if row:
        return int(row[0])

    base_slug = slugify(name) or 'staff'

    username = base_slug
    cur.execute("SELECT id FROM users WHERE username=%s LIMIT 1", (username,))
    suffix = 1
    while cur.fetchone():
        username = f"{base_slug}{suffix}"
        cur.execute("SELECT id FROM users WHERE username=%s LIMIT 1", (username,))
        suffix += 1

    email = f"legacy.{base_slug}@studio59.local"
    cur.execute("SELECT id FROM users WHERE email=%s LIMIT 1", (email,))
    suffix = 1
    while cur.fetchone():
        email = f"legacy.{base_slug}{suffix}@studio59.local"
        cur.execute("SELECT id FROM users WHERE email=%s LIMIT 1", (email,))
        suffix += 1

    cur.execute(
        "INSERT INTO users (name, username, email, password, role, permissions, created_at, updated_at) "
        "VALUES (%s, %s, %s, %s, 'photographer', NULL, NOW(), NOW())",
        (name, username, email, password_hash),
    )
    return int(cur.lastrowid)


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
        "SELECT id, event_meta FROM events "
        "WHERE legacy_report_number IS NOT NULL AND event_meta IS NOT NULL"
    )

    password_hash = hash_placeholder()
    inserted_links = 0
    created_users = 0

    for event_id, meta_raw in cur.fetchall():
        if not meta_raw:
            continue
        try:
            meta = json.loads(meta_raw)
        except Exception:
            continue

        raw_team = meta.get('EQUIPA DE TRABALHO') or meta.get('equipa_de_trabalho')
        if not raw_team:
            continue

        names = split_team(raw_team)
        if not names:
            continue

        for name in names:
            user_id_before = None
            cur.execute("SELECT id FROM users WHERE LOWER(name)=LOWER(%s) LIMIT 1", (name,))
            row = cur.fetchone()
            if row:
                user_id_before = int(row[0])

            user_id = get_or_create_user(cur, name, password_hash)
            if user_id_before is None:
                created_users += 1

            cur.execute(
                "INSERT IGNORE INTO event_staff (event_id, user_id, role, status, invited_at, created_at, updated_at) "
                "VALUES (%s, %s, 'photographer', 'assigned', NOW(), NOW(), NOW())",
                (event_id, user_id),
            )
            if cur.rowcount:
                inserted_links += 1

    conn.commit()
    cur.close()
    conn.close()

    print(f"Created users: {created_users}")
    print(f"Linked staff: {inserted_links}")


if __name__ == '__main__':
    main()
