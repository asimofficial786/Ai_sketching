import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class PNGLoader {
  static final Map<String, ui.Image> _imageCache = {};

  static Future<ui.Image?> loadImage(String assetPath) async {
    // Return from cache if available
    if (_imageCache.containsKey(assetPath)) {
      return _imageCache[assetPath];
    }

    try {
      // Load image data
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      // Decode PNG
      final Completer<ui.Image> completer = Completer();
      ui.decodeImageFromList(bytes, (ui.Image img) {
        _imageCache[assetPath] = img;
        completer.complete(img);
      });

      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏱️ Timeout loading image: $assetPath');
          // Throw an exception instead of returning null in timeout
          throw TimeoutException('Image loading timed out');
        },
      );
    } catch (e) {
      print('❌ Error loading PNG: $assetPath - $e');
      return null; // This return null is fine because the function returns Future<ui.Image?>
    }
  }

  static void clearCache() {
    _imageCache.clear();
    print('🗑️ PNG cache cleared');
  }

  static void preloadImages(List<String> paths) {
    for (final path in paths) {
      loadImage(path).catchError((e) {
        // Silently fail for preloading
        print('⚠️ Failed to preload: $path');
      });
    }
  }

  // Optional: Get cache stats
  static Map<String, dynamic> getCacheStats() {
    return {
      'cachedImages': _imageCache.length,
      'cachedPaths': _imageCache.keys.toList(),
    };
  }

  // Optional: Remove specific image from cache
  static void removeFromCache(String assetPath) {
    _imageCache.remove(assetPath);
    print('🗑️ Removed from cache: $assetPath');
  }
}