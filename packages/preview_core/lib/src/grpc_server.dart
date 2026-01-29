import 'dart:async';
import 'dart:collection';

import 'package:grpc/grpc.dart';

import 'generated/preview.pb.dart';
import 'generated/preview.pbgrpc.dart';

class PreviewGrpcServer extends PreviewServiceBase {
  final StreamController<Frame> _frameController =
      StreamController<Frame>.broadcast();

  /// Buffer to store recent frames for late-connecting clients
  final Queue<Frame> _frameBuffer = Queue<Frame>();
  static const int _maxBufferSize = 10;

  Server? _server;
  int _frameCount = 0;
  String _testName = '';
  bool _isRunning = false;
  bool _clientConnected = false;
  bool _clientReady = false; // True when client is actually receiving frames
  Completer<void>? _clientConnectionCompleter;
  Completer<void>? _clientReadyCompleter;

  Stream<Frame> get frameStream => _frameController.stream;
  bool get hasClientConnected => _clientConnected;

  /// Waits for a client to connect AND be ready to receive frames.
  /// This ensures the test doesn't start until the viewer is actually listening.
  Future<void> waitForClientConnection({Duration? timeout}) async {
    if (_clientReady) return;

    _clientReadyCompleter ??= Completer<void>();

    if (timeout != null) {
      await _clientReadyCompleter!.future.timeout(
        timeout,
        onTimeout: () {
          print('GRPC_CLIENT_TIMEOUT:${timeout.inSeconds}s');
        },
      );
    } else {
      await _clientReadyCompleter!.future;
    }
  }

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

    // Add to buffer for late-connecting clients
    _frameBuffer.add(frame);
    while (_frameBuffer.length > _maxBufferSize) {
      _frameBuffer.removeFirst();
    }

    _frameController.add(frame);
  }

  @override
  Stream<Frame> watchFrames(ServiceCall call, WatchRequest request) async* {
    print('CLIENT_STREAM_STARTED');
    _clientConnected = true;
    if (_clientConnectionCompleter != null &&
        !_clientConnectionCompleter!.isCompleted) {
      _clientConnectionCompleter!.complete();
    }

    // First, send any buffered frames to the new client
    for (final frame in _frameBuffer) {
      yield frame;
    }

    // Send a "ready" signal - an empty frame that indicates the stream is active
    // This ensures the client's listen() callback has been invoked
    yield Frame()
      ..width = 0
      ..height = 0
      ..testName = '__READY__';

    // Mark client as ready after yielding the ready signal
    _clientReady = true;
    if (_clientReadyCompleter != null && !_clientReadyCompleter!.isCompleted) {
      _clientReadyCompleter!.complete();
    }
    print('CLIENT_READY');

    // Then stream new frames as they arrive using an async generator
    await for (final frame in _frameController.stream) {
      yield frame;
    }
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
