'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { auditSource, toMarkdown } = require('./audit_vsp_design_tokens_motion.cjs');

function withTree(callback) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vsp-design-audit-'));
  try {
    fs.mkdirSync(path.join(dir, 'features'), { recursive: true });
    fs.mkdirSync(path.join(dir, 'generated'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'features', 'colors.dart'), `
final x = VSPColors.accent;
final x2 = VSPDSColors.zinc950;
final x3 = VSPDSSemanticColors.accent;
final y = Color(0xFF112233);
final z = Colors.green;
final a = VSPSpacing.sm;
final a2 = VSPDSSpacing.sm;
final b = EdgeInsets.all(12);
final radius = VSPRadius.card;
final radius2 = VSPDSRadius.card;
final label = TextStyle(fontSize: 14, fontFamily: 'Fixture');
`);
    fs.writeFileSync(path.join(dir, 'features', 'motion.dart'), `
final p = VSPDSMotion.selection;
final animation = AnimatedContainer(duration: Duration(milliseconds: 350));
final reduced = MediaQuery.disableAnimationsOf(context);
`);
    fs.writeFileSync(path.join(dir, 'features', 'some.g.dart'),
      'final ignored = Colors.red;');
    fs.writeFileSync(path.join(dir, 'generated', 'automated.dart'),
      'final ignored = Duration(seconds: 1);');
    return callback(dir);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('inventory identifies tokens, literals, type and motion across handwritten files', () => {
  withTree((dir) => {
    const inventory = auditSource(dir);
    assert.equal(inventory.totalDartFiles, 2);
    for (const category of [
      'colorToken', 'directMaterialColor', 'literalColor', 'spacingToken',
      'radiusToken', 'textFontSize', 'textFontFamily', 'edgeInsets',
      'motionToken', 'animatedWidget', 'explicitMotionDuration',
      'reduceMotionGate',
    ]) {
      assert.equal(inventory.groups[category].matches,
        category === 'colorToken' ? 3 :
        category === 'spacingToken' || category === 'radiusToken' ? 2 : 1, category);
      assert.equal(inventory.groups[category].files, 1, category);
      assert.equal(inventory.groups[category].samples[0].line > 0, true);
    }
    assert.equal(inventory.groups.colorToken.matches, 3);
    assert.equal(inventory.groups.spacingToken.matches, 2);
    assert.equal(inventory.groups.radiusToken.matches, 2);
    const summary = toMarkdown(inventory);
    assert.match(summary, /Inspected 2 non-generated Dart files/);
    assert.match(summary, /\| `motionToken` \| 1 \| 1 \|/);
    assert.match(summary, /Limitations/);
    assert.doesNotMatch(summary, /some.g.dart/);
  });
});

test('empty source folder returns zero counts, deterministic result', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vsp-inventory-empty-'));
  try {
    const a = auditSource(dir);
    const b = auditSource(dir);
    assert.deepEqual(a, b);
    assert.equal(a.totalDartFiles, 0);
    assert.equal(a.groups.colorToken.matches, 0);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('unknown directory must not silently produce an empty audit', () => {
  assert.throws(() => auditSource('/path/that/does/not/exist'),
    /Source directory does not exist/);
});
