import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../../../providers/drawing_provider.dart';
import '../../../providers/ai_provider.dart';

class CompleteCanvasScreen extends StatefulWidget {
  const CompleteCanvasScreen({super.key});

  @override
  State<CompleteCanvasScreen> createState() => _CompleteCanvasScreenState();
}

class _CompleteCanvasScreenState extends State<CompleteCanvasScreen> {
  bool _showTools = true;
  bool _showAIOverlay = true;
  double _brushSize = 5.0;
  Color _selectedColor = Colors.black;
  String _selectedTool = 'brush';
  List<Offset> _currentStroke = [];

  // Add ScreenshotController at top level
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    final drawingProvider = Provider.of<DrawingProvider>(context);
    final aiProvider = Provider.of<AIProvider>(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Screenshot(
        controller: _screenshotController,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background (if selected) - FIXED
            aiProvider.selectedBackground != 'none'
                ? Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(aiProvider.selectedBackground),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
                : Positioned.fill(
              child: Container(color: Colors.white),
            ),

            // Drawing Canvas
            Positioned.fill(
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _currentStroke = [details.localPosition];
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentStroke.add(details.localPosition);

                    // Analyze shape in real-time
                    if (_currentStroke.length % 5 == 0) {
                      aiProvider.analyzePoints(_currentStroke);
                    }
                  });
                },
                onPanEnd: (details) {
                  // Apply AI correction if enabled
                  final correctedPoints = aiProvider.applyCorrection(_currentStroke);

                  drawingProvider.addPoints(correctedPoints);
                  _currentStroke.clear();
                  setState(() {});
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _AICanvasPainter(
                      points: drawingProvider.points,
                      currentStroke: _currentStroke,
                      showAIOverlay: _showAIOverlay && aiProvider.showDetectionBoxes,
                      aiProvider: aiProvider,
                      selectedColor: _selectedColor,
                      brushSize: _brushSize,
                    ),
                  ),
                ),
              ),
            ),

            // Top App Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildAppBar(context, aiProvider),
            ),

            // Left Toolbar
            if (_showTools)
              Positioned(
                left: 20,
                top: 100,
                child: _buildLeftToolbar(context),
              ),

            // Right Toolbar (AI Controls)
            if (_showTools)
              Positioned(
                right: 20,
                top: 100,
                child: _buildAIToolbar(context, aiProvider),
              ),

            // Bottom Toolbar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomToolbar(context, drawingProvider, aiProvider),
            ),

            // AI Detection Overlay
            if (_showAIOverlay && aiProvider.detectedShape.isNotEmpty)
              Positioned(
                top: 100,
                left: 10,
                right: 10,
                child: _buildAIDetectionCard(aiProvider, screenSize),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AIProvider aiProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          IconButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/mode-selection',
                    (route) => false,
              );
            },
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            tooltip: 'Back to Mode Selection',
            padding: EdgeInsets.zero,
          ),

          // Title
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              child: const Text(
                'AI Sketch Canvas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const Spacer(),

          // AI Toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.auto_awesome,
                  color: aiProvider.autoCorrectionEnabled ? Colors.green : Colors.grey,
                  size: 18,
                ),
              ),
              Switch(
                value: aiProvider.autoCorrectionEnabled,
                onChanged: (value) => aiProvider.toggleAutoCorrection(),
                activeColor: Colors.green,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),

          // Visibility Toggle
          IconButton(
            onPressed: () => setState(() => _showTools = !_showTools),
            icon: Icon(
              _showTools ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
              size: 22,
            ),
            tooltip: 'Toggle Tools',
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildLeftToolbar(BuildContext context) {
    return Container(
      width: 60,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          _ToolButton(
            icon: Icons.brush,
            label: 'Brush',
            isSelected: _selectedTool == 'brush',
            onTap: () => setState(() => _selectedTool = 'brush'),
          ),
          _ToolButton(
            icon: Icons.edit,
            label: 'Pencil',
            isSelected: _selectedTool == 'pencil',
            onTap: () => setState(() => _selectedTool = 'pencil'),
          ),
          _ToolButton(
            icon: Icons.format_shapes,
            label: 'Shapes',
            isSelected: _selectedTool == 'shapes',
            onTap: () => setState(() => _selectedTool = 'shapes'),
          ),
          _ToolButton(
            icon: Icons.text_fields,
            label: 'Text',
            isSelected: _selectedTool == 'text',
            onTap: () => setState(() => _selectedTool = 'text'),
          ),
          const Divider(color: Colors.white30, height: 20),
          _ToolButton(
            icon: Icons.undo,
            label: 'Undo',
            onTap: () {
              // TODO: Implement undo
            },
          ),
          _ToolButton(
            icon: Icons.redo,
            label: 'Redo',
            onTap: () {
              // TODO: Implement redo
            },
          ),
          _ToolButton(
            icon: Icons.delete,
            label: 'Clear',
            onTap: () {
              // TODO: Implement clear
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAIToolbar(BuildContext context, AIProvider aiProvider) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Controls',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),

          // AI Correction Strength
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Correction Strength',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${(aiProvider.correctionStrength * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              Slider(
                value: aiProvider.correctionStrength,
                min: 0.1,
                max: 1.0,
                onChanged: aiProvider.updateCorrectionStrength,
                activeColor: Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Detection Boxes Toggle
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Show Detection Boxes',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Switch(
                value: _showAIOverlay,
                onChanged: (value) => setState(() => _showAIOverlay = value),
                activeColor: Colors.blue,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Background Selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Background',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: aiProvider.backgrounds.map((bg) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(bg.name),
                        selected: aiProvider.selectedBackground == bg.name,
                        onSelected: (selected) {
                          if (selected) {
                            aiProvider.selectBackground(bg.name);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context, DrawingProvider drawingProvider, AIProvider aiProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          // Color Palette
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ColorButton(color: Colors.black, isSelected: _selectedColor == Colors.black),
                _ColorButton(color: Colors.red, isSelected: _selectedColor == Colors.red),
                _ColorButton(color: Colors.blue, isSelected: _selectedColor == Colors.blue),
                _ColorButton(color: Colors.green, isSelected: _selectedColor == Colors.green),
                _ColorButton(color: Colors.yellow, isSelected: _selectedColor == Colors.yellow),
                _ColorButton(color: Colors.purple, isSelected: _selectedColor == Colors.purple),
                _ColorButton(color: Colors.orange, isSelected: _selectedColor == Colors.orange),
                _ColorButton(color: Colors.brown, isSelected: _selectedColor == Colors.brown),
                _ColorButton(color: Colors.white, isSelected: _selectedColor == Colors.white),
              ].map((btn) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = btn.color),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: btn,
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // Brush Size & Actions
          Row(
            children: [
              // Brush Size
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Brush Size',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Slider(
                      value: _brushSize,
                      min: 1,
                      max: 30,
                      onChanged: (value) => setState(() => _brushSize = value),
                      activeColor: _selectedColor,
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                children: [
                  // SAVE BUTTON - NOW ACTIVE
                  IconButton(
                    onPressed: () => _saveDrawing(context, drawingProvider),
                    icon: const Icon(Icons.save, color: Colors.white),
                    tooltip: 'Save Drawing',
                  ),
                  IconButton(
                    onPressed: () {
                      _toggleEraser(drawingProvider);
                    },
                    icon: const Icon(Icons.cleaning_services, color: Colors.white),
                    tooltip: 'Erase',
                  ),
                  IconButton(
                    onPressed: () => drawingProvider.clear(),
                    icon: const Icon(Icons.delete_forever, color: Colors.white),
                    tooltip: 'Clear All',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIDetectionCard(AIProvider aiProvider, Size screenSize) {
    return Container(
      width: screenSize.width * 0.8,
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI Detection',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _showAIOverlay = false),
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (aiProvider.detectedShape.isNotEmpty) ...[
            Row(
              children: [
                const Text('Shape: ', style: TextStyle(color: Colors.white70)),
                Text(
                  aiProvider.detectedShape.toUpperCase(),
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 5),
            if (aiProvider.classifiedObject.isNotEmpty)
              Row(
                children: [
                  const Text('Object: ', style: TextStyle(color: Colors.white70)),
                  Text(
                    aiProvider.classifiedObject,
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              'Tips: ${_getShapeTips(aiProvider.detectedShape)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ] else ...[
            const Text(
              'Draw something to see AI analysis',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  // Save Drawing Function
  Future<void> _saveDrawing(BuildContext context, DrawingProvider drawingProvider) async {
    // Debug: Check if there are points to save
    print("Debug: Total points to save = ${drawingProvider.points.length}");

    if (drawingProvider.points.isEmpty && _currentStroke.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No drawing to save! Please draw something first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show saving dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Saving drawing...',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Points: ${drawingProvider.points.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );

    try {
      // Add a small delay to ensure UI is rendered
      await Future.delayed(const Duration(milliseconds: 100));

      // Capture screenshot with higher pixel ratio for better quality
      final bytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0, // Higher resolution
      );

      if (bytes == null) {
        throw Exception('Failed to capture screenshot - bytes is null');
      }

      print("Debug: Screenshot captured - ${bytes.length} bytes");

      // Save to gallery
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(bytes),
        quality: 100,
        name: 'ai_drawing_${DateTime.now().millisecondsSinceEpoch}',
      );

      print("Debug: Save result = $result");

      if (result['isSuccess'] != true) {
        throw Exception('Failed to save to gallery: ${result['errorMessage']}');
      }

      // Close dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Drawing saved successfully to gallery!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
            textColor: Colors.white,
          ),
          duration: const Duration(seconds: 3),
        ),
      );

    } catch (e) {
      // Close dialog
      if (mounted) Navigator.of(context).pop();

      // Show error message
      print("Error saving: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _toggleEraser(DrawingProvider drawingProvider) {
    drawingProvider.toggleEraser();
    setState(() {
      _selectedColor = drawingProvider.isErasing ? Colors.white : Colors.black;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          drawingProvider.isErasing ? 'Eraser activated' : 'Drawing mode',
        ),
        backgroundColor: drawingProvider.isErasing ? Colors.blue : Colors.black,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _getShapeTips(String shape) {
    switch (shape) {
      case 'circle':
        return 'Try adding details to make it a clock or sun';
      case 'triangle':
        return 'Perfect for mountains or pyramids';
      case 'square':
      case 'rectangle':
        return 'Great for buildings or windows';
      case 'line':
        return 'Use for horizons or arrows';
      default:
        return 'Keep drawing to see AI suggestions';
    }
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: isSelected ? Colors.blue : Colors.white),
        ),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final bool isSelected;

  const _ColorButton({
    required this.color,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.transparent,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 5,
          ),
        ],
      ),
    );
  }
}

class _AICanvasPainter extends CustomPainter {
  final List<Offset> points;
  final List<Offset> currentStroke;
  final bool showAIOverlay;
  final AIProvider aiProvider;
  final Color selectedColor;
  final double brushSize;

  _AICanvasPainter({
    required this.points,
    required this.currentStroke,
    required this.showAIOverlay,
    required this.aiProvider,
    required this.selectedColor,
    required this.brushSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background (transparent so white shows through)
    final backgroundPaint = Paint()..color = Colors.transparent;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw all completed points
    if (points.isNotEmpty) {
      final paint = Paint()
        ..color = selectedColor
        ..strokeWidth = brushSize
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      // Use Path for smoother lines
      if (points.length > 1) {
        final path = Path();
        path.moveTo(points.first.dx, points.first.dy);

        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }

        canvas.drawPath(path, paint);
      }
    }

    // Draw current stroke
    if (currentStroke.length > 1) {
      final currentPaint = Paint()
        ..color = selectedColor
        ..strokeWidth = brushSize
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final currentPath = Path();
      currentPath.moveTo(currentStroke.first.dx, currentStroke.first.dy);

      for (int i = 1; i < currentStroke.length; i++) {
        currentPath.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }

      canvas.drawPath(currentPath, currentPaint);
    }

    // Draw AI detection boxes
    if (showAIOverlay && aiProvider.detectedShapes.isNotEmpty) {
      final recentShape = aiProvider.detectedShapes.last;

      final detectionPaint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      // Draw bounding box
      canvas.drawRect(recentShape.bounds, detectionPaint);

      // Draw shape label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${recentShape.shape}\n${recentShape.object}',
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          recentShape.bounds.left,
          recentShape.bounds.top - 30,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}