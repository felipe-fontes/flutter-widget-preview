typedef GetFrameIndexParseResult = ({int? index, String? error});

GetFrameIndexParseResult parseGetFrameIndexSelector(
  dynamic indexArg, {
  required int frameCount,
}) {
  if (indexArg is int) {
    if (indexArg == -1) {
      return (index: frameCount - 1, error: null);
    }
    return (index: indexArg, error: null);
  }

  if (indexArg is String) {
    final raw = indexArg.trim();
    final keyword = raw.toLowerCase();

    switch (keyword) {
      case 'first':
        return (index: 0, error: null);
      case 'last':
        return (index: frameCount - 1, error: null);
    }

    final parsed = int.tryParse(raw);
    if (parsed == null) {
      return (
        index: null,
        error:
            'Invalid index: $indexArg. Use integer (0-based), numeric string (e.g. "1" or "10"), or "first"/"last".',
      );
    }

    // Compatibility: numeric strings are often 1-based when produced by LLMs.
    // Keep "0" working (first frame), and keep "-1" meaning last.
    if (parsed == -1) {
      return (index: frameCount - 1, error: null);
    }
    if (parsed == 0) {
      return (index: 0, error: null);
    }
    if (parsed > 0) {
      return (index: parsed - 1, error: null);
    }

    // Other negatives behave like integer indices (and will be rejected later if out of range).
    return (index: parsed, error: null);
  }

  return (index: null, error: 'Invalid index type');
}
