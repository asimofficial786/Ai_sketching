// drawing_provider.dart
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class DrawingProvider extends ChangeNotifier {
  List<List<Offset>> _strokes = [];
  List<Color> _strokeColors = [];
  List<double> _strokeWidths = [];

  List<Offset> _currentStroke = [];
  Color _currentColor = Colors.black;
  double _currentStrokeWidth = 5.0;
  String _currentTool = 'brush';

  // History for undo/redo - FIXED
  List<DrawingState> _history = [];
  int _historyIndex = -1;

  bool _isDrawing = false;
  bool _isErasing = false;

  // Shape mode
  String _selectedShape = '';
  List<Offset> _shapePreviewPoints = [];
  bool _isDrawingShape = false;

  // Text
  List<TextData> _texts = [];

  // Auto-correction management
  List<List<Offset>> _pendingCorrections = [];
  bool _hasPendingCorrection = false;

  DrawingProvider() {
    // Initialize with empty state
    _addToHistory();
  }

  // Getters
  List<List<Offset>> get strokes => _strokes;
  List<Color> get strokeColors => _strokeColors;
  List<double> get strokeWidths => _strokeWidths;
  List<Offset> get currentStroke => _currentStroke;
  Color get currentColor => _currentColor;
  double get currentStrokeWidth => _currentStrokeWidth;
  String get currentTool => _currentTool;
  bool get isDrawing => _isDrawing;
  bool get isErasing => _isErasing;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;
  String get selectedShape => _selectedShape;
  List<Offset> get shapePreviewPoints => _shapePreviewPoints;
  bool get isDrawingShape => _isDrawingShape;
  List<TextData> get texts => _texts;
  bool get hasPendingCorrection => _hasPendingCorrection;

  // Drawing methods
  void startDrawing(Offset point) {
    _isDrawing = true;
    if (_currentTool == 'shapes' && _selectedShape.isNotEmpty) {
      _isDrawingShape = true;
      _shapePreviewPoints = [point];
    } else if (_currentTool != 'text') {
      _currentStroke = [point];
    }
    notifyListeners();
  }

  void updateDrawing(Offset point) {
    if (!_isDrawing) return;
    if (_currentTool == 'shapes' && _isDrawingShape) {
      if (_shapePreviewPoints.length == 1) {
        _shapePreviewPoints.add(point);
      } else {
        _shapePreviewPoints[1] = point;
      }
    } else if (_currentTool != 'text') {
      _currentStroke.add(point);
    }
    notifyListeners();
  }

  void stopDrawing() {
    if (!_isDrawing) return;
    _isDrawing = false;

    if (_currentTool == 'shapes' && _isDrawingShape) {
      _completeShapeDrawing();
      _isDrawingShape = false;
    } else if (_currentTool != 'text' && _currentStroke.length > 1) {
      // IMPORTANT: Save the stroke WITHOUT auto-correction
      // Auto-correction will be applied manually when requested
      _saveCurrentStroke();
    }

    // Clear current stroke after saving
    _currentStroke.clear();
    notifyListeners();
  }

  void _saveCurrentStroke() {
    if (_currentStroke.length > 1) {
      _addToHistory();
      _strokes.add(List.from(_currentStroke));
      _strokeColors.add(_currentColor);
      _strokeWidths.add(_currentStrokeWidth);
    }
  }

  void _completeShapeDrawing() {
    if (_shapePreviewPoints.length < 2 || _selectedShape.isEmpty) return;

    final start = _shapePreviewPoints[0];
    final end = _shapePreviewPoints[1];
    List<Offset> shapePoints = [];

    if (_selectedShape == 'rectangle') {
      shapePoints = [start, Offset(end.dx, start.dy), end, Offset(start.dx, end.dy), start];
    } else if (_selectedShape == 'circle') {
      final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final radius = min((end.dx - start.dx).abs(), (end.dy - start.dy).abs()) / 2;
      for (int i = 0; i <= 36; i++) {
        final angle = 2 * pi * i / 36;
        shapePoints.add(Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle)));
      }
    } else if (_selectedShape == 'triangle') {
      final centerX = (start.dx + end.dx) / 2;
      shapePoints = [Offset(centerX, start.dy), end, Offset(start.dx, end.dy), Offset(centerX, start.dy)];
    } else if (_selectedShape == 'line') {
      shapePoints = [start, end];
    }

    if (shapePoints.isNotEmpty) {
      _addToHistory();
      _strokes.add(shapePoints);
      _strokeColors.add(_currentColor);
      _strokeWidths.add(_currentStrokeWidth);
      _shapePreviewPoints.clear();
      _selectedShape = '';
    }
  }

  // Tool methods
  void selectTool(String tool) {
    _currentTool = tool;
    if (tool != 'shapes') {
      _selectedShape = '';
      _isDrawingShape = false;
    }
    _isErasing = (tool == 'eraser');
    if (_isErasing) {
      _currentColor = Colors.white;
    } else if (tool == 'brush') {
      _currentStrokeWidth = 5.0;
    } else if (tool == 'pencil') {
      _currentStrokeWidth = 2.0;
    }
    notifyListeners();
  }

  void selectShape(String shape) {
    _selectedShape = shape;
    _currentTool = 'shapes';
    notifyListeners();
  }

  void updateColor(Color color) {
    _currentColor = color;
    notifyListeners();
  }

  void updateStrokeWidth(double width) {
    _currentStrokeWidth = width;
    notifyListeners();
  }

  void toggleEraser() {
    _isErasing = !_isErasing;
    if (_isErasing) {
      _currentTool = 'eraser';
      _currentColor = Colors.white;
    } else {
      _currentTool = 'brush';
      _currentColor = Colors.black;
    }
    notifyListeners();
  }

  // Text method
  void addText(String text, Offset position) {
    _addToHistory();
    _texts.add(TextData(
      text: text,
      position: position,
      color: _currentColor,
      fontSize: _currentStrokeWidth * 4,
    ));
    notifyListeners();
  }

  // Clear method - FIXED PROPERLY
  void clear() {
    _addToHistory(); // Save current state before clearing
    _strokes.clear();
    _strokeColors.clear();
    _strokeWidths.clear();
    _texts.clear();
    _currentStroke.clear();
    _shapePreviewPoints.clear();
    _selectedShape = '';
    _isDrawingShape = false;
    _hasPendingCorrection = false;
    _pendingCorrections.clear();
    notifyListeners();
  }

  // History methods - COMPLETELY REVISED
  void _addToHistory() {
    // Create a snapshot of current state
    final state = DrawingState(
      strokes: _strokes.map((stroke) => List<Offset>.from(stroke)).toList(),
      colors: List<Color>.from(_strokeColors),
      widths: List<double>.from(_strokeWidths),
      texts: _texts.map((text) => TextData(
        text: text.text,
        position: text.position,
        color: text.color,
        fontSize: text.fontSize,
      )).toList(),
    );

    // If we're not at the end of history (i.e., we've undone),
    // remove all future states
    if (_historyIndex < _history.length - 1) {
      _history = _history.sublist(0, _historyIndex + 1);
    }

    // Add new state
    _history.add(state);
    _historyIndex++;

    // Limit history size (optional)
    if (_history.length > 30) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void undo() {
    if (canUndo) {
      _historyIndex--;
      _restoreState(_history[_historyIndex]);
      notifyListeners();
    }
  }

  void redo() {
    if (canRedo) {
      _historyIndex++;
      _restoreState(_history[_historyIndex]);
      notifyListeners();
    }
  }

  void _restoreState(DrawingState state) {
    _strokes = state.strokes.map((stroke) => List<Offset>.from(stroke)).toList();
    _strokeColors = List<Color>.from(state.colors);
    _strokeWidths = List<double>.from(state.widths);
    _texts = state.texts.map((text) => TextData(
      text: text.text,
      position: text.position,
      color: text.color,
      fontSize: text.fontSize,
    )).toList();

    // Clear temporary data
    _currentStroke.clear();
    _shapePreviewPoints.clear();
    _isDrawingShape = false;
    _hasPendingCorrection = false;
    _pendingCorrections.clear();
  }

  // IMPORTANT: Apply auto-correction manually (only when user requests)
  void applyAutoCorrection(List<Offset> correctedPoints, int strokeIndex) {
    if (strokeIndex < 0 || strokeIndex >= _strokes.length) return;

    _addToHistory();
    _strokes[strokeIndex] = List<Offset>.from(correctedPoints);
    _hasPendingCorrection = false;
    notifyListeners();
  }

  // Get last stroke for correction
  List<Offset>? getLastStroke() {
    if (_strokes.isEmpty) return null;
    return _strokes.last;
  }

  int getLastStrokeIndex() {
    return _strokes.length - 1;
  }

  // Manual correction methods
  void addCorrectedStroke(List<Offset> points) {
    if (points.length < 2) return;
    _addToHistory();
    _strokes.add(List.from(points));
    _strokeColors.add(_currentColor);
    _strokeWidths.add(_currentStrokeWidth);
    notifyListeners();
  }

  void removeLastStroke() {
    if (_strokes.isNotEmpty) {
      _addToHistory();
      _strokes.removeLast();
      _strokeColors.removeLast();
      _strokeWidths.removeLast();
      notifyListeners();
    }
  }

  // Batch correction
  void applyBatchCorrections(List<List<Offset>> correctedStrokes) {
    _addToHistory();
    _strokes = List.from(correctedStrokes);
    notifyListeners();
  }
}

class DrawingState {
  final List<List<Offset>> strokes;
  final List<Color> colors;
  final List<double> widths;
  final List<TextData> texts;

  DrawingState({
    required this.strokes,
    required this.colors,
    required this.widths,
    required this.texts,
  });
}

class TextData {
  final String text;
  final Offset position;
  final Color color;
  final double fontSize;

  TextData({
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
  });

  // Add copyWith method for proper cloning
  TextData copyWith({
    String? text,
    Offset? position,
    Color? color,
    double? fontSize,
  }) {
    return TextData(
      text: text ?? this.text,
      position: position ?? this.position,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}