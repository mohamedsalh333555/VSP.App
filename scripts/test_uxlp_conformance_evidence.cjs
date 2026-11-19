'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');
const evidence = read('docs/VSP_UXLP_44_CONFORMANCE_EVIDENCE_01_05_2026-11-20.md');
const map = read('docs/VSP_UXLP_44_RULE_SCREEN_MAP_01_01_2026-11-19.md');
const audit = read('docs/UXLP_44_RULE_AUDIT.md');
const criteria = read('docs/UXLP_44_INDEPENDENT_ACCEPTANCE_CRITERIA_2026-11-13.md');
const rows = (s) => s.split(/\r?\n/).filter(line =>
  /^\|\s*\d{1,2}\s*\|/.test(line)).map(line =>
  line.split('|').slice(1, -1).map(cell => cell.trim()));
test('01.05: every evidence record is traceable to a rule, two screens and an acceptance criterion', () => {
  const docs = [evidence, map, audit, criteria].map(rows);
  for (const items of docs) assert.equal(items.length, 44);
  const [records, sources, sourceAudit, testCriteria] = docs;
  for (let i = 0; i < 44; i++) {
    const [id, name, player, owner, summary, outstanding] = records[i];
    assert.equal(Number(id), i + 1);
    assert.equal(name, sources[i][1]);
    assert.equal(name, sourceAudit[i][1]);
    assert.equal(name, testCriteria[i][1]);
    assert.equal(player, sources[i][2]);
    assert.equal(owner, sources[i][3]);
    assert.ok(player.startsWith('`lib/') && owner.startsWith('`lib/'));
    assert.ok(summary.length >= 24, 'Missing specific audit evidence: ' + id);
    assert.match(outstanding, /pending/i);
    assert.ok(!/\bpass(ed)?\b/i.test(outstanding), 'unearned pass: ' + id);
    const status = sources[i][5];
    assert.ok(['source reviewed—runtime pending', 'needs product decision'].includes(status));
    assert.ok(sourceAudit[i].slice(3).join('|').length >= 24);
  }
});
test('01.05: decision blockers and runtime gates must not be erased', () => {
  const unresolved = rows(map).filter(r => r[5] === 'needs product decision')
    .map(r => Number(r[0]));
  assert.deepEqual(unresolved, [25, 31, 38, 39, 41]);
  assert.match(evidence, /0\/44 have global runtime sign-off/);
  assert.match(evidence, /01\.04/);
  assert.match(evidence, /01\.06/);
  assert.match(evidence, /screen × state × locale × viewport × role/);
});
