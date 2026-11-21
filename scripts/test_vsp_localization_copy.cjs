'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { placeholders, review, toMarkdown } =
  require('./audit_vsp_localization_copy.cjs');

test('ICU placeholder name extraction is deterministic and ignores duplicates', () => {
  assert.deepEqual(placeholders('Hi {name}, hello {name}! {count, plural, one{one}}'),
    ['count', 'name']);
  assert.deepEqual(placeholders('Static copy'), []);
});

test('translation audit catches missing, blank and mismatched entries with source positions', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vsp-locale-review-'));
  try {
    fs.mkdirSync(path.join(dir, 'feature'));
    fs.writeFileSync(path.join(dir, 'feature', 'screen.dart'), `
Widget build() {
  return Column(children: [
    Text('Hello'),
    Text('مرحبا'),
    Text(AppLocalizations.of(context)!.login),
  ]);
}
`);
    fs.writeFileSync(path.join(dir, 'feature', 'generated.g.dart'),
      "Text('Unreviewed generated copy');");
    const result = review({
      arabicArb: {
        '@@locale': 'ar',
        hello: 'أهلا {user}',
        blank: '  ',
        arOnly: 'عربي فقط',
        shared: 'مشترك',
      },
      englishArb: {
        '@@locale': 'en',
        hello: 'Hi {name}',
        blank: 'Blank',
        enOnly: 'English only',
        shared: 'Shared',
      },
      sourceRoot: dir,
    });
    assert.equal(result.analyzedDartFiles, 1);
    assert.deepEqual(result.missingArabic, ['enOnly']);
    assert.deepEqual(result.missingEnglish, ['arOnly']);
    assert.deepEqual(result.blankTranslations, ['blank']);
    assert.equal(result.mismatchedPlaceholders.length, 1);
    assert.equal(result.mismatchedPlaceholders[0].key, 'hello');
    assert.equal(result.directTextCalls, 2);
    assert.equal(result.latinLiteralText, 1);
    assert.equal(result.arabicLiteralText, 1);
    assert.match(toMarkdown(result), /Placeholder mismatch candidates/);
    assert.doesNotMatch(toMarkdown(result), /generated.g.dart/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('actual VSP app translation files parse with known localizations', () => {
  const result = review({
    arabicArb: fs.readFileSync('lib/l10n/app_ar.arb', 'utf8'),
    englishArb: fs.readFileSync('lib/l10n/app_en.arb', 'utf8'),
  });
  assert.ok(result.arabicTranslationKeys >= 700);
  assert.ok(result.englishTranslationKeys >= 700);
  assert.ok(result.analyzedDartFiles >= 500);
  assert.ok(result.directTextCalls >= 0);
  assert.ok(result.latinLiteralText <= result.directTextCalls);
});
