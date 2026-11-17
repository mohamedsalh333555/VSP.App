#!/usr/bin/env node
'use strict';

/** Source-only Arabic/English localization review. Flags hard-coded Text
 * literals for human review; never rewrites UI copy or user-supplied content.
 */
const fs = require('node:fs');
const path = require('node:path');
const { walkDartFiles } = require('./audit_vsp_design_tokens_motion.cjs');

function visibleKeys(arb) {
  return Object.keys(arb).filter(k => !k.startsWith('@'));
}
function placeholders(value) {
  if (typeof value !== 'string') return [];
  return [...new Set(
    [...value.matchAll(/\{\s*([A-Za-z][A-Za-z0-9_]*)\s*(?:,|\})/g)].map(m => m[1]),
  )].sort();
}

function review({
  arabicArb,
  englishArb,
  sourceRoot = 'lib',
}) {
  const ar = typeof arabicArb === 'string' ? JSON.parse(arabicArb) : arabicArb;
  const en = typeof englishArb === 'string' ? JSON.parse(englishArb) : englishArb;
  const arKeys = new Set(visibleKeys(ar));
  const enKeys = new Set(visibleKeys(en));
  const missingArabic = [...enKeys].filter(k => !arKeys.has(k)).sort();
  const missingEnglish = [...arKeys].filter(k => !enKeys.has(k)).sort();
  const mismatchedPlaceholders = [];
  const blankTranslations = [];
  for (const key of arKeys) {
    if (!enKeys.has(key)) continue;
    if (typeof ar[key] !== 'string' || !ar[key].trim() ||
        typeof en[key] !== 'string' || !en[key].trim()) {
      blankTranslations.push(key);
    }
    const a = placeholders(ar[key]);
    const b = placeholders(en[key]);
    if (JSON.stringify(a) !== JSON.stringify(b)) {
      mismatchedPlaceholders.push({ key, arabic: a, english: b });
    }
  }

  const dir = path.resolve(sourceRoot);
  if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) {
    throw Error('Flutter source directory missing');
  }
  const files = walkDartFiles(dir);
  let directTextCalls = 0;
  let latinLiteralText = 0;
  let arabicLiteralText = 0;
  const samples = [];
  for (const file of files) {
    const filename = path.relative(dir, file).replaceAll(path.sep, '/');
    for (const [index, line] of fs.readFileSync(file, 'utf8').split(/\r?\n/).entries()) {
      if (line.trimStart().startsWith('//')) continue;
      // Simple same-line Text('...') expressions only. Dynamic, conditional
      // and multiline constructors need an AST or manual review.
      const re = /\bText\s*\(\s*(['"])(.*?)\1/g;
      for (const match of line.matchAll(re)) {
        const value = match[2];
        if (!value.trim() || value.startsWith('$')) continue;
        directTextCalls++;
        if (/[A-Za-z]/.test(value)) latinLiteralText++;
        if (/[\u0600-\u06FF]/.test(value)) arabicLiteralText++;
        if (samples.length < 35) {
          samples.push({ file: filename, line: index + 1 });
        }
      }
    }
  }
  return {
    analyzedDartFiles: files.length,
    arabicTranslationKeys: arKeys.size,
    englishTranslationKeys: enKeys.size,
    missingArabic,
    missingEnglish,
    mismatchedPlaceholders,
    blankTranslations,
    directTextCalls,
    latinLiteralText,
    arabicLiteralText,
    sourceExamples: samples,
    limitations: [
      'Source candidate inventory only: direct Text literals are not automatically untranslated defects.',
      'An AST-based review is needed to cover multiline expressions, TextSpan, semantics labels and dynamically constructed copy.',
      'Placeholder checks are a simple ICU-name consistency screen, not a full ICU MessageFormat parser.',
      'User-generated descriptions and runtime server text are outside this localization source review.',
    ],
  };
}
function toMarkdown(r) {
  const lines = [
    '# VSP — Arabic/English translation key and hardcoded UI copy review',
    '',
    `Scanned ${r.analyzedDartFiles} non-generated Dart files and both app locale ARB files.`,
    '',
    '| Metric | Count |', '| --- | ---: |',
    `| Arabic translation keys | ${r.arabicTranslationKeys} |`,
    `| English translation keys | ${r.englishTranslationKeys} |`,
    `| Missing Arabic keys | ${r.missingArabic.length} |`,
    `| Missing English keys | ${r.missingEnglish.length} |`,
    `| Key placeholder mismatches | ${r.mismatchedPlaceholders.length} |`,
    `| Blank entries | ${r.blankTranslations.length} |`,
    `| Same-line literal Text(...) candidates | ${r.directTextCalls} |`,
    `| Candidates containing Latin letters | ${r.latinLiteralText} |`,
    `| Candidates containing Arabic characters | ${r.arabicLiteralText} |`,
  ];
  for (const [heading, data] of [
    ['Missing Arabic', r.missingArabic],
    ['Missing English', r.missingEnglish],
    ['Blank', r.blankTranslations],
  ]) {
    if (data.length) lines.push('', `## ${heading} keys`, '', ...data.map(x=>'- \`'+x+'\`'));
  }
  if (r.mismatchedPlaceholders.length) {
    lines.push('', '## Placeholder mismatch candidates', '');
    for (const item of r.mismatchedPlaceholders.slice(0, 40)) {
      lines.push(`- \`${item.key}\`: Arabic [${item.arabic.join(', ')}], English [${item.english.join(', ')}]`);
    }
  }
  lines.push('', '## Representative raw UI text positions', '');
  for (const item of r.sourceExamples) lines.push(`- \`${item.file}:${item.line}\``);
  lines.push('', '## Limitations', '', ...r.limitations.map(x => '- ' + x), '');
  return lines.join('\n');
}

if (require.main === module) {
  const report = review({
    arabicArb: fs.readFileSync('lib/l10n/app_ar.arb', 'utf8'),
    englishArb: fs.readFileSync('lib/l10n/app_en.arb', 'utf8'),
  });
  process.stdout.write(
    process.argv.includes('--json') ?
      JSON.stringify(report, null, 2) + '\n' : toMarkdown(report) + '\n',
  );
}
module.exports = { visibleKeys, placeholders, review, toMarkdown };
