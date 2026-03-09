import 'dart:math';
import 'package:flutter/material.dart';

/// Shape data detected by AI
class ShapeData {
  final String shape;
  final String object;
  final Rect bounds;
  final List<Offset> points;
  final DateTime timestamp;

  ShapeData({
    required this.shape,
    required this.object,
    required this.bounds,
    required this.points,
    required this.timestamp,
  });
}

/// Background type enum
enum BackgroundType {
  none,
  indoor,
  outdoor,
}

/// Background data class
class Background {
  final String name;
  final String path;
  final BackgroundType type;

  Background({
    required this.name,
    required this.path,
    required this.type,
  });
}

/// AI Provider for drawing assistance and shape detection
class AIProvider extends ChangeNotifier {
  // ========== AI SETTINGS ==========
  bool _autoCorrectionEnabled = false;
  bool _showDetectionBoxes = true;
  double _correctionStrength = 0.7;
  String _detectedShape = '';
  String _classifiedObject = '';
  String _selectedBackground = 'none';

  // ========== DETECTION STATE ==========
  final List<ShapeData> _detectedShapes = [];
  List<Offset> _currentPoints = [];

  // ========== BACKGROUND DATA ==========
  final List<Background> _backgrounds = [
    Background(name: 'None', path: '', type: BackgroundType.none),
    Background(name: 'Living Room Wall', path: 'assets/background/living_room.jpg', type: BackgroundType.indoor),
    Background(name: 'Kitchen', path: 'assets/background/kitchen.jpg', type: BackgroundType.indoor),
    Background(name: 'Office Desk', path: 'assets/background/office.jpg', type: BackgroundType.indoor),
    Background(name: 'Sky', path: 'assets/background/sky.jpg', type: BackgroundType.outdoor),
    Background(name: 'Garden', path: 'assets/background/garden.jpg', type: BackgroundType.outdoor),
    Background(name: 'Beach', path: 'assets/background/beach.jpg', type: BackgroundType.outdoor),
    Background(name: 'Forest', path: 'assets/background/forest.jpg', type: BackgroundType.outdoor),
  ];

  // ========== GETTERS ==========
  bool get autoCorrectionEnabled => _autoCorrectionEnabled;
  bool get showDetectionBoxes => _showDetectionBoxes;
  double get correctionStrength => _correctionStrength;
  String get detectedShape => _detectedShape;
  String get classifiedObject => _classifiedObject;
  String get selectedBackground => _selectedBackground;
  List<ShapeData> get detectedShapes => _detectedShapes;
  List<Background> get backgrounds => _backgrounds;

  // ========== AI CONTROL METHODS ==========
  void toggleAutoCorrection() {
    _autoCorrectionEnabled = !_autoCorrectionEnabled;
    notifyListeners();
  }

  void updateCorrectionStrength(double strength) {
    _correctionStrength = strength.clamp(0.1, 1.0);
    notifyListeners();
  }

  void toggleDetectionBoxes() {
    _showDetectionBoxes = !_showDetectionBoxes;
    notifyListeners();
  }

  // ========== SHAPE DETECTION & CLASSIFICATION ==========
  String analyzePoints(List<Offset> points) {
    if (points.length < 3) return '';

    _currentPoints = List.from(points);

    // 1. Detect Basic Shape
    final shape = _detectBasicShape(points);
    _detectedShape = shape;

    // 2. Classify Object
    _classifiedObject = _classifyObject(shape, points);

    // 3. Store shape data for rendering
    if (shape.isNotEmpty) {
      _detectedShapes.add(ShapeData(
        shape: shape,
        object: _classifiedObject,
        bounds: _calculateBoundingBox(points),
        points: List.from(points),
        timestamp: DateTime.now(),
      ));
    }

    notifyListeners();
    return shape;
  }

  // ========== CORRECTION METHODS ==========
  List<Offset> applyManualCorrection(List<Offset> points) {
    if (points.length < 2) return points;

    final shape = _detectBasicShape(points);

    switch (shape) {
      case 'circle':
        return _correctToCircle(points);
      case 'triangle':
        return _correctToTriangle(points);
      case 'square':
      case 'rectangle':
        return _correctToRectangle(points);
      case 'line':
        return _correctToLine(points);
      default:
        return _smoothPoints(points);
    }
  }

  List<Offset> applyAutoCorrection(List<Offset> points) {
    if (!_autoCorrectionEnabled || points.length < 3) return points;

    final shape = _detectBasicShape(points);

    switch (shape) {
      case 'circle':
        return _correctToCircle(points);
      case 'triangle':
        return _correctToTriangle(points);
      case 'square':
      case 'rectangle':
        return _correctToRectangle(points);
      case 'line':
        return _correctToLine(points);
      default:
        return _smoothPoints(points);
    }
  }

  // ========== BACKGROUND MANAGEMENT ==========
  void selectBackground(String backgroundName) {
    _selectedBackground = backgroundName;
    notifyListeners();
  }

  // ========== CLEAR DETECTIONS ==========
  void clearDetections() {
    _detectedShapes.clear();
    _detectedShape = '';
    _classifiedObject = '';
    notifyListeners();
  }

  // ========== PRIVATE HELPER METHODS ==========

  // Shape Detection Logic
  String _detectBasicShape(List<Offset> points) {
    if (points.length < 3) return '';

    final bounds = _calculateBoundingBox(points);
    final width = bounds.right - bounds.left;
    final height = bounds.bottom - bounds.top;
    final aspectRatio = width / height;

    // Calculate circularity
    final double area = _calculateArea(points);
    final double perimeter = _calculatePerimeter(points);
    final double circularity = (4 * pi * area) / (perimeter * perimeter);

    // Calculate corner detection (for polygons)
    final int corners = _detectCorners(points);

    // Shape detection logic
    if (circularity > 0.7 && aspectRatio > 0.8 && aspectRatio < 1.2) {
      return 'circle';
    } else if (circularity > 0.6 && aspectRatio > 0.7 && aspectRatio < 1.3) {
      return 'ellipse';
    } else if (corners == 3) {
      return 'triangle';
    } else if (corners == 4) {
      if (aspectRatio > 0.8 && aspectRatio < 1.2) {
        return 'square';
      } else {
        return 'rectangle';
      }
    } else if (corners > 4) {
      return 'polygon';
    } else {
      // Check if it's a line
      final lineScore = _calculateLineScore(points);
      if (lineScore > 0.8) {
        return 'line';
      }
    }

    return 'unknown';
  }

  String _classifyObject(String shape, List<Offset> points) {
    switch (shape) {
      case 'circle':
        final bounds = _calculateBoundingBox(points);
        final width = bounds.right - bounds.left;

        // Small circle = button/clock center
        if (width < 50) return 'Button';

        // Medium circle = clock/sun
        if (width < 150) {
          // Check for clock features (numbers, hands)
          final hasLines = _detectRadialLines(points);
          return hasLines ? 'Clock' : 'Sun';
        }

        // Large circle = moon/planet
        return 'Planet';

      case 'triangle':
        final orientation = _getTriangleOrientation(points);
        if (orientation == 'upward') return 'Mountain';
        if (orientation == 'downward') return 'Arrow';
        return 'Pyramid';

      case 'square':
      case 'rectangle':
        final aspectRatio = _calculateAspectRatio(points);
        if (aspectRatio > 2.0) return 'Door';
        if (aspectRatio < 0.5) return 'Window';
        return 'Building';

      case 'line':
        final angle = _calculateLineAngle(points);
        if (angle.abs() < 30) return 'Horizon';
        if (angle.abs() > 60) return 'Tree';
        return 'Arrow';

      default:
        return 'Object';
    }
  }

  // Shape Correction Methods
  List<Offset> _correctToCircle(List<Offset> points) {
    final bounds = _calculateBoundingBox(points);
    final center = Offset(
      (bounds.left + bounds.right) / 2,
      (bounds.top + bounds.bottom) / 2,
    );
    final radius = min(bounds.width, bounds.height) / 2;

    final corrected = <Offset>[];
    for (int i = 0; i < 36; i++) {
      final angle = 2 * pi * i / 36;
      corrected.add(Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      ));
    }

    return _blendPoints(points, corrected, _correctionStrength);
  }

  List<Offset> _correctToTriangle(List<Offset> points) {
    final bounds = _calculateBoundingBox(points);
    final center = Offset(
      (bounds.left + bounds.right) / 2,
      (bounds.top + bounds.bottom) / 2,
    );

    // Create equilateral triangle
    final triangle = [
      Offset(center.dx, bounds.top), // Top
      Offset(bounds.right, bounds.bottom), // Bottom right
      Offset(bounds.left, bounds.bottom), // Bottom left
      Offset(center.dx, bounds.top), // Close triangle
    ];

    return _blendPoints(points, triangle, _correctionStrength);
  }

  List<Offset> _correctToRectangle(List<Offset> points) {
    final bounds = _calculateBoundingBox(points);

    final rectangle = [
      Offset(bounds.left, bounds.top),
      Offset(bounds.right, bounds.top),
      Offset(bounds.right, bounds.bottom),
      Offset(bounds.left, bounds.bottom),
      Offset(bounds.left, bounds.top),
    ];

    return _blendPoints(points, rectangle, _correctionStrength);
  }

  List<Offset> _correctToLine(List<Offset> points) {
    if (points.length < 2) return points;

    final start = points.first;
    final end = points.last;

    // Create straight line between first and last point
    final line = [start, end];

    return _blendPoints(points, line, _correctionStrength);
  }

  List<Offset> _smoothPoints(List<Offset> points) {
    if (points.length < 3) return points;

    final smoothed = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      if (i == 0 || i == points.length - 1) {
        smoothed.add(points[i]);
      } else {
        // Simple smoothing: average of 3 points
        final smoothedPoint = Offset(
          (points[i-1].dx + points[i].dx + points[i+1].dx) / 3,
          (points[i-1].dy + points[i].dy + points[i+1].dy) / 3,
        );
        smoothed.add(smoothedPoint);
      }
    }

    return smoothed;
  }

  List<Offset> _blendPoints(List<Offset> original, List<Offset> corrected, double strength) {
    if (strength >= 1.0) return corrected;
    if (strength <= 0.0) return original;

    // For simplicity, return corrected if shape is very different
    if (original.length < 5) return corrected;

    return corrected; // In production, implement proper blending
  }

  // Geometry Helper Methods
  Rect _calculateBoundingBox(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;

    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final point in points) {
      minX = min(minX, point.dx);
      maxX = max(maxX, point.dx);
      minY = min(minY, point.dy);
      maxY = max(maxY, point.dy);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double _calculateArea(List<Offset> points) {
    // Shoelace formula for polygon area
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      area += points[i].dx * points[j].dy;
      area -= points[j].dx * points[i].dy;
    }
    return area.abs() / 2;
  }

  double _calculatePerimeter(List<Offset> points) {
    double perimeter = 0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      perimeter += (points[j] - points[i]).distance;
    }
    return perimeter;
  }

  int _detectCorners(List<Offset> points) {
    if (points.length < 4) return points.length;

    // Simplified corner detection
    int corners = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i-1];
      final curr = points[i];
      final next = points[i+1];

      final angle = _calculateAngle(prev, curr, next);
      if (angle.abs() < 150) { // Sharp angle
        corners++;
      }
    }

    return max(3, corners);
  }

  double _calculateLineScore(List<Offset> points) {
    if (points.length < 2) return 0;

    // Check if points are roughly in a straight line
    final start = points.first;
    final end = points.last;
    final lineVector = end - start;

    double totalDeviation = 0;
    for (final point in points) {
      // Calculate distance from line
      final deviation = _distanceFromLine(point, start, end);
      totalDeviation += deviation;
    }

    final avgDeviation = totalDeviation / points.length;
    final lineLength = lineVector.distance;

    // Score based on deviation relative to line length
    return max(0, 1 - (avgDeviation / lineLength));
  }

  double _distanceFromLine(Offset point, Offset lineStart, Offset lineEnd) {
    final lineLength = (lineEnd - lineStart).distance;
    if (lineLength == 0) return (point - lineStart).distance;

    final t = ((point.dx - lineStart.dx) * (lineEnd.dx - lineStart.dx) +
        (point.dy - lineStart.dy) * (lineEnd.dy - lineStart.dy)) /
        (lineLength * lineLength);

    final tClamped = t.clamp(0.0, 1.0);
    final projection = Offset(
      lineStart.dx + tClamped * (lineEnd.dx - lineStart.dx),
      lineStart.dy + tClamped * (lineEnd.dy - lineStart.dy),
    );

    return (point - projection).distance;
  }

  double _calculateAngle(Offset a, Offset b, Offset c) {
    final ba = a - b;
    final bc = c - b;

    final dot = ba.dx * bc.dx + ba.dy * bc.dy;
    final cross = ba.dx * bc.dy - ba.dy * bc.dx;

    return atan2(cross, dot) * 180 / pi;
  }

  bool _detectRadialLines(List<Offset> points) {
    // Simplified check for clock-like features
    if (points.length < 20) return false;

    final bounds = _calculateBoundingBox(points);
    final center = Offset(
      (bounds.left + bounds.right) / 2,
      (bounds.top + bounds.bottom) / 2,
    );

    int radialCount = 0;
    for (int i = 0; i < points.length; i += 5) {
      final point = points[i];
      final vector = point - center;
      if (vector.distance > 10) {
        radialCount++;
      }
    }

    return radialCount > 3;
  }

  String _getTriangleOrientation(List<Offset> points) {
    if (points.length < 3) return 'unknown';

    final sortedByY = List.from(points)..sort((a, b) => a.dy.compareTo(b.dy));
    final highestPoint = sortedByY.first;

    // Count how many points are near the top
    int topPoints = 0;
    for (final point in points) {
      if ((point.dy - highestPoint.dy).abs() < 10) {
        topPoints++;
      }
    }

    return topPoints == 1 ? 'upward' : 'downward';
  }

  double _calculateAspectRatio(List<Offset> points) {
    final bounds = _calculateBoundingBox(points);
    final width = bounds.width;
    final height = bounds.height;
    return width / height;
  }

  double _calculateLineAngle(List<Offset> points) {
    if (points.length < 2) return 0;

    final start = points.first;
    final end = points.last;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    return atan2(dy, dx) * 180 / pi;
  }
}