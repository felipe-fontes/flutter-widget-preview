import 'package:mcp_preview/src/index_selectors.dart';
import 'package:test/test.dart';

void main() {
  group('parseGetFrameIndexSelector', () {
    test('accepts int indices (0-based) and -1', () {
      const frameCount = 5;

      expect(
        parseGetFrameIndexSelector(0, frameCount: frameCount),
        (index: 0, error: null),
      );
      expect(
        parseGetFrameIndexSelector(4, frameCount: frameCount),
        (index: 4, error: null),
      );
      expect(
        parseGetFrameIndexSelector(-1, frameCount: frameCount),
        (index: 4, error: null),
      );
    });

    test('accepts "first"/"last" (case-insensitive, trimmed)', () {
      const frameCount = 5;

      expect(
        parseGetFrameIndexSelector('first', frameCount: frameCount),
        (index: 0, error: null),
      );
      expect(
        parseGetFrameIndexSelector(' last ', frameCount: frameCount),
        (index: 4, error: null),
      );
      expect(
        parseGetFrameIndexSelector('FIRST', frameCount: frameCount),
        (index: 0, error: null),
      );
    });

    test('accepts numeric strings (1-based compatibility)', () {
      const frameCount = 5;

      expect(
        parseGetFrameIndexSelector('1', frameCount: frameCount),
        (index: 0, error: null),
      );
      expect(
        parseGetFrameIndexSelector('10', frameCount: frameCount),
        (index: 9, error: null),
      );
      expect(
        parseGetFrameIndexSelector('0', frameCount: frameCount),
        (index: 0, error: null),
      );
      expect(
        parseGetFrameIndexSelector('-1', frameCount: frameCount),
        (index: 4, error: null),
      );
    });

    test('rejects non-numeric strings and unsupported types', () {
      const frameCount = 5;

      final badString =
          parseGetFrameIndexSelector('nope', frameCount: frameCount);
      expect(badString.index, isNull);
      expect(badString.error, isNotNull);

      final badType = parseGetFrameIndexSelector(1.5, frameCount: frameCount);
      expect(badType.index, isNull);
      expect(badType.error, isNotNull);
    });
  });
}
