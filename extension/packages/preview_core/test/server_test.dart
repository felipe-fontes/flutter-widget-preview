import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:preview_core/preview_core.dart';
import 'package:test/test.dart';

void main() {
  test('server starts and pushes frames', () async {
    final server = PreviewGrpcServer();
    final port = await server.start(port: 0);

    expect(port, greaterThan(0));
    print('SERVER_STARTED:$port');

    server.setTestName('test_widget');

    for (var i = 0; i < 3; i++) {
      final frame = Frame()
        ..width = 100
        ..height = 100
        ..rgbaData = Uint8List(100 * 100 * 4)
        ..devicePixelRatio = 2.0
        ..timestampMs = Int64(DateTime.now().millisecondsSinceEpoch);

      server.pushFrame(frame);
      print('FRAME_SENT:$i');
      await Future.delayed(const Duration(milliseconds: 50));
    }

    final status = await server.getStatus(_MockServiceCall(), Empty());
    expect(status.frameCount, equals(3));
    expect(status.testName, equals('test_widget'));
    print('STATUS_FRAME_COUNT:${status.frameCount}');

    await server.stop();
    print('SERVER_TEST_PASSED');
  });
}

class _MockServiceCall implements ServiceCall {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
