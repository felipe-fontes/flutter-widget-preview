import 'dart:async';

import 'package:grpc/grpc.dart';

import 'generated/preview.pb.dart';
import 'generated/preview.pbgrpc.dart';

class PreviewGrpcClient {
  ClientChannel? _channel;
  PreviewServiceClient? _stub;

  Future<void> connect(String host, int port) async {
    _channel = ClientChannel(
      host,
      port: port,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    _stub = PreviewServiceClient(_channel!);
  }

  Future<void> disconnect() async {
    await _channel?.shutdown();
    _channel = null;
    _stub = null;
  }

  Stream<Frame> watchFrames() {
    if (_stub == null) {
      throw StateError('Client not connected. Call connect() first.');
    }
    return _stub!.watchFrames(WatchRequest());
  }

  Future<Status> getStatus() async {
    if (_stub == null) {
      throw StateError('Client not connected. Call connect() first.');
    }
    return _stub!.getStatus(Empty());
  }
}
