#!/usr/bin/env python3
"""Build one coherent SACO analysis from a complete Gmail snapshot."""
import argparse
import base64
from collections import Counter
from datetime import datetime, timezone
from email.utils import parseaddr
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
TZ = ZoneInfo('Europe/Berlin')
STATUSES = ['Working', 'Working DUMMY', 'Needs work']
CUSTOMER = re.compile(r'^(Kein Kunde existiert|Bei der Kunden-E-Mail|The customer email|The customer account|Customer does not exist|Gelöschter Kundenaccount|Kunde ist keiner Firma|Gültige Firmen|Mehrere valide (Tarife|Firmen)|Firmen vom Kunden|absenderEmail)', re.I)
STOP = r'Entwicklerinformationen|Developer information|Für die weitere Kundenkommunikation|For further customer communication'


class BodyText(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.hidden = 0

    def handle_starttag(self, tag, attrs):
        if tag in ('style', 'script'):
            self.hidden += 1
        if tag in ('p', 'div', 'tr', 'br', 'li'):
            self.parts.append('\n')
        if tag in ('td', 'th'):
            self.parts.append(' ')
        if tag == 'li':
            self.parts.append('• ')

    def handle_endtag(self, tag):
        if tag in ('style', 'script'):
            self.hidden = max(0, self.hidden - 1)
        if tag in ('p', 'div', 'tr', 'li'):
            self.parts.append('\n')

    def handle_data(self, text):
        if not self.hidden:
            self.parts.append(text)


def html_text(value):
    parser = BodyText()
    parser.feed(value)
    return ''.join(parser.parts)


def outer_parts(part):
    disposition = next((h.get('value', '') for h in part.get('headers', []) if h['name'].lower() == 'content-disposition'), '')
    if part.get('filename') or part.get('mime_type', '').lower() == 'message/rfc822' or disposition.lower().startswith('attachment'):
        return []
    return [part] + [p for child in part.get('parts') or [] for p in outer_parts(child)]


def part_text(part):
    body = part.get('body') or {}
    if body.get('content') is not None:
        return body['content']
    encoded = body.get('base64_url_content') or body.get('data')
    if encoded:
        charset = 'utf-8'
        ctype = next((h['value'] for h in part.get('headers', []) if h['name'].lower() == 'content-type'), '')
        match = re.search(r'charset=["\']?([^;"\'\s]+)', ctype, re.I)
        if match:
            charset = match.group(1)
        return base64.urlsafe_b64decode(encoded + '=' * (-len(encoded) % 4)).decode(charset, errors='replace')
    if body.get('attachment_id'):
        raise ValueError('Outer text body requires a separate supported read; body content is missing')
    return ''


def normalize(row):
    row = row.get('structuredContent', row)
    if row.get('isError'):
        raise ValueError('A failed Gmail read was supplied')
    headers = {h['name'].lower(): h['value'] for h in (row.get('payload') or {}).get('headers', [])}
    subject = row.get('subject', headers.get('subject', ''))
    sender = row.get('from', row.get('from_', headers.get('from')))
    timestamp = row.get('internal_date', row.get('internalDate'))
    if not row.get('id') or subject is None or not sender or timestamp is None:
        raise ValueError('Every message needs id, subject, from, internal_date')
    if 'payload' in row:
        parts = outer_parts(row['payload'])
        plain = '\n'.join(part_text(p) for p in parts if p.get('mime_type') == 'text/plain')
        html = '\n'.join(part_text(p) for p in parts if p.get('mime_type') == 'text/html')
    else:
        plain = row.get('body_text', '')
        html = row.get('body_html', '')
    if not (plain.strip() or html.strip()):
        raise ValueError(f"Message {row['id']} has no complete outer body")
    return {'id': row['id'], 'subject': subject, 'sender': parseaddr(sender)[1].lower(),
            'timestamp': int(timestamp), 'text': plain if plain.strip() else html_text(html),
            'html': html}


def month_range(start, end):
    year, month = map(int, start.split('-'))
    out = []
    while f'{year:04d}-{month:02d}' <= end:
        out.append(f'{year:04d}-{month:02d}')
        year, month = (year + 1, 1) if month == 12 else (year, month + 1)
    return out


def load_rows(path):
    text = path.read_text()
    try:
        value = json.loads(text)
        if isinstance(value, list):
            return value
        if isinstance(value, dict) and 'messages' in value:
            return value['messages']
        if isinstance(value, dict) and 'id' in value:
            return [value]
    except json.JSONDecodeError:
        pass
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def analyze(rows, manifest, rules):
    as_of = datetime.fromisoformat(manifest['as_of'].replace('Z', '+00:00'))
    if as_of.tzinfo is None:
        raise ValueError('as_of must include a timezone')
    if manifest.get('pagination_complete') is not True:
        raise ValueError('Pagination is not confirmed complete')
    expected = set(manifest['expected_message_ids'])
    messages = {}
    duplicates = 0
    for raw in rows:
        row = normalize(raw)
        if row['id'] in messages:
            if messages[row['id']] != row:
                raise ValueError(f"Conflicting duplicate {row['id']}")
            duplicates += 1
        messages[row['id']] = row
    if set(messages) != expected:
        raise ValueError(f'ID mismatch: missing={len(expected-set(messages))}; extra={len(set(messages)-expected)}')
    since = manifest.get('since')
    since_time = datetime.fromisoformat(since.replace('Z', '+00:00')) if since else None
    if since_time and since_time.tzinfo is None:
        raise ValueError('since must include a timezone')
    eligible = []
    for row in messages.values():
        date = datetime.fromtimestamp(row['timestamp'] / 1000, timezone.utc)
        if row['sender'] != 'quote@sacoshipping.com' or date >= as_of or (since_time and date < since_time):
            raise ValueError(f"Message {row['id']} is outside the declared sender/time scope")
        eligible.append((row, date.astimezone(TZ)))
    eligible.sort(key=lambda pair: (pair[0]['timestamp'], pair[0]['id']))
    if not eligible:
        raise ValueError('No matching emails: report an empty source rather than manufacturing a report')
    counts = Counter()
    group_months = {r['id']: Counter() for r in rules}
    groups_by_id = {r['id']: r for r in rules}
    review = []
    unknown = excluded = with_errors = 0
    for row, date in eligible:
        month = date.strftime('%Y-%m')
        clean = re.split(STOP, row['text'], flags=re.I)[0]
        dummy = bool(re.search(r'\bTariff?\s*:\s*VORGABE\b', clean, re.I))
        # HTML is a second complete representation when plain text omits a field.
        if not dummy and row['html']:
            dummy = bool(re.search(r'\bTariff?\s*:\s*VORGABE\b', re.split(STOP, html_text(row['html']), flags=re.I)[0], re.I))
        needs = bool(re.search(r'\[Needs work\]', row['subject'], re.I))
        status = 'Needs work' if needs else 'Working DUMMY' if dummy else 'Working'
        counts[(month, status)] += 1
        if not needs:
            continue
        bullets = [re.sub(r'\s+', ' ', re.split(r'\n(?:Angebot|Offer|Sendungsübersicht|Shipment overview|Status|⚠|✘)', b)[0].strip()) for b in clean.split('•')[1:]]
        found = {r['id'] for r in rules if r.get('pattern') and any(re.search(r['pattern'], b, re.I) for b in bullets)}
        special = {
            'Einige Angaben konnten nicht zuverlässig aus der Originalmail übernommen werden': 'error-07',
            'Verarbeitung ist wegen eines technischen Fehlers abgebrochen': 'processing-abort',
            'Zielort nicht eindeutig zugeordnet': 'error-11',
        }
        for phrase, key in special.items():
            if phrase in clean:
                if key not in groups_by_id:
                    raise ValueError(f'Missing required rule {key}')
                found.add(key)
        if found:
            with_errors += 1
            for key in found:
                group_months[key][month] += 1
        elif any(CUSTOMER.search(b) for b in bullets):
            excluded += 1
        else:
            unknown += 1
            review.append({'id': row['id'], 'reason': 'Needs work without a recognized error or exclusion', 'excerpt': clean[:1600]})
        # New API errors may coexist with already recognized categories.
        for block in re.findall(r'OSCA[^\n]{0,180}(?:Fehler gemeldet|reported[^\n]*errors)[^\n]*:([\s\S]*?)(?=\n(?:Angebot|Offer|Sendungsübersicht|Shipment overview|Entwicklerinformationen)|$)', clean, re.I):
            for bullet in block.split('•')[1:]:
                b = re.sub(r'\s+', ' ', bullet.strip())
                if b and not CUSTOMER.search(b) and not any(r.get('pattern') and re.search(r['pattern'], b, re.I) for r in rules):
                    review.append({'id': row['id'], 'reason': 'Unrecognized OSCA error text', 'excerpt': b[:1200]})
    start = (since_time.astimezone(TZ) if since_time else eligible[0][1])
    end = as_of.astimezone(TZ)
    months = month_range(start.strftime('%Y-%m'), end.strftime('%Y-%m'))
    monthly = [{'month': m, 'counts': [counts[(m, s)] for s in STATUSES]} for m in months]
    groups = [dict(id=r['id'], name=r['name'], color=r.get('color', 1), total=sum(group_months[r['id']].values()),
                   counts=[group_months[r['id']][m] for m in months]) for r in rules if sum(group_months[r['id']].values())]
    groups.sort(key=lambda g: (-g['total'], g['name']))
    totals = [sum(m['counts'][i] for m in monthly) for i in range(3)]
    result = {'schemaVersion': 1, 'title': 'SACO Quote Report', 'asOf': as_of.isoformat(), 'periodStart': start.isoformat(),
              'periodEnd': end.isoformat(), 'timezone': 'Europe/Berlin', 'query': manifest['query'],
              'statuses': STATUSES, 'totals': totals, 'totalEmails': len(eligible), 'monthly': monthly,
              'groups': groups, 'assignments': sum(g['total'] for g in groups),
              'emailsWithOtherErrors': with_errors, 'excludedCustomerOnly': excluded,
              'uncategorizedNeedsWork': unknown, 'duplicateIdsRemoved': duplicates,
              'review': review, 'sourceComplete': True}
    validate(result)
    return result


def validate(data):
    if data.get('schemaVersion') != 1 or data.get('sourceComplete') is not True:
        raise ValueError('A complete, schemaVersion 1 analysis is required')
    if data['statuses'] != STATUSES:
        raise ValueError('Status definitions differ from the report contract')
    n = len(data['monthly'])
    if sum(data['totals']) != data['totalEmails']:
        raise ValueError('Status total mismatch')
    for i in range(3):
        if sum(m['counts'][i] for m in data['monthly']) != data['totals'][i]:
            raise ValueError('Monthly status mismatch')
    if data['emailsWithOtherErrors'] + data['excludedCustomerOnly'] + data['uncategorizedNeedsWork'] != data['totals'][2]:
        raise ValueError('Needs-work coverage mismatch')
    for g in data['groups']:
        if len(g['counts']) != n or sum(g['counts']) != g['total']:
            raise ValueError('Error group totals mismatch')
        if any(v < 0 or not isinstance(v, int) or v > data['monthly'][i]['counts'][2] for i,v in enumerate(g['counts'])):
            raise ValueError('Invalid per-email error count')
    if sum(g['total'] for g in data['groups']) != data['assignments']:
        raise ValueError('Assignment total mismatch')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--rules', type=Path, default=ROOT / 'references/error-groups.json')
    args = parser.parse_args()
    result = analyze(load_rows(args.input), json.loads(args.manifest.read_text()), json.loads(args.rules.read_text()))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'emails': result['totalEmails'], 'assignments': result['assignments'], 'reviewItems': len(result['review']), 'output': str(args.output)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
