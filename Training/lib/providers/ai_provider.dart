import 'dart:math';
import 'package:flutter/material.dart';

/// Shape data detected by AI
class ShapeData {
  final String shape;
  final String object;
  final double confidence;
  final Rect bounds;
  final List<Offset> points;
  final DateTime timestamp;

  ShapeData({
    required this.shape,
    required this.object,
    required this.confidence,
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
  bool get exists => path.isNotEmpty;

  Background({
    required this.name,
    required this.path,
    required this.type,
  });
}

/// AI Provider for drawing assistance and shape detection
class AIProvider extends ChangeNotifier {
  // ========== AI SETTINGS ==========
  bool _autoCorrectionEnabled = true;
  bool _showDetectionBoxes = true;
  double _correctionStrength = 0.9;
  String _detectedShape = '';
  String _classifiedObject = '';
  double _detectionConfidence = 0.0;
  String _selectedBackground = 'none';

  // ========== DETECTION STATE ==========
  final List<ShapeData> _detectedShapes = [];
  List<Offset> _currentPoints = [];

  // ========== BACKGROUND DATA ==========
  final List<Background> _backgrounds = [
    Background(name: 'None', path: '', type: BackgroundType.none),
    Background(name: 'Living Room', path: 'assets/background/living_room.jpg', type: BackgroundType.indoor),
    Background(name: 'Kitchen', path: 'assets/background/kitchen.jpg', type: BackgroundType.indoor),
    Background(name: 'Office', path: 'assets/background/office.jpg', type: BackgroundType.indoor),
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
  double get detectionConfidence => _detectionConfidence;
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

  // ========== MAIN SHAPE DETECTION ==========
  String analyzePoints(List<Offset> points) {
    if (points.length < 8) return '';

    _currentPoints = List.from(points);
    final detection = _detectShape(points);
    _detectedShape = detection['shape'];
    _detectionConfidence = detection['confidence'];

    if (_detectionConfidence > 0.6) {
      _classifiedObject = _classifyObject(_detectedShape, points);
    } else {
      _classifiedObject = '';
    }

    if (_detectedShape.isNotEmpty && _detectionConfidence > 0.6) {
      _detectedShapes.add(ShapeData(
        shape: _detectedShape,
        object: _classifiedObject,
        confidence: _detectionConfidence,
        bounds: _calculateBoundingBox(points),
        points: List.from(points),
        timestamp: DateTime.now(),
      ));

      while (_detectedShapes.length > 5) {
        _detectedShapes.removeAt(0);
      }
    }

    notifyListeners();
    return _detectedShape;
  }

  // ========== SIMPLIFIED SHAPE DETECTION ==========
  Map<String, dynamic> _detectShape(List<Offset> points) {
    if (points.length < 8) {
      return {'shape': 'unknown', 'confidence': 0.0};
    }

    final bounds = _calculateBoundingBox(points);
    final width = bounds.width;
    final height = bounds.height;

    if (width < 5 || height < 5) {
      return {'shape': 'unknown', 'confidence': 0.0};
    }

    final aspectRatio = width / height;
    final double area = _calculateArea(points);
    final double perimeter = _calculatePerimeter(points);
    final double circularity = perimeter > 0 ? (4 * pi * area) / (perimeter * perimeter) : 0;

    // Check if it's a line
    if (_isLine(points)) {
      return {'shape': 'line', 'confidence': 0.9};
    }

    // CIRCLE DETECTION
    if (circularity > 0.8 && (aspectRatio - 1.0).abs() < 0.3) {
      double confidence = circularity.clamp(0.7, 0.98);
      return {'shape': 'circle', 'confidence': confidence};
    }

    // Get corners for polygon detection
    final corners = _findCorners(points);
    final cornerCount = corners.length;

    // TRIANGLE DETECTION (3 corners)
    if (cornerCount == 3) {
      double confidence = _checkTriangle(points, corners);
      if (confidence > 0.6) {
        return {'shape': 'triangle', 'confidence': confidence};
      }
    }

    // RECTANGLE/SQUARE DETECTION (4 corners)
    if (cornerCount == 4) {
      double confidence = _checkRectangle(points, corners);
      if (confidence > 0.6) {
        if ((aspectRatio - 1.0).abs() < 0.2) {
          return {'shape': 'square', 'confidence': confidence};
        } else {
          return {'shape': 'rectangle', 'confidence': confidence};
        }
      }
    }

    // PENTAGON (5 corners)
    if (cornerCount == 5) {
      return {'shape': 'pentagon', 'confidence': 0.7};
    }

    // HEXAGON (6 corners)
    if (cornerCount == 6) {
      return {'shape': 'hexagon', 'confidence': 0.7};
    }

    // OCTAGON (8 corners)
    if (cornerCount == 8) {
      return {'shape': 'octagon', 'confidence': 0.7};
    }

    // STAR (10-12 corners)
    if (cornerCount >= 10 && cornerCount <= 12) {
      if (_isStar(points)) {
        return {'shape': 'star', 'confidence': 0.75};
      }
    }

    return {'shape': 'unknown', 'confidence': 0.3};
  }

  // ========== CORNER DETECTION ==========
  List<Offset> _findCorners(List<Offset> points) {
    if (points.length < 10) return [];

    // Simplify points first
    final simplified = _simplifyPoints(points, 3.0);
    final corners = <Offset>[];

    for (int i = 1; i < simplified.length - 1; i++) {
      final prev = simplified[i - 1];
      final curr = simplified[i];
      final next = simplified[i + 1];

      final angle = _calculateAngle(prev, curr, next);

      // Corner if angle is sharp (less than 140 degrees)
      if (angle < 140) {
        corners.add(curr);
      }
    }

    // Add first and last points if they're corners
    if (simplified.length > 2) {
      final firstAngle = _calculateAngle(
        simplified.last,
        simplified.first,
        simplified[1],
      );
      if (firstAngle < 140) {
        corners.add(simplified.first);
      }

      final lastAngle = _calculateAngle(
        simplified[simplified.length - 2],
        simplified.last,
        simplified.first,
      );
      if (lastAngle < 140) {
        corners.add(simplified.last);
      }
    }

    return _mergeNearbyPoints(corners, 15.0);
  }

  // ========== SIMPLIFY POINTS ==========
  List<Offset> _simplifyPoints(List<Offset> points, double epsilon) {
    if (points.length < 3) return points;

    double maxDistance = 0;
    int index = 0;

    for (int i = 1; i < points.length - 1; i++) {
      double distance = _distanceFromLine(points[i], points.first, points.last);
      if (distance > maxDistance) {
        maxDistance = distance;
        index = i;
      }
    }

    if (maxDistance > epsilon) {
      final firstPart = _simplifyPoints(points.sublist(0, index + 1), epsilon);
      final secondPart = _simplifyPoints(points.sublist(index), epsilon);
      return [...firstPart.sublist(0, firstPart.length - 1), ...secondPart];
    } else {
      return [points.first, points.last];
    }
  }

  // ========== MERGE NEARBY POINTS ==========
  List<Offset> _mergeNearbyPoints(List<Offset> points, double threshold) {
    if (points.isEmpty) return points;

    final merged = <Offset>[];
    for (var point in points) {
      bool found = false;
      for (var existing in merged) {
        if ((point - existing).distance < threshold) {
          found = true;
          break;
        }
      }
      if (!found) {
        merged.add(point);
      }
    }
    return merged;
  }

  // ========== CHECK TRIANGLE ==========
  double _checkTriangle(List<Offset> points, List<Offset> corners) {
    if (corners.length < 3) return 0.0;

    final triangleCorners = corners.length > 3 ? corners.sublist(0, 3) : corners;
    final bounds = _calculateBoundingBox(points);

    // Check if points are near the triangle edges
    int pointsNearEdges = 0;
    for (var point in points) {
      for (int i = 0; i < 3; i++) {
        final start = triangleCorners[i];
        final end = triangleCorners[(i + 1) % 3];
        double dist = _distanceFromLine(point, start, end);
        if (dist < bounds.width * 0.1) {
          pointsNearEdges++;
          break;
        }
      }
    }

    double edgeCoverage = pointsNearEdges / points.length;
    return 0.6 + edgeCoverage * 0.3;
  }

  // ========== CHECK RECTANGLE ==========
  double _checkRectangle(List<Offset> points, List<Offset> corners) {
    if (corners.length < 4) return 0.0;

    final rectCorners = corners.length > 4 ? corners.sublist(0, 4) : corners;
    final bounds = _calculateBoundingBox(points);

    // Check for right angles
    int rightAngles = 0;
    for (int i = 0; i < 4; i++) {
      final a = rectCorners[i];
      final b = rectCorners[(i + 1) % 4];
      final c = rectCorners[(i + 2) % 4];
      final angle = _calculateAngle(a, b, c);
      if ((angle - 90).abs() < 30) {
        rightAngles++;
      }
    }

    // Check if points are near rectangle edges
    int pointsNearEdges = 0;
    for (var point in points) {
      for (int i = 0; i < 4; i++) {
        final start = rectCorners[i];
        final end = rectCorners[(i + 1) % 4];
        double dist = _distanceFromLine(point, start, end);
        if (dist < bounds.width * 0.1) {
          pointsNearEdges++;
          break;
        }
      }
    }

    double edgeCoverage = pointsNearEdges / points.length;
    double angleScore = rightAngles / 4.0;

    return 0.5 + angleScore * 0.3 + edgeCoverage * 0.2;
  }

  // ========== CHECK STAR ==========
  bool _isStar(List<Offset> points) {
    final corners = _findCorners(points);
    if (corners.length < 8) return false;

    final bounds = _calculateBoundingBox(points);
    final center = bounds.center;

    // Stars have alternating distances from center
    List<double> distances = [];
    for (var corner in corners) {
      distances.add((corner - center).distance);
    }

    int changes = 0;
    for (int i = 1; i < distances.length; i++) {
      if ((distances[i] - distances[i-1]).abs() > bounds.width * 0.1) {
        changes++;
      }
    }

    return changes > 3;
  }

  // ========== LINE DETECTION ==========
  bool _isLine(List<Offset> points) {
    if (points.length < 3) return true;

    final start = points.first;
    final end = points.last;
    double maxDeviation = 0;
    double length = (end - start).distance;

    if (length < 20) return false;

    for (var point in points) {
      double deviation = _distanceFromLine(point, start, end);
      maxDeviation = max(maxDeviation, deviation);
    }

    return maxDeviation < length * 0.08;
  }

  // ========== OBJECT CLASSIFICATION ==========
  String _classifyObject(String shape, List<Offset> points) {
    final bounds = _calculateBoundingBox(points);
    final width = bounds.width;
    final height = bounds.height;
    final aspectRatio = width / height;

    switch (shape) {
      case 'circle':
        if (width < 50) return 'Button';
        if (width < 100) return 'Coin';
        if (height > width * 1.2) return 'Oval';
        return 'Circle';

      case 'triangle':
        final orientation = _getTriangleOrientation(points);
        if (orientation == 'upward') {
          if (height > width * 1.3) return 'Mountain';
          return 'Triangle';
        }
        return 'Triangle';

      case 'square':
        return 'Square';

      case 'rectangle':
        if (height > width * 1.8) return 'Door';
        if (width > height * 1.8) return 'Book';
        return 'Rectangle';

      case 'pentagon':
        return 'Pentagon';

      case 'hexagon':
        return 'Hexagon';

      case 'octagon':
        return 'Stop Sign';

      case 'star':
        return 'Star';

      case 'line':
        final angle = _calculateLineAngle(points).abs();
        if (angle < 30) return 'Horizontal Line';
        if (angle > 60) return 'Vertical Line';
        return 'Diagonal Line';

      default:
        return 'Shape';
    }
  }

  // ========== SHAPE CORRECTION METHODS ==========
  List<Offset> applyManualCorrection(List<Offset> points) {
    if (points.length < 3) return points;

    final detection = _detectShape(points);
    final shape = detection['shape'];
    final confidence = detection['confidence'];

    if (confidence < 0.6) {
      return _smoothPoints(points);
    }

    switch (shape) {
      case 'circle':
        return _correctToCircle(points);
      case 'triangle':
        return _correctToTriangle(points);
      case 'square':
        return _correctToSquare(points);
      case 'rectangle':
        return _correctToRectangle(points);
      case 'pentagon':
        return _correctToPolygon(points, 5);
      case 'hexagon':
        return _correctToPolygon(points, 6);
      case 'octagon':
        return _correctToPolygon(points, 8);
      case 'star':
        return _correctToStar(points);
      case 'line':
        return _correctToLine(points);
      default:
        return _smoothPoints(points);
    }
  }

  List<Offset> applyAutoCorrection(List<Offset> points) {
    if (!_autoCorrectionEnabled || points.length < 3) return points;
    return applyManualCorrection(points);
  }

  // ========== PERFECT SHAPE GENERATORS ==========
  List<Offset> _correctToCircle(List<Offset> points) {
    final bounds = _calculateBoundingBox(points);
    final center = bounds.center;
    final radius = max(bounds.width, bounds.height) / 2;
    final numPoints = points.length;

    final circle = <Offset>[];
    for (int i = 0; i < numPoints; i++) {
      final angle = 2 * pi * i / numPoints;
      circle.add(Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      ));
    }
    return circle;
  }

  List<Offset> _correctToTriangle(List<Offset> points) {
    final bounds = _calculateBoundingBox(points);
    final centerX = bounds.center.dx;
    final orientation = _getTriangleOrientation(points);

    List<Offset> triangle;
    if (orientation == 'upward') {
      triangle = [
        Offset(centerX, bounds.top),
        Offset(bounds.right, bounds.bottom),
        Offset(bounds.left, bounds.bottom),
        Offset(centerX, bounds.top),
      ];
    } else {
      triangle = [
        Offset(centerX, bounds.bottom),
        Offset(bounds.right, bounds.top),
        Offset(bounds.left, bounds.top),
        Offset(centerX, bounds.bottom),
      ];
    }
    return _resamplePoints(triangle, points.length);
  }

  List<Offset> _correctToSquare(List<Offset> points) {
    final bounds = _calculateBoundingBox(points);
    final size = max(bounds.width, bounds.height);
    final center = bounds.center;

    final left = center.dx - size / 2;
    final top = center.dy - size / 2;
    final right = center.dx + size / 2;
    final bottom = center.dy + size / 2;

    final square = [
      Offset(left, top),
      Offset(right, top),
      Offset(right, bottom),
      Offset(left, bottom),
      Offset(left, top),
    ];
    return _resamplePoints(square, points.length);
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
    return _resamplePoints(rectangle, points.length);
  }

  List<Offset> _correctToPolygon(List<Offset> points, int sides) {
    final bounds = _calculateBoundingBox(points);
    final center = bounds.center;
    final radius = max(bounds.width, bounds.height) / 2;

    final polygon = <Offset>[];
    for (int i = 0; i <= sides; i++) {
      final angle = 2 * pi * i / sides - pi / 2;
      polygon.add(Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      ));
    }
    return _resamplePoints(polygon, points.length);
  }

  List<Offset> _correctToStar(List<Offset> points) {
    final bounds = _calculateBoundingBox(points);
    final center = bounds.center;
    final outerRadius = max(bounds.width, bounds.height) / 2;
    final innerRadius = outerRadius * 0.4;

    final star = <Offset>[];
    for (int i = 0; i < 10; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = pi * i / 5 - pi / 2;
      star.add(Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      ));
    }
    star.add(star.first);
    return _resamplePoints(star, points.length);
  }

  List<Offset> _correctToLine(List<Offset> points) {
    if (points.length < 2) return points;
    final start = points.first;
    final end = points.last;

    final line = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final t = i / (points.length - 1);
      line.add(Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      ));
    }
    return line;
  }

  List<Offset> _smoothPoints(List<Offset> points) {
    if (points.length < 3) return points;

    final smoothed = <Offset>[points.first];
    for (int i = 1; i < points.length - 1; i++) {
      final avgX = (points[i-1].dx + points[i].dx + points[i+1].dx) / 3;
      final avgY = (points[i-1].dy + points[i].dy + points[i+1].dy) / 3;
      smoothed.add(Offset(avgX, avgY));
    }
    smoothed.add(points.last);
    return smoothed;
  }

  List<Offset> _resamplePoints(List<Offset> source, int targetCount) {
    if (source.length == targetCount) return source;

    final resampled = <Offset>[];
    for (int i = 0; i < targetCount; i++) {
      final t = i / (targetCount - 1) * (source.length - 1);
      final index = t.floor();
      final fraction = t - index;

      if (index >= source.length - 1) {
        resampled.add(source.last);
      } else {
        resampled.add(Offset(
          source[index].dx * (1 - fraction) + source[index + 1].dx * fraction,
          source[index].dy * (1 - fraction) + source[index + 1].dy * fraction,
        ));
      }
    }
    return resampled;
  }

  // ========== BACKGROUND MANAGEMENT ==========
  void selectBackground(String backgroundName) {
    _selectedBackground = backgroundName;
    notifyListeners();
  }

  String getBackgroundPath(String backgroundName) {
    try {
      final background = _backgrounds.firstWhere(
            (bg) => bg.name == backgroundName,
      );
      return background.path;
    } catch (e) {
      return '';
    }
  }

  // ========== CLEAR DETECTIONS ==========
  void clearDetections() {
    _detectedShapes.clear();
    _detectedShape = '';
    _classifiedObject = '';
    _detectionConfidence = 0.0;
    notifyListeners();
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

    if (maxX - minX < 1) maxX = minX + 1;
    if (maxY - minY < 1) maxY = minY + 1;

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double _calculateArea(List<Offset> points) {
    if (points.length < 3) return 0;

    double area = 0;
    for (int i = 0; i < points.length - 1; i++) {
      area += points[i].dx * points[i + 1].dy - points[i + 1].dx * points[i].dy;
    }
    return area.abs() / 2;
  }

  double _calculatePerimeter(List<Offset> points) {
    double perimeter = 0;
    for (int i = 0; i < points.length - 1; i++) {
      perimeter += (points[i + 1] - points[i]).distance;
    }
    return perimeter;
  }

  double _calculateAngle(Offset a, Offset b, Offset c) {
    final ba = a - b;
    final bc = c - b;
    final dot = ba.dx * bc.dx + ba.dy * bc.dy;
    final cross = ba.dx * bc.dy - ba.dy * bc.dx;
    return atan2(cross.abs(), dot) * 180 / pi;
  }

  double _distanceFromLine(Offset point, Offset lineStart, Offset lineEnd) {
    final lineLength = (lineEnd - lineStart).distance;
    if (lineLength < 0.1) return (point - lineStart).distance;

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

  String _getTriangleOrientation(List<Offset> points) {
    final bounds = _calculateBoundingBox(points);
    final center = bounds.center;

    int pointsAbove = 0;
    int pointsBelow = 0;

    for (final point in points) {
      if (point.dy < center.dy) {
        pointsAbove++;
      } else {
        pointsBelow++;
      }
    }

    return pointsAbove > pointsBelow ? 'upward' : 'downward';
  }

  double _calculateLineAngle(List<Offset> points) {
    if (points.length < 2) return 0;
    final start = points.first;
    final end = points.last;
    return atan2(end.dy - start.dy, end.dx - start.dx) * 180 / pi;
  }
}