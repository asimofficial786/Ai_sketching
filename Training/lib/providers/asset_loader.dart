import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';

/// Asset metadata class - moved outside of AssetLoader class
class AssetMetadata {
  final String path;
  final int size;
  final DateTime lastAccessed;
  final int loadCount;

  AssetMetadata({
    required this.path,
    required this.size,
    required this.lastAccessed,
    required this.loadCount,
  });

  AssetMetadata copyWith({
    String? path,
    int? size,
    DateTime? lastAccessed,
    int? loadCount,
  }) {
    return AssetMetadata(
      path: path ?? this.path,
      size: size ?? this.size,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      loadCount: loadCount ?? this.loadCount,
    );
  }
}

/// AssetLoader - A comprehensive utility for loading and caching assets
class AssetLoader {
  // Singleton pattern
  static final AssetLoader _instance = AssetLoader._internal();
  factory AssetLoader() => _instance;
  AssetLoader._internal();

  // Cache for loaded images
  final Map<String, ImageProvider> _imageCache = {};

  // Cache for asset existence checks
  final Map<String, bool> _assetExistsCache = {};

  // Cache for loaded byte data
  final Map<String, Uint8List> _byteDataCache = {};

  // Cache for asset metadata (size, modification time, etc.)
  final Map<String, AssetMetadata> _metadataCache = {};

  // Loading states to prevent multiple simultaneous loads
  final Map<String, Future<bool>> _loadingStates = {};

  // Preload queue
  final List<String> _preloadQueue = [];
  bool _isPreloading = false;

  /// Check if asset exists with caching
  Future<bool> assetExists(String path) async {
    if (path.isEmpty) return false;

    // Return from cache if available
    if (_assetExistsCache.containsKey(path)) {
      _updateMetadata(path);
      return _assetExistsCache[path]!;
    }

    // Check if already loading
    if (_loadingStates.containsKey(path)) {
      return _loadingStates[path]!;
    }

    // Create loading future
    final future = _checkAssetExists(path);
    _loadingStates[path] = future;

    final result = await future;
    _loadingStates.remove(path);

    return result;
  }

  Future<bool> _checkAssetExists(String path) async {
    try {
      await rootBundle.load(path);
      _assetExistsCache[path] = true;
      _metadataCache[path] = AssetMetadata(
        path: path,
        size: 0, // Will be updated when loading
        lastAccessed: DateTime.now(),
        loadCount: 0,
      );
      return true;
    } catch (e) {
      print('⚠️ Asset not found: $path - $e');
      _assetExistsCache[path] = false;
      return false;
    }
  }

  /// Load image with caching
  Future<ImageProvider> loadImage(String path) async {
    if (path.isEmpty) {
      return _getFallbackImage();
    }

    // Return from cache if available
    if (_imageCache.containsKey(path)) {
      _updateMetadata(path);
      return _imageCache[path]!;
    }

    // Check if asset exists
    final exists = await assetExists(path);
    if (!exists) {
      print('❌ Cannot load image - asset does not exist: $path');
      return _getFallbackImage();
    }

    try {
      // Load and cache the image
      final provider = AssetImage(path);

      // Pre-resolve the image to ensure it's valid
      await _precacheImage(provider);

      _imageCache[path] = provider;
      _updateMetadata(path, incrementLoadCount: true);

      return provider;
    } catch (e) {
      print('❌ Error loading image: $path - $e');
      return _getFallbackImage();
    }
  }

  /// Precache an image - FIXED: Using proper ImageStream approach
  Future<void> _precacheImage(ImageProvider provider) async {
    final completer = Completer<void>();

    // Use PaintingBinding.instance to properly handle image cache
    final imageStream = provider.resolve(ImageConfiguration.empty);

    void listener(ImageInfo imageInfo, bool synchronousCall) {
      // Dispose the image to free memory
      imageInfo.image.dispose();
      completer.complete();
    }

    // Add listener and handle errors
    imageStream.addListener(
      ImageStreamListener(listener, onError: (dynamic error, StackTrace? stackTrace) {
        completer.completeError(error);
      }),
    );

    // Timeout to prevent hanging
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        // Cannot remove listener easily, but we'll complete the future
        throw TimeoutException('Image precache timeout');
      },
    );
  }

  /// Load image as bytes with caching
  Future<Uint8List?> loadImageBytes(String path) async {
    if (path.isEmpty) return null;

    // Return from cache if available
    if (_byteDataCache.containsKey(path)) {
      _updateMetadata(path);
      return _byteDataCache[path];
    }

    // Check if asset exists
    final exists = await assetExists(path);
    if (!exists) {
      print('❌ Cannot load bytes - asset does not exist: $path');
      return null;
    }

    try {
      final byteData = await rootBundle.load(path);
      final bytes = byteData.buffer.asUint8List();

      _byteDataCache[path] = bytes;
      _updateMetadata(path,
          size: byteData.lengthInBytes,
          incrementLoadCount: true
      );

      return bytes;
    } catch (e) {
      print('❌ Error loading bytes: $path - $e');
      return null;
    }
  }

  /// Get fallback image for error cases
  ImageProvider _getFallbackImage() {
    // Return a transparent 1x1 pixel image as fallback
    return MemoryImage(Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]));
  }

  /// Preload multiple assets - FIXED: Proper type casting
  Future<void> preloadAssets(List<String> paths, {
    void Function(double)? onProgress,
  }) async {
    if (_isPreloading) {
      _preloadQueue.addAll(paths);
      return;
    }

    _isPreloading = true;
    final total = paths.length;
    var completed = 0;

    try {
      for (final path in paths) {
        try {
          // Check if asset exists
          final exists = await assetExists(path);
          if (exists) {
            // Load bytes to cache
            await loadImageBytes(path);
          }
        } catch (e) {
          print('⚠️ Failed to preload: $path - $e');
        } finally {
          completed++;
          onProgress?.call(completed / total);
        }
      }
    } finally {
      _isPreloading = false;

      // Process queue if any
      if (_preloadQueue.isNotEmpty) {
        final queue = List<String>.from(_preloadQueue);
        _preloadQueue.clear();
        preloadAssets(queue, onProgress: onProgress);
      }
    }
  }

  /// Update metadata for an asset
  void _updateMetadata(String path, {
    int? size,
    bool incrementLoadCount = false,
  }) {
    if (!_metadataCache.containsKey(path)) {
      _metadataCache[path] = AssetMetadata(
        path: path,
        size: size ?? 0,
        lastAccessed: DateTime.now(),
        loadCount: incrementLoadCount ? 1 : 0,
      );
    } else {
      final current = _metadataCache[path]!;
      _metadataCache[path] = current.copyWith(
        lastAccessed: DateTime.now(),
        loadCount: incrementLoadCount ? current.loadCount + 1 : current.loadCount,
        size: size ?? current.size,
      );
    }
  }

  /// Clear specific asset from cache
  void clearAsset(String path) {
    _imageCache.remove(path);
    _byteDataCache.remove(path);
    // Keep existence check but clear other caches
    print('🗑️ Cleared cache for: $path');
  }

  /// Clear all caches
  void clearAllCaches() {
    _imageCache.clear();
    _byteDataCache.clear();
    // Keep existence checks but clear everything else
    print('🗑️ Cleared all caches');
  }

  /// Clear only image caches (keep existence checks)
  void clearImageCache() {
    _imageCache.clear();
    print('🗑️ Cleared image cache');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'images': _imageCache.length,
      'bytes': _byteDataCache.length,
      'existenceChecks': _assetExistsCache.length,
      'metadata': _metadataCache.length,
      'totalEntries': _imageCache.length +
          _byteDataCache.length +
          _assetExistsCache.length,
    };
  }

  /// Get list of missing assets
  List<String> getMissingAssets() {
    return _assetExistsCache.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get list of loaded assets
  List<String> getLoadedAssets() {
    return _assetExistsCache.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get asset metadata
  AssetMetadata? getAssetMetadata(String path) {
    return _metadataCache[path];
  }

  /// Check if asset is cached
  bool isAssetCached(String path) {
    return _imageCache.containsKey(path) || _byteDataCache.containsKey(path);
  }

  /// Get cache size estimation (in bytes)
  int estimateCacheSize() {
    int total = 0;
    for (final bytes in _byteDataCache.values) {
      total += bytes.length;
    }
    return total;
  }

  /// Warm up cache by loading essential assets
  Future<void> warmupCache(List<String> essentialPaths) async {
    print('🔥 Warming up cache with ${essentialPaths.length} assets');
    await preloadAssets(essentialPaths);
    print('✅ Cache warmup complete');
  }

  /// Retry loading a failed asset
  Future<bool> retryLoad(String path) async {
    print('🔄 Retrying load for: $path');

    // Clear from failed cache
    _assetExistsCache.remove(path);
    _imageCache.remove(path);
    _byteDataCache.remove(path);

    // Try loading again
    return await assetExists(path);
  }

  /// Verify all assets in a list
  Future<Map<String, bool>> verifyAssets(List<String> paths) async {
    final results = <String, bool>{};

    for (final path in paths) {
      results[path] = await assetExists(path);
    }

    return results;
  }
}

/// SafeAssetImage - A robust Image widget with built-in error handling and caching
class SafeAssetImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final Widget? errorWidget;
  final Widget? loadingWidget;
  final bool useCache;
  final VoidCallback? onLoadSuccess;
  final Function(dynamic)? onLoadError;

  const SafeAssetImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.color,
    this.errorWidget,
    this.loadingWidget,
    this.useCache = true,
    this.onLoadSuccess,
    this.onLoadError,
  });

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return _buildErrorWidget('Empty path');
    }

    return FutureBuilder<bool>(
      future: AssetLoader().assetExists(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }

        if (snapshot.hasError || !(snapshot.data ?? false)) {
          return _buildErrorWidget(
              snapshot.error?.toString() ?? 'Asset not found'
          );
        }

        return _buildImage();
      },
    );
  }

  Widget _buildImage() {
    if (useCache) {
      return FutureBuilder<ImageProvider>(
        future: AssetLoader().loadImage(path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingWidget();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorWidget(snapshot.error?.toString());
          }

          return Image(
            image: snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            color: color,
            errorBuilder: (context, error, stackTrace) {
              onLoadError?.call(error);
              return _buildErrorWidget(error.toString());
            },
          );
        },
      );
    }

    // Direct loading without cache
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        onLoadError?.call(error);
        return _buildErrorWidget(error.toString());
      },
    );
  }

  Widget _buildLoadingWidget() {
    return loadingWidget ?? Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: SizedBox(
          width: (width ?? 40) * 0.3,
          height: (height ?? 40) * 0.3,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String? error) {
    if (errorWidget != null) return errorWidget!;

    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image,
                size: (width ?? 40) * 0.3,
                color: Colors.grey[600]
            ),
            if (width == null || (width! > 50)) ...[
              const SizedBox(height: 4),
              Text(
                'Image not found',
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
              ),
              Text(
                _getFileName(path),
                style: TextStyle(color: Colors.grey[500], fontSize: 8),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFileName(String path) {
    try {
      return path.split('/').last;
    } catch (e) {
      return 'unknown';
    }
  }
}

/// AssetPreloader - Widget to preload assets before showing content
class AssetPreloader extends StatefulWidget {
  final List<String> assets;
  final WidgetBuilder builder;
  final Widget? loadingWidget;
  final VoidCallback? onComplete;
  final ValueChanged<double>? onProgress;

  const AssetPreloader({
    super.key,
    required this.assets,
    required this.builder,
    this.loadingWidget,
    this.onComplete,
    this.onProgress,
  });

  @override
  State<AssetPreloader> createState() => _AssetPreloaderState();
}

class _AssetPreloaderState extends State<AssetPreloader> {
  bool _isLoading = true;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _preloadAssets();
  }

  Future<void> _preloadAssets() async {
    await AssetLoader().preloadAssets(
      widget.assets,
      onProgress: (progress) {
        setState(() {
          _progress = progress;
        });
        widget.onProgress?.call(progress);
      },
    );

    setState(() {
      _isLoading = false;
    });
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ?? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading assets... ${(_progress * 100).toInt()}%'),
          ],
        ),
      );
    }

    return widget.builder(context);
  }
}

/// Extension methods for easier asset loading
extension AssetLoaderExtension on BuildContext {
  Future<bool> assetExists(String path) => AssetLoader().assetExists(path);
  Future<ImageProvider> loadImage(String path) => AssetLoader().loadImage(path);
  Future<Uint8List?> loadImageBytes(String path) => AssetLoader().loadImageBytes(path);
}