import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(__dirname, '..');
const workspaceRoot = path.resolve(appRoot, '..');
const canonicalPath = path.join(appRoot, 'design-tokens.json');
const originalRaw = fs.readFileSync(canonicalPath, 'utf8');
const originalJson = JSON.parse(originalRaw);

const testAccent = '#A8E600';

try {
  // 1. Mutate central accent token temporarily
  const mutated = structuredClone(originalJson);
  mutated.colors.accent = testAccent;
  fs.writeFileSync(canonicalPath, JSON.stringify(mutated, null, 2) + '\n', 'utf8');

  // 2. Assert --check detects drift before syncing
  let driftDetected = false;
  try {
    execFileSync(process.execPath, ['scripts/sync_design_tokens.mjs', '--check'], {
      cwd: appRoot,
      stdio: 'pipe',
    });
  } catch {
    driftDetected = true;
  }
  assert.strictEqual(driftDetected, true, 'sync_design_tokens.mjs --check must fail when repos are out of sync');

  // 3. Run sync and verify all 3 repos reflect the updated token
  execFileSync(process.execPath, ['scripts/sync_design_tokens.mjs'], {
    cwd: appRoot,
    stdio: 'pipe',
  });

  const websiteGenerated = fs.readFileSync(
    path.join(workspaceRoot, 'vsp_website', 'src', 'styles', 'generated_tokens.ts'),
    'utf8'
  );
  assert.ok(websiteGenerated.includes(testAccent), 'vsp_website generated_tokens.ts must reflect mutated accent');

  const adminGenerated = JSON.parse(
    fs.readFileSync(path.join(workspaceRoot, 'vsp_admin_panel', 'generated_tokens.json'), 'utf8')
  );
  assert.strictEqual(adminGenerated.colors.accent, testAccent, 'vsp_admin_panel generated_tokens.json must reflect mutated accent');

  // 4. Verify --check passes after propagation
  execFileSync(process.execPath, ['scripts/sync_design_tokens.mjs', '--check'], {
    cwd: appRoot,
    stdio: 'pipe',
  });

  console.log('PASS: Central token change propagated to VSP.App, vsp_website, and vsp_admin_panel, and CI guard detected drift.');
} finally {
  // 5. Restore canonical tokens cleanly
  fs.writeFileSync(canonicalPath, originalRaw, 'utf8');
  execFileSync(process.execPath, ['scripts/sync_design_tokens.mjs'], {
    cwd: appRoot,
    stdio: 'pipe',
  });
  execFileSync(process.execPath, ['scripts/sync_design_tokens.mjs', '--check'], {
    cwd: appRoot,
    stdio: 'pipe',
  });
}
