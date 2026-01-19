// This is a generated file - do not edit.
//
// Generated from preview.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use emptyDescriptor instead')
const Empty$json = {
  '1': 'Empty',
};

/// Descriptor for `Empty`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emptyDescriptor =
    $convert.base64Decode('CgVFbXB0eQ==');

@$core.Deprecated('Use watchRequestDescriptor instead')
const WatchRequest$json = {
  '1': 'WatchRequest',
};

/// Descriptor for `WatchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchRequestDescriptor =
    $convert.base64Decode('CgxXYXRjaFJlcXVlc3Q=');

@$core.Deprecated('Use frameDescriptor instead')
const Frame$json = {
  '1': 'Frame',
  '2': [
    {'1': 'rgba_data', '3': 1, '4': 1, '5': 12, '10': 'rgbaData'},
    {'1': 'width', '3': 2, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 3, '4': 1, '5': 5, '10': 'height'},
    {
      '1': 'device_pixel_ratio',
      '3': 4,
      '4': 1,
      '5': 1,
      '10': 'devicePixelRatio'
    },
    {'1': 'timestamp_ms', '3': 5, '4': 1, '5': 3, '10': 'timestampMs'},
    {'1': 'test_name', '3': 6, '4': 1, '5': 9, '10': 'testName'},
  ],
};

/// Descriptor for `Frame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List frameDescriptor = $convert.base64Decode(
    'CgVGcmFtZRIbCglyZ2JhX2RhdGEYASABKAxSCHJnYmFEYXRhEhQKBXdpZHRoGAIgASgFUgV3aW'
    'R0aBIWCgZoZWlnaHQYAyABKAVSBmhlaWdodBIsChJkZXZpY2VfcGl4ZWxfcmF0aW8YBCABKAFS'
    'EGRldmljZVBpeGVsUmF0aW8SIQoMdGltZXN0YW1wX21zGAUgASgDUgt0aW1lc3RhbXBNcxIbCg'
    'l0ZXN0X25hbWUYBiABKAlSCHRlc3ROYW1l');

@$core.Deprecated('Use statusDescriptor instead')
const Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'is_running', '3': 1, '4': 1, '5': 8, '10': 'isRunning'},
    {'1': 'test_name', '3': 2, '4': 1, '5': 9, '10': 'testName'},
    {'1': 'frame_count', '3': 3, '4': 1, '5': 5, '10': 'frameCount'},
    {'1': 'server_uri', '3': 4, '4': 1, '5': 9, '10': 'serverUri'},
  ],
};

/// Descriptor for `Status`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List statusDescriptor = $convert.base64Decode(
    'CgZTdGF0dXMSHQoKaXNfcnVubmluZxgBIAEoCFIJaXNSdW5uaW5nEhsKCXRlc3RfbmFtZRgCIA'
    'EoCVIIdGVzdE5hbWUSHwoLZnJhbWVfY291bnQYAyABKAVSCmZyYW1lQ291bnQSHQoKc2VydmVy'
    'X3VyaRgEIAEoCVIJc2VydmVyVXJp');
