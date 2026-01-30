import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:preview_core/preview_core.dart';
import 'package:preview_viewer/preview_viewer.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  group('FrameRelay and ViewerServer', () {
    test('relays frames from gRPC to WebSocket browsers', () async {
      final grpcServer = PreviewGrpcServer();
      final grpcPort = await grpcServer.start();
      print('GRPC_SERVER:localhost:$grpcPort');

      final relay = FrameRelay();
      final viewerServer = ViewerServer(relay);

      await relay.connectToTest('localhost', grpcPort);
      final webPort = await viewerServer.start(port: 0);
      print('WEB_SERVER:http://localhost:$webPort');

      final ws = IOWebSocketChannel.connect('ws://localhost:$webPort/ws');
      print('BROWSER_SIMULATED');

      final receivedMetadata = <Map<String, dynamic>>[];
      final receivedFrames = <List<int>>[];

      ws.stream.listen((data) {
        if (data is String) {
          final meta = jsonDecode(data) as Map<String, dynamic>;
          receivedMetadata.add(meta);
          print('METADATA_RECEIVED:${receivedMetadata.length}');
        } else if (data is List<int>) {
          receivedFrames.add(data);
          print('FRAME_RELAYED:${receivedFrames.length}');
        }
      });

      await Future.delayed(const Duration(milliseconds: 100));

      grpcServer.pushFrame(Frame(
        rgbaData: Uint8List.fromList(List.filled(400 * 300 * 4, 128)),
        width: 400,
        height: 300,
        devicePixelRatio: 2.0,
        testName: 'test_widget',
      ));
      print('FRAME_PUSHED_BY_SERVER');

      await Future.delayed(const Duration(milliseconds: 500));

      // Filter out the "ready" signal frame (0x0 dimensions)
      final actualFrameMetadata = receivedMetadata
          .where((m) => m['width'] != 0 && m['height'] != 0)
          .toList();
      final readySignals = receivedMetadata
          .where((m) => m['width'] == 0 && m['height'] == 0)
          .toList();

      print('READY_SIGNALS:${readySignals.length}');
      print('ACTUAL_FRAMES:${actualFrameMetadata.length}');

      expect(actualFrameMetadata.length, 1,
          reason: 'Should receive 1 actual frame');
      expect(actualFrameMetadata[0]['width'], 400);
      expect(actualFrameMetadata[0]['height'], 300);
      expect(actualFrameMetadata[0]['devicePixelRatio'], 2.0);
      print('METADATA_VERIFIED:${actualFrameMetadata[0]}');

      // Filter actual frame data (non-empty)
      final actualFrameData =
          receivedFrames.where((f) => f.isNotEmpty).toList();
      expect(actualFrameData.length, 1, reason: 'Should receive 1 frame');
      expect(actualFrameData[0].length, 400 * 300 * 4);
      print('FRAME_SIZE_VERIFIED:${actualFrameData[0].length}');

      await ws.sink.close();
      await relay.disconnect();
      await viewerServer.stop();
      await grpcServer.stop();

      print('VIEWER_TEST_PASSED');
    });
  });
}
