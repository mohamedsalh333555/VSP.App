import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(__dirname, '..');
const workspaceRoot = path.resolve(appRoot, '..');
const canonicalPath = path.join(appRoot, 'design-tokens.json');
const canonical = JSON.parse(fs.readFileSync(canonicalPath, 'utf8'));

// 1. Sync to vsp_website
const websiteRoot = path.join(workspaceRoot, 'vsp_website');
if (fs.existsSync(websiteRoot)) {
  fs.writeFileSync(
    path.join(websiteRoot, 'design-tokens.json'),
    JSON.stringify(canonical, null, 2) + '\n',
    'utf8'
  );
  const tsContent = `// AUTO-GENERATED FROM VSP.App/design-tokens.json — DO NOT EDIT MANUALLY
export const VSP_GENERATED_TOKENS = ${JSON.stringify(
    { colors: canonical.colors, spacing: canonical.spacing, radius: canonical.radius },
    null,
    2
  )} as const;
`;
  fs.writeFileSync(
    path.join(websiteRoot, 'src', 'styles', 'generated_tokens.ts'),
    tsContent,
    'utf8'
  );
}

// 2. Sync to vsp_admin_panel
const adminRoot = path.join(workspaceRoot, 'vsp_admin_panel');
if (fs.existsSync(adminRoot)) {
  fs.writeFileSync(
    path.join(adminRoot, 'design-tokens.json'),
    JSON.stringify(canonical, null, 2) + '\n',
    'utf8'
  );
  fs.writeFileSync(
    path.join(adminRoot, 'generated_tokens.json'),
    JSON.stringify(
      { colors: canonical.colors, spacing: canonical.spacing, radius: canonical.radius },
      null,
      2
    ) + '\n',
    'utf8'
  );
}

console.log('Synced canonical design tokens across VSP.App, vsp_website, and vsp_admin_panel.');
