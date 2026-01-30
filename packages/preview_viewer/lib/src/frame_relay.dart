import 'dart:async';
import 'dart:convert';

import 'package:preview_core/preview_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Relays frames from a gRPC test connection to browser WebSocket connections.
///
/// Key feature: Caches ALL frames so they can be replayed to browsers that
/// connect after the test has finished. This is essential because the browser
/// often connects after the test completes.
class FrameRelay {
  final PreviewGrpcClient _grpcClient = PreviewGrpcClient();
  final List<WebSocketChannel> _browserConnections = [];
  StreamSubscription<Frame>? _frameSubscription;

  /// Cache of ALL frames received during the test session.
  /// Unlike a ring buffer, this keeps everything so late-connecting browsers
  /// can see the entire test run.
  final List<Frame> _frameCache = [];

  /// Whether the gRPC stream has ended (test finished)
  bool _streamEnded = false;

  /// Number of frames received
  int get frameCount => _frameCache.length;

  /// Whether frames are available for replay
  bool get hasFrames => _frameCache.isNotEmpty;

  /// Whether the test stream has ended
  bool get isStreamEnded => _streamEnded;

  /// Get a specific frame by index (0-based)
  Frame? getFrame(int index) =>
      index >= 0 && index < _frameCache.length ? _frameCache[index] : null;

  /// Get the last captured frame
  Frame? get lastFrame => _frameCache.isNotEmpty ? _frameCache.last : null;

  /// Get the first captured frame
  Frame? get firstFrame => _frameCache.isNotEmpty ? _frameCache.first : null;

  /// Get all frames
  List<Frame> get allFrames => List.unmodifiable(_frameCache);

  /// Get metadata for all frames (useful for listing without transferring image data)
  List<Map<String, dynamic>> get frameMetadata => _frameCache
      .asMap()
      .entries
      .map((e) => {
            'index': e.key,
            'width': e.value.width,
            'height': e.value.height,
            'devicePixelRatio': e.value.devicePixelRatio,
            'timestampMs': e.value.timestampMs.toInt(),
            'testName': e.value.testName,
          })
      .toList();

  Future<void> connectToTest(String host, int port) async {
    // Clear any previous session data
    _frameCache.clear();
    _streamEnded = false;

    await _grpcClient.connect(host, port);
    print('Connected to test gRPC server at $host:$port');

    final stream = _grpcClient.watchFrames();

    _frameSubscription = stream.listen(
      (frame) {
        print(
            'Frame received: ${frame.width}x${frame.height} (total: ${_frameCache.length + 1})');
        _handleFrame(frame);
      },
      onError: (error) {
        print('gRPC stream error (test may have ended): $error');
        _streamEnded = true;
        // Don't clear the cache! Browsers can still connect and see the frames.
      },
      onDone: () {
        print(
            'gRPC stream closed. ${_frameCache.length} frames cached for replay.');
        _streamEnded = true;
      },
    );
  }

  void addBrowserConnection(WebSocketChannel channel) {
    _browserConnections.add(channel);
    print('Browser connected (${_browserConnections.length} total)');

    // Send ALL cached frames to the newly connected browser
    if (_frameCache.isNotEmpty) {
      print('Replaying ${_frameCache.length} cached frames to new browser');
      for (var i = 0; i < _frameCache.length; i++) {
        _sendFrameToBrowser(channel, _frameCache[i], index: i);
      }

      if (_streamEnded) {
        // Let the browser know the test has finished
        _sendTestComplete(channel);
      }
    } else if (_streamEnded) {
      print('Browser connected but no frames were captured');
      _sendNoFrames(channel);
    } else {
      print('Browser connected, waiting for frames...');
    }

    channel.stream.listen(
      (message) {
        // Handle any messages from browser if needed
      },
      onDone: () {
        _browserConnections.remove(channel);
        print('Browser disconnected (${_browserConnections.length} remaining)');
      },
      onError: (e) {
        _browserConnections.remove(channel);
        print('Browser connection error: $e');
      },
    );
  }

  void _handleFrame(Frame frame) {
    // Cache the frame (keep all frames, no limit)
    _frameCache.add(frame);

    // Send to all currently connected browsers
    for (final connection in _browserConnections) {
      _sendFrameToBrowser(connection, frame);
    }
  }

  void _sendFrameToBrowser(WebSocketChannel connection, Frame frame,
      {int? index}) {
    final frameIndex = index ?? _frameCache.indexOf(frame);
    final metadata = jsonEncode({
      'type': 'frame',
      'index': frameIndex,
      'width': frame.width,
      'height': frame.height,
      'devicePixelRatio': frame.devicePixelRatio,
      'timestampMs': frame.timestampMs.toInt(),
      'testName': frame.testName,
    });

    try {
      connection.sink.add(metadata);
      connection.sink.add(frame.rgbaData);
    } catch (e) {
      print('Error sending frame to browser: $e');
    }
  }

  void _sendTestComplete(WebSocketChannel connection) {
    // Calculate total duration from first to last frame
    int totalDurationMs = 0;
    int firstTimestampMs = 0;
    if (_frameCache.length >= 2) {
      firstTimestampMs = _frameCache.first.timestampMs.toInt();
      totalDurationMs = _frameCache.last.timestampMs.toInt() - firstTimestampMs;
    }

    // Build frame timeline data (relative timestamps)
    final frameTimeline = _frameCache.asMap().entries.map((e) {
      final relativeMs = _frameCache.isNotEmpty
          ? e.value.timestampMs.toInt() - firstTimestampMs
          : 0;
      return {
        'index': e.key,
        'relativeMs': relativeMs,
      };
    }).toList();

    try {
      connection.sink.add(jsonEncode({
        'type': 'testComplete',
        'totalFrames': _frameCache.length,
        'totalDurationMs': totalDurationMs,
        'frameTimeline': frameTimeline,
      }));
    } catch (e) {
      print('Error sending test complete: $e');
    }
  }

  void _sendNoFrames(WebSocketChannel connection) {
    try {
      connection.sink.add(jsonEncode({
        'type': 'noFrames',
        'message': 'Test completed but no frames were captured',
      }));
    } catch (e) {
      print('Error sending no frames message: $e');
    }
  }

  /// Clears the frame cache. Call this when starting a new test session.
  void clearCache() {
    _frameCache.clear();
    _streamEnded = false;
    print('Frame cache cleared');
  }

  Future<void> disconnect() async {
    await _frameSubscription?.cancel();
    await _grpcClient.disconnect();

    // Close browser connections but DON'T clear the frame cache
    // so we can still serve frames if browsers reconnect
    final connections = List.of(_browserConnections);
    _browserConnections.clear();
    for (final connection in connections) {
      await connection.sink.close();
    }
    print('Relay disconnected (${_frameCache.length} frames still cached)');
  }
}
