import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'frame_relay.dart';

class ViewerServer {
  final FrameRelay _relay;
  HttpServer? _server;

  ViewerServer(this._relay);

  Future<int> start({int port = 8080}) async {
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_createHandler());

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print('VIEWER_SERVER_STARTED:http://localhost:${_server!.port}');
    return _server!.port;
  }

  Handler _createHandler() {
    return (Request request) {
      if (request.url.path == 'ws') {
        return _handleWebSocket(request);
      }

      if (request.url.path == '' || request.url.path == '/') {
        return Response.ok(_viewerHtml, headers: {
          'content-type': 'text/html',
        });
      }

      return Response.notFound('Not found');
    };
  }

  Future<Response> _handleWebSocket(Request request) async {
    final handler =
        webSocketHandler((WebSocketChannel channel, String? protocol) {
      _relay.addBrowserConnection(channel);
    });
    return await handler(request);
  }

  Future<void> stop() async {
    await _server?.close();
    print('VIEWER_SERVER_STOPPED');
  }

  static const _viewerHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Flutter Widget Preview</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
    }
    body {
      background: #1a1a2e;
      display: flex;
      flex-direction: column;
      font-family: 'SF Mono', 'Fira Code', monospace;
      color: #eee;
    }
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 16px;
      background: rgba(0, 0, 0, 0.3);
      flex-shrink: 0;
    }
    h1 {
      font-size: 14px;
      font-weight: 500;
      color: #888;
      text-transform: uppercase;
      letter-spacing: 2px;
    }
    #status {
      font-size: 12px;
      color: #4ade80;
      padding: 6px 12px;
      background: rgba(74, 222, 128, 0.1);
      border-radius: 4px;
    }
    #status.disconnected {
      color: #f87171;
      background: rgba(248, 113, 113, 0.1);
    }
    .canvas-wrapper {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 16px;
      min-height: 0;
      overflow: hidden;
    }
    .canvas-container {
      background: #16213e;
      border-radius: 12px;
      padding: 16px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
      max-width: 100%;
      max-height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    #preview {
      display: block;
      border-radius: 8px;
      background: #0f0f23;
      max-width: 100%;
      max-height: calc(100vh - 200px);
      object-fit: contain;
    }
    
    /* Playback Controls */
    .playback-container {
      padding: 12px 16px;
      background: rgba(0, 0, 0, 0.4);
      flex-shrink: 0;
    }
    .playback-controls {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 8px;
    }
    .playback-btn {
      background: rgba(255, 255, 255, 0.1);
      border: none;
      color: #ccc;
      width: 32px;
      height: 32px;
      border-radius: 6px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 14px;
      transition: all 0.15s ease;
    }
    .playback-btn:hover {
      background: rgba(255, 255, 255, 0.2);
      color: #fff;
    }
    .playback-btn:active {
      transform: scale(0.95);
    }
    .playback-btn.play-pause {
      width: 40px;
      height: 40px;
      background: #4f46e5;
      color: #fff;
    }
    .playback-btn.play-pause:hover {
      background: #6366f1;
    }
    .speed-select {
      background: rgba(255, 255, 255, 0.1);
      border: none;
      color: #ccc;
      padding: 6px 10px;
      border-radius: 6px;
      font-size: 12px;
      cursor: pointer;
    }
    .time-display {
      font-size: 12px;
      color: #888;
      min-width: 140px;
      text-align: right;
    }
    .frame-counter {
      font-size: 12px;
      color: #666;
      margin-left: auto;
    }
    
    /* Timeline Track */
    .timeline-container {
      position: relative;
      height: 24px;
      display: flex;
      align-items: center;
    }
    .timeline-track {
      position: relative;
      flex: 1;
      height: 6px;
      background: rgba(255, 255, 255, 0.1);
      border-radius: 3px;
      cursor: pointer;
    }
    .timeline-progress {
      position: absolute;
      left: 0;
      top: 0;
      height: 100%;
      background: linear-gradient(90deg, #4f46e5, #7c3aed);
      border-radius: 3px;
      pointer-events: none;
    }
    .timeline-playhead {
      position: absolute;
      top: 50%;
      width: 14px;
      height: 14px;
      background: #fff;
      border-radius: 50%;
      transform: translate(-50%, -50%);
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4);
      pointer-events: none;
      z-index: 10;
    }
    
    /* Frame Markers */
    .frame-markers {
      position: absolute;
      left: 0;
      right: 0;
      top: 50%;
      transform: translateY(-50%);
      height: 20px;
      pointer-events: none;
    }
    .frame-marker {
      position: absolute;
      width: 8px;
      height: 8px;
      background: rgba(255, 255, 255, 0.3);
      border-radius: 50%;
      transform: translate(-50%, -50%);
      top: 50%;
      transition: all 0.15s ease;
      pointer-events: auto;
      cursor: pointer;
    }
    .frame-marker:hover {
      background: rgba(255, 255, 255, 0.6);
      transform: translate(-50%, -50%) scale(1.3);
    }
    .frame-marker.active {
      background: #4f46e5;
      box-shadow: 0 0 8px rgba(79, 70, 229, 0.6);
    }
    .frame-marker.current {
      background: #fff;
      transform: translate(-50%, -50%) scale(1.4);
      box-shadow: 0 0 12px rgba(255, 255, 255, 0.6);
    }
    
    /* Tooltip */
    .marker-tooltip {
      position: absolute;
      bottom: 100%;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(0, 0, 0, 0.9);
      color: #fff;
      padding: 4px 8px;
      border-radius: 4px;
      font-size: 10px;
      white-space: nowrap;
      pointer-events: none;
      opacity: 0;
      transition: opacity 0.15s ease;
      margin-bottom: 8px;
    }
    .frame-marker:hover .marker-tooltip {
      opacity: 1;
    }
    
    .footer {
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 8px 16px;
      background: rgba(0, 0, 0, 0.3);
      flex-shrink: 0;
    }
    .info {
      font-size: 11px;
      color: #666;
    }
    
    /* Waiting state */
    .waiting-message {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: #666;
      font-size: 14px;
      text-align: center;
    }
    .waiting-message .spinner {
      width: 24px;
      height: 24px;
      border: 2px solid rgba(255,255,255,0.1);
      border-top-color: #4f46e5;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin: 0 auto 12px;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>Widget Preview</h1>
    <div id="status" class="disconnected">Connecting...</div>
  </div>
  <div class="canvas-wrapper">
    <div class="canvas-container">
      <canvas id="preview"></canvas>
      <div id="waitingMessage" class="waiting-message">
        <div class="spinner"></div>
        Waiting for frames...
      </div>
    </div>
  </div>
  
  <div class="playback-container">
    <div class="playback-controls">
      <button id="skipStart" class="playback-btn" title="Skip to start">⏮</button>
      <button id="prevFrame" class="playback-btn" title="Previous frame">◀</button>
      <button id="playPause" class="playback-btn play-pause" title="Play/Pause">▶</button>
      <button id="nextFrame" class="playback-btn" title="Next frame">▶</button>
      <button id="skipEnd" class="playback-btn" title="Skip to end">⏭</button>
      <select id="speedSelect" class="speed-select">
        <option value="0.25">0.25x</option>
        <option value="0.5">0.5x</option>
        <option value="1" selected>1x</option>
        <option value="2">2x</option>
        <option value="4">4x</option>
      </select>
      <div id="timeDisplay" class="time-display">00:00.000 / 00:00.000</div>
      <div id="frameCounter" class="frame-counter">Frame 0/0</div>
    </div>
    <div class="timeline-container">
      <div id="timeline" class="timeline-track">
        <div id="timelineProgress" class="timeline-progress"></div>
        <div id="frameMarkers" class="frame-markers"></div>
        <div id="playhead" class="timeline-playhead"></div>
      </div>
    </div>
  </div>
  
  <div class="footer">
    <div class="info">
      <span id="dimensions">--</span> |
      <span id="fps">-- fps</span>
    </div>
  </div>

  <script>
    const canvas = document.getElementById('preview');
    const ctx = canvas.getContext('2d');
    const status = document.getElementById('status');
    const dimensions = document.getElementById('dimensions');
    const fpsDisplay = document.getElementById('fps');
    const canvasWrapper = document.querySelector('.canvas-wrapper');
    const waitingMessage = document.getElementById('waitingMessage');
    
    // Playback elements
    const playPauseBtn = document.getElementById('playPause');
    const skipStartBtn = document.getElementById('skipStart');
    const skipEndBtn = document.getElementById('skipEnd');
    const prevFrameBtn = document.getElementById('prevFrame');
    const nextFrameBtn = document.getElementById('nextFrame');
    const speedSelect = document.getElementById('speedSelect');
    const timeDisplay = document.getElementById('timeDisplay');
    const frameCounter = document.getElementById('frameCounter');
    const timeline = document.getElementById('timeline');
    const timelineProgress = document.getElementById('timelineProgress');
    const playhead = document.getElementById('playhead');
    const frameMarkersContainer = document.getElementById('frameMarkers');

    // State
    let frameHistory = [];  // {meta, rgbaData, relativeMs}
    let currentFrameIndex = 0;
    let isPlaying = false;
    let playbackFinished = false;
    let playbackSpeed = 1;
    let playbackStartTime = null;
    let playbackStartPosition = 0;
    let totalDurationMs = 0;
    let testComplete = false;
    let animationFrameId = null;
    let pendingMetadata = null;
    let currentMeta = null;

    const MIN_DURATION_MS = 500;  // Minimum playback duration for very short tests
    const DEFAULT_FRAME_INTERVAL_MS = 100; // Fallback: assume 10fps if no timestamps

    function formatTime(ms) {
      if (ms === null || ms === undefined || isNaN(ms)) ms = 0;
      const totalSeconds = Math.floor(ms / 1000);
      const minutes = Math.floor(totalSeconds / 60);
      const seconds = totalSeconds % 60;
      const millis = Math.floor(ms % 1000);
      return String(minutes).padStart(2, '0') + ':' + 
             String(seconds).padStart(2, '0') + '.' + 
             String(millis).padStart(3, '0');
    }

    function connect() {
      const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
      const ws = new WebSocket(protocol + '//' + location.host + '/ws');
      ws.binaryType = 'arraybuffer';

      ws.onopen = () => {
        status.textContent = 'Connected';
        status.classList.remove('disconnected');
      };

      ws.onclose = () => {
        status.textContent = 'Disconnected - Reconnecting...';
        status.classList.add('disconnected');
        setTimeout(connect, 1000);
      };

      ws.onerror = () => {
        ws.close();
      };

      ws.onmessage = (event) => {
        if (typeof event.data === 'string') {
          const data = JSON.parse(event.data);
          
          if (data.type === 'frame') {
            pendingMetadata = data;
          } else if (data.type === 'testComplete') {
            handleTestComplete(data);
          } else if (data.type === 'noFrames') {
            waitingMessage.innerHTML = '<div style="color: #f87171;">No frames captured</div>';
          }
        } else if (event.data instanceof ArrayBuffer && pendingMetadata) {
          receiveFrame(pendingMetadata, new Uint8ClampedArray(event.data));
          pendingMetadata = null;
        }
      };
    }

    function receiveFrame(meta, rgbaData) {
      // Skip ready signal frames (0x0 dimensions) - they're just handshake signals
      if (meta.width === 0 || meta.height === 0) {
        return;
      }
      
      waitingMessage.style.display = 'none';
      
      // Use timestamp if available and valid, otherwise use frame index * default interval
      const frameIndex = meta.index !== undefined ? meta.index : frameHistory.length;
      const hasValidTimestamp = meta.timestampMs && meta.timestampMs > 0;
      const timestampMs = hasValidTimestamp ? meta.timestampMs : (frameIndex * DEFAULT_FRAME_INTERVAL_MS);
      
      // Store frame
      const frameData = { meta, rgbaData, timestampMs: timestampMs, relativeMs: 0 };
      
      // Check if this frame index already exists (replay scenario)
      if (meta.index !== undefined && meta.index < frameHistory.length) {
        frameHistory[meta.index] = frameData;
      } else {
        frameHistory.push(frameData);
      }
      
      // Recalculate relative timestamps
      if (frameHistory.length > 0) {
        const firstTimestamp = frameHistory[0].timestampMs || 0;
        frameHistory.forEach((f, i) => {
          if (f.timestampMs && f.timestampMs > 0) {
            f.relativeMs = f.timestampMs - firstTimestamp;
          } else {
            // Fallback: use frame index for timing
            f.relativeMs = i * DEFAULT_FRAME_INTERVAL_MS;
          }
        });
        const lastRelativeMs = frameHistory[frameHistory.length - 1].relativeMs || 0;
        totalDurationMs = Math.max(lastRelativeMs, MIN_DURATION_MS);
      }
      
      // Show latest frame if not playing and at end
      if (!isPlaying && currentFrameIndex === frameHistory.length - 2) {
        currentFrameIndex = frameHistory.length - 1;
      }
      
      // Render current frame
      renderFrameAtIndex(currentFrameIndex);
      updateTimelineMarkers();
      updateUI();
    }

    function handleTestComplete(data) {
      testComplete = true;
      
      if (data.totalDurationMs !== undefined) {
        totalDurationMs = Math.max(data.totalDurationMs, MIN_DURATION_MS);
      }
      
      // Apply frame timeline data if provided
      if (data.frameTimeline && Array.isArray(data.frameTimeline)) {
        data.frameTimeline.forEach((ft) => {
          if (ft.index < frameHistory.length) {
            frameHistory[ft.index].relativeMs = ft.relativeMs;
          }
        });
      }
      
      updateTimelineMarkers();
      updateUI();
      
      // Auto-play from beginning when test completes
      if (frameHistory.length > 1) {
        currentFrameIndex = 0;
        renderFrameAtIndex(0);
        play();
      }
    }

    function renderFrameAtIndex(index) {
      if (index < 0 || index >= frameHistory.length) return;
      
      const frame = frameHistory[index];
      // Skip frames with invalid dimensions (ready signal frames)
      if (frame.meta.width <= 0 || frame.meta.height <= 0) {
        console.log('renderFrameAtIndex: skipping invalid frame at index ' + index);
        return;
      }
      currentFrameIndex = index;
      renderFrame(frame.meta, frame.rgbaData);
      updateUI();
    }

    function renderFrame(meta, rgbaData) {
      const { width, height, devicePixelRatio } = meta;
      currentMeta = meta;
      
      if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
      }

      const logicalWidth = width / devicePixelRatio;
      const logicalHeight = height / devicePixelRatio;
      
      const availableWidth = canvasWrapper.clientWidth - 64;
      const availableHeight = canvasWrapper.clientHeight - 64;
      
      const scaleX = availableWidth / logicalWidth;
      const scaleY = availableHeight / logicalHeight;
      const scale = Math.min(scaleX, scaleY, 1);
      
      canvas.style.width = Math.round(logicalWidth * scale) + 'px';
      canvas.style.height = Math.round(logicalHeight * scale) + 'px';

      const imageData = new ImageData(rgbaData, width, height);
      ctx.putImageData(imageData, 0, 0);

      dimensions.textContent = Math.round(logicalWidth) + 'x' + Math.round(logicalHeight) + ' @' + devicePixelRatio + 'x';
    }

    function updateTimelineMarkers() {
      frameMarkersContainer.innerHTML = '';
      
      if (frameHistory.length === 0 || totalDurationMs === 0) return;
      
      frameHistory.forEach((frame, index) => {
        const marker = document.createElement('div');
        marker.className = 'frame-marker' + (index === currentFrameIndex ? ' current' : '');
        const position = (frame.relativeMs / totalDurationMs) * 100;
        marker.style.left = position + '%';
        
        const tooltip = document.createElement('div');
        tooltip.className = 'marker-tooltip';
        tooltip.textContent = 'Frame ' + (index + 1) + ' • ' + formatTime(frame.relativeMs);
        marker.appendChild(tooltip);
        
        marker.addEventListener('click', (e) => {
          e.stopPropagation();
          pause();
          seekToFrame(index);
        });
        
        frameMarkersContainer.appendChild(marker);
      });
    }

    function updateUI() {
      // Update frame counter
      frameCounter.textContent = 'Frame ' + (currentFrameIndex + 1) + '/' + frameHistory.length;
      
      // Update time display
      const currentTime = frameHistory.length > 0 ? frameHistory[currentFrameIndex].relativeMs : 0;
      timeDisplay.textContent = formatTime(currentTime) + ' / ' + formatTime(totalDurationMs);
      
      // Update timeline position
      const progress = totalDurationMs > 0 ? (currentTime / totalDurationMs) * 100 : 0;
      timelineProgress.style.width = progress + '%';
      playhead.style.left = progress + '%';
      
      // Show replay icon when finished, pause when playing, play when paused
      if (playbackFinished) {
        playPauseBtn.textContent = '↻';
      } else {
        playPauseBtn.textContent = isPlaying ? '⏸' : '▶';
      }
      
      // Update marker highlighting
      const markers = frameMarkersContainer.querySelectorAll('.frame-marker');
      markers.forEach((marker, index) => {
        marker.classList.toggle('current', index === currentFrameIndex);
      });
    }

    function getFirstValidFrameIndex() {
      for (let i = 0; i < frameHistory.length; i++) {
        if (frameHistory[i].meta.width > 0 && frameHistory[i].meta.height > 0) {
          return i;
        }
      }
      return 0;
    }

    function getLastValidFrameIndex() {
      for (let i = frameHistory.length - 1; i >= 0; i--) {
        if (frameHistory[i].meta.width > 0 && frameHistory[i].meta.height > 0) {
          return i;
        }
      }
      return frameHistory.length - 1;
    }

    function play() {
      console.log('play() called, frameHistory.length=' + frameHistory.length + ', currentFrameIndex=' + currentFrameIndex + ', playbackFinished=' + playbackFinished + ', isPlaying=' + isPlaying);
      if (frameHistory.length < 2) {
        console.log('play() early return - not enough frames');
        return;
      }
      
      // Clear finished state first
      playbackFinished = false;
      
      const lastValidIndex = getLastValidFrameIndex();
      
      // If at end, restart from beginning
      if (currentFrameIndex >= lastValidIndex) {
        console.log('play() restarting from beginning');
        const firstValidIndex = getFirstValidFrameIndex();
        currentFrameIndex = firstValidIndex;
        // Render first valid frame immediately so user sees it
        const frame = frameHistory[firstValidIndex];
        if (frame.meta.width > 0 && frame.meta.height > 0) {
          renderFrame(frame.meta, frame.rgbaData);
        }
      }
      
      isPlaying = true;
      playbackStartTime = performance.now();
      playbackStartPosition = frameHistory[currentFrameIndex]?.relativeMs || 0;
      console.log('play() starting playback at frame ' + currentFrameIndex + ', playbackStartPosition=' + playbackStartPosition + ', totalDurationMs=' + totalDurationMs);
      
      updateUI();
      animationFrameId = requestAnimationFrame(playbackLoop);
    }

    function pause(finished = false) {
      isPlaying = false;
      playbackFinished = finished;
      if (animationFrameId) {
        cancelAnimationFrame(animationFrameId);
        animationFrameId = null;
      }
      updateUI();
    }

    function togglePlayPause() {
      console.log('togglePlayPause() called, isPlaying=' + isPlaying + ', playbackFinished=' + playbackFinished);
      if (isPlaying) {
        pause();
      } else {
        play();
      }
    }

    function playbackLoop(timestamp) {
      if (!isPlaying) {
        console.log('playbackLoop: isPlaying is false, returning');
        return;
      }
      
      const elapsed = (timestamp - playbackStartTime) * playbackSpeed;
      const currentPosition = playbackStartPosition + elapsed;
      
      // Find the frame at or before current position (skip invalid frames)
      let targetIndex = getFirstValidFrameIndex();
      for (let i = frameHistory.length - 1; i >= 0; i--) {
        if (frameHistory[i].relativeMs <= currentPosition) {
          // Skip invalid frames
          if (frameHistory[i].meta.width > 0 && frameHistory[i].meta.height > 0) {
            targetIndex = i;
            break;
          }
        }
      }
      
      if (targetIndex !== currentFrameIndex) {
        renderFrameAtIndex(targetIndex);
      }
      
      // Update progress bar smoothly
      const progress = Math.min((currentPosition / totalDurationMs) * 100, 100);
      timelineProgress.style.width = progress + '%';
      playhead.style.left = progress + '%';
      timeDisplay.textContent = formatTime(Math.min(currentPosition, totalDurationMs)) + ' / ' + formatTime(totalDurationMs);
      
      // Stop at end instead of looping
      if (currentPosition >= totalDurationMs) {
        console.log('playbackLoop: reached end, currentPosition=' + currentPosition + ', totalDurationMs=' + totalDurationMs);
        renderFrameAtIndex(getLastValidFrameIndex());
        pause(true);  // Mark as finished
        return;
      }
      
      animationFrameId = requestAnimationFrame(playbackLoop);
    }

    function seekToFrame(index, clearFinished = true) {
      index = Math.max(0, Math.min(index, frameHistory.length - 1));
      if (clearFinished) playbackFinished = false;
      
      // Find nearest valid frame
      let validIndex = index;
      // First try to find valid frame at or after the requested index
      for (let i = index; i < frameHistory.length; i++) {
        if (frameHistory[i].meta.width > 0 && frameHistory[i].meta.height > 0) {
          validIndex = i;
          break;
        }
      }
      // If not found, try before
      if (frameHistory[validIndex].meta.width <= 0 || frameHistory[validIndex].meta.height <= 0) {
        for (let i = index - 1; i >= 0; i--) {
          if (frameHistory[i].meta.width > 0 && frameHistory[i].meta.height > 0) {
            validIndex = i;
            break;
          }
        }
      }
      
      renderFrameAtIndex(validIndex);
      
      if (isPlaying) {
        playbackStartTime = performance.now();
        playbackStartPosition = frameHistory[validIndex]?.relativeMs || 0;
      }
    }

    function seekToPrevValidFrame() {
      // Find previous valid frame from current position
      for (let i = currentFrameIndex - 1; i >= 0; i--) {
        if (frameHistory[i].meta.width > 0 && frameHistory[i].meta.height > 0) {
          seekToFrame(i);
          return;
        }
      }
    }

    function seekToNextValidFrame() {
      // Find next valid frame from current position
      for (let i = currentFrameIndex + 1; i < frameHistory.length; i++) {
        if (frameHistory[i].meta.width > 0 && frameHistory[i].meta.height > 0) {
          seekToFrame(i);
          return;
        }
      }
    }

    function seekToPosition(positionMs) {
      // Find frame at or before this position
      let targetIndex = 0;
      for (let i = frameHistory.length - 1; i >= 0; i--) {
        if (frameHistory[i].relativeMs <= positionMs) {
          targetIndex = i;
          break;
        }
      }
      seekToFrame(targetIndex);
    }

    // Event listeners
    playPauseBtn.addEventListener('click', togglePlayPause);
    skipStartBtn.addEventListener('click', () => { pause(); seekToFrame(getFirstValidFrameIndex()); });
    skipEndBtn.addEventListener('click', () => { pause(); seekToFrame(getLastValidFrameIndex()); });
    prevFrameBtn.addEventListener('click', () => { pause(); seekToPrevValidFrame(); });
    nextFrameBtn.addEventListener('click', () => { pause(); seekToNextValidFrame(); });
    
    speedSelect.addEventListener('change', (e) => {
      playbackSpeed = parseFloat(e.target.value);
      if (isPlaying) {
        playbackStartTime = performance.now();
        playbackStartPosition = frameHistory[currentFrameIndex].relativeMs;
      }
    });
    
    timeline.addEventListener('click', (e) => {
      const rect = timeline.getBoundingClientRect();
      const clickPosition = (e.clientX - rect.left) / rect.width;
      const targetMs = clickPosition * totalDurationMs;
      pause();
      seekToPosition(targetMs);
    });
    
    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      if (e.code === 'Space') {
        e.preventDefault();
        togglePlayPause();
      } else if (e.code === 'ArrowLeft') {
        e.preventDefault();
        pause();
        seekToFrame(currentFrameIndex - 1);
      } else if (e.code === 'ArrowRight') {
        e.preventDefault();
        pause();
        seekToFrame(currentFrameIndex + 1);
      } else if (e.code === 'Home') {
        e.preventDefault();
        pause();
        seekToFrame(0);
      } else if (e.code === 'End') {
        e.preventDefault();
        pause();
        seekToFrame(frameHistory.length - 1);
      }
    });

    // Handle window resize
    window.addEventListener('resize', () => {
      if (currentMeta) {
        const { width, height, devicePixelRatio } = currentMeta;
        const logicalWidth = width / devicePixelRatio;
        const logicalHeight = height / devicePixelRatio;
        
        const availableWidth = canvasWrapper.clientWidth - 64;
        const availableHeight = canvasWrapper.clientHeight - 64;
        
        const scaleX = availableWidth / logicalWidth;
        const scaleY = availableHeight / logicalHeight;
        const scale = Math.min(scaleX, scaleY, 1);
        
        canvas.style.width = Math.round(logicalWidth * scale) + 'px';
        canvas.style.height = Math.round(logicalHeight * scale) + 'px';
      }
    });

    connect();
  </script>
</body>
</html>
''';
}
