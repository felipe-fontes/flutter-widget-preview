import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:preview_viewer/preview_viewer.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('grpc-host', abbr: 'h', defaultsTo: 'localhost')
    ..addOption('grpc-port', abbr: 'p', help: 'gRPC server port from test')
    ..addOption('web-port', abbr: 'w', defaultsTo: '9090')
    ..addFlag('help', negatable: false);

  final results = parser.parse(args);

  if (results['help'] as bool) {
    print('Flutter Widget Test Viewer\n');
    print('Usage: preview_viewer --grpc-port <port>\n');
    print(parser.usage);
    exit(0);
  }

  final grpcPort = results['grpc-port'] as String?;
  if (grpcPort == null) {
    print('ERROR: --grpc-port is required');
    print('Usage: preview_viewer --grpc-port <port>');
    exit(1);
  }

  final grpcHost = results['grpc-host'] as String;
  final webPort = int.parse(results['web-port'] as String);

  print('VIEWER_STARTING');
  print('Connecting to test at $grpcHost:$grpcPort...');

  final relay = FrameRelay();
  final server = ViewerServer(relay);

  try {
    await relay.connectToTest(grpcHost, int.parse(grpcPort));
    final actualWebPort = await server.start(port: webPort);

    print('');
    print('═══════════════════════════════════════════');
    print('  Open in browser: http://localhost:$actualWebPort');
    print('═══════════════════════════════════════════');
    print('');
    print('Press Ctrl+C to stop');

    await ProcessSignal.sigint.watch().first;
    print('\nShutting down...');
  } catch (e) {
    print('ERROR: $e');
    exit(1);
  } finally {
    await relay.disconnect();
    await server.stop();
  }
}
