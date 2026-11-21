'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { palette, contrastRatio, audit, markdown } =
  require('./audit_vsp_semantic_contrast.cjs');

test('WCAG contrast ratio is 21 for opaque black on white, 1 for identical', () => {
  const black = { r: 0, g: 0, b: 0, a: 1 };
  const white = { r: 255, g: 255, b: 255, a: 1 };
  assert.ok(Math.abs(contrastRatio(black, white) - 21) < 1e-9);
  assert.ok(Math.abs(contrastRatio(white, black) - 21) < 1e-9);
  assert.ok(Math.abs(contrastRatio(white, white) - 1) < 1e-9);
});

test('alpha foreground is composited against the selected background', () => {
  const black = { r: 0, g: 0, b: 0, a: 1 };
  const translucentWhite = { r: 255, g: 255, b: 255, a: 0.5 };
  const ratio = contrastRatio(translucentWhite, black);
  assert.ok(ratio > 4.5 && ratio < 6, 'alpha must not be treated as solid white');
});

test('resolves canonical semantic colors through legacy-safe VSP token aliases', () => {
  const src = `
abstract final class VSPDSColors {
  static const Color black = Color(0xFF000000);
  static const Color zinc400 = Color(0xFFA1A1AA);
  static const Color voltGreen = zinc400;
}
abstract final class VSPDSSemanticColors {
  static const Color background = VSPDSColors.black;
  static const Color accent = VSPDSColors.voltGreen;
}
`;
  const colors = palette(src);
  assert.deepEqual(colors.resolve('background'),
    { a: 1, r: 0, g: 0, b: 0 });
  assert.deepEqual(colors.resolve('accent'),
    { a: 1, r: 161, g: 161, b: 170 });
  assert.throws(() => colors.resolve('missingToken'), /Unresolved color token/);
});

test('actual VSP semantic design tokens produce stable reviewable threshold results', () => {
  const actual = fs.readFileSync(
    'lib/core/ui/tokens/vsp_design_tokens.dart', 'utf8',
  );
  const result = audit(actual);
  assert.equal(result.checks.length, 12);
  assert.equal(result.passed + result.flagged, 12);
  assert.equal(result.flagged, 0,
    'canonical text and status token pairs must clear sampled thresholds');
  assert.ok(result.passed > 0);
  const primary = result.checks.find(x =>
    x.foreground.endsWith('.textPrimary') && x.background.endsWith('.background'));
  assert.equal(primary.meetsThreshold, true);
  const muted = result.checks.find(x =>
    x.foreground.endsWith('.textMuted'));
  assert.ok(muted, 'muted text review point must remain visible');
  assert.equal(muted.meetsThreshold, true);

  const legacy = actual.replace(
    'static const Color textMuted = VSPDSColors.zinc400;',
    'static const Color textMuted = VSPDSColors.gray500;',
  );
  assert.notEqual(legacy, actual, 'expected semantic token source');
  const historical = audit(legacy);
  assert.equal(historical.checks.find(x =>
    x.foreground.endsWith('.textMuted') &&
    x.background.endsWith('.surface')).meetsThreshold, false,
    'the old low-contrast token must fail the same audit');
  const output = markdown(result);
  assert.match(output, /Canonical semantic contrast source audit/);
  assert.match(output, /review purpose/i);
});
