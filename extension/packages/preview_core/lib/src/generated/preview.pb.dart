// This is a generated file - do not edit.
//
// Generated from preview.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Empty extends $pb.GeneratedMessage {
  factory Empty() => create();

  Empty._();

  factory Empty.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Empty.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Empty',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fontes_widget_viewer'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty copyWith(void Function(Empty) updates) =>
      super.copyWith((message) => updates(message as Empty)) as Empty;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Empty create() => Empty._();
  @$core.override
  Empty createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Empty getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Empty>(create);
  static Empty? _defaultInstance;
}

class WatchRequest extends $pb.GeneratedMessage {
  factory WatchRequest() => create();

  WatchRequest._();

  factory WatchRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WatchRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WatchRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fontes_widget_viewer'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchRequest copyWith(void Function(WatchRequest) updates) =>
      super.copyWith((message) => updates(message as WatchRequest))
          as WatchRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WatchRequest create() => WatchRequest._();
  @$core.override
  WatchRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WatchRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WatchRequest>(create);
  static WatchRequest? _defaultInstance;
}

class Frame extends $pb.GeneratedMessage {
  factory Frame({
    $core.List<$core.int>? rgbaData,
    $core.int? width,
    $core.int? height,
    $core.double? devicePixelRatio,
    $fixnum.Int64? timestampMs,
    $core.String? testName,
  }) {
    final result = create();
    if (rgbaData != null) result.rgbaData = rgbaData;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (devicePixelRatio != null) result.devicePixelRatio = devicePixelRatio;
    if (timestampMs != null) result.timestampMs = timestampMs;
    if (testName != null) result.testName = testName;
    return result;
  }

  Frame._();

  factory Frame.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Frame.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Frame',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fontes_widget_viewer'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'rgbaData', $pb.PbFieldType.OY)
    ..aI(2, _omitFieldNames ? '' : 'width')
    ..aI(3, _omitFieldNames ? '' : 'height')
    ..aD(4, _omitFieldNames ? '' : 'devicePixelRatio')
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..aOS(6, _omitFieldNames ? '' : 'testName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Frame clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Frame copyWith(void Function(Frame) updates) =>
      super.copyWith((message) => updates(message as Frame)) as Frame;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Frame create() => Frame._();
  @$core.override
  Frame createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Frame getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Frame>(create);
  static Frame? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get rgbaData => $_getN(0);
  @$pb.TagNumber(1)
  set rgbaData($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRgbaData() => $_has(0);
  @$pb.TagNumber(1)
  void clearRgbaData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get width => $_getIZ(1);
  @$pb.TagNumber(2)
  set width($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWidth() => $_has(1);
  @$pb.TagNumber(2)
  void clearWidth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get height => $_getIZ(2);
  @$pb.TagNumber(3)
  set height($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeight() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get devicePixelRatio => $_getN(3);
  @$pb.TagNumber(4)
  set devicePixelRatio($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDevicePixelRatio() => $_has(3);
  @$pb.TagNumber(4)
  void clearDevicePixelRatio() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestampMs => $_getI64(4);
  @$pb.TagNumber(5)
  set timestampMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTimestampMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimestampMs() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get testName => $_getSZ(5);
  @$pb.TagNumber(6)
  set testName($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTestName() => $_has(5);
  @$pb.TagNumber(6)
  void clearTestName() => $_clearField(6);
}

class Status extends $pb.GeneratedMessage {
  factory Status({
    $core.bool? isRunning,
    $core.String? testName,
    $core.int? frameCount,
    $core.String? serverUri,
  }) {
    final result = create();
    if (isRunning != null) result.isRunning = isRunning;
    if (testName != null) result.testName = testName;
    if (frameCount != null) result.frameCount = frameCount;
    if (serverUri != null) result.serverUri = serverUri;
    return result;
  }

  Status._();

  factory Status.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Status.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Status',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fontes_widget_viewer'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'isRunning')
    ..aOS(2, _omitFieldNames ? '' : 'testName')
    ..aI(3, _omitFieldNames ? '' : 'frameCount')
    ..aOS(4, _omitFieldNames ? '' : 'serverUri')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Status clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Status copyWith(void Function(Status) updates) =>
      super.copyWith((message) => updates(message as Status)) as Status;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Status create() => Status._();
  @$core.override
  Status createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Status getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Status>(create);
  static Status? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isRunning => $_getBF(0);
  @$pb.TagNumber(1)
  set isRunning($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsRunning() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsRunning() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get testName => $_getSZ(1);
  @$pb.TagNumber(2)
  set testName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTestName() => $_has(1);
  @$pb.TagNumber(2)
  void clearTestName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get frameCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set frameCount($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFrameCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearFrameCount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get serverUri => $_getSZ(3);
  @$pb.TagNumber(4)
  set serverUri($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasServerUri() => $_has(3);
  @$pb.TagNumber(4)
  void clearServerUri() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
