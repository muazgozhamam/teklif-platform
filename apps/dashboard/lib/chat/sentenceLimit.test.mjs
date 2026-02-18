import test from 'node:test';
import assert from 'node:assert/strict';
import { truncateToTwoSentences } from './sentenceLimit.js';

test('keeps single sentence untouched', () => {
  assert.equal(truncateToTwoSentences('Merhaba nasılsın?'), 'Merhaba nasılsın?');
});

test('truncates to first two sentences', () => {
  assert.equal(
    truncateToTwoSentences('Birinci cümle. İkinci cümle! Üçüncü cümle? Dördüncü.'),
    'Birinci cümle. İkinci cümle!',
  );
});

test('supports ellipsis punctuation', () => {
  assert.equal(
    truncateToTwoSentences('İlk düşünce… İkinci düşünce… Üçüncü düşünce.'),
    'İlk düşünce… İkinci düşünce…',
  );
});

test('normalizes whitespace', () => {
  assert.equal(
    truncateToTwoSentences('  İlk   cümle.   İkinci\n\n cümle?   Üçüncü. '),
    'İlk cümle. İkinci cümle?',
  );
});
