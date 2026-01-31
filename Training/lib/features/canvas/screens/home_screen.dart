import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final drawingProvider = Provider.of<DrawingProvider>(context);
    final aiProvider = Provider.of<AIProvider>(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background (if selected)
          if (aiProvider.selectedBackground != 'none')
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(aiProvider.selectedBackground),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
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
              left: screenSize.width / 2 - 150,
              child: _buildAIDetectionCard(aiProvider),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AIProvider aiProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text(
            'AI Sketch Canvas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),

          // AI Correction Toggle
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: aiProvider.autoCorrectionEnabled ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 5),
              Switch(
                value: aiProvider.autoCorrectionEnabled,
                onChanged: (value) => aiProvider.toggleAutoCorrection(),
                activeColor: Colors.green,
              ),
            ],
          ),

          IconButton(
            onPressed: () => setState(() => _showTools = !_showTools),
            icon: Icon(
              _showTools ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
            ),
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
                  IconButton(
                    onPressed: () {
                      // TODO: Implement save
                    },
                    icon: const Icon(Icons.save, color: Colors.white),
                    tooltip: 'Save',
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: Implement erase
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
  Widget _buildAIDetectionCard(AIProvider aiProvider) {
    return Container(
      width: 300,
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
    // Draw all completed points
    final paint = Paint()
      ..color = selectedColor
      ..strokeWidth = brushSize
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    // Draw current stroke
    if (currentStroke.length > 1) {
      for (int i = 0; i < currentStroke.length - 1; i++) {
        canvas.drawLine(currentStroke[i], currentStroke[i + 1], paint);
      }
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