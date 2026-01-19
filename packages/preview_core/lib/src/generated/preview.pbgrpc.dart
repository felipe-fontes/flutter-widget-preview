// This is a generated file - do not edit.
//
// Generated from preview.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'preview.pb.dart' as $0;

export 'preview.pb.dart';

@$pb.GrpcServiceName('fontes_widget_viewer.PreviewService')
class PreviewServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  PreviewServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseStream<$0.Frame> watchFrames(
    $0.WatchRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$watchFrames, $async.Stream.fromIterable([request]),
        options: options);
  }

  $grpc.ResponseFuture<$0.Status> getStatus(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getStatus, request, options: options);
  }

  // method descriptors

  static final _$watchFrames = $grpc.ClientMethod<$0.WatchRequest, $0.Frame>(
      '/fontes_widget_viewer.PreviewService/WatchFrames',
      ($0.WatchRequest value) => value.writeToBuffer(),
      $0.Frame.fromBuffer);
  static final _$getStatus = $grpc.ClientMethod<$0.Empty, $0.Status>(
      '/fontes_widget_viewer.PreviewService/GetStatus',
      ($0.Empty value) => value.writeToBuffer(),
      $0.Status.fromBuffer);
}

@$pb.GrpcServiceName('fontes_widget_viewer.PreviewService')
abstract class PreviewServiceBase extends $grpc.Service {
  $core.String get $name => 'fontes_widget_viewer.PreviewService';

  PreviewServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.WatchRequest, $0.Frame>(
        'WatchFrames',
        watchFrames_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.WatchRequest.fromBuffer(value),
        ($0.Frame value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.Status>(
        'GetStatus',
        getStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.Status value) => value.writeToBuffer()));
  }

  $async.Stream<$0.Frame> watchFrames_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.WatchRequest> $request) async* {
    yield* watchFrames($call, await $request);
  }

  $async.Stream<$0.Frame> watchFrames(
      $grpc.ServiceCall call, $0.WatchRequest request);

  $async.Future<$0.Status> getStatus_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getStatus($call, await $request);
  }

  $async.Future<$0.Status> getStatus($grpc.ServiceCall call, $0.Empty request);
}
