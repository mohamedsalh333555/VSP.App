#!/usr/bin/env python3
"""Build a read-only fingerprint plan for an additive admin RPC precondition.

Input contains private schema source; output deliberately contains only function
signatures, SHA-256 fingerprints and Unicode character offsets, never SQL bodies.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

INJECTION = '\n  PERFORM public.require_active_admin_actor();\n'


def begin_offset(source):
    """Locate the outer BEGIN, excluding identifiers, strings and nested comments."""
    i = 0
    while i < len(source):
        if source.startswith('--', i):
            end = source.find('\n', i + 2)
            i = len(source) if end < 0 else end + 1
        elif source.startswith('/*', i):
            depth = 1
            i += 2
            while i < len(source) and depth:
                if source.startswith('/*', i):
                    depth += 1
                    i += 2
                elif source.startswith('*/', i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            if depth:
                raise ValueError('Unterminated SQL comment')
        elif source[i] in ("'", '"'):
            quote = source[i]
            escaped = (quote == "'" and i > 0 and source[i - 1] in 'eE'
                       and (i < 2 or not (source[i - 2].isalnum() or source[i - 2] == '_')))
            i += 1
            closed = False
            while i < len(source):
                if escaped and source[i] == '\\':
                    i += 2
                elif source[i] == quote:
                    if i + 1 < len(source) and source[i + 1] == quote:
                        i += 2
                    else:
                        i += 1
                        closed = True
                        break
                else:
                    i += 1
            if not closed:
                raise ValueError('Unterminated quoted SQL value')
        elif source[i] == '$' and (match := re.match(r'\$(?:[A-Za-z_][A-Za-z_0-9]*)?\$', source[i:])):
            tag = match.group()
            end = source.find(tag, i + len(tag))
            if end < 0:
                raise ValueError('Unterminated dollar-quoted SQL value')
            i = end + len(tag)
        elif source[i].isalpha() or source[i] == '_':
            end = i + 1
            while end < len(source) and (source[end].isalnum() or source[end] in '_$'):
                end += 1
            if source[i:end].lower() == 'begin':
                return end
            i = end
        else:
            i += 1
    raise ValueError('No outer PL/pgSQL BEGIN found')


def sha256(source):
    return hashlib.sha256(source.encode('utf-8')).hexdigest()


def build_plan(sources):
    signatures = {}
    entries = {}
    for origin, functions in sources.items():
        signatures[origin] = set()
        for function in functions:
            signature = function['signature']
            if not signature.startswith('public.'):
                signature = 'public.' + signature
            if not re.fullmatch(r'public\.[a-z_][a-z_0-9]*\([a-z_0-9., \[\]]*\)', signature):
                raise ValueError('Unsupported function signature')
            signatures[origin].add(signature)
            original = function['prosrc']
            if function.get('source_md5') and hashlib.md5(original.encode()).hexdigest() != function['source_md5']:
                raise ValueError('Input source fingerprint does not match server metadata')
            variants = [(origin, original)]
            if '\r\n' in original:
                variants.append((origin + '_lf', original.replace('\r\n', '\n')))
            for variant_origin, source in variants:
                offset = begin_offset(source)
                guarded = source[:offset] + INJECTION + source[offset:]
                assert guarded[:offset] + guarded[offset + len(INJECTION):] == source
                key = (signature, sha256(source))
                if key not in entries:
                    entries[key] = {'signature': signature, 'before_sha256': key[1],
                                    'after_sha256': sha256(guarded), 'begin_offset': offset,
                                    'origins': []}
                entries[key]['origins'].append(variant_origin)
    if not signatures or any(value != next(iter(signatures.values())) for value in signatures.values()):
        raise ValueError('Project function inventories differ; review missing/extra routines first')
    return {'schema_version': 1, 'observed_at': '2026-11-11',
            'function_count': len(next(iter(signatures.values()))),
            'injection': INJECTION, 'variants': sorted(entries.values(), key=lambda row: (row['signature'], row['before_sha256'])),
            'limits': 'Known source fingerprints only. Missing functions are not created; unknown existing bodies must fail closed. No SQL bodies or credentials are exported.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_json', type=Path)
    parser.add_argument('output_json', type=Path)
    args = parser.parse_args()
    plan = build_plan(json.loads(args.source_json.read_text()))
    args.output_json.write_text(json.dumps(plan, indent=2) + '\n')
    print(json.dumps({'functions': plan['function_count'], 'known_source_variants': len(plan['variants'])}))


if __name__ == '__main__':
    main()
