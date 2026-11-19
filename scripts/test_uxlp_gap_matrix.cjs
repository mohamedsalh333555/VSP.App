const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const audit = fs.readFileSync(
  path.join(__dirname, '..', 'docs', 'UXLP_44_RULE_AUDIT.md'), 'utf8');
const rows = audit.split(/\r?\n/)
  .filter((line) => /^\|\s*\d{1,2}\s*\|/.test(line))
  .map((line) => {
    const parts = line.split('|').slice(1, -1).map((value) => value.trim());
    return {id: Number(parts[0]), rule: parts[1],
      status: parts[2], evidence: parts.slice(3).join('|').trim()};
  });

test('all 44 UX rules have distinct IDs, evidence and explicit unresolved states', () => {
  assert.equal(rows.length, 44);
  assert.deepEqual(rows.map((r) => r.id), Array.from({length: 44},
    (_, index) => index + 1));
  for (const row of rows) {
    assert.ok(row.rule.length > 0, 'missing rule name ' + row.id);
    assert.ok(row.evidence.length > 20, 'missing evidence ' + row.id);
    assert.ok(['source reviewed—runtime pending', 'needs product decision']
      .includes(row.status), 'unexpectedly accepted without runtime ' + row.id);
  }
});

test('five unresolved product/server decisions stay identified and not misreported as passes', () => {
  const decisions = rows.filter((row) => row.status === 'needs product decision');
  assert.deepEqual(decisions.map((row) => row.id), [25, 31, 38, 39, 41]);
  assert.equal(rows.filter((row) =>
    row.status === 'source reviewed—runtime pending').length, 39);
  assert.match(decisions[0].evidence, /submit_team_league_match_result/);
  assert.match(decisions[3].evidence, /get_team_active_league/);
  assert.match(decisions[4].evidence, /refund|retention/i);
});
