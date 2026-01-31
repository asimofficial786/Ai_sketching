import 'dart:ui';
import 'package:flutter/material.dart';

class DrawingProvider extends ChangeNotifier {
  List<Offset> _points = [];
  Color _selectedColor = Colors.black;
  double _strokeWidth = 5.0;
  bool _isDrawing = false;
  bool _isErasing = false;

  // History for undo/redo
  List<List<Offset>> _history = [];
  int _historyIndex = -1;

  // Drawing tools state
  String _selectedTool = 'brush'; // 'brush', 'pencil', 'eraser', 'shapes', 'text'

  // Getters
  List<Offset> get points => _points;
  Color get selectedColor => _selectedColor;
  double get strokeWidth => _strokeWidth;
  bool get isDrawing => _isDrawing;
  bool get isErasing => _isErasing;
  String get selectedTool => _selectedTool;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  // Drawing methods
  void startDrawing(Offset point) {
    _isDrawing = true;
    _addToHistory();
    _points.add(point);
    notifyListeners();
  }

  void updateDrawing(Offset point) {
    if (!_isDrawing) return;
    _points.add(point);
    notifyListeners();
  }

  void stopDrawing() {
    _isDrawing = false;
    // Save final stroke to history
    _addToHistory();
    notifyListeners();
  }

  void addPoints(List<Offset> newPoints) {
    _addToHistory();
    _points.addAll(newPoints);
    notifyListeners();
  }

  // Tool controls
  void updateColor(Color color) {
    _selectedColor = color;
    notifyListeners();
  }

  void updateStrokeWidth(double width) {
    _strokeWidth = width;
    notifyListeners();
  }

  void toggleEraser() {
    _isErasing = !_isErasing;
    if (_isErasing) {
      _selectedColor = Colors.white; // Or canvas color
    } else {
      _selectedColor = Colors.black;
    }
    notifyListeners();
  }

  void selectTool(String tool) {
    _selectedTool = tool;
    if (tool == 'eraser') {
      _isErasing = true;
      _selectedColor = Colors.white;
    } else {
      _isErasing = false;
      _selectedColor = Colors.black;
    }
    notifyListeners();
  }

  // Canvas operations
  void clear() {
    _addToHistory();
    _points.clear();
    notifyListeners();
  }

  // History management
  void _addToHistory() {
    // Remove redo history if we're not at the end
    if (_historyIndex < _history.length - 1) {
      _history = _history.sublist(0, _historyIndex + 1);
    }

    // Save current state
    _history.add(List.from(_points));
    _historyIndex = _history.length - 1;

    // Limit history size
    if (_history.length > 20) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void undo() {
    if (canUndo) {
      _historyIndex--;
      _points = List.from(_history[_historyIndex]);
      notifyListeners();
    }
  }

  void redo() {
    if (canRedo) {
      _historyIndex++;
      _points = List.from(_history[_historyIndex]);
      notifyListeners();
    }
  }

  // Save/Load functionality
  List<Map<String, dynamic>> getDrawingData() {
    return _points.map((point) => {
      'x': point.dx,
      'y': point.dy,
      'color': _selectedColor.value,
      'strokeWidth': _strokeWidth,
    }).toList();
  }

  void loadDrawingData(List<Map<String, dynamic>> data) {
    _addToHistory();
    _points.clear();

    for (var pointData in data) {
      _points.add(Offset(
        pointData['x'] as double,
        pointData['y'] as double,
      ));
    }

    if (data.isNotEmpty) {
      _selectedColor = Color(data.first['color'] as int);
      _strokeWidth = data.first['strokeWidth'] as double;
    }

    notifyListeners();
  }
}