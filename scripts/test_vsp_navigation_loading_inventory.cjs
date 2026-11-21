'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { inventory, toMarkdown } = require('./audit_vsp_navigation_loading.cjs');

test('real route declaration, loading states and retry controls are enumerated', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vsp-navigation-scan-'));
  try {
    fs.mkdirSync(path.join(dir, 'screens'));
    fs.writeFileSync(path.join(dir, 'router.dart'), `
GoRoute(
  path: '/owner',
  redirect: (context, state) => isAuthenticated ? null : '/login',
  builder: (context, state) => OwnerScreen(),
);
GoRoute(path: '/team/:teamId', builder: (_, __) => TeamScreen());
final x = context.push('/owner');
final p = Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerScreen()));
Navigator.pop(context);
`);
    fs.writeFileSync(path.join(dir, 'screens', 'loading.dart'), `
return FutureBuilder<String>(
  future: load,
  builder: (_, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return VSPStateView(state: VSPUiState.loading);
    }
    if (snapshot.hasError) return VSPErrorState(onRetry: () => retry());
    if (!snapshot.hasData) return VSPEmptyState();
    return CircularProgressIndicator();
  },
);
`);
    fs.writeFileSync(path.join(dir, 'screens', 'generated.g.dart'),
      'GoRoute(path: \'/generated\', builder: ...);');
    const audit = inventory(dir);
    assert.equal(audit.inspectedFiles, 2);
    assert.deepEqual(audit.declaredRoutes.map(x => x.path),
      ['/owner', '/team/:teamId']);
    for (const group of ['goRoute', 'pushNavigation', 'popNavigation',
      'navigationGuard', 'loadingState', 'dataBuilder',
      'errorState', 'emptyState', 'retryAction']) {
      assert.equal(audit.groups[group].references > 0, true, group);
      assert.equal(audit.groups[group].files > 0, true, group);
    }
    const output = toMarkdown(audit);
    assert.match(output, /2 declared literal GoRouter paths/);
    assert.match(output, /\| `retryAction` \|/);
    assert.doesNotMatch(output, /generated.g.dart/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('empty inventories and invalid roots are explicitly reported', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vsp-navigation-empty-'));
  try {
    const value = inventory(dir);
    assert.equal(value.inspectedFiles, 0);
    assert.equal(value.declaredRoutes.length, 0);
    assert.equal(value.groups.loadingState.references, 0);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
  assert.throws(() => inventory('/not/a/real/flutter/source'),
    /Invalid Dart source root/);
});
