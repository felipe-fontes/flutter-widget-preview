import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:preview_core/preview_core.dart';

void main() async {
  print('Starting demo gRPC server...');
  
  final server = PreviewGrpcServer();
  final port = await server.start(port: 50055);
  
  print('');
  print('════════════════════════════════════════════════════════════');
  print('  DEMO SERVER RUNNING');
  print('  gRPC server on port: $port');
  print('');
  print('  Connect viewer:');
  print('  cd packages/preview_viewer');
  print('  dart run bin/preview_viewer.dart --grpc-port $port');
  print('');
  print('  Then open: http://localhost:9090');
  print('════════════════════════════════════════════════════════════');
  print('');
  
  server.setTestName('demo_animation');
  
  var tick = 0;
  Timer.periodic(const Duration(milliseconds: 100), (timer) {
    final frame = _generateColorfulFrame(tick, 400, 800);
    server.pushFrame(frame);
    tick++;
    
    if (tick % 50 == 0) {
      print('Sent $tick frames');
    }
    
    if (tick >= 600) {
      print('Demo complete after 600 frames');
      timer.cancel();
      server.stop();
    }
  });
}

Frame _generateColorfulFrame(int tick, int width, int height) {
  final random = Random(tick);
  final data = Uint8List(width * height * 4);
  
  final baseHue = (tick * 3) % 360;
  
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      
      final hue = (baseHue + (x + y) ~/ 10) % 360;
      final wave = (sin((x + tick * 2) / 30) * 0.5 + 0.5);
      final brightness = 0.3 + wave * 0.7;
      
      final rgb = _hsvToRgb(hue.toDouble(), 0.8, brightness);
      
      data[i] = rgb[0];
      data[i + 1] = rgb[1];
      data[i + 2] = rgb[2];
      data[i + 3] = 255;
    }
  }
  
  return Frame(
    rgbaData: data,
    width: width,
    height: height,
    devicePixelRatio: 2.0,
  );
}

List<int> _hsvToRgb(double h, double s, double v) {
  final c = v * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = v - c;
  
  double r, g, b;
  if (h < 60) {
    r = c; g = x; b = 0;
  } else if (h < 120) {
    r = x; g = c; b = 0;
  } else if (h < 180) {
    r = 0; g = c; b = x;
  } else if (h < 240) {
    r = 0; g = x; b = c;
  } else if (h < 300) {
    r = x; g = 0; b = c;
  } else {
    r = c; g = 0; b = x;
  }
  
  return [
    ((r + m) * 255).round(),
    ((g + m) * 255).round(),
    ((b + m) * 255).round(),
  ];
}
