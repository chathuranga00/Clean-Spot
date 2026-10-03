import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Utility class for image optimization, resizing, and EXIF metadata stripping.
/// 
/// Privacy & Bandwidth:
/// CleanSpot reports must strip device EXIF tags (such as camera metadata, device serials,
/// and embedded photo EXIF GPS) to protect citizen privacy before uploading to public/PHI storage.
/// Location is independently verified via device live GPS with high accuracy.
class ImageProcessor {
  static const int defaultMaxDimension = 1280;
  static const int defaultJpegQuality = 80;

  /// Compresses the provided raw bytes, scales the resolution if larger than [maxDimension],
  /// and strips all EXIF metadata by re-encoding the raw decoded pixel buffer into JPEG.
  static Future<Uint8List> compressAndStripExif(
    Uint8List rawBytes, {
    int maxDimension = defaultMaxDimension,
    int quality = defaultJpegQuality,
  }) async {
    final image = img.decodeImage(rawBytes);
    if (image == null) {
      throw const FormatException('Unable to decode image data.');
    }

    // Fix orientation according to EXIF if it had an orientation tag
    final orientedImage = img.bakeOrientation(image);

    // Calculate scaled dimensions while preserving aspect ratio
    img.Image resizedImage = orientedImage;
    if (orientedImage.width > maxDimension || orientedImage.height > maxDimension) {
      if (orientedImage.width > orientedImage.height) {
        resizedImage = img.copyResize(
          orientedImage,
          width: maxDimension,
          interpolation: img.Interpolation.linear,
        );
      } else {
        resizedImage = img.copyResize(
          orientedImage,
          height: maxDimension,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // Encoding as JPEG from the raw pixel buffer removes all EXIF and metadata blocks
    final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
    return Uint8List.fromList(compressedBytes);
  }
}
