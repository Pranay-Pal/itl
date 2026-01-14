import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class ImageCompressionService {
  /// Compresses the image to ensure it is preferably under 500KB.
  ///
  /// [file] - The original XFile from ImagePicker.
  /// Returns a new [XFile] pointing to the compressed image, or the original if compression fails.
  static Future<XFile> compressImage(XFile file) async {
    final String path = file.path;
    final int size = await file.length();

    // If already smaller than 500KB (500 * 1024 bytes), return original
    if (size < 500 * 1024) {
      debugPrint(
          'ImageCompression: Original image is small enough (${(size / 1024).toStringAsFixed(1)} KB). No compression needed.');
      return file;
    }

    debugPrint(
        'ImageCompression: Compressing image... Original: ${(size / 1024).toStringAsFixed(1)} KB');

    try {
      final String targetPath = '${path}_compressed.jpg';

      // Attempt aggressive compression to ensure < 500KB
      // Resize to max 1024px width/height and quality 85 which is usually very safe for photos
      var result = await FlutterImageCompress.compressAndGetFile(
        path,
        targetPath,
        quality: 85,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result != null) {
        final int newSize = await result.length();
        debugPrint(
            'ImageCompression: Pass 1 Result: ${(newSize / 1024).toStringAsFixed(1)} KB');

        // If still > 500KB, try one more aggressive pass
        if (newSize > 500 * 1024) {
          final String aggressivePath = '${path}_compressed_v2.jpg';
          result = await FlutterImageCompress.compressAndGetFile(
            path,
            aggressivePath,
            quality: 70, // Lower quality
            minWidth: 800, // Smaller dimensions
            minHeight: 800,
          );
          if (result != null) {
            final int finalSize = await result.length();
            debugPrint(
                'ImageCompression: Pass 2 Result: ${(finalSize / 1024).toStringAsFixed(1)} KB');
          }
        }

        return result ?? file;
      } else {
        debugPrint('ImageCompression: Compression returned null.');
        return file;
      }
    } catch (e) {
      debugPrint('ImageCompression: Error compressing image: $e');
      return file;
    }
  }
}
