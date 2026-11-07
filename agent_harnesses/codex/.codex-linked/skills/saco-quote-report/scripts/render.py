#!/usr/bin/env python3
"""Render the complete SACO report as one offline HTML document."""
import argparse
import json
from pathlib import Path
from analyze import ROOT, validate


def render(data, output):
    validate(data)
    # Review excerpts and message IDs belong in the private analysis, not HTML.
    public = {key: value for key, value in data.items() if key != 'review'}
    public['review'] = [{'id': row['id']} for row in data.get('review', [])]
    encoded = json.dumps(public, ensure_ascii=False, separators=(',', ':')).replace('<', '\\u003c').replace('\u2028', '\\u2028').replace('\u2029', '\\u2029')
    template = (ROOT / 'assets/report.html').read_text()
    if template.count('REPORT_DATA_JSON') != 1:
        raise ValueError('Report template must have exactly one data marker')
    result = template.replace('REPORT_DATA_JSON', encoded)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(result)
    return len(result.encode())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    data = json.loads(args.input.read_text())
    size = render(data, args.output)
    print(json.dumps({'output': str(args.output), 'bytes': size, 'emails': data['totalEmails'], 'reviewItems': len(data.get('review', []))}))


if __name__ == '__main__':
    main()
