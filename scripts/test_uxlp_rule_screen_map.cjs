'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const root = require('node:path').resolve(__dirname, '..');
const source = fs.readFileSync(root + '/docs/VSP_UXLP_44_RULE_SCREEN_MAP_01_01_2026-11-19.md', 'utf8');
const audit = fs.readFileSync(root + '/docs/UXLP_44_RULE_AUDIT.md', 'utf8');
const register = fs.readFileSync(root + '/docs/UXLP_44_SCREEN_REGISTER.md', 'utf8');
const pathPattern = new RegExp("\\x60(lib/[^\\x60]+\\.dart)\\x60", 'g');
const registered = new Set([...register.matchAll(pathPattern)].map(m => m[1]));
const auditRows = audit.split('\n').filter(line => /^\|\s*\d{1,2}\s*\|/.test(line)).map(line => {
  const parts = line.split('|').slice(1, -1).map(x => x.trim());
  return { id: Number(parts[0]), name: parts[1], status: parts[2] };
});
const rows = source.split('\n').filter(line => /^\|\s*\d\d\s*\|/.test(line)).map(line => {
  const parts = line.split('|').slice(1, -1).map(x => x.trim());
  return { id: Number(parts[0]), name: parts[1], player: parts[2], owner: parts[3], focus: parts[4], status: parts[5] };
});

test('all 44 UXLP rules map once to named existing player/owner source screens', () => {
  assert.equal(auditRows.length, 44);
  assert.equal(rows.length, 44);
  const used = new Set();
  for (let i = 0; i < 44; i++) {
    const row = rows[i];
    const expected = auditRows[i];
    assert.equal(row.id, i + 1, 'rule missing or out of order');
    assert.equal(row.id, expected.id);
    assert.equal(row.name, expected.name);
    assert.equal(row.status, expected.status, 'must not promote audit state');
    assert.ok(row.focus.length >= 8, 'inspection focus required');
    for (const field of ['player', 'owner']) {
      const cell = row[field];
      const tick = String.fromCharCode(96);
      assert.ok(cell.startsWith(tick) && cell.endsWith(tick), 'not a source link: ' + cell);
      const path = cell.slice(1, -1);
      assert.ok(/^lib\/.+\.dart$/.test(path));
      assert.ok(registered.has(path), 'not in screen register: ' + path);
      used.add(path);
    }
  }
  assert.ok(used.size >= 25, 'rule map must include distinct source areas');
});

test('unverified runtime rules and all five decision blockers remain explicitly open', () => {
  assert.equal(rows.filter(r => r.status === 'needs product decision').length, 5);
  assert.deepEqual(rows.filter(r => r.status === 'needs product decision').map(r => r.id), [25, 31, 38, 39, 41]);
  assert.equal(rows.filter(r => r.status === 'source reviewed—runtime pending').length, 39);
  assert.ok(source.includes('not exhaustive coverage'));
  assert.ok(source.includes('Zero'));
  assert.ok(!rows.some(r => /^pass$/i.test(r.status)));
});
