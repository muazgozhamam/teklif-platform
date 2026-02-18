export function truncateToTwoSentences(input) {
  const compact = String(input ?? '').replace(/\s+/g, ' ').trim();
  if (!compact) return '';

  const matches = compact.match(/[^.!?…]+(?:[.!?…]+|$)/g) ?? [];
  const sentences = matches.map((s) => s.trim()).filter(Boolean);
  if (!sentences.length) return compact;

  return sentences.slice(0, 2).join(' ').replace(/\s+/g, ' ').trim();
}
