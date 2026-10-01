// Lockfile security-pin regression guard (issue #23)
//
// npm audit reports against the RESOLVED versions recorded in
// package-lock.json, so a lockfile that still resolves a vulnerable
// transitive (fast-uri <= 3.1.7, ip-address <= 10.7.0) is the defect this
// guard prevents from regressing. The npm "overrides" block in package.json
// is the enforcement mechanism; this test asserts both halves:
//   1. package.json carries the pinning overrides (enforcement), and
//   2. every resolved lockfile entry satisfies the pinned range (effect).

import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const pkg = JSON.parse(readFileSync(join(here, '..', '..', 'package.json'), 'utf8')) as {
  overrides?: Record<string, string>;
};
const lock = JSON.parse(readFileSync(join(here, '..', '..', 'package-lock.json'), 'utf8')) as {
  packages: Record<string, { version?: string }>;
};

type PinSpec = { range: string };
const EXPECTED_OVERRIDES: Record<string, PinSpec> = {
  // >= 3.1.8 fixes GHSA-hrr3-gc8f-f4qj (moderate, CWE-178)
  'fast-uri': { range: '^3.1.8' },
  // >= 10.7.1 fixes GHSA-j6r3-76f7-8jcv + GHSA-h3mg-xc3c-68pw (moderate)
  'ip-address': { range: '^10.7.1' },
};

function satisfiesCaret(version: string, range: string): boolean {
  const m = /^(\d+)\.(\d+)\.(\d+)$/.exec(version);
  if (!m) return false;
  const rm = /^\^?(\d+)\.(\d+)\.(\d+)$/.exec(range);
  if (!rm) return false;
  const cur = [Number(m[1]), Number(m[2]), Number(m[3])];
  const min = [Number(rm[1]), Number(rm[2]), Number(rm[3])];
  for (let i = 0; i < 3; i++) {
    if (cur[i] > min[i]) return true;
    if (cur[i] < min[i]) return false;
  }
  return true; // exactly equal satisfies ^X.Y.Z
}

test('package.json pins the fixed transitive ranges via overrides', () => {
  const expected = Object.fromEntries(
    Object.entries(EXPECTED_OVERRIDES).map(([k, v]) => [k, v.range])
  ) as Record<string, string>;
  assert.deepEqual(
    pkg.overrides,
    expected,
    'package.json must keep the security-pinning overrides for fast-uri and ip-address'
  );
});

test('every lockfile entry for pinned packages resolves to a patched version', () => {
  const entries: Array<{ key: string; name: string; version: string }> = [];
  for (const [key, value] of Object.entries(lock.packages)) {
    const name = key.split('/').pop();
    if (name && name in EXPECTED_OVERRIDES) {
      assert.ok(value.version, `lockfile entry ${key} has no resolved version`);
      entries.push({ key, name, version: value.version as string });
    }
  }
  assert.equal(
    entries.length,
    2,
    `expected exactly 2 lockfile entries (fast-uri, ip-address), got ${entries.length}: ${JSON.stringify(entries)}`
  );
  for (const { key, name, version } of entries) {
    const spec = EXPECTED_OVERRIDES[name] as PinSpec;
    assert.ok(
      satisfiesCaret(version, spec.range),
      `${key} resolves ${version}, which violates the pinned override ${spec.range}`
    );
  }
});
