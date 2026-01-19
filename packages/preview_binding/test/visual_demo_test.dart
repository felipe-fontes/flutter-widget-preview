import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preview_binding/preview_binding.dart';

void main() {
  final binding = PreviewTestBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('visual demo', (tester) async {
    final serverUri = await binding.startServer(port: 0);
    final port = Uri.parse(serverUri).port;

    print('');
    print('════════════════════════════════════════════════════════════');
    print('  VISUAL DEMO RUNNING FOR 60 SECONDS');
    print('  Server: grpc://localhost:$port');
    print('');
    print('  Connect viewer:');
    print('  dart run bin/preview_viewer.dart --grpc-port $port --web-port 9090');
    print('');
    print('  Then open: http://localhost:9090');
    print('════════════════════════════════════════════════════════════');
    print('');

    await tester.pumpWidget(const VisualDemoApp());
    await tester.pump();

    final endTime = DateTime.now().add(const Duration(seconds: 60));
    var frameCount = 0;

    while (DateTime.now().isBefore(endTime)) {
      await tester.tap(find.byKey(const Key('tap_target')));
      await tester.pump();
      
      for (var i = 0; i < 10; i++) {
        await Future(() {});
      }
      
      final frameCompleter = Completer<void>();
      Timer(const Duration(milliseconds: 80), frameCompleter.complete);
      await frameCompleter.future;
      
      for (var i = 0; i < 10; i++) {
        await Future(() {});
      }
      
      frameCount++;
      if (frameCount % 50 == 0) {
        final remaining = endTime.difference(DateTime.now()).inSeconds;
        print('Frame $frameCount - ${remaining}s remaining');
      }
    }

    print('Demo finished after $frameCount frames');
    await binding.stopServer();
  });
}

class VisualDemoApp extends StatefulWidget {
  const VisualDemoApp({super.key});

  @override
  State<VisualDemoApp> createState() => _VisualDemoAppState();
}

class _VisualDemoAppState extends State<VisualDemoApp> {
  int _tick = 0;

  final _colors = [
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.lime,
    Colors.green,
    Colors.teal,
    Colors.cyan,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: GestureDetector(
        key: const Key('tap_target'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tick++),
        child: Scaffold(
          backgroundColor: Color.lerp(
            const Color(0xFF0a0a1a),
            _colors[_tick % _colors.length],
            0.1,
          ),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  'LIVE PREVIEW',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w300,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$_tick',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w100,
                    color: _colors[_tick % _colors.length],
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: 9,
                      itemBuilder: (context, index) {
                        final colorIndex = (_tick + index) % _colors.length;
                        final offset = sin((_tick + index) * 0.3) * 8;
                        return Transform.translate(
                          offset: Offset(0, offset),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _colors[colorIndex],
                                  _colors[(colorIndex + 3) % _colors.length],
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                8 + (_tick % 12).toDouble(),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _colors[colorIndex].withOpacity(0.5),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _stat('Frame', '$_tick'),
                        _stat('Colors', '${_colors.length}'),
                        _stat('Boxes', '9'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _colors[_tick % _colors.length],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
