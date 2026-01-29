import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CounterApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byKey(const Key('increment_button')));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Counter decrements correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const CounterApp());

    expect(find.text('0'), findsOneWidget);

    // Tap increment twice
    await tester.tap(find.byKey(const Key('increment_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('increment_button')));
    await tester.pump();

    expect(find.text('2'), findsOneWidget);

    // Tap decrement once
    await tester.tap(find.byKey(const Key('decrement_button')));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('CounterWidget increments and decrements',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CounterWidget(initialValue: 5),
          ),
        ),
      ),
    );

    expect(find.text('Count: 5'), findsOneWidget);

    // Increment
    await tester.tap(find.byKey(const Key('plus_button')));
    await tester.pump();
    expect(find.text('Count: 6'), findsOneWidget);

    // Decrement
    await tester.tap(find.byKey(const Key('minus_button')));
    await tester.pump();
    expect(find.text('Count: 5'), findsOneWidget);
  });
}
