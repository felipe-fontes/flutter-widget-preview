import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preview_binding/preview_binding.dart';

void main() {
  PreviewTestBinding.ensureInitialized();

  testWidgets('long running test for viewer connection', (tester) async {
    final binding = PreviewTestBinding.instance;
    
    final serverUri = await binding.startServer(port: 0);
    final port = Uri.parse(serverUri).port;
    print('');
    print('═══════════════════════════════════════════════════════════════');
    print('  TEST SERVER STARTED: $serverUri');
    print('');
    print('  In another terminal, run:');
    print('  cd fontes_widget_viewer/packages/preview_viewer');
    print('  dart run bin/preview_viewer.dart --grpc-port $port');
    print('═══════════════════════════════════════════════════════════════');
    print('');

    await tester.pumpWidget(const AnimatedCounterApp());
    await tester.pumpAndSettle();

    final incrementButton = find.byIcon(Icons.add);
    
    for (var i = 0; i < 100; i++) {
      await Future.delayed(const Duration(seconds: 2));
      await tester.tap(incrementButton);
      await tester.pump();
      print('Counter: $i');
    }

    await binding.stopServer();
  });
}

class AnimatedCounterApp extends StatefulWidget {
  const AnimatedCounterApp({super.key});

  @override
  State<AnimatedCounterApp> createState() => _AnimatedCounterAppState();
}

class _AnimatedCounterAppState extends State<AnimatedCounterApp> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.flutter_dash,
                size: 120,
                color: Colors.cyan,
              ),
              const SizedBox(height: 32),
              Text(
                'Counter',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton.large(
                    heroTag: 'decrement',
                    onPressed: () => setState(() => _counter--),
                    child: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 24),
                  FloatingActionButton.large(
                    heroTag: 'increment',
                    onPressed: () => setState(() => _counter++),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
