import 'dart:async';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preview_core/preview_core.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;

import 'preview_platform_dispatcher.dart';
import 'font_loader.dart';

/// Path to the extension's fonts folder, passed via --dart-define
const _fontsPath = String.fromEnvironment(
  'PREVIEW_FONTS_PATH',
  defaultValue: '',
);

class PreviewTestBinding extends TestWidgetsFlutterBinding
    implements LiveTestWidgetsFlutterBinding {
  PreviewTestBinding() {
    debugPrint = debugPrintOverride;
    // Automatically load fonts when binding is created
    _initializeFonts();
  }

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  late final _grpcServer = PreviewGrpcServer();
  bool _serverStarted = false;
  bool _fontsLoaded = false;
  Completer<void>? _fontsCompleter;
  int _framesSent = 0;

  /// Completer that resolves when the process should exit.
  /// Used to keep the process alive until frames are delivered.
  static Completer<void>? _exitCompleter;

  /// Call this to wait before exiting the process.
  /// Should be called from flutter_test_config after tests complete.
  static Future<void> waitBeforeExit() async {
    if (_exitCompleter != null && !_exitCompleter!.isCompleted) {
      await _exitCompleter!.future;
    }
  }

  /// Signals that the process can exit now.
  static void signalReadyToExit() {
    if (_exitCompleter != null && !_exitCompleter!.isCompleted) {
      _exitCompleter!.complete();
      print('PREVIEW_READY_TO_EXIT');
    }
  }

  static PreviewTestBinding get instance =>
      BindingBase.checkInstance(_instance);
  static PreviewTestBinding? _instance;

  static PreviewTestBinding ensureInitialized() {
    if (_instance != null) return _instance!;
    return _instance ??= PreviewTestBinding();
  }

  /// Automatically loads fonts during binding initialization.
  void _initializeFonts() {
    if (_fontsPath.isNotEmpty && !_fontsLoaded) {
      _fontsCompleter = Completer<void>();
      _loadFontsAsync();
    }
  }

  Future<void> _loadFontsAsync() async {
    try {
      debugPrint('Loading preview fonts from: $_fontsPath');
      await loadPreviewFonts(_fontsPath);
      _fontsLoaded = true;
      debugPrint('Preview fonts loaded successfully');
    } catch (e) {
      debugPrint('Failed to load fonts: $e');
    } finally {
      _fontsCompleter?.complete();
    }
  }

  /// Waits for fonts to finish loading. Called automatically before tests run.
  Future<void> waitForFonts() async {
    await _fontsCompleter?.future;
  }

  /// Loads fonts for proper rendering. Usually not needed - fonts load automatically.
  ///
  /// [fontsPath] is optional - if not provided, uses PREVIEW_FONTS_PATH dart-define.
  Future<void> loadFonts([String? fontsPath]) async {
    if (_fontsLoaded) return;

    final path = fontsPath ?? _fontsPath;
    if (path.isNotEmpty) {
      debugPrint('Loading preview fonts from: $path');
      await loadPreviewFonts(path);
      _fontsLoaded = true;
      debugPrint('Preview fonts loaded successfully');
    } else {
      debugPrint('No fonts path provided - fonts will not be loaded');
    }
  }

  Future<String> startServer({int port = 0}) async {
    // Ensure fonts are loaded before starting server
    await waitForFonts();

    if (_serverStarted) {
      return 'grpc://localhost:${_grpcServer.hashCode}';
    }

    final serverPort = await _grpcServer.start(port: port);
    _serverStarted = true;

    final uri = 'grpc://localhost:$serverPort';
    print('PREVIEW_SERVER_STARTED:$uri');
    return uri;
  }

  /// Waits for a viewer client to connect to the gRPC server.
  /// This should be called after [startServer] and before running tests.
  Future<void> waitForViewerConnection({Duration? timeout}) async {
    if (!_serverStarted) {
      throw StateError('Server not started. Call startServer() first.');
    }
    print('PREVIEW_WAITING_FOR_VIEWER');
    await _grpcServer.waitForClientConnection(timeout: timeout);
    print('PREVIEW_VIEWER_CONNECTED');
  }

  /// Returns true if a viewer client is connected.
  bool get hasViewerConnected => _grpcServer.hasClientConnected;

  Future<void> stopServer() async {
    if (_serverStarted) {
      await _grpcServer.stop();
      _serverStarted = false;
    }
  }

  @override
  PreviewPlatformDispatcher get platformDispatcher => _platformDispatcher;

  late final _platformDispatcher = PreviewPlatformDispatcher(
    platformDispatcher: super.platformDispatcher,
    onFrameCaptured: _handleFrameCaptured,
  );

  void _handleFrameCaptured(
    ui.Scene scene,
    ui.Size physicalSize,
    double devicePixelRatio,
  ) async {
    if (!_serverStarted) return;

    try {
      final width = physicalSize.width.toInt();
      final height = physicalSize.height.toInt();

      final image = scene.toImageSync(width, height);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();

      if (byteData == null) return;

      final frame = Frame()
        ..width = width
        ..height = height
        ..rgbaData = byteData.buffer.asUint8List()
        ..devicePixelRatio = devicePixelRatio
        ..timestampMs = Int64(DateTime.now().millisecondsSinceEpoch)
        ..testName = _currentTestName ?? '';

      _grpcServer.pushFrame(frame);
    } catch (e) {
      debugPrint('Error capturing frame: $e');
    }
  }

  String? _currentTestName;

  void setTestName(String name) {
    _currentTestName = name;
    _grpcServer.setTestName(name);
  }

  @override
  void scheduleFrame() {
    if (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.benchmark) {
      return;
    }
    // Don't capture on every frame - only capture when pump() is called
    // This prevents excessive frame capture at 60fps
    super.scheduleFrame();
  }

  void _captureCurrentFrame() {
    if (!_serverStarted) return;

    try {
      // In newer Flutter versions, we need to get the RenderView from the binding
      // rather than casting from rootElement.renderObject
      final renderView = renderViews.firstOrNull;
      if (renderView == null) return;

      final layer = renderView.debugLayer as OffsetLayer?;
      if (layer == null) return;

      final logicalSize = renderView.size;
      final devicePixelRatio =
          platformDispatcher.implicitView?.devicePixelRatio ?? 2.0;

      final image = layer.toImageSync(
        Offset.zero & (logicalSize * devicePixelRatio),
        pixelRatio: 1.0,
      );

      _sendFrame(image, logicalSize, devicePixelRatio);
    } catch (e, st) {
      debugPrint('Error in _captureCurrentFrame: $e\n$st');
    }
  }

  Future<void> _sendFrame(
    ui.Image image,
    ui.Size logicalSize,
    double devicePixelRatio,
  ) async {
    try {
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();

      if (byteData == null) return;

      final frame = Frame()
        ..width = image.width
        ..height = image.height
        ..rgbaData = byteData.buffer.asUint8List()
        ..devicePixelRatio = devicePixelRatio
        ..timestampMs = Int64(DateTime.now().millisecondsSinceEpoch)
        ..testName = _currentTestName ?? '';

      _grpcServer.pushFrame(frame);
      _framesSent++;
      print('FRAME_CAPTURED:${frame.width}x${frame.height}');
    } catch (e) {
      debugPrint('Error sending frame: $e');
    }
  }

  /// Returns the number of frames sent during this test session.
  int get framesSent => _framesSent;

  @override
  bool get inTest => _inTest;
  bool _inTest = false;

  @override
  Clock get clock => const Clock();

  @override
  int get microtaskCount {
    assert(
        false, 'microtaskCount cannot be reported when running in real time');
    return -1;
  }

  @override
  Timeout get defaultTestTimeout => Timeout.none;

  // Use fadePointers instead of fullyLive to prevent continuous frame scheduling
  // We only want frames when pump() is called, not at 60fps continuously
  @override
  LiveTestWidgetsFlutterBindingFramePolicy framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fadePointers;

  Completer<void>? _pendingFrame;
  bool _expectingFrame = false;
  bool _expectingFrameToReassemble = false;
  bool _viewNeedsPaint = false;
  bool _runningAsyncTasks = false;
  bool? _doDrawThisFrame;

  @override
  Future<void> delayed(Duration duration) {
    return Future<void>.delayed(duration);
  }

  @override
  void scheduleForcedFrame() {
    if (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.benchmark) {
      return;
    }
    super.scheduleForcedFrame();
  }

  @override
  Future<void> reassembleApplication() async {
    _expectingFrameToReassemble = true;
    await super.reassembleApplication();
  }

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    assert(_doDrawThisFrame == null);
    if (_expectingFrame ||
        _expectingFrameToReassemble ||
        (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.fullyLive) ||
        (framePolicy ==
            LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive) ||
        (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.benchmark) ||
        (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.fadePointers &&
            _viewNeedsPaint)) {
      _doDrawThisFrame = true;
      super.handleBeginFrame(rawTimeStamp);
    } else {
      _doDrawThisFrame = false;
    }
  }

  @override
  void handleDrawFrame() {
    assert(_doDrawThisFrame != null);
    if (_doDrawThisFrame!) {
      super.handleDrawFrame();
    }
    _doDrawThisFrame = null;
    _viewNeedsPaint = false;
    _expectingFrameToReassemble = false;
    if (_expectingFrame) {
      assert(_pendingFrame != null);
      // Capture frame ONLY when pump() was called (expectingFrame is true)
      _captureCurrentFrame();
      _pendingFrame!.complete();
      _pendingFrame = null;
      _expectingFrame = false;
    }
    // Don't continuously schedule frames - only when pump() is called
  }

  @override
  Future<void> pump(
      [Duration? duration,
      EnginePhase newPhase = EnginePhase.sendSemanticsUpdate]) async {
    assert(newPhase == EnginePhase.sendSemanticsUpdate);
    assert(inTest);
    assert(!_expectingFrame);
    assert(_pendingFrame == null);

    if (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive) {
      return delayed(duration ?? Duration.zero);
    }

    await TestAsyncUtils.guard<void>(() {
      if (duration != null) {
        Timer(duration, () {
          _expectingFrame = true;
          scheduleFrame();
        });
      } else {
        _expectingFrame = true;
        scheduleFrame();
      }
      _pendingFrame = Completer<void>();
      return _pendingFrame!.future;
    });
  }

  @override
  Future<T?> runAsync<T>(
    Future<T> Function() callback, {
    Duration additionalTime = const Duration(milliseconds: 1000),
  }) async {
    assert(() {
      if (!_runningAsyncTasks) {
        return true;
      }
      fail('Reentrant call to runAsync() denied.');
    }());

    _runningAsyncTasks = true;
    try {
      return await callback();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'Flutter test framework',
        context: ErrorSummary('while running async test code'),
      ));
      return null;
    } finally {
      _runningAsyncTasks = false;
    }
  }

  @override
  Future<void> runTest(
    Future<void> Function() testBody,
    VoidCallback invariantTester, {
    String description = '',
    @Deprecated('This parameter has no effect.') Duration? timeout,
  }) {
    assert(!inTest);
    _inTest = true;
    _currentTestName = description;
    _grpcServer.setTestName(description);
    return _runTest(testBody, invariantTester, description);
  }

  FlutterExceptionHandler? _oldExceptionHandler;
  late StackTraceDemangler _oldStackTraceDemangler;
  FlutterErrorDetails? _pendingExceptionDetails;
  Zone? _parentZone;

  Future<void> _runTest(
    Future<void> Function() testBody,
    VoidCallback invariantTester,
    String description,
  ) {
    assert(inTest);
    _oldExceptionHandler = FlutterError.onError;
    _oldStackTraceDemangler = FlutterError.demangleStackTrace;

    int exceptionCount = 0;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_pendingExceptionDetails != null) {
        debugPrint = debugPrintOverride;
        if (exceptionCount == 0) {
          exceptionCount = 2;
          FlutterError.dumpErrorToConsole(_pendingExceptionDetails!,
              forceReport: true);
        } else {
          exceptionCount += 1;
        }
        FlutterError.dumpErrorToConsole(details, forceReport: true);
        _pendingExceptionDetails = FlutterErrorDetails(
          exception: 'Multiple exceptions ($exceptionCount) were detected.',
          library: 'Flutter test framework',
        );
      } else {
        reportExceptionNoticed(details);
        _pendingExceptionDetails = details;
      }
    };

    FlutterError.demangleStackTrace = (StackTrace stack) {
      if (stack is stack_trace.Trace) {
        return stack.vmTrace;
      }
      if (stack is stack_trace.Chain) {
        return stack.toTrace().vmTrace;
      }
      return stack;
    };

    final testCompleter = Completer<void>();
    final testCompletionHandler =
        _createTestCompletionHandler(description, testCompleter);

    void handleUncaughtError(Object exception, StackTrace stack) {
      if (testCompleter.isCompleted) {
        debugPrint = debugPrintOverride;
        FlutterError.dumpErrorToConsole(
            FlutterErrorDetails(
              exception: exception,
              stack: stack,
              context: ErrorDescription(
                  'running a test (but after the test had completed)'),
              library: 'Flutter test framework',
            ),
            forceReport: true);
        return;
      }

      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        context: ErrorDescription('running a test'),
        library: 'Flutter test framework',
      ));

      assert(_parentZone != null);
      _parentZone!.run<void>(testCompletionHandler);
    }

    final errorHandlingZoneSpecification = ZoneSpecification(
        handleUncaughtError: (Zone self, ZoneDelegate parent, Zone zone,
            Object exception, StackTrace stack) {
      handleUncaughtError(exception, stack);
    });

    _parentZone = Zone.current;
    final testZone =
        _parentZone!.fork(specification: errorHandlingZoneSpecification);
    testZone
        .runBinary<Future<void>, Future<void> Function(), VoidCallback>(
            _runTestBody, testBody, invariantTester)
        .whenComplete(testCompletionHandler);

    return testCompleter.future;
  }

  Future<void> _runTestBody(
    Future<void> Function() testBody,
    VoidCallback invariantTester,
  ) async {
    assert(inTest);

    runApp(Container(key: UniqueKey()));
    await pump();

    await testBody();
    asyncBarrier();
  }

  VoidCallback _createTestCompletionHandler(
      String testDescription, Completer<void> completer) {
    return () {
      assert(Zone.current == _parentZone);
      if (_pendingExceptionDetails != null) {
        debugPrint = debugPrintOverride;
        reportTestException(_pendingExceptionDetails!, testDescription);
        _pendingExceptionDetails = null;
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    };
  }

  @override
  void reportExceptionNoticed(FlutterErrorDetails exception) {
    final testPrint = debugPrint;
    debugPrint = debugPrintOverride;
    debugPrint(
        '(The following exception is now available via WidgetTester.takeException:)');
    FlutterError.dumpErrorToConsole(exception, forceReport: true);
    debugPrint = testPrint;
  }

  @override
  void postTest() {
    assert(inTest);
    FlutterError.onError = _oldExceptionHandler;
    FlutterError.demangleStackTrace = _oldStackTraceDemangler;
    _pendingExceptionDetails = null;
    _parentZone = null;
    _inTest = false;
  }

  @override
  HitTestDispatcher? deviceEventDispatcher;

  @override
  bool get semanticsEnabled => true;

  @override
  TextPainter? get label => null;

  @override
  void setLabel(String value) {}
}
