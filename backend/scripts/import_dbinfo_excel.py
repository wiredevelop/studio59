import argparse
import json
import os
import random
import re
from collections import defaultdict
from datetime import date, datetime
from pathlib import Path

import mysql.connector
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / '.env'
DBINFO_DIR = ROOT.parent / 'docs' / 'dbinfo'
SOURCE_FILES = [
    'tudo.xlsx',
    'todos.xlsx',
    'batizados.xlsx',
    'comunhao.xlsx',
]
FILE_PRIORITY = {
    'tudo.xlsx': 400,
    'todos.xlsx': 300,
    'batizados.xlsx': 200,
    'comunhao.xlsx': 100,
}


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


def to_jsonable(val):
    if pd.isna(val):
        return None
    if isinstance(val, pd.Timestamp):
        return val.isoformat()
    if isinstance(val, (datetime, date)):
        return val.isoformat()
    return val


def to_str_number(val):
    if pd.isna(val):
        return None
    if isinstance(val, int):
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
        return None if pd.isna(val) else val.date()
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
    return f'{h:02d}:{m:02d}:00'


def normalize_time_text(val):
    if pd.isna(val):
        return None
    s = str(val).strip()
    return s or None


def parse_int(val):
    if pd.isna(val):
        return None
    if isinstance(val, int):
        return int(val)
    if isinstance(val, float):
        if val != val:
            return None
        if val.is_integer():
            return int(val)
        return int(round(val))
    s = str(val).strip()
    if not s:
        return None
    s = s.replace(',', '.')
    if re.match(r'^\d+(?:\.\d+)?$', s):
        try:
            return int(round(float(s)))
        except ValueError:
            return None
    s = re.sub(r'[^0-9]', '', s)
    if not s:
        return None
    return int(s)


def parse_money(val):
    if pd.isna(val):
        return None
    s = str(val).strip().lower()
    if not s:
        return None
    s = s.replace('€', '').replace('eur', '').replace('euros', '')
    m = re.search(r'\d+(?:[\.,]\d{3})*(?:[\.,]\d+)?', s)
    if not m:
        return None
    s = m.group(0)
    if ',' in s and '.' in s:
        if s.rfind(',') > s.rfind('.'):
            s = s.replace('.', '').replace(',', '.')
        else:
            s = s.replace(',', '')
    elif ',' in s and '.' not in s:
        s = s.replace(',', '.')
    try:
        return float(s)
    except ValueError:
        return None


def sanitize_db_money(val, max_abs=99999999.99):
    if val is None:
        return None
    try:
        num = float(val)
    except (TypeError, ValueError):
        return None
    if abs(num) > max_abs:
        return None
    return num


def normalize_service(raw):
    if not raw:
        return None
    s = str(raw).lower()
    if 'casamento' in s:
        return 'casamento'
    if 'baptiz' in s or 'batiz' in s:
        return 'batizado'
    if 'comunh' in s:
        return 'comunhao'
    if 'boda' in s:
        return 'bodas'
    if 'anivers' in s:
        return 'aniversario'
    return 'outros'


def clip(val, max_len):
    if val is None:
        return None
    s = str(val)
    return s if len(s) <= max_len else s[:max_len]


def slug_upper(text, max_len):
    raw = re.sub(r'[^A-Za-z0-9]+', '', str(text or ''))
    return (raw[:max_len] or 'EV').upper()


def build_event_name(event_type, event_date, merged):
    type_label = (event_type or 'evento').upper()
    date_label = event_date.strftime('%Y-%m-%d') if event_date else None
    names = ''
    if event_type == 'casamento':
        noivo = str(merged.get('NOIVO') or '').strip()
        noiva = str(merged.get('NOIVA') or '').strip()
        if noivo and noiva:
            names = f'{noivo} & {noiva}'
        else:
            names = (noivo + ' ' + noiva).strip()
    elif event_type == 'batizado':
        names = str(merged.get('BEBÉ') or merged.get('BEBE') or '').strip()
    parts = [p for p in [type_label, names, date_label] if p]
    return ' - '.join(parts) if parts else 'Evento'


def normalize_text(raw):
    text = re.sub(r'[^a-z0-9]+', ' ', str(raw or '').lower())
    return f' {text.strip()} '


def normalize_token(raw):
    text = re.sub(r'\(.*?\)', '', str(raw or ''))
    text = re.sub(r'[^\w]+', ' ', text, flags=re.UNICODE).strip().lower()
    if not text:
        return ''
    return text.split(' ')[0]


def initials_from_name(name):
    parts = [p for p in re.split(r'\s+', str(name or '').strip()) if p]
    if not parts:
        return ''
    first = parts[0]
    last = parts[-1]
    return (first[:1] + last[:1]).lower()


def split_team_parts(raw):
    text = str(raw or '').replace('\r', ' ').replace('\n', ' ')
    text = re.sub(r'\s*[+,&;/]+\s*', ',', text)
    text = re.sub(r'\s+e\s+', ',', text, flags=re.I)
    text = re.sub(r'\s+and\s+', ',', text, flags=re.I)
    return [p.strip() for p in text.split(',') if p.strip()]


def resolve_team_user_ids(raw, users):
    if not raw or not str(raw).strip():
        return []
    tokens = [normalize_token(part) for part in split_team_parts(raw)]
    tokens = [t for t in tokens if t]
    ids = []
    by_token = defaultdict(list)
    by_username = {}
    for user in users:
        username = str(user.get('username') or '').strip().lower()
        if username:
            by_username[username] = user['id']
            by_token[username].append(user['id'])
        initials = initials_from_name(user.get('name'))
        if initials:
            by_token[initials].append(user['id'])
    for token in tokens:
        ids.extend(by_token.get(token, []))
    normalized_raw = normalize_text(raw)
    for username, user_id in by_username.items():
        pattern = re.compile(rf'(^|[^a-z0-9]){re.escape(username)}([^a-z0-9]|$)')
        if pattern.search(normalized_raw):
            ids.append(user_id)
    for user in users:
        name = str(user.get('name') or '').strip()
        if not name:
            continue
        parts = [p for p in re.split(r'\s+', name) if p]
        if len(parts) == 1:
            single = normalize_text(parts[0])
            if single.strip() and single in normalized_raw:
                ids.append(user['id'])
        else:
            full = normalize_text(name)
            if full.strip() and full in normalized_raw:
                ids.append(user['id'])
    return sorted(set(ids))


def make_client_numbers(event_type, event_date, meta):
    date_text = event_date.strftime('%Y%m%d') if event_date else datetime.utcnow().strftime('%Y%m%d')

    def make_number(suffix):
        return f'{date_text}{suffix}{random.randint(100, 999)}'

    if event_type == 'casamento':
        if not meta.get('cliente_noivo_num'):
            meta['cliente_noivo_num'] = make_number('1')
        if not meta.get('cliente_noiva_num'):
            meta['cliente_noiva_num'] = make_number('2')
        if meta.get('cliente_noivo_num') == meta.get('cliente_noiva_num'):
            meta['cliente_noiva_num'] = make_number('2')
    elif event_type == 'batizado':
        if not meta.get('cliente_batizado_num'):
            meta['cliente_batizado_num'] = make_number('B')


def generate_unique_pin(used_pins):
    for _ in range(80):
        pin = f'{random.randint(1000, 9999)}'
        if pin not in used_pins:
            used_pins.add(pin)
            return pin
    pin = f'{random.randint(1000, 9999)}'
    used_pins.add(pin)
    return pin


def generate_internal_code(event_type, event_date, name, existing_codes):
    date_text = event_date.strftime('%Y%m%d') if event_date else datetime.utcnow().strftime('%Y%m%d')
    type_text = (event_type or 'evt')[:3].upper()
    initial = slug_upper(name, 2)
    for _ in range(40):
        suffix = str(random.randint(100, 999))
        code = f'{type_text}-{date_text}-{initial}{suffix}'
        if code not in existing_codes:
            existing_codes.add(code)
            return code
    code = f'{type_text}-{date_text}-{slug_upper(random.random(), 4)}'
    existing_codes.add(code)
    return code


def row_richness(row):
    score = 0
    for value in row.values():
        if value is None:
            continue
        if isinstance(value, str) and value.strip() == '':
            continue
        score += 1
    return score


def source_rank(name):
    return FILE_PRIORITY.get(name, 0)


def row_key(row):
    report = to_str_number(row.get('REPORTAGEM Nº'))
    if report:
        return f'report:{report}'
    service = str(row.get('SERVIÇO DE:') or '').strip().lower()
    when = parse_date(row.get('DATA')) or parse_date(row.get('DATA ENTREGA'))
    when_text = when.isoformat() if when else 'nodate'
    name = str(row.get('NOIVA') or row.get('NOIVO') or row.get('BEBÉ') or row.get('BEBE') or row.get('NOME') or '').strip().lower()
    return f'fallback:{service}|{when_text}|{name}'


def load_sources():
    records = []
    for filename in SOURCE_FILES:
        path = DBINFO_DIR / filename
        if not path.exists():
            continue
        df = pd.read_excel(path, sheet_name=0)
        for idx, row in df.iterrows():
            values = {str(col).strip(): to_jsonable(row.get(col)) for col in df.columns}
            if not any(v not in [None, ''] for v in values.values()):
                continue
            records.append({
                'file': filename,
                'sheet': 'Sheet1',
                'row_number': int(idx) + 2,
                'values': values,
                'richness': row_richness(values),
            })
    return records


def merge_records(records):
    grouped = defaultdict(list)
    for record in records:
        grouped[row_key(record['values'])].append(record)

    merged = []
    for _, items in grouped.items():
        items = sorted(
            items,
            key=lambda item: (item['richness'], source_rank(item['file'])),
            reverse=True,
        )
        merged_row = {}
        for item in items:
            for key, value in item['values'].items():
                if value in [None, '']:
                    continue
                if merged_row.get(key) in [None, '']:
                    merged_row[key] = value
        merged.append({
            'preferred': items[0],
            'sources': items,
            'values': merged_row,
        })
    return merged


def build_event_payload(record, used_pins, existing_codes, created_by, users):
    row = record['values']
    legacy_report = clip(to_str_number(row.get('REPORTAGEM Nº')), 50)
    legacy_client = clip(to_str_number(row.get('CLIENTE Nº')), 50)
    service_raw = str(row.get('SERVIÇO DE:') or '').strip() or None
    event_type = normalize_service(service_raw)
    event_date = parse_date(row.get('DATA')) or parse_date(row.get('DATA ENTREGA')) or date(1900, 1, 1)
    delivery_date = parse_date(row.get('DATA ENTREGA'))
    bride_name = clip((row.get('NOIVA') or None), 255)
    groom_name = clip((row.get('NOIVO') or None), 255)
    bride_email = clip((row.get('Email noiva') or None), 255)
    groom_email = clip((row.get('Email noivo') or None), 255)
    bride_phone = clip((row.get('Telemovel noiva') or None), 40)
    groom_phone = clip((row.get('Telemovel noivo') or None), 40)
    notes = clip((row.get('OBS') or None), 65535)

    meta = dict(row)
    if legacy_report:
        meta['legacy_report_number_raw'] = legacy_report
    if legacy_client:
        meta['legacy_client_number_raw'] = legacy_client
    meta['source_files'] = [
        {
            'file': source['file'],
            'sheet': source['sheet'],
            'row': source['row_number'],
        }
        for source in record['sources']
    ]

    raw_map = {
        'DATA_raw': row.get('DATA'),
        'DATA_ENTREGA_raw': row.get('DATA ENTREGA'),
        'HORAS_raw': row.get('HORAS'),
        'HORAS2_raw': row.get('HORAS2'),
        'MISSA_AS_raw': row.get('MISSA ÀS'),
        'ESTAR_NA_LOJA_raw': row.get('Estar na Loja ás:'),
        'SAIR_NOIVA_raw': row.get('sair noiva'),
        'SAIR_NOIVO_raw': row.get('sair noivo'),
        'PRECO_raw': row.get('PREÇO'),
        'PRECO_BASE_raw': row.get('Preço Base'),
    }
    for key, value in raw_map.items():
        if value not in [None, '']:
            meta[key] = value

    if event_type == 'casamento':
        if groom_name:
            meta.setdefault('noivo_nome', groom_name)
        if bride_name:
            meta.setdefault('noiva_nome', bride_name)
        if groom_phone:
            meta.setdefault('noivo_contacto', groom_phone)
        if bride_phone:
            meta.setdefault('noiva_contacto', bride_phone)
    elif event_type == 'batizado':
        baby = row.get('BEBÉ') or row.get('BEBE')
        if baby:
            meta.setdefault('bebe_nome', baby)

    make_client_numbers(event_type, event_date, meta)

    name = build_event_name(event_type, event_date, meta)
    internal_code = generate_internal_code(event_type, event_date, name, existing_codes)

    team_raw = str(meta.get('EQUIPA DE TRABALHO') or meta.get('equipa_de_trabalho') or '').strip()
    meta['equipa_de_trabalho'] = team_raw or meta.get('equipa_de_trabalho')
    team_user_ids = resolve_team_user_ids(team_raw, users)
    legacy_price = sanitize_db_money(parse_money(row.get('PREÇO')))
    legacy_base_price = sanitize_db_money(parse_money(row.get('Preço Base')))
    legacy_total_price = sanitize_db_money(parse_money(row.get('VALOR CONTRATO'))) or legacy_price

    payload = {
        'name': name,
        'client_id': None,
        'internal_code': internal_code,
        'legacy_report_number': legacy_report,
        'legacy_client_number': legacy_client,
        'event_type': event_type,
        'service_raw': service_raw,
        'event_date': event_date,
        'event_time': parse_time(row.get('MISSA ÀS')),
        'delivery_date': delivery_date,
        'guest_count': parse_int(row.get('Nº CONVIDADOS')),
        'location': clip((row.get('LOCAL') or None), 255),
        'city': clip((row.get('LOCALIDADE') or None), 120),
        'address': clip((row.get('MORADA') or None), 255),
        'address2': clip((row.get('MORADA2') or None), 255),
        'mass_time_raw': clip(normalize_time_text(row.get('MISSA ÀS')), 20),
        'store_time_raw': clip(normalize_time_text(row.get('Estar na Loja ás:')), 20),
        'bride_departure_time_raw': clip(normalize_time_text(row.get('sair noiva')), 20),
        'groom_departure_time_raw': clip(normalize_time_text(row.get('sair noivo')), 20),
        'notes': notes,
        'status': 'scheduled',
        'access_mode': 'both',
        'qr_token': os.urandom(24).hex(),
        'qr_enabled': 1,
        'is_locked': 0,
        'storage_path': None,
        'event_meta': json.dumps(meta, ensure_ascii=False),
        'legacy_payload': json.dumps({
            'merged_row': row,
            'sources': record['sources'],
        }, ensure_ascii=False),
        'legacy_source_file': record['preferred']['file'],
        'legacy_source_sheet': record['preferred']['sheet'],
        'legacy_source_row': record['preferred']['row_number'],
        'access_pin': generate_unique_pin(used_pins),
        'is_active_today': 0,
        'created_by': created_by,
        'price_per_photo': legacy_price or 5.0,
        'base_price': legacy_base_price or 0.0,
        'total_price': legacy_total_price,
        'bride_name': bride_name,
        'groom_name': groom_name,
        'bride_email': bride_email,
        'groom_email': groom_email,
        'bride_phone': bride_phone,
        'groom_phone': groom_phone,
        'team_user_ids': team_user_ids,
    }
    return payload


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()

    env = load_env(ENV_PATH)
    db_config = {
        'host': env.get('DB_HOST', '127.0.0.1'),
        'port': int(env.get('DB_PORT', '3306')),
        'user': env.get('DB_USERNAME', 'root'),
        'password': env.get('DB_PASSWORD', ''),
        'database': env.get('DB_DATABASE', 'studio59'),
    }

    records = load_sources()
    merged = merge_records(records)

    conn = mysql.connector.connect(**db_config)
    conn.autocommit = False
    cur = conn.cursor(dictionary=True)

    cur.execute('SELECT id FROM users ORDER BY id LIMIT 1')
    created_by = cur.fetchone()['id']

    cur.execute('SELECT access_pin FROM events WHERE access_pin IS NOT NULL')
    used_pins = {row['access_pin'] for row in cur.fetchall()}

    cur.execute('SELECT internal_code FROM events WHERE internal_code IS NOT NULL')
    existing_codes = {row['internal_code'] for row in cur.fetchall()}

    cur.execute('SELECT id, username, name FROM users')
    users = cur.fetchall()

    cur.execute('SELECT id, legacy_report_number, legacy_source_file, legacy_source_sheet, legacy_source_row FROM events')
    existing = cur.fetchall()
    existing_by_report = {}
    existing_by_source = {}
    for row in existing:
        if row['legacy_report_number']:
            existing_by_report[str(row['legacy_report_number'])] = row['id']
        key = (row['legacy_source_file'], row['legacy_source_sheet'], row['legacy_source_row'])
        if key[0] and key[1] and key[2]:
            existing_by_source[key] = row['id']

    payloads = [build_event_payload(record, used_pins, existing_codes, created_by, users) for record in merged]

    to_insert = 0
    to_update = 0
    to_assign = 0
    for payload in payloads:
        report = payload['legacy_report_number']
        source_key = (payload['legacy_source_file'], payload['legacy_source_sheet'], payload['legacy_source_row'])
        event_id = existing_by_report.get(report) if report else None
        if not event_id:
            event_id = existing_by_source.get(source_key)
        if event_id:
            to_update += 1
        else:
            to_insert += 1
        to_assign += len(payload['team_user_ids'])

    print(json.dumps({
        'source_rows': len(records),
        'merged_events': len(payloads),
        'to_insert': to_insert,
        'to_update': to_update,
        'team_links': to_assign,
        'mode': 'apply' if args.apply else 'dry-run',
    }, ensure_ascii=False, indent=2))

    if not args.apply:
        conn.close()
        return

    insert_cols = [
        'name', 'client_id', 'internal_code', 'legacy_report_number', 'legacy_client_number',
        'event_type', 'service_raw', 'event_date', 'event_time', 'delivery_date', 'guest_count',
        'location', 'city', 'address', 'address2', 'mass_time_raw', 'store_time_raw',
        'bride_departure_time_raw', 'groom_departure_time_raw', 'notes', 'status', 'access_mode',
        'qr_token', 'qr_enabled', 'is_locked', 'storage_path', 'event_meta', 'legacy_payload',
        'legacy_source_file', 'legacy_source_sheet', 'legacy_source_row', 'access_pin',
        'is_active_today', 'created_by', 'price_per_photo', 'base_price', 'total_price',
        'bride_name', 'groom_name', 'bride_email', 'groom_email', 'bride_phone', 'groom_phone',
        'created_at', 'updated_at',
    ]

    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')

    try:
        for payload in payloads:
            report = payload['legacy_report_number']
            source_key = (payload['legacy_source_file'], payload['legacy_source_sheet'], payload['legacy_source_row'])
            event_id = existing_by_report.get(report) if report else None
            if not event_id:
                event_id = existing_by_source.get(source_key)

            row_values = {key: payload.get(key) for key in insert_cols if key not in ['created_at', 'updated_at']}
            row_values['updated_at'] = now

            if event_id:
                update_cols = [key for key in insert_cols if key not in ['created_at']]
                set_sql = ', '.join(f'{col}=%s' for col in update_cols if col != 'created_at')
                values = [payload.get(col) if col not in ['updated_at'] else now for col in update_cols if col != 'created_at']
                values.append(event_id)
                cur.execute(f'UPDATE events SET {set_sql} WHERE id=%s', values)
            else:
                row_values['created_at'] = now
                insert_sql = 'INSERT INTO events (' + ','.join(insert_cols) + ') VALUES (' + ','.join(['%s'] * len(insert_cols)) + ')'
                values = [payload.get(col) if col not in ['created_at', 'updated_at'] else now for col in insert_cols]
                cur.execute(insert_sql, values)
                event_id = cur.lastrowid
                if report:
                    existing_by_report[report] = event_id
                existing_by_source[source_key] = event_id

            for user_id in payload['team_user_ids']:
                cur.execute(
                    '''
                    INSERT INTO event_staff (event_id, user_id, role, status, invited_at, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE
                        role = VALUES(role),
                        status = VALUES(status),
                        invited_at = VALUES(invited_at),
                        updated_at = VALUES(updated_at)
                    ''',
                    (event_id, user_id, 'photographer', 'assigned', now, now, now),
                )

        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == '__main__':
    main()
