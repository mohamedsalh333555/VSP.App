#!/usr/bin/env node
'use strict';

/** Source-only inventory of app navigation and loading/error/empty UI states.
 * Does NOT simulate user journeys, authorization or network behavior.
 */
const fs = require('node:fs');
const path = require('node:path');
const { walkDartFiles } = require('./audit_vsp_design_tokens_motion.cjs');

const PATTERNS = {
  goRoute: /\bGoRoute\s*\(/g,
  pushNavigation: /\b(?:Navigator\.(?:push|pushNamed|pushReplacement|pushReplacementNamed)|context\.(?:push|pushNamed|go|goNamed|replace))\s*\(/g,
  popNavigation: /\b(?:Navigator\.(?:pop|maybePop)|context\.pop|VSPBackButton)\b/g,
  navigationGuard: /\b(?:redirectLogic|redirect\s*:|isAuthenticated|isOwner|isAdmin|isPlayer)\b/g,
  loadingState: /\b(?:VSPUiState\.loading|CircularProgressIndicator|LinearProgressIndicator|CupertinoActivityIndicator)\b/g,
  dataBuilder: /\b(?:FutureBuilder|StreamBuilder)\s*(?:<[^>]+>)?\s*\(/g,
  errorState: /\b(?:VSPUiState\.error|VSPErrorState)\b/g,
  emptyState: /\b(?:VSPUiState\.empty|VSPEmptyState)\b/g,
  retryAction: /\b(?:onRetry\s*:|forceRefresh\s*:)\b/g,
};
const NAMES = Object.freeze(Object.keys(PATTERNS));

function inventory(root = 'lib') {
  const folder = path.resolve(root);
  if (!fs.existsSync(folder) || !fs.statSync(folder).isDirectory()) {
    throw new Error('Invalid Dart source root');
  }
  const files = walkDartFiles(folder);
  const kinds = Object.fromEntries(
    NAMES.map(key => [key, { references: 0, files: 0, positions: [] }]),
  );
  const declaredRoutes = [];
  for (const file of files) {
    const source = fs.readFileSync(file, 'utf8');
    const relative = path.relative(folder, file).replaceAll(path.sep, '/');
    const seen = new Set();
    for (const [index, line] of source.split(/\r?\n/).entries()) {
      if (line.trimStart().startsWith('//')) continue;
      for (const [key, expression] of Object.entries(PATTERNS)) {
        const hits = line.match(expression);
        if (!hits) continue;
        seen.add(key);
        kinds[key].references += hits.length;
        if (kinds[key].positions.length < 15) {
          kinds[key].positions.push({ file: relative, line: index + 1 });
        }
      }
    }
    for (const key of seen) kinds[key].files++;

    // Extract declared, literal GoRouter paths, including dynamic path
    // parameters. Deliberately ignore user-provided or computed destinations.
    const re = /\bGoRoute\s*\(\s*path\s*:\s*['"]([^'"]+)['"]/g;
    for (const match of source.matchAll(re)) {
      const before = source.slice(0, match.index);
      declaredRoutes.push({
        path: match[1],
        file: relative,
        line: before.split('\n').length,
      });
    }
  }
  declaredRoutes.sort((a, b) => a.path.localeCompare(b.path, 'en'));
  return {
    inspectedFiles: files.length,
    groups: kinds,
    declaredRoutes,
    notes: [
      'Read-only source inventory, not evidence of authenticated navigation or role-based authorization.',
      'Only literal GoRoute path declarations are enumerated; nested runtime-generated paths may be absent.',
      'Counts may include strings and multi-line comments, and do not measure actual loading, retry or offline behavior.',
      'Task 03.07 recovery and task 07.04 role permissions require separate integration tests.',
    ],
  };
}

function toMarkdown(report) {
  const lines = [
    '# VSP — Navigation and async UI-state source inventory',
    '',
    `Inspected ${report.inspectedFiles} non-generated Flutter Dart files.`,
    '',
    '| Source pattern | Occurrences | Files |',
    '| --- | ---: | ---: |',
  ];
  for (const key of NAMES) {
    const row = report.groups[key];
    lines.push(`| \`${key}\` | ${row.references} | ${row.files} |`);
  }
  lines.push('', `## ${report.declaredRoutes.length} declared literal GoRouter paths`, '');
  for (const route of report.declaredRoutes) {
    lines.push(`- \`${route.path}\` — \`${route.file}:${route.line}\``);
  }
  for (const key of NAMES) {
    const group = report.groups[key];
    if (!group.positions.length) continue;
    lines.push('', `## ${key}: source examples`, '');
    for (const position of group.positions) {
      lines.push(`- \`${position.file}:${position.line}\``);
    }
  }
  lines.push('', '## Limits', '', ...report.notes.map(x => '- ' + x), '');
  return lines.join('\n');
}

if (require.main === module) {
  const idx = process.argv.indexOf('--root');
  const source = idx === -1 ? 'lib' : process.argv[idx + 1];
  const result = inventory(source);
  process.stdout.write(
    process.argv.includes('--json') ?
      JSON.stringify(result, null, 2) + '\n' : toMarkdown(result) + '\n',
  );
}
module.exports = { PATTERNS, inventory, toMarkdown };
