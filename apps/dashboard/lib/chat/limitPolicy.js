export function shouldTriggerForm({ authenticated, messageCount, confidence }) {
  const thresholdReached = authenticated ? messageCount >= 9 : messageCount >= 4;
  const confidenceReached = confidence >= 0.7;
  return thresholdReached || confidenceReached;
}
