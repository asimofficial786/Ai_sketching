import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

/// Represents a single point in the drawing.
class AirDrawingPoint {
  final Offset point;
  final Color color;
  final double strokeWidth;
  final DateTime timestamp;

  AirDrawingPoint({
    required this.point,
    required this.color,
    required this.strokeWidth,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'x': point.dx,
    'y': point.dy,
    'color': color.value,
    'strokeWidth': strokeWidth,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AirDrawingPoint.fromJson(Map<String, dynamic> json) => AirDrawingPoint(
    point: Offset(json['x'], json['y']),
    color: Color(json['color']),
    strokeWidth: json['strokeWidth'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

/// Background types for air drawing
enum BackgroundType {
  none,
  indoor,
  outdoor,
  custom,
}

/// Background image data class
class BackgroundImage {
  final String name;
  final String assetPath;
  final BackgroundType type;
  Uint8List? imageBytes;

  BackgroundImage({
    required this.name,
    required this.assetPath,
    required this.type,
    this.imageBytes,
  });
}

/// Handles the core state for air drawing with background support.
class AirDrawingProvider extends ChangeNotifier {
  // ========== DRAWING STATE ==========
  List<AirDrawingPoint> _points = [];
  List<List<AirDrawingPoint>> _drawingHistory = [];
  List<List<AirDrawingPoint>> _redoHistory = []; // NEW: Redo history
  Color _selectedColor = Colors.blueAccent;
  double _strokeWidth = 8.0;
  bool _isDrawing = false;

  // ========== HAND TRACKING STATE ==========
  Offset? _currentCursorPosition;
  List<Offset> _handLandmarks = [];
  bool _handDetected = false;

  // ========== UI STATE ==========
  bool _showHandSkeleton = false;
  bool _showCursor = true;
  double _canvasOpacity = 0.85;
  Color _cursorColor = Colors.yellow;
  double _cursorSize = 12.0;

  // ========== BACKGROUND STATE ==========
  BackgroundImage _selectedBackground = BackgroundImage(
    name: 'None',
    assetPath: '',
    type: BackgroundType.none,
  );
  List<BackgroundImage> _backgrounds = [];
  ImageProvider? _backgroundImageProvider;

  // ========== UTILITIES ==========
  final ScreenshotController _screenshotController = ScreenshotController();

  // ========== CONSTRUCTOR ==========
  AirDrawingProvider() {
    _initializeBackgrounds();
  }

  // ========== GETTERS ==========
  List<AirDrawingPoint> get points => _points;
  Color get selectedColor => _selectedColor;
  double get strokeWidth => _strokeWidth;
  bool get isDrawing => _isDrawing;
  Offset? get cursorPosition => _currentCursorPosition;
  List<Offset> get handLandmarks => _handLandmarks;
  bool get handDetected => _handDetected;
  bool get showHandSkeleton => _showHandSkeleton;
  bool get showCursor => _showCursor;
  double get canvasOpacity => _canvasOpacity;
  Color get cursorColor => _cursorColor;
  double get cursorSize => _cursorSize;
  ScreenshotController get screenshotController => _screenshotController;
  BackgroundImage get selectedBackground => _selectedBackground;
  List<BackgroundImage> get backgrounds => _backgrounds;
  ImageProvider? get backgroundImageProvider => _backgroundImageProvider;

  // NEW: Redo availability getter
  bool get canRedo => _redoHistory.isNotEmpty;
  bool get canUndo => _drawingHistory.isNotEmpty;

  // ========== HAND TRACKING METHODS ==========
  void updateHandData(List<Offset> newLandmarks) {
    _handLandmarks = newLandmarks;
    _handDetected = newLandmarks.isNotEmpty;

    if (_handDetected && newLandmarks.length >= 9) {
      _currentCursorPosition = newLandmarks[8];
      if (_isDrawing && _currentCursorPosition != null) {
        _addDrawingPoint(_currentCursorPosition!);
      }
    } else {
      _currentCursorPosition = null;
    }
    notifyListeners();
  }

  void updateCursorPosition(Offset? position) {
    _currentCursorPosition = position;
    notifyListeners();
  }

  // ========== DRAWING CONTROL METHODS ==========
  void startDrawing() {
    if (_handDetected && _currentCursorPosition != null) {
      _isDrawing = true;
      _saveToHistory(); // Save current state before starting new drawing
      _addDrawingPoint(_currentCursorPosition!);
      notifyListeners();
    }
  }

  void startDrawingAt(Offset position) {
    _isDrawing = true;
    _saveToHistory(); // Save current state before starting new drawing
    _addDrawingPoint(position);
    notifyListeners();
  }

  void stopDrawing() {
    _isDrawing = false;
    notifyListeners();
  }

  void stopDrawingAt(Offset position) {
    _isDrawing = false;
    if (_currentCursorPosition != null) {
      _addDrawingPoint(_currentCursorPosition!);
    }
    notifyListeners();
  }

  void toggleDrawing() {
    _isDrawing ? stopDrawing() : startDrawing();
  }

  void _addDrawingPoint(Offset normalizedPoint) {
    _points.add(AirDrawingPoint(
      point: normalizedPoint,
      color: _selectedColor,
      strokeWidth: _strokeWidth,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  void addPoint(Offset point) {
    _addDrawingPoint(point);
  }

  void clearDrawing() {
    _saveToHistory(); // Save current drawing before clearing
    _points.clear();
    _isDrawing = false;
    _redoHistory.clear(); // Clear redo history when clearing drawing
    notifyListeners();
  }

  void undo() {
    if (_drawingHistory.isNotEmpty) {
      // Save current state to redo history
      _redoHistory.add([..._points]);

      // Restore previous state from undo history
      _points = _drawingHistory.removeLast();

      notifyListeners();
    }
  }

  // NEW: Redo method
  void redo() {
    if (_redoHistory.isNotEmpty) {
      // Save current state to undo history
      _drawingHistory.add([..._points]);

      // Restore state from redo history
      _points = _redoHistory.removeLast();

      notifyListeners();
    }
  }

  // Helper method to save current state to history
  void _saveToHistory() {
    _drawingHistory.add([..._points]);
    _redoHistory.clear(); // Clear redo history when new action is performed
  }

  void updateColor(Color color) {
    _selectedColor = color;
    notifyListeners();
  }

  void updateStrokeWidth(double width) {
    _strokeWidth = width;
    notifyListeners();
  }

  // ========== BACKGROUND METHODS ==========
  Future<void> _initializeBackgrounds() async {
    _backgrounds = [
      BackgroundImage(name: 'None', assetPath: '', type: BackgroundType.none),
      BackgroundImage(
          name: 'Living Room',
          assetPath: 'assets/backgrounds/living_room.jpg',
          type: BackgroundType.indoor),
      BackgroundImage(
          name: 'Kitchen',
          assetPath: 'assets/backgrounds/kitchen.jpg',
          type: BackgroundType.indoor),
      BackgroundImage(
          name: 'Office',
          assetPath: 'assets/backgrounds/office.jpg',
          type: BackgroundType.indoor),
      BackgroundImage(
          name: 'Sky',
          assetPath: 'assets/backgrounds/sky.jpg',
          type: BackgroundType.outdoor),
      BackgroundImage(
          name: 'Garden',
          assetPath: 'assets/backgrounds/garden.jpg',
          type: BackgroundType.outdoor),
      BackgroundImage(
          name: 'Beach',
          assetPath: 'assets/backgrounds/beach.jpg',
          type: BackgroundType.outdoor),
      BackgroundImage(
          name: 'Forest',
          assetPath: 'assets/backgrounds/forest.jpg',
          type: BackgroundType.outdoor),
    ];

    // Preload background images
    for (var bg in _backgrounds) {
      if (bg.assetPath.isNotEmpty) {
        try {
          final byteData = await rootBundle.load(bg.assetPath);
          bg.imageBytes = byteData.buffer.asUint8List();
        } catch (e) {
          debugPrint('Failed to load background ${bg.name}: $e');
        }
      }
    }
    notifyListeners();
  }

  void selectBackground(BackgroundImage background) {
    _selectedBackground = background;

    if (background.assetPath.isNotEmpty && background.imageBytes != null) {
      _backgroundImageProvider = MemoryImage(background.imageBytes!);
    } else {
      _backgroundImageProvider = null;
    }
    notifyListeners();
  }

  void clearBackground() {
    _selectedBackground = BackgroundImage(
      name: 'None',
      assetPath: '',
      type: BackgroundType.none,
    );
    _backgroundImageProvider = null;
    notifyListeners();
  }

  // ========== UI SETTINGS METHODS ==========
  void toggleHandSkeleton() {
    _showHandSkeleton = !_showHandSkeleton;
    notifyListeners();
  }

  void toggleCursor() {
    _showCursor = !_showCursor;
    notifyListeners();
  }

  void updateCanvasOpacity(double opacity) {
    _canvasOpacity = opacity.clamp(0.1, 1.0);
    notifyListeners();
  }

  void updateCursorColor(Color color) {
    _cursorColor = color;
    notifyListeners();
  }

  void updateCursorSize(double size) {
    _cursorSize = size.clamp(6.0, 30.0);
    notifyListeners();
  }

  // ========== SAVING FUNCTIONALITY ==========
  Future<String> saveDrawingLocally() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'air_drawing_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${directory.path}/$fileName';

      final bytes = await _screenshotController.capture(delay: Duration.zero);
      if (bytes == null) throw Exception('Failed to capture screenshot');

      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      debugPrint('Error saving locally: $e');
      rethrow;
    }
  }

  Future<bool> saveDrawingToGallery() async {
    try {
      final bytes = await _screenshotController.capture(delay: Duration.zero);
      if (bytes == null) return false;

      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(bytes),
        quality: 100,
        name: 'air_drawing_${DateTime.now().millisecondsSinceEpoch}',
      );
      return result['isSuccess'] == true;
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
      return false;
    }
  }

  Future<String> exportDrawingAsJson() async {
    try {
      final jsonData = {
        'points': _points.map((p) => p.toJson()).toList(),
        'metadata': {
          'created': DateTime.now().toIso8601String(),
          'pointCount': _points.length,
          'colorsUsed': _points.map((p) => p.color.value).toSet().toList(),
        }
      };

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'air_drawing_${DateTime.now().millisecondsSinceEpoch}.json';
      final filePath = '${directory.path}/$fileName';

      await File(filePath).writeAsString(json.encode(jsonData));
      return filePath;
    } catch (e) {
      debugPrint('Error exporting JSON: $e');
      rethrow;
    }
  }

  Future<void> loadDrawingFromJson(String filePath) async {
    try {
      final file = File(filePath);
      final jsonData = json.decode(await file.readAsString());

      _saveToHistory(); // Save current state before loading
      _points = (jsonData['points'] as List)
          .map((p) => AirDrawingPoint.fromJson(p))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading JSON: $e');
      rethrow;
    }
  }
}