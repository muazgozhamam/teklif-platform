import test from 'node:test';
import assert from 'node:assert/strict';
import { shouldTriggerForm } from './limitPolicy.js';

test('anon triggers form on 4th message', () => {
  assert.equal(shouldTriggerForm({ authenticated: false, messageCount: 3, confidence: 0.2 }), false);
  assert.equal(shouldTriggerForm({ authenticated: false, messageCount: 4, confidence: 0.2 }), true);
});

test('auth triggers form on 9th message', () => {
  assert.equal(shouldTriggerForm({ authenticated: true, messageCount: 8, confidence: 0.2 }), false);
  assert.equal(shouldTriggerForm({ authenticated: true, messageCount: 9, confidence: 0.2 }), true);
});

test('confidence can trigger early', () => {
  assert.equal(shouldTriggerForm({ authenticated: false, messageCount: 1, confidence: 0.71 }), true);
});
