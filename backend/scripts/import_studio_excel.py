import json
import os
import re
import random
from datetime import datetime, date
from pathlib import Path

import mysql.connector
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / '.env'
EXCEL_PATH = ROOT.parent / 'docs' / 'Studio.xlsx'


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


def to_str_number(val):
    if pd.isna(val):
        return None
    if isinstance(val, (int,)):
        return str(val)
    if isinstance(val, float):
        if val.is_integer():
            return str(int(val))
        return str(val)
    s = str(val).strip()
    return s or None


def parse_date(val):
    if pd.isna(val):
        return None
    if isinstance(val, pd.Timestamp):
        if pd.isna(val):
            return None
        return val.date()
    if isinstance(val, datetime):
        return val.date()
    if isinstance(val, date):
        return val
    s = str(val).strip()
    if not s:
        return None
    dt = pd.to_datetime(s, errors='coerce', dayfirst=True)
    if pd.isna(dt):
        return None
    return dt.date()


def parse_time(val):
    if pd.isna(val):
        return None
    s = str(val).strip()
    if not s:
        return None
    # Normalize separators
    s = s.replace(',', ':').replace('.', ':')
    if not re.match(r'^\d{1,2}:\d{2}$', s):
        return None
    h_str, m_str = s.split(':', 1)
    try:
        h = int(h_str)
        m = int(m_str)
    except ValueError:
        return None
    if h < 0 or h > 23 or m < 0 or m > 59:
        return None
    return f"{h:02d}:{m:02d}:00"


def parse_int(val):
    if pd.isna(val):
        return None
    s = str(val).strip()
    if not s:
        return None
    s = re.sub(r'[^0-9]', '', s)
    if not s:
        return None
    try:
        return int(s)
    except ValueError:
        return None


def parse_money(val):
    if pd.isna(val):
        return None
    s = str(val).strip().lower()
    if not s:
        return None
    s = s.replace('€', '').replace('eur', '').replace('euros', '').replace(' ', '')
    s = re.sub(r'[^0-9,\.]', '', s)
    if not s:
        return None
    if ',' in s and '.' in s:
        if s.rfind(',') > s.rfind('.'):
            s = s.replace('.', '').replace(',', '.')
        else:
            s = s.replace(',', '')
    elif ',' in s and '.' not in s:
        s = s.replace(',', '.')
    try:
        num = float(s)
    except ValueError:
        return None
    if num > 99999999.99 or num < -99999999.99:
        return None
    return num


def normalize_service(raw):
    if not raw:
        return None
    s = str(raw).lower()
    flags = []
    if 'casamento' in s:
        flags.append('casamento')
    if 'baptiz' in s or 'batiz' in s:
        flags.append('batizado')
    if 'comunh' in s:
        flags.append('comunhao')
    if 'boda' in s:
        flags.append('bodas')
    if 'anivers' in s:
        flags.append('aniversario')
    if not flags:
        return 'outros'
    return '+'.join(flags)


def to_jsonable(val):
    if pd.isna(val):
        return None
    if isinstance(val, pd.Timestamp):
        return val.isoformat()
    if isinstance(val, (datetime, date)):
        return val.isoformat()
    return val


def clip(val, max_len):
    if val is None:
        return None
    s = str(val)
    if len(s) <= max_len:
        return s
    return s[:max_len]


def generate_unique_pin(used_pins: set) -> str:
    for _ in range(80):
        pin = f"{random.randint(1000, 9999)}"
        if pin not in used_pins:
            used_pins.add(pin)
            return pin
    pin = f"{random.randint(1000, 9999)}"
    used_pins.add(pin)
    return pin


def main():
    env = load_env(ENV_PATH)
    db_config = {
        'host': env.get('DB_HOST', '127.0.0.1'),
        'port': int(env.get('DB_PORT', '3306')),
        'user': env.get('DB_USERNAME', 'root'),
        'password': env.get('DB_PASSWORD', ''),
        'database': env.get('DB_DATABASE', 'studio59'),
    }

    if not EXCEL_PATH.exists():
        raise SystemExit(f"Excel not found: {EXCEL_PATH}")

    df = pd.read_excel(EXCEL_PATH, sheet_name=0)

    # Prepare DB
    conn = mysql.connector.connect(**db_config)
    conn.autocommit = False
    cur = conn.cursor()

    cur.execute("SELECT id FROM users ORDER BY id LIMIT 1")
    row = cur.fetchone()
    if not row:
        raise SystemExit("No users found. Create a user first.")
    created_by = row[0]

    cur.execute("SELECT legacy_report_number FROM events WHERE legacy_report_number IS NOT NULL")
    existing = {r[0] for r in cur.fetchall()}
    cur.execute("SELECT access_pin FROM events WHERE access_pin IS NOT NULL")
    used_pins = {r[0] for r in cur.fetchall()}

    mapped_cols = {
        'REPORTAGEM Nº',
        'CLIENTE Nº',
        'SERVIÇO DE:',
        'NOIVA',
        'NOIVO',
        'Email noiva',
        'Email noivo',
        'Telemovel noiva',
        'Telemovel noivo',
        'DATA',
        'DATA ENTREGA',
        'HORAS',
        'LOCAL',
        'LOCALIDADE',
        'MORADA',
        'MORADA2',
        'MISSA ÀS',
        'Estar na Loja ás:',
        'sair noiva',
        'sair noivo',
        'Nº CONVIDADOS',
        'PREÇO',
        'Preço Base',
        'OBS',
    }

    cols = [
        'name',
        'client_id',
        'internal_code',
        'legacy_report_number',
        'legacy_client_number',
        'event_type',
        'service_raw',
        'event_date',
        'event_time',
        'delivery_date',
        'guest_count',
        'location',
        'city',
        'address',
        'address2',
        'mass_time_raw',
        'store_time_raw',
        'bride_departure_time_raw',
        'groom_departure_time_raw',
        'notes',
        'storage_path',
        'event_meta',
        'access_pin',
        'base_price',
        'total_price',
        'created_by',
        'bride_name',
        'groom_name',
        'bride_email',
        'groom_email',
        'bride_phone',
        'groom_phone',
        'created_at',
        'updated_at',
    ]

    insert_sql = (
        "INSERT INTO events (" + ",".join(cols) + ") VALUES (" + ",".join(["%s"] * len(cols)) + ")"
    )

    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    batch = []
    inserted = 0
    skipped = 0

    for _, r in df.iterrows():
        legacy_report = clip(to_str_number(r.get('REPORTAGEM Nº')), 50)
        legacy_client = clip(to_str_number(r.get('CLIENTE Nº')), 50)
        service_raw = r.get('SERVIÇO DE:')
        service_raw = None if pd.isna(service_raw) else str(service_raw).strip() or None

        event_date = parse_date(r.get('DATA'))
        delivery_date = parse_date(r.get('DATA ENTREGA'))
        if event_date is None:
            event_date = delivery_date
        if event_date is None:
            # Ensure NOT NULL constraint is satisfied; mark missing date in metadata
            event_date = date(1900, 1, 1)

        bride_name = r.get('NOIVA')
        bride_name = None if pd.isna(bride_name) else str(bride_name).strip() or None
        groom_name = r.get('NOIVO')
        groom_name = None if pd.isna(groom_name) else str(groom_name).strip() or None

        has_meaning = any([
            legacy_report,
            legacy_client,
            service_raw,
            event_date,
            bride_name,
            groom_name,
        ])
        if not has_meaning:
            skipped += 1
            continue

        if legacy_report and legacy_report in existing:
            skipped += 1
            continue

        name = None
        if bride_name and groom_name:
            name = f"{bride_name} & {groom_name}"
        elif bride_name or groom_name:
            name = bride_name or groom_name
        elif service_raw:
            name = service_raw
        elif legacy_report:
            name = f"Evento {legacy_report}"
        else:
            name = "Evento importado"

        event_type = normalize_service(service_raw)

        event_time = parse_time(r.get('MISSA ÀS'))

        location = r.get('LOCAL')
        location = None if pd.isna(location) else str(location).strip() or None
        city = r.get('LOCALIDADE')
        city = None if pd.isna(city) else str(city).strip() or None
        address = r.get('MORADA')
        address = None if pd.isna(address) else str(address).strip() or None
        address2 = r.get('MORADA2')
        address2 = None if pd.isna(address2) else str(address2).strip() or None

        mass_time_raw = r.get('MISSA ÀS')
        mass_time_raw = None if pd.isna(mass_time_raw) else str(mass_time_raw).strip() or None
        mass_time_raw = clip(mass_time_raw, 20)
        store_time_raw = r.get('Estar na Loja ás:')
        store_time_raw = None if pd.isna(store_time_raw) else str(store_time_raw).strip() or None
        store_time_raw = clip(store_time_raw, 20)
        bride_departure_time_raw = r.get('sair noiva')
        bride_departure_time_raw = None if pd.isna(bride_departure_time_raw) else str(bride_departure_time_raw).strip() or None
        bride_departure_time_raw = clip(bride_departure_time_raw, 20)
        groom_departure_time_raw = r.get('sair noivo')
        groom_departure_time_raw = None if pd.isna(groom_departure_time_raw) else str(groom_departure_time_raw).strip() or None
        groom_departure_time_raw = clip(groom_departure_time_raw, 20)

        notes = r.get('OBS')
        notes = None if pd.isna(notes) else str(notes).strip() or None

        guest_count = parse_int(r.get('Nº CONVIDADOS'))
        total_price = parse_money(r.get('PREÇO'))
        base_price = parse_money(r.get('Preço Base'))

        bride_email = r.get('Email noiva')
        bride_email = None if pd.isna(bride_email) else str(bride_email).strip() or None
        groom_email = r.get('Email noivo')
        groom_email = None if pd.isna(groom_email) else str(groom_email).strip() or None
        bride_phone = r.get('Telemovel noiva')
        bride_phone = None if pd.isna(bride_phone) else str(bride_phone).strip() or None
        bride_phone = clip(bride_phone, 40)
        groom_phone = r.get('Telemovel noivo')
        groom_phone = None if pd.isna(groom_phone) else str(groom_phone).strip() or None
        groom_phone = clip(groom_phone, 40)

        meta = {}
        for col in df.columns:
            if col in mapped_cols:
                continue
            val = r.get(col)
            if pd.isna(val) or val == '':
                continue
            meta[col] = to_jsonable(val)
        # Keep raw values for parsed fields that may have been normalized
        raw_map = {
            'DATA_raw': r.get('DATA'),
            'DATA_ENTREGA_raw': r.get('DATA ENTREGA'),
            'HORAS_raw': r.get('HORAS'),
            'HORAS2_raw': r.get('HORAS2'),
            'MISSA_AS_raw': r.get('MISSA ÀS'),
            'ESTAR_NA_LOJA_raw': r.get('Estar na Loja ás:'),
            'SAIR_NOIVA_raw': r.get('sair noiva'),
            'SAIR_NOIVO_raw': r.get('sair noivo'),
            'PRECO_raw': r.get('PREÇO'),
            'PRECO_BASE_raw': r.get('Preço Base'),
        }
        for k, v in raw_map.items():
            if pd.isna(v) or v == '':
                continue
            meta[k] = to_jsonable(v)

        if event_date == date(1900, 1, 1):
            meta['event_date_missing'] = True
        event_meta = json.dumps(meta, ensure_ascii=False) if meta else None

        access_pin = generate_unique_pin(used_pins)

        values = (
            name,
            None,
            None,
            legacy_report,
            legacy_client,
            event_type,
            service_raw,
            event_date,
            event_time,
            delivery_date,
            guest_count,
            location,
            city,
            address,
            address2,
            mass_time_raw,
            store_time_raw,
            bride_departure_time_raw,
            groom_departure_time_raw,
            notes,
            None,
            event_meta,
            access_pin,
            base_price,
            total_price,
            created_by,
            bride_name,
            groom_name,
            bride_email,
            groom_email,
            bride_phone,
            groom_phone,
            now,
            now,
        )

        batch.append(values)

        if len(batch) >= 500:
            cur.executemany(insert_sql, batch)
            conn.commit()
            inserted += len(batch)
            batch.clear()

    if batch:
        cur.executemany(insert_sql, batch)
        conn.commit()
        inserted += len(batch)

    cur.close()
    conn.close()

    print(f"Inserted: {inserted}")
    print(f"Skipped: {skipped}")


if __name__ == '__main__':
    main()
