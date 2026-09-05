import assert from 'node:assert/strict';
import test from 'node:test';
import { redactText } from '../src/redaction.js';
import { riskAllowed, classifyMutation } from '../src/policy.js';
import { createChangePlan } from '../src/change.js';

test('redaction hides tokens', () => {
  assert.match(redactText('Bearer abc123 ghp_abcdefghijklmnopqrstuvwxyz'), /\[REDACTED\]/);
});

test('policy enforces observer mode', () => {
  assert.equal(riskAllowed('observer', 'R0'), true);
  assert.equal(riskAllowed('observer', 'R1'), false);
});

test('policy enforces operator mode', () => {
  assert.equal(riskAllowed('operator', 'R2'), true);
  assert.equal(riskAllowed('operator', 'R3'), false);
});

test('mutation classification covers destructive keywords', () => {
  assert.equal(classifyMutation('delete workspace'), 'R4');
  assert.equal(classifyMutation('publish template'), 'R3');
});

test('change plan shape is populated', () => {
  const plan = createChangePlan('template', 'old', 'new', ['publish'], 'R2', 'tester');
  assert.ok(plan.id.startsWith('chg-'));
  assert.equal(plan.requires_approval, false);
  assert.equal(plan.risk, 'R2');
});