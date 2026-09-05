const DEFAULT_PATTERNS: RegExp[] = [
  /Bearer\s+[A-Za-z0-9._-]+/g,
  /CODER_(?:TOKEN|SESSION_TOKEN)=[^\s]+/g,
  /ghp_[A-Za-z0-9_]{20,}/g,
  /github_pat_[A-Za-z0-9_]{20,}/g,
  /sk-[A-Za-z0-9]{20,}/g,
  /(?:api[_-]?key|password|secret)[:=]\s*[^\s]+/gi,
];

export function redactText(value: string): string {
  let output = value;
  for (const pattern of DEFAULT_PATTERNS) {
    output = output.replace(pattern, '[REDACTED]');
  }
  return output;
}

export function redactValue(value: unknown): unknown {
  if (typeof value === 'string') {
    return redactText(value);
  }
  if (Array.isArray(value)) {
    return value.map(redactValue);
  }
  if (value && typeof value === 'object') {
    const input = value as Record<string, unknown>;
    const output: Record<string, unknown> = {};
    for (const [key, item] of Object.entries(input)) {
      if (/token|secret|password|authorization|apikey/i.test(key)) {
        output[key] = '[REDACTED]';
      } else {
        output[key] = redactValue(item);
      }
    }
    return output;
  }
  return value;
}