import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Converts RGBA raw data to PNG format
class ImageConverter {
  /// Convert RGBA byte data to PNG bytes
  static Uint8List rgbaToPng(
    List<int> rgbaData, {
    required int width,
    required int height,
  }) {
    // Create image from RGBA data
    final image = img.Image(width: width, height: height, numChannels: 4);

    // Copy RGBA data into image pixels
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        final r = rgbaData[offset];
        final g = rgbaData[offset + 1];
        final b = rgbaData[offset + 2];
        final a = rgbaData[offset + 3];
        image.setPixelRgba(x, y, r, g, b, a);
      }
    }

    // Encode to PNG
    return Uint8List.fromList(img.encodePng(image));
  }
}
