import 'dart:ui';
import 'package:flutter/material.dart';

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
}

/// Handles the core state for air drawing.
class AirDrawingProvider extends ChangeNotifier {
  // Drawing state
  List<AirDrawingPoint> _points = [];
  Color _selectedColor = Colors.blueAccent;
  double _strokeWidth = 8.0;
  bool _isDrawing = false;

  // Hand tracking & cursor state
  Offset? _currentCursorPosition;
  List<Offset> _handLandmarks = [];
  bool _handDetected = false;

  // Getters
  List<AirDrawingPoint> get points => _points;
  Color get selectedColor => _selectedColor;
  double get strokeWidth => _strokeWidth;
  bool get isDrawing => _isDrawing;
  Offset? get cursorPosition => _currentCursorPosition;
  List<Offset> get handLandmarks => _handLandmarks;
  bool get handDetected => _handDetected;

  // ========== HAND TRACKING METHODS ==========
  /// Called from the screen when new hand landmarks are detected.
  /// Landmarks are normalized (0.0 to 1.0). Index 8 is the index finger tip[citation:7].
  void updateHandData(List<Offset> newLandmarks) {
    _handLandmarks = newLandmarks;
    _handDetected = newLandmarks.isNotEmpty;

    if (_handDetected) {
      // Use the index finger tip (landmark 8) as the drawing cursor.
      // The coordinates are normalized, so we store them as-is.
      _currentCursorPosition = newLandmarks[8];
      // If drawing mode is active, add this point to the canvas.
      if (_isDrawing) {
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
      point: normalizedPoint, // Store normalized point
      color: _selectedColor,
      strokeWidth: _strokeWidth,
      timestamp: DateTime.now(),
    ));
  }

  void clearDrawing() {
    _points.clear();
    _isDrawing = false;
    notifyListeners();
  }

  void updateColor(Color color) {
    _selectedColor = color;
    notifyListeners();
  }

  void updateStrokeWidth(double width) {
    _strokeWidth = width;
    notifyListeners();
  }
}