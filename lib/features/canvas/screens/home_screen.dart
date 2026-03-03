import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../../../providers/drawing_provider.dart';
import '../../../providers/ai_provider.dart';
import 'dart:math';

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

  // Add ScreenshotController
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    // Initialize with provider values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final drawingProvider = context.read<DrawingProvider>();
      setState(() {
        _brushSize = drawingProvider.currentStrokeWidth;
        _selectedColor = drawingProvider.currentColor;
        _selectedTool = drawingProvider.currentTool;
      });
    });
  }

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
            // Background - FIXED
            Positioned.fill(
              child: _getBackgroundWidget(aiProvider),
            ),

            // Drawing Canvas
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  drawingProvider.startDrawing(details.localPosition);
                },
                onPanUpdate: (details) {
                  drawingProvider.updateDrawing(details.localPosition);

                  // Analyze for AI if not drawing shapes
                  if (drawingProvider.currentTool != 'shapes' && drawingProvider.currentTool != 'text') {
                    final currentStroke = drawingProvider.currentStroke;
                    if (currentStroke.length > 5 && currentStroke.length % 10 == 0) {
                      aiProvider.analyzePoints(currentStroke);
                    }
                  }
                },
                onPanEnd: (details) {
                  drawingProvider.stopDrawing();

                  // Apply AI correction for freehand drawings only
                  if (drawingProvider.currentTool != 'shapes' &&
                      drawingProvider.currentTool != 'text') {
                    if (aiProvider.autoCorrectionEnabled && drawingProvider.currentStroke.isNotEmpty) {
                      final correctedPoints = aiProvider.applyAutoCorrection(drawingProvider.currentStroke);// <-- THIS LINE
                      if (correctedPoints.isNotEmpty && correctedPoints.length >= 2) {
                        drawingProvider.removeLastStroke();
                        drawingProvider.addCorrectedStroke(correctedPoints);
                      }
                    }
                    aiProvider.clearDetections();
                  }
                },
                child: Consumer2<DrawingProvider, AIProvider>(
                  builder: (context, drawingProvider, aiProvider, child) {
                    return RepaintBoundary(
                      child: CustomPaint(
                        painter: _AICanvasPainter(
                          strokes: drawingProvider.strokes,
                          currentStroke: drawingProvider.currentStroke,
                          strokeColors: drawingProvider.strokeColors,
                          strokeWidths: drawingProvider.strokeWidths,
                          showAIOverlay: _showAIOverlay && aiProvider.showDetectionBoxes,
                          aiProvider: aiProvider,
                          selectedColor: drawingProvider.currentColor,
                          brushSize: _brushSize,
                          shapePreviewPoints: drawingProvider.shapePreviewPoints,
                          selectedShape: drawingProvider.selectedShape,
                          isDrawingShape: drawingProvider.isDrawingShape,
                          texts: drawingProvider.texts,
                        ),
                      ),
                    );
                  },
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
                child: _buildLeftToolbar(context, drawingProvider),
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

            // Debug button (remove after testing)
            Positioned(
              top: 150,
              right: 20,
              child: FloatingActionButton.small(
                onPressed: () {
                  _debugBackground(aiProvider);
                },
                child: Icon(Icons.bug_report),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIXED: Background widget method
  Widget _getBackgroundWidget(AIProvider aiProvider) {
    // If "None" is selected, show white background
    if (aiProvider.selectedBackground == 'none') {
      return Container(color: Colors.white);
    }

    try {
      // Find the background object by name
      final background = aiProvider.backgrounds.firstWhere(
            (bg) => bg.name == aiProvider.selectedBackground,
      );

      // If we found it and it has a path, show the image
      if (background.path.isNotEmpty) {
        return Image.asset(
          background.path,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // If image fails to load, show error placeholder
            print('Error loading background image: $error');
            print('Path: ${background.path}');
            return Container(
              color: Colors.grey[300],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 50, color: Colors.grey[600]),
                    SizedBox(height: 10),
                    Text(
                      'Background not found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      background.name,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        // No path (shouldn't happen except for "None")
        return Container(color: Colors.white);
      }
    } catch (e) {
      // Background not found in list
      print('Error: Background "${aiProvider.selectedBackground}" not found');
      return Container(color: Colors.white);
    }
  }
  // Helper method for auto-correction
  void _applyAutoCorrection(BuildContext context, DrawingProvider drawingProvider, AIProvider aiProvider) {
    if (drawingProvider.strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No drawing to correct!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get the last drawn stroke
    final lastStroke = drawingProvider.getLastStroke();
    if (lastStroke != null && lastStroke.length >= 2) {
      final strokeIndex = drawingProvider.getLastStrokeIndex();

      // Use applyManualCorrection
      final correctedPoints = aiProvider.applyManualCorrection(lastStroke);

      // Check if correction actually changed something
      if (correctedPoints.length >= 2) {
        // Apply the correction
        drawingProvider.applyAutoCorrection(correctedPoints, strokeIndex);

        // Show success message
        final shapeType = aiProvider.detectedShape.isNotEmpty
            ? aiProvider.detectedShape
            : 'shape';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-corrected to $shapeType'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Clear AI detections for fresh analysis
        aiProvider.clearDetections();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not detect shape for correction'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _debugBackground(AIProvider aiProvider) {
    print('=== BACKGROUND DEBUG ===');
    print('Selected background: ${aiProvider.selectedBackground}');
    print('Available backgrounds:');
    for (var bg in aiProvider.backgrounds) {
      print('  - ${bg.name}: ${bg.path}');
    }

    if (aiProvider.selectedBackground != 'none') {
      try {
        final bg = aiProvider.backgrounds.firstWhere(
              (b) => b.name == aiProvider.selectedBackground,
        );
        print('Found: ${bg.name} -> ${bg.path}');
      } catch (e) {
        print('Error finding background: $e');
      }
    }
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

  Widget _buildLeftToolbar(BuildContext context, DrawingProvider drawingProvider) {
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
          // Brush
          _ToolButton(
            icon: Icons.brush,
            label: 'Brush',
            isSelected: drawingProvider.currentTool == 'brush',
            onTap: () {
              drawingProvider.selectTool('brush');
              drawingProvider.updateStrokeWidth(5.0);
              setState(() {
                _selectedTool = 'brush';
                _selectedColor = drawingProvider.currentColor;
                _brushSize = 5.0;
              });
            },
          ),

          // Pencil
          _ToolButton(
            icon: Icons.edit,
            label: 'Pencil',
            isSelected: drawingProvider.currentTool == 'pencil',
            onTap: () {
              drawingProvider.selectTool('pencil');
              drawingProvider.updateStrokeWidth(2.0);
              setState(() {
                _selectedTool = 'pencil';
                _selectedColor = drawingProvider.currentColor;
                _brushSize = 2.0;
              });
            },
          ),

          // Shapes
          _ToolButton(
            icon: Icons.format_shapes,
            label: 'Shapes',
            isSelected: drawingProvider.currentTool == 'shapes',
            onTap: () {
              _showShapeSelectionDialog(context, drawingProvider);
            },
          ),

          // Text
          _ToolButton(
            icon: Icons.text_fields,
            label: 'Text',
            isSelected: drawingProvider.currentTool == 'text',
            onTap: () {
              _showTextInputDialog(context, drawingProvider);
            },
          ),

          const Divider(color: Colors.white30, height: 20),

          // Undo
          _ToolButton(
            icon: Icons.undo,
            label: 'Undo',
            isSelected: false,
            onTap: () {
              final drawingProvider = Provider.of<DrawingProvider>(context, listen: false);
              if (drawingProvider.canUndo) {
                drawingProvider.undo();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Undo performed'),
                    duration: Duration(milliseconds: 800),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nothing to undo'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),

          // Redo
          _ToolButton(
            icon: Icons.redo,
            label: 'Redo',
            isSelected: false,
            onTap: () {
              final drawingProvider = Provider.of<DrawingProvider>(context, listen: false);
              if (drawingProvider.canRedo) {
                drawingProvider.redo();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Redo performed'),
                    duration: Duration(milliseconds: 800),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nothing to redo'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),

          // Clear
          _ToolButton(
            icon: Icons.delete,
            label: 'Clear',
            isSelected: false,
            onTap: () {
              _showClearConfirmationDialog(context, drawingProvider);
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
                _buildColorButton(Colors.black, drawingProvider),
                _buildColorButton(Colors.red, drawingProvider),
                _buildColorButton(Colors.blue, drawingProvider),
                _buildColorButton(Colors.green, drawingProvider),
                _buildColorButton(Colors.yellow, drawingProvider),
                _buildColorButton(Colors.purple, drawingProvider),
                _buildColorButton(Colors.orange, drawingProvider),
                _buildColorButton(Colors.brown, drawingProvider),
                _buildColorButton(Colors.white, drawingProvider),
              ],
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
                      onChanged: (value) {
                        setState(() => _brushSize = value);
                        drawingProvider.updateStrokeWidth(value);
                      },
                      activeColor: _selectedColor,
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                children: [
                  // SAVE BUTTON
                  IconButton(
                    onPressed: () => _saveDrawing(context, drawingProvider),
                    icon: const Icon(Icons.save, color: Colors.white),
                    tooltip: 'Save Drawing',
                  ),
                  // Add this to the bottom toolbar Row after the Save button
                  IconButton(
                    onPressed: () {
                      final drawingProvider = context.read<DrawingProvider>();
                      final aiProvider = context.read<AIProvider>();

                      if (drawingProvider.strokes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('No drawing to correct!'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      // Get the last drawn stroke
                      final lastStroke = drawingProvider.getLastStroke();
                      if (lastStroke != null) {
                        final strokeIndex = drawingProvider.getLastStrokeIndex();
                        final correctedPoints = aiProvider.applyManualCorrection(lastStroke);

                        // Apply the correction
                        drawingProvider.applyAutoCorrection(correctedPoints, strokeIndex);

                        // Show success message
                        final detectedShape = aiProvider.detectedShape;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Auto-corrected to ${detectedShape.isNotEmpty ? detectedShape : "smooth shape"}'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.auto_awesome, color: Colors.yellow),
                    tooltip: 'Auto-Correct Last Shape',
                  ),                  // ERASER BUTTON
                  IconButton(
                    onPressed: () {
                      drawingProvider.toggleEraser();
                      setState(() {
                        _selectedColor = drawingProvider.currentColor;
                        _selectedTool = drawingProvider.currentTool;
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
                    },
                    icon: Icon(
                      drawingProvider.isErasing ? Icons.brush : Icons.cleaning_services,
                      color: Colors.white,
                    ),
                    tooltip: drawingProvider.isErasing ? 'Switch to Brush' : 'Switch to Eraser',
                  ),
                  // CLEAR BUTTON
                  IconButton(
                    onPressed: () {
                      final drawingProvider = Provider.of<DrawingProvider>(context, listen: false);
                      _showClearConfirmationDialog(context, drawingProvider);
                    },
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

  Widget _buildColorButton(Color color, DrawingProvider drawingProvider) {
    return GestureDetector(
      onTap: () {
        drawingProvider.updateColor(color);
        setState(() => _selectedColor = color);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: _ColorButton(
          color: color,
          isSelected: drawingProvider.currentColor == color,
        ),
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

  // Helper Methods
  void _showShapeSelectionDialog(BuildContext context, DrawingProvider drawingProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Shape'),
        backgroundColor: Colors.black.withOpacity(0.9),
        content: Container(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShapeOption(
                icon: Icons.square_outlined,
                label: 'Rectangle',
                onTap: () {
                  drawingProvider.selectShape('rectangle');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rectangle mode: Drag to draw rectangle'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _ShapeOption(
                icon: Icons.circle_outlined,
                label: 'Circle',
                onTap: () {
                  drawingProvider.selectShape('circle');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Circle mode: Drag to draw circle'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _ShapeOption(
                icon: Icons.change_history_outlined,
                label: 'Triangle',
                onTap: () {
                  drawingProvider.selectShape('triangle');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Triangle mode: Drag to draw triangle'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _ShapeOption(
                icon: Icons.horizontal_rule,
                label: 'Line',
                onTap: () {
                  drawingProvider.selectShape('line');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Line mode: Drag to draw straight line'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showTextInputDialog(BuildContext context, DrawingProvider drawingProvider) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        // Calculate position for text (center of screen)
        final screenSize = MediaQuery.of(context).size;
        final position = Offset(
          screenSize.width / 2 - 100,
          screenSize.height / 2 - 50,
        );

        return AlertDialog(
          title: const Text('Add Text'),
          content: SizedBox(
            width: 300,
            child: TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Enter your text here',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  drawingProvider.addText(textController.text.trim(), position);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Text added: "${textController.text}"'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Add Text'),
            ),
          ],
        );
      },
    );
  }

  void _showClearConfirmationDialog(BuildContext context, DrawingProvider drawingProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Canvas'),
        content: const Text('Are you sure you want to clear the entire canvas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              drawingProvider.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Canvas cleared successfully'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Clear All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
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

  // Save Drawing Function
  Future<void> _saveDrawing(BuildContext context, DrawingProvider drawingProvider) async {
    final bool hasStrokes = drawingProvider.strokes.isNotEmpty ||
        drawingProvider.currentStroke.isNotEmpty ||
        drawingProvider.texts.isNotEmpty;

    print("Debug: Total strokes to save = ${drawingProvider.strokes.length}");
    print("Debug: Current stroke points = ${drawingProvider.currentStroke.length}");
    print("Debug: Texts to save = ${drawingProvider.texts.length}");

    if (!hasStrokes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No drawing to save! Please draw something first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
              'Strokes: ${drawingProvider.strokes.length}, Texts: ${drawingProvider.texts.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );

    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final bytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0,
      );

      if (bytes == null) {
        throw Exception('Failed to capture screenshot');
      }

      print("Debug: Screenshot captured - ${bytes.length} bytes");

      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(bytes),
        quality: 100,
        name: 'ai_drawing_${DateTime.now().millisecondsSinceEpoch}',
      );

      print("Debug: Save result = $result");

      if (result['isSuccess'] != true) {
        throw Exception('Failed to save to gallery: ${result['errorMessage']}');
      }

      if (mounted) Navigator.of(context).pop();

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
      if (mounted) Navigator.of(context).pop();
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
}

// Custom Painters
class _AICanvasPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final List<Color> strokeColors;
  final List<double> strokeWidths;
  final bool showAIOverlay;
  final AIProvider aiProvider;
  final Color selectedColor;
  final double brushSize;
  final List<Offset> shapePreviewPoints;
  final String selectedShape;
  final bool isDrawingShape;
  final List<TextData> texts;

  _AICanvasPainter({
    required this.strokes,
    required this.currentStroke,
    required this.strokeColors,
    required this.strokeWidths,
    required this.showAIOverlay,
    required this.aiProvider,
    required this.selectedColor,
    required this.brushSize,
    required this.shapePreviewPoints,
    required this.selectedShape,
    required this.isDrawingShape,
    required this.texts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw each stroke separately
    for (int i = 0; i < strokes.length; i++) {
      final stroke = strokes[i];
      if (stroke.length < 2) continue;

      final paint = Paint()
        ..color = i < strokeColors.length ? strokeColors[i] : Colors.black
        ..strokeWidth = i < strokeWidths.length ? strokeWidths[i] : 5.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);

      for (int j = 1; j < stroke.length; j++) {
        path.lineTo(stroke[j].dx, stroke[j].dy);
      }

      canvas.drawPath(path, paint);
    }

    // Draw current stroke (in progress)
    if (currentStroke.length > 1) {
      final currentPaint = Paint()
        ..color = selectedColor
        ..strokeWidth = brushSize
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final currentPath = Path();
      currentPath.moveTo(currentStroke.first.dx, currentStroke.first.dy);

      for (int i = 1; i < currentStroke.length; i++) {
        currentPath.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }

      canvas.drawPath(currentPath, currentPaint);
    }

    // Draw shape preview
    if (isDrawingShape && shapePreviewPoints.length >= 2) {
      final previewPaint = Paint()
        ..color = selectedColor.withOpacity(0.5)
        ..strokeWidth = brushSize
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final previewPath = Path();
      final start = shapePreviewPoints[0];
      final end = shapePreviewPoints[1];

      switch (selectedShape) {
        case 'rectangle':
          previewPath.moveTo(start.dx, start.dy);
          previewPath.lineTo(end.dx, start.dy);
          previewPath.lineTo(end.dx, end.dy);
          previewPath.lineTo(start.dx, end.dy);
          previewPath.close();
          break;
        case 'circle':
        // Fixed single circle drawing
          final center = Offset(
            (start.dx + end.dx) / 2,
            (start.dy + end.dy) / 2,
          );
          final radius = min((end.dx - start.dx).abs(), (end.dy - start.dy).abs()) / 2;
          previewPath.addOval(Rect.fromCircle(center: center, radius: radius));
          break;
        case 'triangle':
          final centerX = (start.dx + end.dx) / 2;
          previewPath.moveTo(centerX, start.dy);
          previewPath.lineTo(end.dx, end.dy);
          previewPath.lineTo(start.dx, end.dy);
          previewPath.close();
          break;
        case 'line':
          previewPath.moveTo(start.dx, start.dy);
          previewPath.lineTo(end.dx, end.dy);
          break;
      }

      canvas.drawPath(previewPath, previewPaint);
    }

    // Draw texts
    for (final textData in texts) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: textData.text,
          style: TextStyle(
            color: textData.color,
            fontSize: textData.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, textData.position);
    }

    // Draw AI detection boxes
    if (showAIOverlay && aiProvider.detectedShapes.isNotEmpty) {
      final recentShape = aiProvider.detectedShapes.last;

      if (recentShape.bounds.width > 0 && recentShape.bounds.height > 0) {
        final detectionPaint = Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

        canvas.drawRect(recentShape.bounds, detectionPaint);

        final textPainter = TextPainter(
          text: TextSpan(
            text: '${recentShape.shape}\n${recentShape.object}',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.black,
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom Widgets
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: isSelected ? Colors.blue : Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
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

class _ShapeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShapeOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}