#!/usr/bin/env node
'use strict';

/** Read-only WCAG 2.2 relative-contrast audit for canonical VSP semantic
 * colors. Tests token pairs, not actual rendered components or text sizes.
 */
const fs = require('node:fs');
const path = require('node:path');

function classConstants(source, className) {
  const marker = `abstract final class ${className} {`;
  const start = source.indexOf(marker);
  if (start < 0) throw Error('Palette class unavailable: ' + className);
  const end = source.indexOf('\n}', start);
  if (end < 0) throw Error('Incomplete palette class: ' + className);
  const body = source.slice(start + marker.length, end);
  const values = {};
  for (const m of body.matchAll(
    /static const (?:Color\s+)?([a-zA-Z_]\w*)\s*=\s*([^;]+);/g,
  )) {
    values[m[1]] = m[2].split('//')[0].trim();
  }
  return values;
}

function palette(source) {
  const classes = {
    VSPDSColors: classConstants(source, 'VSPDSColors'),
    VSPDSSemanticColors: classConstants(source, 'VSPDSSemanticColors'),
  };
  function resolve(reference, currentClass = 'VSPDSSemanticColors', seen = new Set()) {
    const full = reference.includes('.') ? reference : currentClass + '.' + reference;
    if (seen.has(full)) throw Error('Circular color alias: ' + full);
    const parts = full.split('.');
    if (parts.length !== 2 || !classes[parts[0]] || !classes[parts[0]][parts[1]]) {
      throw Error('Unresolved color token: ' + full);
    }
    const definition = classes[parts[0]][parts[1]].trim();
    const hex = /^Color\s*\(\s*0x([a-fA-F0-9]{8})\s*\)$/.exec(definition);
    if (hex) {
      const value = hex[1];
      return {
        a: parseInt(value.slice(0, 2), 16) / 255,
        r: parseInt(value.slice(2, 4), 16),
        g: parseInt(value.slice(4, 6), 16),
        b: parseInt(value.slice(6, 8), 16),
      };
    }
    const next = new Set(seen);
    next.add(full);
    return resolve(definition, parts[0], next);
  }
  return { resolve };
}

function over(foreground, background) {
  const a = foreground.a;
  return {
    r: foreground.r * a + background.r * (1 - a),
    g: foreground.g * a + background.g * (1 - a),
    b: foreground.b * a + background.b * (1 - a),
    a: 1,
  };
}
function luminance(color) {
  const linear = channel => {
    const s = channel / 255;
    return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  };
  return linear(color.r) * 0.2126 +
    linear(color.g) * 0.7152 +
    linear(color.b) * 0.0722;
}
function contrastRatio(foreground, background) {
  const base = background.a === 1 ? background :
    over(background, { r: 0, g: 0, b: 0, a: 1 });
  const top = foreground.a === 1 ? foreground : over(foreground, base);
  const a = luminance(top), b = luminance(base);
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

const CHECKS = [
  ['textPrimary', 'background', 4.5, 'normal text'],
  ['textPrimary', 'surface', 4.5, 'normal text'],
  ['textSecondary', 'background', 4.5, 'normal text'],
  ['textSecondary', 'surface', 4.5, 'normal text'],
  ['textMuted', 'surface', 4.5, 'potential normal text'],
  ['accent', 'background', 3.0, 'non-text highlight'],
  ['warning', 'surface', 4.5, 'normal warning text'],
  ['error', 'surface', 4.5, 'normal error text'],
  ['info', 'surface', 4.5, 'normal information text'],
  ['success', 'surface', 3.0, 'non-text status icon'],
  ['focusRing', 'surface', 3.0, 'non-text focus indicator'],
];

function audit(source) {
  const tokens = palette(source);
  const results = CHECKS.map(([fg, bg, minimum, purpose]) => {
    const ratio = contrastRatio(tokens.resolve(fg), tokens.resolve(bg));
    return {
      foreground: 'VSPDSSemanticColors.' + fg,
      background: 'VSPDSSemanticColors.' + bg,
      ratio: Number(ratio.toFixed(2)),
      minimum, purpose, meetsThreshold: ratio + 1e-9 >= minimum,
    };
  });
  return {
    checks: results,
    passed: results.filter(x => x.meetsThreshold).length,
    flagged: results.filter(x => !x.meetsThreshold).length,
    notes: [
      'This checks selected semantic token pairs; component opacity, image overlays, text scale and runtime themes require widget/device inspection.',
      'A flagged pair is a prioritized review point, not proof it is used as normal-sized text.',
      'Passing pairs do not establish accessibility compliance across all screens.',
    ],
  };
}

function markdown(result) {
  return [
    '# VSP — Canonical semantic contrast source audit',
    '',
    `WCAG 2.2-relative contrast review: ${result.passed} sampled pairs meet the selected threshold; ${result.flagged} are review flags.`,
    '',
    '| Foreground | Background | Ratio | Minimum | Review purpose | Status |',
    '| --- | --- | ---: | ---: | --- | --- |',
    ...result.checks.map(x =>
      `| \`${x.foreground}\` | \`${x.background}\` | ${x.ratio}:1 | ${x.minimum}:1 | ${x.purpose} | ${x.meetsThreshold ? 'pass' : 'review'} |`,
    ),
    '',
    '## Limits',
    '',
    ...result.notes.map(x => '- ' + x),
    '',
  ].join('\n');
}

if (require.main === module) {
  const idx = process.argv.indexOf('--file');
  const filename = idx < 0 ?
    'lib/core/ui/tokens/vsp_design_tokens.dart' : process.argv[idx + 1];
  const result = audit(fs.readFileSync(path.resolve(filename), 'utf8'));
  process.stdout.write(
    process.argv.includes('--json') ?
      JSON.stringify(result, null, 2) + '\n' : markdown(result) + '\n',
  );
}
module.exports = { classConstants, palette, over, luminance, contrastRatio, audit, markdown };
