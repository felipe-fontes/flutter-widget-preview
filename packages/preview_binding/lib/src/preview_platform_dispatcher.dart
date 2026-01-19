import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

typedef OnFrameCaptured = void Function(
  Scene scene,
  Size physicalSize,
  double devicePixelRatio,
);

class PreviewPlatformDispatcher implements TestPlatformDispatcher {
  PreviewPlatformDispatcher({
    required PlatformDispatcher platformDispatcher,
    required this.onFrameCaptured,
  }) : _platformDispatcher = platformDispatcher {
    _updateViewsAndDisplays();
    _platformDispatcher.onMetricsChanged = _handleMetricsChanged;
  }

  final OnFrameCaptured onFrameCaptured;
  final PlatformDispatcher _platformDispatcher;

  final Map<int, PreviewFlutterView> _testViews = <int, PreviewFlutterView>{};
  final Map<int, PreviewDisplay> _testDisplays = <int, PreviewDisplay>{};

  @override
  PreviewFlutterView? get implicitView {
    return _platformDispatcher.implicitView != null
        ? _testViews[_platformDispatcher.implicitView!.viewId]
        : null;
  }

  VoidCallback? _onMetricsChanged;

  @override
  VoidCallback? get onMetricsChanged => _platformDispatcher.onMetricsChanged;

  @override
  set onMetricsChanged(VoidCallback? callback) {
    _onMetricsChanged = callback;
  }

  void _handleMetricsChanged() {
    _updateViewsAndDisplays();
    _onMetricsChanged?.call();
  }

  void _updateViewsAndDisplays() {
    final extraDisplayKeys = <Object>[..._testDisplays.keys];
    for (final display in _platformDispatcher.displays) {
      extraDisplayKeys.remove(display.id);
      if (!_testDisplays.containsKey(display.id)) {
        _testDisplays[display.id] = PreviewDisplay(this, display);
      }
    }
    extraDisplayKeys.forEach(_testDisplays.remove);

    final extraViewKeys = <Object>[..._testViews.keys];
    for (final view in _platformDispatcher.views) {
      late final PreviewDisplay display;
      try {
        final realDisplay = view.display;
        if (_testDisplays.containsKey(realDisplay.id)) {
          display = _testDisplays[view.display.id]!;
        } else {
          display = PreviewDisplay(this, view.display);
        }
      } catch (error) {
        display = PreviewDisplay(this, view.display);
      }

      extraViewKeys.remove(view.viewId);
      if (!_testViews.containsKey(view.viewId)) {
        _testViews[view.viewId] = PreviewFlutterView(
          view: view,
          platformDispatcher: this,
          display: display,
          onRender: onFrameCaptured,
        );
      }
    }
    extraViewKeys.forEach(_testViews.remove);
  }

  @override
  Iterable<PreviewFlutterView> get views => _testViews.values;

  @override
  FlutterView? view({required int id}) => _testViews[id];

  @override
  Iterable<PreviewDisplay> get displays => _testDisplays.values;

  @override
  Locale get locale => _localeTestValue ?? _platformDispatcher.locale;
  Locale? _localeTestValue;

  @override
  set localeTestValue(Locale localeTestValue) {
    _localeTestValue = localeTestValue;
    onLocaleChanged?.call();
  }

  @override
  void clearLocaleTestValue() {
    _localeTestValue = null;
    onLocaleChanged?.call();
  }

  @override
  List<Locale> get locales => _localesTestValue ?? _platformDispatcher.locales;
  List<Locale>? _localesTestValue;

  @override
  set localesTestValue(List<Locale> localesTestValue) {
    _localesTestValue = localesTestValue;
    onLocaleChanged?.call();
  }

  @override
  void clearLocalesTestValue() {
    _localesTestValue = null;
    onLocaleChanged?.call();
  }

  @override
  VoidCallback? get onLocaleChanged => _platformDispatcher.onLocaleChanged;
  @override
  set onLocaleChanged(VoidCallback? callback) {
    _platformDispatcher.onLocaleChanged = callback;
  }

  @override
  String get initialLifecycleState => _initialLifecycleStateTestValue;
  String _initialLifecycleStateTestValue = '';

  @override
  set initialLifecycleStateTestValue(String state) {
    _initialLifecycleStateTestValue = state;
  }

  @override
  void resetInitialLifecycleState() {
    _initialLifecycleStateTestValue = '';
  }

  @override
  double get textScaleFactor =>
      _textScaleFactorTestValue ?? _platformDispatcher.textScaleFactor;
  double? _textScaleFactorTestValue;

  @override
  set textScaleFactorTestValue(double textScaleFactorTestValue) {
    _textScaleFactorTestValue = textScaleFactorTestValue;
    onTextScaleFactorChanged?.call();
  }

  @override
  void clearTextScaleFactorTestValue() {
    _textScaleFactorTestValue = null;
    onTextScaleFactorChanged?.call();
  }

  @override
  Brightness get platformBrightness =>
      _platformBrightnessTestValue ?? _platformDispatcher.platformBrightness;
  Brightness? _platformBrightnessTestValue;

  @override
  VoidCallback? get onPlatformBrightnessChanged =>
      _platformDispatcher.onPlatformBrightnessChanged;
  @override
  set onPlatformBrightnessChanged(VoidCallback? callback) {
    _platformDispatcher.onPlatformBrightnessChanged = callback;
  }

  @override
  set platformBrightnessTestValue(Brightness platformBrightnessTestValue) {
    _platformBrightnessTestValue = platformBrightnessTestValue;
    onPlatformBrightnessChanged?.call();
  }

  @override
  void clearPlatformBrightnessTestValue() {
    _platformBrightnessTestValue = null;
    onPlatformBrightnessChanged?.call();
  }

  @override
  bool get alwaysUse24HourFormat =>
      _alwaysUse24HourFormatTestValue ??
      _platformDispatcher.alwaysUse24HourFormat;
  bool? _alwaysUse24HourFormatTestValue;

  @override
  set alwaysUse24HourFormatTestValue(bool alwaysUse24HourFormatTestValue) {
    _alwaysUse24HourFormatTestValue = alwaysUse24HourFormatTestValue;
  }

  @override
  void clearAlwaysUse24HourTestValue() {
    _alwaysUse24HourFormatTestValue = null;
  }

  @override
  VoidCallback? get onTextScaleFactorChanged =>
      _platformDispatcher.onTextScaleFactorChanged;
  @override
  set onTextScaleFactorChanged(VoidCallback? callback) {
    _platformDispatcher.onTextScaleFactorChanged = callback;
  }

  @override
  bool get nativeSpellCheckServiceDefined =>
      _nativeSpellCheckServiceDefinedTestValue ??
      _platformDispatcher.nativeSpellCheckServiceDefined;
  bool? _nativeSpellCheckServiceDefinedTestValue;

  @override
  set nativeSpellCheckServiceDefinedTestValue(
      bool nativeSpellCheckServiceDefinedTestValue) {
    _nativeSpellCheckServiceDefinedTestValue =
        nativeSpellCheckServiceDefinedTestValue;
  }

  @override
  void clearNativeSpellCheckServiceDefined() {
    _nativeSpellCheckServiceDefinedTestValue = null;
  }

  @override
  bool get brieflyShowPassword =>
      _brieflyShowPasswordTestValue ?? _platformDispatcher.brieflyShowPassword;
  bool? _brieflyShowPasswordTestValue;

  @override
  set brieflyShowPasswordTestValue(bool brieflyShowPasswordTestValue) {
    _brieflyShowPasswordTestValue = brieflyShowPasswordTestValue;
  }

  @override
  void resetBrieflyShowPassword() {
    _brieflyShowPasswordTestValue = null;
  }

  @override
  FrameCallback? get onBeginFrame => _platformDispatcher.onBeginFrame;
  @override
  set onBeginFrame(FrameCallback? callback) {
    _platformDispatcher.onBeginFrame = callback;
  }

  @override
  VoidCallback? get onDrawFrame => _platformDispatcher.onDrawFrame;
  @override
  set onDrawFrame(VoidCallback? callback) {
    _platformDispatcher.onDrawFrame = callback;
  }

  @override
  TimingsCallback? get onReportTimings => _platformDispatcher.onReportTimings;
  @override
  set onReportTimings(TimingsCallback? callback) {
    _platformDispatcher.onReportTimings = callback;
  }

  @override
  PointerDataPacketCallback? get onPointerDataPacket =>
      _platformDispatcher.onPointerDataPacket;
  @override
  set onPointerDataPacket(PointerDataPacketCallback? callback) {
    _platformDispatcher.onPointerDataPacket = callback;
  }

  @override
  String get defaultRouteName =>
      _defaultRouteNameTestValue ?? _platformDispatcher.defaultRouteName;
  String? _defaultRouteNameTestValue;

  @override
  set defaultRouteNameTestValue(String defaultRouteNameTestValue) {
    _defaultRouteNameTestValue = defaultRouteNameTestValue;
  }

  @override
  void clearDefaultRouteNameTestValue() {
    _defaultRouteNameTestValue = null;
  }

  @override
  void scheduleFrame() {
    _platformDispatcher.scheduleFrame();
  }

  @override
  bool get semanticsEnabled =>
      _semanticsEnabledTestValue ?? _platformDispatcher.semanticsEnabled;
  bool? _semanticsEnabledTestValue;

  @override
  set semanticsEnabledTestValue(bool semanticsEnabledTestValue) {
    _semanticsEnabledTestValue = semanticsEnabledTestValue;
    onSemanticsEnabledChanged?.call();
  }

  @override
  void clearSemanticsEnabledTestValue() {
    _semanticsEnabledTestValue = null;
    onSemanticsEnabledChanged?.call();
  }

  @override
  VoidCallback? get onSemanticsEnabledChanged =>
      _platformDispatcher.onSemanticsEnabledChanged;
  @override
  set onSemanticsEnabledChanged(VoidCallback? callback) {
    _platformDispatcher.onSemanticsEnabledChanged = callback;
  }

  @override
  SemanticsActionEventCallback? get onSemanticsActionEvent =>
      _platformDispatcher.onSemanticsActionEvent;
  @override
  set onSemanticsActionEvent(SemanticsActionEventCallback? callback) {
    _platformDispatcher.onSemanticsActionEvent = callback;
  }

  @override
  AccessibilityFeatures get accessibilityFeatures =>
      _accessibilityFeaturesTestValue ??
      _platformDispatcher.accessibilityFeatures;
  AccessibilityFeatures? _accessibilityFeaturesTestValue;

  @override
  set accessibilityFeaturesTestValue(
      AccessibilityFeatures accessibilityFeaturesTestValue) {
    _accessibilityFeaturesTestValue = accessibilityFeaturesTestValue;
    onAccessibilityFeaturesChanged?.call();
  }

  @override
  void clearAccessibilityFeaturesTestValue() {
    _accessibilityFeaturesTestValue = null;
    onAccessibilityFeaturesChanged?.call();
  }

  @override
  VoidCallback? get onAccessibilityFeaturesChanged =>
      _platformDispatcher.onAccessibilityFeaturesChanged;
  @override
  set onAccessibilityFeaturesChanged(VoidCallback? callback) {
    _platformDispatcher.onAccessibilityFeaturesChanged = callback;
  }

  @override
  void setIsolateDebugName(String name) {
    _platformDispatcher.setIsolateDebugName(name);
  }

  @override
  void sendPlatformMessage(
    String name,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) {
    _platformDispatcher.sendPlatformMessage(name, data, callback);
  }

  @override
  void clearAllTestValues() {
    clearAccessibilityFeaturesTestValue();
    clearAlwaysUse24HourTestValue();
    clearDefaultRouteNameTestValue();
    clearPlatformBrightnessTestValue();
    clearLocaleTestValue();
    clearLocalesTestValue();
    clearSemanticsEnabledTestValue();
    clearTextScaleFactorTestValue();
    clearNativeSpellCheckServiceDefined();
    resetBrieflyShowPassword();
    resetInitialLifecycleState();
    resetSystemFontFamily();
  }

  @override
  VoidCallback? get onFrameDataChanged =>
      _platformDispatcher.onFrameDataChanged;
  @override
  set onFrameDataChanged(VoidCallback? value) {
    _platformDispatcher.onFrameDataChanged = value;
  }

  @override
  KeyDataCallback? get onKeyData => _platformDispatcher.onKeyData;
  @override
  set onKeyData(KeyDataCallback? onKeyData) {
    _platformDispatcher.onKeyData = onKeyData;
  }

  @override
  VoidCallback? get onPlatformConfigurationChanged =>
      _platformDispatcher.onPlatformConfigurationChanged;
  @override
  set onPlatformConfigurationChanged(
      VoidCallback? onPlatformConfigurationChanged) {
    _platformDispatcher.onPlatformConfigurationChanged =
        onPlatformConfigurationChanged;
  }

  @override
  Locale? computePlatformResolvedLocale(List<Locale> supportedLocales) =>
      _platformDispatcher.computePlatformResolvedLocale(supportedLocales);

  @override
  ByteData? getPersistentIsolateData() =>
      _platformDispatcher.getPersistentIsolateData();

  @override
  ErrorCallback? get onError => _platformDispatcher.onError;
  @override
  set onError(ErrorCallback? value) {
    _platformDispatcher.onError;
  }

  @override
  VoidCallback? get onSystemFontFamilyChanged =>
      _platformDispatcher.onSystemFontFamilyChanged;
  @override
  set onSystemFontFamilyChanged(VoidCallback? value) {
    _platformDispatcher.onSystemFontFamilyChanged = value;
  }

  @override
  FrameData get frameData => _platformDispatcher.frameData;

  @override
  void registerBackgroundIsolate(RootIsolateToken token) {
    _platformDispatcher.registerBackgroundIsolate(token);
  }

  @override
  void requestDartPerformanceMode(DartPerformanceMode mode) {
    _platformDispatcher.requestDartPerformanceMode(mode);
  }

  @override
  String? get systemFontFamily {
    return _forceSystemFontFamilyToBeNull
        ? null
        : _systemFontFamily ?? _platformDispatcher.systemFontFamily;
  }

  String? _systemFontFamily;
  bool _forceSystemFontFamilyToBeNull = false;

  @override
  set systemFontFamily(String? value) {
    _systemFontFamily = value;
    if (value == null) {
      _forceSystemFontFamilyToBeNull = true;
    }
    onSystemFontFamilyChanged?.call();
  }

  @override
  void resetSystemFontFamily() {
    _systemFontFamily = null;
    _forceSystemFontFamilyToBeNull = false;
    onSystemFontFamilyChanged?.call();
  }

  @override
  void updateSemantics(SemanticsUpdate update) {
    _platformDispatcher.updateSemantics(update);
  }

  @override
  bool get supportsShowingSystemContextMenu =>
      _platformDispatcher.supportsShowingSystemContextMenu;

  @override
  double scaleFontSize(double unscaledFontSize) =>
      _platformDispatcher.scaleFontSize(unscaledFontSize);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class PreviewFlutterView implements TestFlutterView {
  PreviewFlutterView({
    required FlutterView view,
    required PreviewPlatformDispatcher platformDispatcher,
    required PreviewDisplay display,
    required this.onRender,
  })  : _view = view,
        _platformDispatcher = platformDispatcher,
        _display = display;

  final FlutterView _view;
  final OnFrameCaptured onRender;

  @override
  PreviewPlatformDispatcher get platformDispatcher => _platformDispatcher;
  final PreviewPlatformDispatcher _platformDispatcher;

  @override
  PreviewDisplay get display => _display;
  final PreviewDisplay _display;

  @override
  int get viewId => _view.viewId;

  @override
  double get devicePixelRatio =>
      _display._devicePixelRatio ?? _view.devicePixelRatio;

  @override
  set devicePixelRatio(double value) {
    _display.devicePixelRatio = value;
  }

  @override
  void resetDevicePixelRatio() {
    _display.resetDevicePixelRatio();
  }

  @override
  List<DisplayFeature> get displayFeatures =>
      _displayFeatures ?? _view.displayFeatures;
  List<DisplayFeature>? _displayFeatures;

  @override
  set displayFeatures(List<DisplayFeature> value) {
    _displayFeatures = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void resetDisplayFeatures() {
    _displayFeatures = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  FakeViewPadding get padding =>
      _padding ?? _PreviewFakeViewPadding._wrap(_view.padding);
  FakeViewPadding? _padding;

  @override
  set padding(FakeViewPadding value) {
    _padding = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void resetPadding() {
    _padding = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  Size get physicalSize => _physicalSize ?? _view.physicalSize;
  Size? _physicalSize;

  @override
  set physicalSize(Size value) {
    _physicalSize = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void resetPhysicalSize() {
    _physicalSize = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  ViewConstraints get physicalConstraints {
    final size = physicalSize;
    return ViewConstraints(
      minWidth: 0,
      maxWidth: size.width,
      minHeight: 0,
      maxHeight: size.height,
    );
  }

  @override
  FakeViewPadding get systemGestureInsets =>
      _systemGestureInsets ??
      _PreviewFakeViewPadding._wrap(_view.systemGestureInsets);
  FakeViewPadding? _systemGestureInsets;

  @override
  set systemGestureInsets(FakeViewPadding value) {
    _systemGestureInsets = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void resetSystemGestureInsets() {
    _systemGestureInsets = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  FakeViewPadding get viewInsets =>
      _viewInsets ?? _PreviewFakeViewPadding._wrap(_view.viewInsets);
  FakeViewPadding? _viewInsets;

  @override
  set viewInsets(FakeViewPadding value) {
    _viewInsets = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void resetViewInsets() {
    _viewInsets = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  FakeViewPadding get viewPadding =>
      _viewPadding ?? _PreviewFakeViewPadding._wrap(_view.viewPadding);
  FakeViewPadding? _viewPadding;

  @override
  set viewPadding(FakeViewPadding value) {
    _viewPadding = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void resetViewPadding() {
    _viewPadding = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  GestureSettings get gestureSettings =>
      _gestureSettings ?? _view.gestureSettings;
  GestureSettings? _gestureSettings;

  @override
  set gestureSettings(GestureSettings value) {
    _gestureSettings = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void resetGestureSettings() {
    _gestureSettings = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void render(Scene scene, {Size? size}) {
    onRender(scene, physicalSize, devicePixelRatio);
  }

  @override
  void updateSemantics(SemanticsUpdate update) {
    _view.updateSemantics(update);
  }

  @override
  void reset() {
    resetDevicePixelRatio();
    resetDisplayFeatures();
    resetPadding();
    resetSystemGestureInsets();
    resetViewInsets();
    resetViewPadding();
    resetGestureSettings();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class PreviewDisplay implements TestDisplay {
  PreviewDisplay(
      PreviewPlatformDispatcher platformDispatcher, Display display)
      : _platformDispatcher = platformDispatcher,
        _display = display;

  final Display _display;
  final PreviewPlatformDispatcher _platformDispatcher;

  @override
  int get id => _display.id;

  @override
  double get devicePixelRatio => _devicePixelRatio ?? _display.devicePixelRatio;
  double? _devicePixelRatio;

  @override
  set devicePixelRatio(double value) {
    _devicePixelRatio = value;
    _platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void resetDevicePixelRatio() {
    _devicePixelRatio = null;
    _platformDispatcher.onMetricsChanged?.call();
  }

  @override
  double get refreshRate => _refreshRate ?? _display.refreshRate;
  double? _refreshRate;

  @override
  set refreshRate(double value) {
    _refreshRate = value;
    _platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void resetRefreshRate() {
    _refreshRate = null;
    _platformDispatcher.onMetricsChanged?.call();
  }

  @override
  Size get size => _size ?? _display.size;
  Size? _size;

  @override
  set size(Size value) {
    _size = value;
    _platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void resetSize() {
    _size = null;
    _platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void reset() {
    resetDevicePixelRatio();
    resetRefreshRate();
    resetSize();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

@immutable
class _PreviewFakeViewPadding implements FakeViewPadding {
  const _PreviewFakeViewPadding({
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
  });

  _PreviewFakeViewPadding._wrap(ViewPadding base)
      : left = base.left,
        top = base.top,
        right = base.right,
        bottom = base.bottom;

  @override
  final double left;
  @override
  final double top;
  @override
  final double right;
  @override
  final double bottom;
}
