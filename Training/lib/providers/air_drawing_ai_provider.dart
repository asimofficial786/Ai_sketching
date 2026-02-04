import 'dart:math';
import 'package:flutter/material.dart';
import 'air_drawing_provider.dart';

/// AI Provider for Air Drawing Assistance
class AirDrawingAIProvider extends ChangeNotifier {
  // AI Settings
  bool _aiEnabled = true;
  bool _autoCorrectionEnabled = false;
  bool _showGuides = true;
  bool _showPredictions = true;
  bool _autoDetectShapes = true;
  double _correctionStrength = 0.5;
  Color _guideColor = Colors.green.withOpacity(0.6);

  // Detection State
  String _detectedShape = '';
  String _classifiedObject = '';
  List<DetectedShape> _detectedShapes = [];
  List<Offset> _guidePoints = [];
  Offset? _predictionPoint;

  // Drawing Analysis
  List<Offset> _currentStroke = [];
  bool _isAnalyzing = false;

  // Getters
  bool get aiEnabled => _aiEnabled;
  bool get autoCorrectionEnabled => _autoCorrectionEnabled;
  bool get showGuides => _showGuides;
  bool get showPredictions => _showPredictions;
  bool get autoDetectShapes => _autoDetectShapes;
  double get correctionStrength => _correctionStrength;
  Color get guideColor => _guideColor;
  String get detectedShape => _detectedShape;
  String get classifiedObject => _classifiedObject;
  List<DetectedShape> get detectedShapes => _detectedShapes;
  List<Offset> get guidePoints => _guidePoints;
  Offset? get predictionPoint => _predictionPoint;
  bool get isAnalyzing => _isAnalyzing;

  // ========== AI CONTROL METHODS ==========
  void toggleAI() {
    _aiEnabled = !_aiEnabled;
    if (!_aiEnabled) {
      clearAnalysis();
    }
    notifyListeners();
  }

  void toggleAutoCorrection() {
    _autoCorrectionEnabled = !_autoCorrectionEnabled;
    notifyListeners();
  }

  void toggleGuides() {
    _showGuides = !_showGuides;
    notifyListeners();
  }

  void togglePredictions() {
    _showPredictions = !_showPredictions;
    notifyListeners();
  }

  void toggleShapeDetection() {
    _autoDetectShapes = !_autoDetectShapes;
    notifyListeners();
  }

  void updateCorrectionStrength(double strength) {
    _correctionStrength = strength.clamp(0.0, 1.0);
    notifyListeners();
  }

  void updateGuideColor(Color color) {
    _guideColor = color;
    notifyListeners();
  }

  // ========== AI ANALYSIS METHODS ==========

  /// Analyze air drawing stroke in real-time
  void analyzeAirStroke(List<AirDrawingPoint> drawingPoints) {
    if (!_aiEnabled || drawingPoints.length < 5) {
      clearAnalysis();
      return;
    }

    _isAnalyzing = true;

    // Convert to normalized points
    _currentStroke = drawingPoints.map((p) => p.point).toList();

    // Detect shape
    _detectedShape = _detectShape(_currentStroke);

    // Classify object
    _classifiedObject = _classifyObject(_detectedShape, _currentStroke);

    // Generate guide points for the detected shape
    if (_showGuides) {
      _guidePoints = _generateGuidePoints(_detectedShape, _currentStroke);
    }

    // Generate prediction point
    if (_showPredictions && drawingPoints.length >= 3) {
      _predictionPoint = _predictNextPoint(_currentStroke);
    }

    // Store detected shape for later use
    if (_autoDetectShapes && _detectedShape.isNotEmpty) {
      _detectedShapes.add(DetectedShape(
        shape: _detectedShape,
        object: _classifiedObject,
        bounds: _calculateBoundingBox(_currentStroke),
        points: List.from(_currentStroke),
        timestamp: DateTime.now(),
      ));
    }

    _isAnalyzing = false;
    notifyListeners();
  }

  /// Apply AI correction to drawing points
  List<AirDrawingPoint> applyCorrection(
      List<AirDrawingPoint> originalPoints,
      Color strokeColor,
      double strokeWidth
      ) {
    if (!_aiEnabled || !_autoCorrectionEnabled || originalPoints.length < 3) {
      return originalPoints;
    }

    final points = originalPoints.map((p) => p.point).toList();
    final shape = _detectShape(points);

    if (shape.isEmpty || shape == 'freeform') {
      return originalPoints;
    }

    final correctedPoints = _correctToShape(points, shape);

    return correctedPoints.map((point) => AirDrawingPoint(
      point: point,
      color: strokeColor,
      strokeWidth: strokeWidth,
      timestamp: DateTime.now(),
    )).toList();
  }

  /// Get drawing guides for the current stroke
  List<Offset> getDrawingGuides(List<Offset> points) {
    if (!_aiEnabled || !_showGuides || points.length < 3) {
      return [];
    }

    final shape = _detectShape(points);
    return _generateGuidePoints(shape, points);
  }

  /// Predict the next point for smoother drawing
  Offset? predictNextPoint(List<Offset> points, Offset currentCursor) {
    if (!_aiEnabled || !_showPredictions || points.length < 5) {
      return null;
    }

    return _predictNextPoint(points);
  }

  /// Clear all AI analysis
  void clearAnalysis() {
    _detectedShape = '';
    _classifiedObject = '';
    _guidePoints.clear();
    _predictionPoint = null;
    _currentStroke.clear();
    _isAnalyzing = false;
    notifyListeners();
  }

  // ========== PRIVATE HELPER METHODS ==========

  String _detectShape(List<Offset> points) {
    if (points.length < 3) return '';

    final circularity = _calculateCircularity(points);
    final lineScore = _calculateLineScore(points);
    final corners = _detectCorners(points);
    final aspectRatio = _calculateAspectRatio(points);

    if (circularity > 0.7) return 'circle';
    if (lineScore > 0.8) return 'line';
    if (corners == 3) return 'triangle';
    if (corners == 4) {
      return aspectRatio > 0.8 && aspectRatio < 1.2 ? 'square' : 'rectangle';
    }

    return 'freeform';
  }

  String _classifyObject(String shape, List<Offset> points) {
    final bounds = _calculateBoundingBox(points);
    final width = bounds.width;
    final height = bounds.height;

    switch (shape) {
      case 'circle':
        if (width < 0.2) return 'Button';
        if (width < 0.4) return 'Clock';
        return 'Planet';

      case 'triangle':
        final orientation = _getTriangleOrientation(points);
        return orientation == 'upward' ? 'Mountain' : 'Arrow';

      case 'square':
      case 'rectangle':
        final aspectRatio = width / height;
        if (aspectRatio > 1.5) return 'Door';
        if (aspectRatio < 0.67) return 'Window';
        return 'Building';

      case 'line':
        final angle = _calculateLineAngle(points);
        if (angle.abs() < 30) return 'Horizon';
        if (angle.abs() > 60) return 'Vertical Line';
        return 'Diagonal Line';

      default:
        return 'Freeform Object';
    }
  }

  List<Offset> _generateGuidePoints(String shape, List<Offset> points) {
    final bounds = _calculateBoundingBox(points);

    switch (shape) {
      case 'circle':
        final center = bounds.center;
        final radius = min(bounds.width, bounds.height) / 2;
        return List.generate(8, (i) {
          final angle = 2 * pi * i / 8;
          return Offset(
            center.dx + radius * cos(angle),
            center.dy + radius * sin(angle),
          );
        });

      case 'triangle':
        return [
          Offset(bounds.center.dx, bounds.top),
          Offset(bounds.right, bounds.bottom),
          Offset(bounds.left, bounds.bottom),
          Offset(bounds.center.dx, bounds.top),
        ];

      case 'square':
      case 'rectangle':
        return [
          bounds.topLeft,
          bounds.topRight,
          bounds.bottomRight,
          bounds.bottomLeft,
          bounds.topLeft,
        ];

      case 'line':
        if (points.length >= 2) {
          return [points.first, points.last];
        }
        return [];

      default:
        return [];
    }
  }

  List<Offset> _correctToShape(List<Offset> points, String shape) {
    final bounds = _calculateBoundingBox(points);

    switch (shape) {
      case 'circle':
        final center = bounds.center;
        final radius = min(bounds.width, bounds.height) / 2;
        final strength = _correctionStrength;

        return points.map((point) {
          final angle = atan2(point.dy - center.dy, point.dx - center.dx);
          final distance = (point - center).distance;
          final newDistance = radius * strength + distance * (1 - strength);

          return Offset(
            center.dx + newDistance * cos(angle),
            center.dy + newDistance * sin(angle),
          );
        }).toList();

      case 'line':
        if (points.length < 2) return points;
        final start = points.first;
        final end = points.last;
        final strength = _correctionStrength;

        return points.map((point) {
          final t = _projectPointOnLine(point, start, end);
          final projection = Offset(
            start.dx + t * (end.dx - start.dx),
            start.dy + t * (end.dy - start.dy),
          );

          return Offset(
            point.dx * (1 - strength) + projection.dx * strength,
            point.dy * (1 - strength) + projection.dy * strength,
          );
        }).toList();

      default:
        return points;
    }
  }

  Offset? _predictNextPoint(List<Offset> points) {
    if (points.length < 3) return null;

    final recentPoints = points.length > 10
        ? points.sublist(points.length - 10)
        : points;

    double dx = 0, dy = 0;
    for (int i = 1; i < recentPoints.length; i++) {
      dx += recentPoints[i].dx - recentPoints[i-1].dx;
      dy += recentPoints[i].dy - recentPoints[i-1].dy;
    }

    dx /= (recentPoints.length - 1);
    dy /= (recentPoints.length - 1);

    final lastPoint = points.last;
    return Offset(
      lastPoint.dx + dx * 2,
      lastPoint.dy + dy * 2,
    );
  }

  // ========== GEOMETRY HELPER METHODS ==========

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

  double _calculateCircularity(List<Offset> points) {
    final area = _calculatePolygonArea(points);
    final perimeter = _calculatePerimeter(points);

    if (perimeter == 0) return 0;
    return (4 * pi * area) / (perimeter * perimeter);
  }

  double _calculatePolygonArea(List<Offset> points) {
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

  double _calculateLineScore(List<Offset> points) {
    if (points.length < 2) return 0;

    final start = points.first;
    final end = points.last;
    final lineLength = (end - start).distance;

    if (lineLength == 0) return 0;

    double totalDeviation = 0;
    for (final point in points) {
      totalDeviation += _distanceFromLine(point, start, end);
    }

    final avgDeviation = totalDeviation / points.length;
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

  double _projectPointOnLine(Offset point, Offset lineStart, Offset lineEnd) {
    final dx = lineEnd.dx - lineStart.dx;
    final dy = lineEnd.dy - lineStart.dy;
    final length2 = dx * dx + dy * dy;

    if (length2 == 0) return 0;

    return ((point.dx - lineStart.dx) * dx +
        (point.dy - lineStart.dy) * dy) / length2;
  }

  int _detectCorners(List<Offset> points) {
    if (points.length < 4) return points.length;

    int corners = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i-1];
      final curr = points[i];
      final next = points[i+1];

      final angle = _calculateAngle(prev, curr, next);
      if (angle.abs() < 150) {
        corners++;
      }
    }

    return max(2, corners);
  }

  double _calculateAngle(Offset a, Offset b, Offset c) {
    final ba = a - b;
    final bc = c - b;

    final dot = ba.dx * bc.dx + ba.dy * bc.dy;
    final cross = ba.dx * bc.dy - ba.dy * bc.dx;

    return atan2(cross, dot) * 180 / pi;
  }

  double _calculateAspectRatio(List<Offset> points) {
    final bounds = _calculateBoundingBox(points);
    return bounds.width / bounds.height;
  }

  String _getTriangleOrientation(List<Offset> points) {
    if (points.length < 3) return 'unknown';

    final sortedByY = List.from(points)..sort((a, b) => a.dy.compareTo(b.dy));
    final highestPoint = sortedByY.first;

    int topPoints = 0;
    for (final point in points) {
      if ((point.dy - highestPoint.dy).abs() < 0.05) {
        topPoints++;
      }
    }

    return topPoints == 1 ? 'upward' : 'downward';
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

/// Data class for detected shapes
class DetectedShape {
  final String shape;
  final String object;
  final Rect bounds;
  final List<Offset> points;
  final DateTime timestamp;

  DetectedShape({
    required this.shape,
    required this.object,
    required this.bounds,
    required this.points,
    required this.timestamp,
  });
}