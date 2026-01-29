import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Font location - either bundled with the extension or from the system.
enum FontLocation {
  /// Font bundled with the preview extension
  preview,

  /// Font from the macOS system fonts
  macSystem,
}

/// Represents a font to load with its file and family names.
class PreviewFont {
  final List<String> families;
  final String file;
  final FontLocation location;

  const PreviewFont(this.location, this.file, this.families);
}

/// System fonts to load for proper rendering.
/// Includes Roboto (Material default) and SF fonts (Cupertino default).
const _systemFonts = [
  PreviewFont(FontLocation.preview, 'Roboto-Regular.ttf', ['Roboto']),
  PreviewFont(
    FontLocation.macSystem,
    'SFNS.ttf',
    [
      'CupertinoSystemDisplay',
      'CupertinoSystemText',
      // Default generic Android font families
      'sans-serif',
      'sans-serif-condensed',
      'serif',
      'monospace',
      'serif-monospace',
      'casual',
      'cursive',
      'sans-serif-smallcaps',
    ],
  ),
];

/// Loads all fonts needed for proper widget test rendering.
///
/// This loads:
/// 1. All fonts declared in the app's FontManifest.json
/// 2. System fonts (Roboto, SF fonts) from the extension's fonts folder
///
/// [fontsPath] is the path to the extension's fonts folder containing Roboto-Regular.ttf
Future<void> loadPreviewFonts(String fontsPath) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Load app-declared fonts from FontManifest.json
  try {
    final fontManifest = await rootBundle.loadStructuredData<Iterable<dynamic>>(
      'FontManifest.json',
      (string) async => json.decode(string) as Iterable<dynamic>,
    );

    for (final font in fontManifest.whereType<Map<String, dynamic>>()) {
      final fontFamily = _deriveFontFamily(font);
      final fontLoader = FontLoader(fontFamily);

      final fonts = font['fonts'] as Iterable<dynamic>?;
      if (fonts == null) continue;

      for (final fontType in fonts.whereType<Map<String, dynamic>>()) {
        final asset = fontType['asset'] as String?;
        if (asset != null) {
          fontLoader.addFont(rootBundle.load(asset));
        }
      }

      await fontLoader.load();
    }
  } catch (e) {
    debugPrint('Could not load FontManifest.json: $e');
  }

  // Load system fonts
  await _loadSystemFonts(fontsPath);
}

/// Loads system fonts from the extension's fonts folder and macOS system fonts.
Future<void> _loadSystemFonts(String fontsPath) async {
  for (final font in _systemFonts) {
    final path = font.location == FontLocation.preview
        ? '$fontsPath/${font.file}'
        : '/System/Library/Fonts/${font.file}';

    await _loadFileSystemFont(path, font.families);
  }
}

/// Loads a font file from the file system and registers it with Flutter.
Future<void> _loadFileSystemFont(String path, List<String> families) async {
  final file = File(path);
  if (!file.existsSync()) {
    debugPrint('Font file not found: $path');
    return;
  }

  final bytes = file.readAsBytesSync();
  final byteData = SynchronousFuture(ByteData.view(bytes.buffer));

  for (final family in families) {
    final fontLoader = FontLoader(family);
    fontLoader.addFont(byteData);
    await fontLoader.load();
  }
}

/// Derives the correct font family name from a font definition.
///
/// This handles the case where fonts are bundled in packages and need
/// their family names adjusted to match what Flutter expects.
String _deriveFontFamily(Map<String, dynamic> fontDefinition) {
  if (!fontDefinition.containsKey('family')) {
    return '';
  }

  final fontFamily = fontDefinition['family'] as String;

  if (_overridableFonts.contains(fontFamily)) {
    return fontFamily;
  }

  if (fontFamily.startsWith('packages/')) {
    final fontFamilyName = fontFamily.split('/').last;
    if (_overridableFonts.any((font) => font == fontFamilyName)) {
      return fontFamilyName;
    }
  } else {
    final fonts = fontDefinition['fonts'] as Iterable<dynamic>?;
    if (fonts != null) {
      for (final fontType in fonts.whereType<Map<String, dynamic>>()) {
        final asset = fontType['asset'] as String?;
        if (asset != null && asset.startsWith('packages')) {
          final packageName = asset.split('/')[1];
          return 'packages/$packageName/$fontFamily';
        }
      }
    }
  }
  return fontFamily;
}

/// Fonts that can be overridden with loaded versions.
/// These are the default Material and Cupertino fonts.
const List<String> _overridableFonts = [
  'Roboto',
  '.SF UI Display',
  '.SF UI Text',
  '.SF Pro Text',
  '.SF Pro Display',
  'CupertinoSystemDisplay',
  'CupertinoSystemText',
];
