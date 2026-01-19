import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart';

import 'generated/preview.pb.dart';
import 'generated/preview.pbgrpc.dart';

class PreviewGrpcServer extends PreviewServiceBase {
  final StreamController<Frame> _frameController =
      StreamController<Frame>.broadcast();

  Server? _server;
  int _frameCount = 0;
  String _testName = '';
  bool _isRunning = false;

  Stream<Frame> get frameStream => _frameController.stream;

  Future<int> start({int port = 0}) async {
    _server = Server.create(services: [this]);
    await _server!.serve(port: port);
    _isRunning = true;
    print('GRPC_SERVER_STARTED:${_server!.port}');
    return _server!.port!;
  }

  Future<void> stop() async {
    _isRunning = false;
    await _server?.shutdown();
    await _frameController.close();
    print('GRPC_SERVER_STOPPED');
  }

  void setTestName(String name) {
    _testName = name;
  }

  void pushFrame(Frame frame) {
    if (_frameController.isClosed) return;

    frame.testName = _testName;
    _frameCount++;
    _frameController.add(frame);
    print('FRAME_PUSHED:${frame.width}x${frame.height}');
  }

  @override
  Stream<Frame> watchFrames(ServiceCall call, WatchRequest request) {
    print('CLIENT_CONNECTED:watchFrames');
    return _frameController.stream;
  }

  @override
  Future<Status> getStatus(ServiceCall call, Empty request) async {
    return Status()
      ..isRunning = _isRunning
      ..testName = _testName
      ..frameCount = _frameCount
      ..serverUri = 'grpc://localhost:${_server?.port ?? 0}';
  }
}
