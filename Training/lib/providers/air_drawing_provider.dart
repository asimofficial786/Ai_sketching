import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:convert'; // <-- ADD THIS IMPORT for json.encode/json.decode
import 'package:flutter/material.dart';
// Use the correct import based on your pubspec.yaml choice
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart'; // If you kept this
// OR use: import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
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

/// Handles the core state for air drawing.
class AirDrawingProvider extends ChangeNotifier {
  // Drawing state
  List<AirDrawingPoint> _points = [];
  List<List<AirDrawingPoint>> _drawingHistory = [];
  Color _selectedColor = Colors.blueAccent;
  double _strokeWidth = 8.0;
  bool _isDrawing = false;

  // Hand tracking & cursor state
  Offset? _currentCursorPosition;
  List<Offset> _handLandmarks = [];
  bool _handDetected = false;

  // UI State
  bool _showHandSkeleton = false;
  bool _showCursor = true;
  double _canvasOpacity = 0.85;
  Color _cursorColor = Colors.yellow;
  double _cursorSize = 12.0;

  // Screenshot controller for saving
  final ScreenshotController _screenshotController = ScreenshotController();

  // Getters
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

  // ========== DRAWING CONTROL METHODS ==========
  void startDrawing() {
    if (_handDetected && _currentCursorPosition != null) {
      _isDrawing = true;
      _drawingHistory.add([..._points]);
      _addDrawingPoint(_currentCursorPosition!);
      notifyListeners();
    }
  }

  void stopDrawing() {
    _isDrawing = false;
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

  void clearDrawing() {
    _drawingHistory.add([..._points]);
    _points.clear();
    _isDrawing = false;
    notifyListeners();
  }

  void undo() {
    if (_drawingHistory.isNotEmpty) {
      _points = _drawingHistory.removeLast();
      notifyListeners();
    }
  }

  void updateColor(Color color) {
    _selectedColor = color;
    notifyListeners();
  }

  void updateStrokeWidth(double width) {
    _strokeWidth = width;
    notifyListeners();
  }

  // ========== UI SETTINGS ==========
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

      // REMOVED THE DUPLICATE METHOD. This is the only definition.
      // Updated for screenshot ^3.0.0: capture() requires a 'delay' parameter.
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

      // Use ImageGallerySaverPlus instead of ImageGallerySaver
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
      // The 'json' variable from dart:convert is now recognized.
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
      // The 'json' variable from dart:convert is now recognized.
      final jsonData = json.decode(await file.readAsString());

      _drawingHistory.add([..._points]);
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