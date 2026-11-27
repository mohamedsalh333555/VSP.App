import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(__dirname, '..');
const workspaceRoot = path.resolve(appRoot, '..');
const checkOnly = process.argv.includes('--check');

const canonicalPath = path.join(appRoot, 'design-tokens.json');
if (!fs.existsSync(canonicalPath)) {
  console.error(`ERROR: Canonical token file missing: ${canonicalPath}`);
  process.exit(1);
}
const canonical = JSON.parse(fs.readFileSync(canonicalPath, 'utf8'));
const payload = {
  colors: canonical.colors,
  typography: canonical.typography,
  spacing: canonical.spacing,
  radius: canonical.radius,
};

const targets = [
  {
    name: 'vsp_website',
    root: path.join(workspaceRoot, 'vsp_website'),
    files: [
      {
        rel: 'design-tokens.json',
        content: JSON.stringify(canonical, null, 2) + '\n',
      },
      {
        rel: path.join('src', 'styles', 'generated_tokens.ts'),
        content:
          `// AUTO-GENERATED FROM VSP.App/design-tokens.json — DO NOT EDIT MANUALLY\n` +
          `export const VSP_GENERATED_TOKENS = ${JSON.stringify(payload, null, 2)} as const;\n`,
      },
    ],
  },
  {
    name: 'vsp_admin_panel',
    root: path.join(workspaceRoot, 'vsp_admin_panel'),
    files: [
      {
        rel: 'design-tokens.json',
        content: JSON.stringify(canonical, null, 2) + '\n',
      },
      {
        rel: 'generated_tokens.json',
        content: JSON.stringify(payload, null, 2) + '\n',
      },
    ],
  },
];

let hasError = false;
const normalize = (s) => s.replace(/\r\n/g, '\n');

for (const target of targets) {
  if (!fs.existsSync(target.root)) {
    console.error(`ERROR: Required repository "${target.name}" not found at: ${target.root}`);
    hasError = true;
    continue;
  }
  for (const file of target.files) {
    const dest = path.join(target.root, file.rel);
    const parent = path.dirname(dest);
    if (!fs.existsSync(parent)) {
      console.error(`ERROR: Target directory missing for ${target.name}: ${parent}`);
      hasError = true;
      continue;
    }
    if (checkOnly) {
      if (!fs.existsSync(dest)) {
        console.error(`DRIFT: Missing generated file ${dest}`);
        hasError = true;
      } else if (normalize(fs.readFileSync(dest, 'utf8')) !== normalize(file.content)) {
        console.error(`DRIFT: Out-of-sync token file ${dest}`);
        hasError = true;
      }
    } else {
      fs.writeFileSync(dest, file.content, 'utf8');
      console.log(`Synced ${target.name}/${file.rel}`);
    }
  }
}

if (hasError) {
  console.error('Design token sync/check FAILED.');
  process.exit(1);
}

console.log(
  checkOnly
    ? 'CI Guard PASSED: All 3 repositories are in sync with VSP.App/design-tokens.json.'
    : 'Successfully synced canonical design tokens across all 3 required repositories.'
);
