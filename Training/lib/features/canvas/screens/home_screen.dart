import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../../../providers/drawing_provider.dart';
import '../../../providers/ai_provider.dart';
import 'dart:math';
import 'package:training/providers/asset_loader.dart';
import 'package:training/providers/png_loader.dart';

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

  // Asset loading state
  final Map<String, bool> _assetCache = {};
  bool _assetsLoaded = false;

  final ScreenshotController _screenshotController = ScreenshotController();
  final AssetLoader _assetLoader = AssetLoader();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAssets();
      final drawingProvider = context.read<DrawingProvider>();

      // Set callback for 3D object placement
      drawingProvider.onObjectPlaced = (objectName) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$objectName placed! Tap again to place more'),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      };

      setState(() {
        _brushSize = drawingProvider.currentStrokeWidth;
        _selectedColor = drawingProvider.currentColor;
        _selectedTool = drawingProvider.currentTool;
      });
    });
  }

  @override
  void dispose() {
    // Clear callback to prevent memory leaks
    context.read<DrawingProvider>().onObjectPlaced = null;
    super.dispose();
  }

  Future<void> _initializeAssets() async {
    final aiProvider = Provider.of<AIProvider>(context, listen: false);

    // Preload background assets
    for (var bg in aiProvider.backgrounds) {
      if (bg.path.isNotEmpty) {
        final exists = await _assetLoader.assetExists(bg.path);
        _assetCache[bg.path] = exists;
      }
    }

    // Preload 3D assets
    final List<String> threeDAssets = [
      'assets/3d/cube.png',
      'assets/3d/sphere.png',
      'assets/3d/cylinder.png',
      'assets/3d/cone.png',
      'assets/3d/pyramid.png',
      'assets/3d/house.png',
    ];

    for (var path in threeDAssets) {
      final exists = await _assetLoader.assetExists(path);
      _assetCache[path] = exists;
    }

    setState(() {
      _assetsLoaded = true;
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
            // Background with proper error handling
            Positioned.fill(
              child: _buildBackground(aiProvider),
            ),

            // Drawing Canvas with Gesture Detector
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  final position = event.localPosition;
                  if (!drawingProvider.isDrawing) {
                    drawingProvider.startDragging(position);
                  }
                  if (!drawingProvider.isDragging) {
                    drawingProvider.startDrawing(position);
                  }
                },
                onPointerMove: (event) {
                  final position = event.localPosition;
                  if (drawingProvider.isDragging) {
                    drawingProvider.updateDragging(position);
                  } else {
                    drawingProvider.updateDrawing(position);
                    if (drawingProvider.currentTool != 'shapes' &&
                        drawingProvider.currentTool != 'text' &&
                        drawingProvider.currentTool != '3dobjects') {
                      final currentStroke = drawingProvider.currentStroke;
                      if (currentStroke.length > 5 && currentStroke.length % 10 == 0) {
                        aiProvider.analyzePoints(currentStroke);
                      }
                    }
                  }
                },
                onPointerUp: (event) {
                  if (drawingProvider.isDragging) {
                    drawingProvider.stopDragging();
                  } else {
                    drawingProvider.stopDrawing();
                    if (aiProvider.autoCorrectionEnabled &&
                        drawingProvider.currentTool != 'shapes' &&
                        drawingProvider.currentTool != 'text' &&
                        drawingProvider.currentTool != '3dobjects' &&
                        aiProvider.detectedShape.isNotEmpty &&
                        aiProvider.detectionConfidence > 0.65) {
                      _showAutoCorrectionDialog(context, drawingProvider, aiProvider);
                    }
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
                          elements: drawingProvider.elements,
                          threeDObjects: drawingProvider.threeDObjects,
                          showAIOverlay: _showAIOverlay && aiProvider.showDetectionBoxes,
                          aiProvider: aiProvider,
                          selectedColor: drawingProvider.currentColor,
                          brushSize: _brushSize,
                          shapePreviewPoints: drawingProvider.shapePreviewPoints,
                          selectedShape: drawingProvider.selectedShape,
                          isDrawingShape: drawingProvider.isDrawingShape,
                          texts: drawingProvider.texts,
                          selectedElement: drawingProvider.selectedElement,
                          selected3DElement: drawingProvider.selected3DElement,
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
                left: 10,
                top: 80,
                child: _buildLeftToolbar(context, drawingProvider),
              ),

            // Right Toolbar (AI Controls)
            if (_showTools)
              Positioned(
                right: 10,
                top: 80,
                child: _buildAIToolbar(context, aiProvider),
              ),

            // Bottom Toolbar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomToolbar(context, drawingProvider, aiProvider),
            ),

            // AI Detection Card
            if (_showAIOverlay && aiProvider.detectedShape.isNotEmpty && aiProvider.detectionConfidence > 0.5)
              Positioned(
                top: 80,
                left: 10,
                right: 10,
                child: _buildAIDetectionCard(aiProvider, screenSize),
              ),

            // 3D Object Placement Indicator
            if (drawingProvider.isPlacing3DObject && drawingProvider.selected3DObject != null)
              Positioned(
                top: screenSize.height / 2 - 80,
                left: screenSize.width / 2 - 150,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          drawingProvider.selected3DObject!.icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Tap to place ${drawingProvider.selected3DObject!.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Loading Indicator
            if (!_assetsLoaded)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(AIProvider aiProvider) {
    if (aiProvider.selectedBackground == 'none') {
      return Container(color: Colors.white);
    }

    try {
      final background = aiProvider.backgrounds.firstWhere(
            (bg) => bg.name == aiProvider.selectedBackground,
      );

      if (background.path.isNotEmpty) {
        final assetExists = _assetCache[background.path] ?? false;

        if (assetExists) {
          return Image.asset(
            background.path,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorBackground(background.path);
            },
          );
        } else {
          return _buildErrorBackground(background.path);
        }
      }
      return Container(color: Colors.white);
    } catch (e) {
      return Container(color: Colors.white);
    }
  }

  Widget _buildErrorBackground(String path) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 40, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              'Background image not found',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              path.split('/').last,
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  void _showAutoCorrectionDialog(
      BuildContext context,
      DrawingProvider drawingProvider,
      AIProvider aiProvider
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Correction Suggestion', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.black.withOpacity(0.9),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                children: [
                  const Text(
                    'AI detected a ',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    aiProvider.detectedShape,
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    ' shape',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: aiProvider.detectionConfidence,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(
                  aiProvider.detectionConfidence > 0.8 ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Confidence: ${(aiProvider.detectionConfidence * 100).toInt()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text(
                'Would you like to auto-correct it?',
                style: TextStyle(color: Colors.white),
              ),
              if (aiProvider.classifiedObject.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.yellow, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Suggestion: "${aiProvider.classifiedObject}"',
                          style: const TextStyle(color: Colors.blue, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyAutoCorrection(context, drawingProvider, aiProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Correct it'),
          ),
        ],
      ),
    );
  }

  void _applyAutoCorrection(BuildContext context, DrawingProvider drawingProvider, AIProvider aiProvider) {
    if (drawingProvider.strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No drawing to correct!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final lastStroke = drawingProvider.getLastStroke();
    if (lastStroke != null && lastStroke.length >= 2) {
      final strokeIndex = drawingProvider.getLastStrokeIndex();
      final correctedPoints = aiProvider.applyManualCorrection(lastStroke);

      if (correctedPoints.length >= 2) {
        drawingProvider.applyAutoCorrection(correctedPoints, strokeIndex);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-corrected to ${aiProvider.detectedShape} (${(aiProvider.detectionConfidence * 100).toInt()}% confidence)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        aiProvider.clearDetections();
      }
    }
  }

  Widget _buildAppBar(BuildContext context, AIProvider aiProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/mode-selection',
                    (route) => false,
              );
            },
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          const SizedBox(width: 4),
          const Flexible(
            child: Text(
              'AI Sketch Canvas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.auto_awesome,
                  color: aiProvider.autoCorrectionEnabled ? Colors.green : Colors.grey,
                  size: 16,
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: aiProvider.autoCorrectionEnabled,
                  onChanged: (value) => aiProvider.toggleAutoCorrection(),
                  activeColor: Colors.green,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => setState(() => _showTools = !_showTools),
            icon: Icon(
              _showTools ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
              size: 20,
            ),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white, size: 20),
            onPressed: _showAssetStatusDialog,
            tooltip: 'Asset Status',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftToolbar(BuildContext context, DrawingProvider drawingProvider) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            _ToolButton(
              icon: Icons.format_shapes,
              label: 'Shapes',
              isSelected: drawingProvider.currentTool == 'shapes',
              onTap: () {
                _showShapeSelectionDialog(context, drawingProvider);
              },
            ),
            _ToolButton(
              icon: Icons.text_fields,
              label: 'Text',
              isSelected: drawingProvider.currentTool == 'text',
              onTap: () {
                _showTextInputDialog(context, drawingProvider);
              },
            ),
            _ToolButton(
              icon: Icons.view_in_ar,
              label: '3D',
              isSelected: drawingProvider.currentTool == '3dobjects',
              onTap: () {
                _show3DObjectSelectionDialog(context, drawingProvider);
              },
            ),
            const Divider(color: Colors.white30, height: 16),
            _ToolButton(
              icon: Icons.undo,
              label: 'Undo',
              isSelected: false,
              onTap: drawingProvider.canUndo ? () {
                drawingProvider.undo();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Undo performed'),
                    duration: Duration(milliseconds: 800),
                  ),
                );
              } : null,
            ),
            _ToolButton(
              icon: Icons.redo,
              label: 'Redo',
              isSelected: false,
              onTap: drawingProvider.canRedo ? () {
                drawingProvider.redo();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Redo performed'),
                    duration: Duration(milliseconds: 800),
                  ),
                );
              } : null,
            ),
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
      ),
    );
  }

  Widget _buildAIToolbar(BuildContext context, AIProvider aiProvider) {
    return Container(
      width: 200,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height - 160,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'AI Controls',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Correction',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '${(aiProvider.correctionStrength * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
                Slider(
                  value: aiProvider.correctionStrength,
                  min: 0.1,
                  max: 1.0,
                  onChanged: aiProvider.updateCorrectionStrength,
                  activeColor: Colors.green,
                  divisions: 9,
                  label: '${(aiProvider.correctionStrength * 100).toInt()}%',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Show Boxes',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Switch(
                  value: _showAIOverlay,
                  onChanged: (value) => setState(() => _showAIOverlay = value),
                  activeColor: Colors.blue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Background',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: aiProvider.backgrounds.length,
                itemBuilder: (context, index) {
                  final bg = aiProvider.backgrounds[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(bg.name, style: const TextStyle(fontSize: 11)),
                      selected: aiProvider.selectedBackground == bg.name,
                      onSelected: (selected) {
                        if (selected) {
                          aiProvider.selectBackground(bg.name);
                        }
                      },
                      selectedColor: Colors.blue.withOpacity(0.3),
                      labelStyle: TextStyle(
                        color: aiProvider.selectedBackground == bg.name ? Colors.white : Colors.grey,
                        fontSize: 11,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (aiProvider.detectedShape.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detection:',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            aiProvider.detectedShape,
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: aiProvider.detectionConfidence > 0.7 ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(aiProvider.detectionConfidence * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                    if (aiProvider.classifiedObject.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        aiProvider.classifiedObject,
                        style: const TextStyle(color: Colors.blue, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context, DrawingProvider drawingProvider, AIProvider aiProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color palette - scrollable horizontally
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _colorPalette.length,
              itemBuilder: (context, index) {
                final color = _colorPalette[index];
                return GestureDetector(
                  onTap: () {
                    drawingProvider.updateColor(color);
                    setState(() => _selectedColor = color);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    child: _ColorButton(
                      color: color,
                      isSelected: drawingProvider.currentColor == color,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Controls row
          Row(
            children: [
              // Brush size slider - expanded
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const Text(
                      'Size:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Slider(
                        value: _brushSize,
                        min: 1,
                        max: 30,
                        onChanged: (value) {
                          setState(() => _brushSize = value);
                          drawingProvider.updateStrokeWidth(value);
                        },
                        activeColor: _selectedColor,
                        divisions: 29,
                        label: _brushSize.round().toString(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action buttons - fixed width
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _saveDrawing(context, drawingProvider),
                    icon: const Icon(Icons.save, color: Colors.white, size: 20),
                    tooltip: 'Save Drawing',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                  IconButton(
                    onPressed: () {
                      if (drawingProvider.strokes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No drawing to correct!'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      final lastStroke = drawingProvider.getLastStroke();
                      if (lastStroke != null) {
                        final strokeIndex = drawingProvider.getLastStrokeIndex();
                        final correctedPoints = aiProvider.applyManualCorrection(lastStroke);
                        drawingProvider.applyAutoCorrection(correctedPoints, strokeIndex);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Auto-corrected to ${aiProvider.detectedShape.isNotEmpty ? aiProvider.detectedShape : "smooth shape"}'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.auto_awesome, color: Colors.yellow, size: 20),
                    tooltip: 'Auto-Correct Last Shape',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                  IconButton(
                    onPressed: () {
                      drawingProvider.toggleEraser();
                      setState(() {
                        _selectedColor = drawingProvider.currentColor;
                        _selectedTool = drawingProvider.currentTool;
                      });
                    },
                    icon: Icon(
                      drawingProvider.isErasing ? Icons.brush : Icons.cleaning_services,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: drawingProvider.isErasing ? 'Switch to Brush' : 'Switch to Eraser',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                  IconButton(
                    onPressed: () {
                      _showClearConfirmationDialog(context, drawingProvider);
                    },
                    icon: const Icon(Icons.delete_forever, color: Colors.white, size: 20),
                    tooltip: 'Clear All',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  final List<Color> _colorPalette = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.brown,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.cyan,
    Colors.amber,
    Colors.lime,
    Colors.white,
  ];

  Widget _buildAIDetectionCard(AIProvider aiProvider, Size screenSize) {
    return Container(
      width: screenSize.width * 0.8,
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              const Text(
                'AI Detection',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: aiProvider.detectionConfidence > 0.7 ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(aiProvider.detectionConfidence * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showAIOverlay = false),
                icon: const Icon(Icons.close, color: Colors.white, size: 14),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(2),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (aiProvider.detectedShape.isNotEmpty) ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Shape: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  aiProvider.detectedShape.toUpperCase(),
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            if (aiProvider.classifiedObject.isNotEmpty) ...[
              const SizedBox(height: 2),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Object: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    aiProvider.classifiedObject,
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Tip: ${_getShapeTips(aiProvider.detectedShape)}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ] else ...[
            const Text(
              'Draw something to see AI analysis',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  void _showShapeSelectionDialog(BuildContext context, DrawingProvider drawingProvider) {
    final List<Map<String, dynamic>> shapeCategories = [
      {
        'category': 'Basic Shapes',
        'shapes': [
          {'name': 'Rectangle', 'icon': Icons.crop_square, 'type': 'rectangle'},
          {'name': 'Square', 'icon': Icons.crop_square, 'type': 'square'},
          {'name': 'Circle', 'icon': Icons.circle_outlined, 'type': 'circle'},
          {'name': 'Triangle', 'icon': Icons.change_history, 'type': 'triangle'},
          {'name': 'Equilateral Triangle', 'icon': Icons.change_history, 'type': 'equilateral_triangle'},
          {'name': 'Line', 'icon': Icons.horizontal_rule, 'type': 'line'},
        ]
      },
      {
        'category': 'Polygons',
        'shapes': [
          {'name': 'Pentagon', 'icon': Icons.pentagon, 'type': 'pentagon'},
          {'name': 'Hexagon', 'icon': Icons.hexagon, 'type': 'hexagon'},
          {'name': 'Heptagon', 'icon': Icons.polyline, 'type': 'heptagon'},
          {'name': 'Octagon', 'icon': Icons.polyline, 'type': 'octagon'},
        ]
      },
      {
        'category': 'Special',
        'shapes': [
          {'name': 'Star', 'icon': Icons.star_outline, 'type': 'star'},
          {'name': 'Cross', 'icon': Icons.close, 'type': 'cross'},
          {'name': 'Arrow', 'icon': Icons.arrow_forward, 'type': 'arrow'},
          {'name': 'Rhombus', 'icon': Icons.crop_square, 'type': 'rhombus'},
        ]
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Shape', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.black.withOpacity(0.9),
        content: Container(
          width: min(350, MediaQuery.of(context).size.width * 0.8),
          height: 400,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  color: Colors.grey[900],
                  child: const TabBar(
                    tabs: [
                      Tab(text: 'Basic'),
                      Tab(text: 'Polygons'),
                      Tab(text: 'Special'),
                    ],
                    indicatorColor: Colors.blue,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildShapeGrid(shapeCategories[0]['shapes'], drawingProvider, context),
                      _buildShapeGrid(shapeCategories[1]['shapes'], drawingProvider, context),
                      _buildShapeGrid(shapeCategories[2]['shapes'], drawingProvider, context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildShapeGrid(List shapes, DrawingProvider drawingProvider, BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      padding: const EdgeInsets.all(8),
      itemCount: shapes.length,
      itemBuilder: (context, index) {
        final shape = shapes[index];
        return GestureDetector(
          onTap: () {
            drawingProvider.selectShape(shape['type']);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${shape['name']} mode: Drag to draw'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(shape['icon'], color: Colors.white, size: 28),
                const SizedBox(height: 4),
                Text(
                  shape['name'],
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // FIXED: 3D Object Selection Dialog with proper StatefulBuilder implementation
  void _show3DObjectSelectionDialog(BuildContext context, DrawingProvider drawingProvider) {
    final List<Map<String, dynamic>> objects = [
      {
        'name': 'Cube',
        'icon': Icons.crop_square,
        'imagePath': 'assets/3d/cube.png',
        'id': 'cube',
        'size': 100.0
      },
      {
        'name': 'Sphere',
        'icon': Icons.circle,
        'imagePath': 'assets/3d/sphere.png',
        'id': 'sphere',
        'size': 100.0
      },
      {
        'name': 'Cylinder',
        'icon': Icons.view_in_ar,
        'imagePath': 'assets/3d/cylinder.png',
        'id': 'cylinder',
        'size': 100.0
      },
      {
        'name': 'Cone',
        'icon': Icons.change_history,
        'imagePath': 'assets/3d/cone.png',
        'id': 'cone',
        'size': 100.0
      },
      {
        'name': 'Pyramid',
        'icon': Icons.change_history,
        'imagePath': 'assets/3d/pyramid.png',
        'id': 'pyramid',
        'size': 100.0
      },
      {
        'name': 'House',
        'icon': Icons.home,
        'imagePath': 'assets/3d/house.png',
        'id': 'house',
        'size': 100.0
      },
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Select 3D Object',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          backgroundColor: Colors.black.withOpacity(0.95),
          content: Container(
            width: min(400, MediaQuery.of(context).size.width * 0.9),
            height: 500,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: objects.length,
              itemBuilder: (context, index) {
                final obj = objects[index];
                return FutureBuilder<ui.Image?>(
                  future: PNGLoader.loadImage(obj['imagePath']),
                  builder: (context, snapshot) {
                    final image = snapshot.data;

                    return GestureDetector(
                      onTap: () async {
                        // Create 3D object with preloaded image
                        final threeDObject = ThreeDObject(
                          id: obj['id'],
                          name: obj['name'],
                          assetPath: obj['imagePath'],
                          icon: obj['icon'],
                          position: Offset.zero,
                          size: 100.0,
                          cachedImage: image,
                        );

                        drawingProvider.select3DObject(threeDObject);
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${obj['name']} selected: Tap anywhere on canvas to place it',
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.blue,
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: snapshot.connectionState == ConnectionState.waiting
                                    ? const CircularProgressIndicator(color: Colors.blue)
                                    : image != null
                                    ? CustomPaint(
                                  painter: _ImagePainter(image),
                                  size: const Size(80, 80),
                                )
                                    : Icon(
                                  obj['icon'],
                                  color: Colors.blue,
                                  size: 60,
                                ),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                obj['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.grey[800],
              ),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showTextInputDialog(BuildContext context, DrawingProvider drawingProvider) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final position = Offset(
          screenSize.width / 2 - 100,
          screenSize.height / 2 - 50,
        );

        return AlertDialog(
          title: const Text('Add Text', style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.black.withOpacity(0.9),
          content: SizedBox(
            width: 280,
            child: TextField(
              controller: textController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Enter your text',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              autofocus: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 14)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add', style: TextStyle(fontSize: 14)),
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
        title: const Text('Clear Canvas', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.black.withOpacity(0.9),
        content: const Text(
          'Are you sure you want to clear the entire canvas?',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () {
              drawingProvider.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Canvas cleared successfully'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _showAssetStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Asset Status', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.black.withOpacity(0.95),
        content: Container(
          width: min(400, MediaQuery.of(context).size.width * 0.8),
          height: 400,
          padding: const EdgeInsets.all(8),
          child: _buildAssetStatusList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.blue.withOpacity(0.2),
            ),
            child: const Text('CLOSE', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetStatusList() {
    final found = _assetCache.values.where((v) => v).length;
    final missing = _assetCache.values.where((v) => !v).length;

    return Column(
      children: [
        Container(
          height: 60,
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('TOTAL', _assetCache.length.toString(), Colors.blue),
              _buildStatCard('FOUND', found.toString(), Colors.green),
              _buildStatCard('MISSING', missing.toString(), Colors.red),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade800, width: 1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(4),
              itemCount: _assetCache.length,
              itemBuilder: (context, index) {
                final entry = _assetCache.entries.elementAt(index);
                final fileName = entry.key.split('/').last;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: entry.value ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: entry.value ? Colors.green : Colors.red,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        entry.value ? Icons.check_circle : Icons.error,
                        color: entry.value ? Colors.green : Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 11,
                            color: entry.value ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!entry.value)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'MISSING',
                            style: TextStyle(color: Colors.red, fontSize: 7, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getShapeTips(String shape) {
    switch (shape.toLowerCase()) {
      case 'circle':
        return 'Try adding details to make it a clock or sun';
      case 'triangle':
        return 'Perfect for mountains or pyramids';
      case 'square':
      case 'rectangle':
        return 'Great for buildings or windows';
      case 'line':
        return 'Use for horizons or arrows';
      case 'pentagon':
        return 'Great for house shapes';
      case 'hexagon':
        return 'Perfect for honeycomb patterns';
      case 'octagon':
        return 'Stop sign shape';
      default:
        return 'Keep drawing to see AI suggestions';
    }
  }

  Future<void> _saveDrawing(BuildContext context, DrawingProvider drawingProvider) async {
    final bool hasContent = drawingProvider.strokes.isNotEmpty ||
        drawingProvider.currentStroke.isNotEmpty ||
        drawingProvider.texts.isNotEmpty ||
        drawingProvider.elements.isNotEmpty ||
        drawingProvider.threeDObjects.isNotEmpty;

    if (!hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No drawing to save!'),
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Saving drawing...', style: TextStyle(color: Colors.white)),
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

      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(bytes),
        quality: 100,
        name: 'ai_drawing_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) Navigator.of(context).pop();

      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Drawing saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to save to gallery');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
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
  final List<DrawingElement> elements;
  final List<ThreeDObject> threeDObjects;
  final bool showAIOverlay;
  final AIProvider aiProvider;
  final Color selectedColor;
  final double brushSize;
  final List<Offset> shapePreviewPoints;
  final String selectedShape;
  final bool isDrawingShape;
  final List<TextData> texts;
  final DrawingElement? selectedElement;
  final ThreeDObject? selected3DElement;

  _AICanvasPainter({
    required this.strokes,
    required this.currentStroke,
    required this.strokeColors,
    required this.strokeWidths,
    required this.elements,
    required this.threeDObjects,
    required this.showAIOverlay,
    required this.aiProvider,
    required this.selectedColor,
    required this.brushSize,
    required this.shapePreviewPoints,
    required this.selectedShape,
    required this.isDrawingShape,
    required this.texts,
    this.selectedElement,
    this.selected3DElement,
  });

  Color _getColorForObject(String objectName) {
    switch (objectName.toLowerCase()) {
      case 'cube': return Colors.red;
      case 'sphere': return Colors.blue;
      case 'cylinder': return Colors.green;
      case 'cone': return Colors.orange;
      case 'pyramid': return Colors.purple;
      case 'house': return Colors.brown;
      default: return Colors.grey;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw strokes
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

    // Draw elements (draggable shapes)
    for (final element in elements) {
      if (element.points == null || element.points!.length < 2) continue;

      final paint = Paint()
        ..color = element.color
        ..strokeWidth = element.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final path = Path();
      path.moveTo(element.points!.first.dx, element.points!.first.dy);

      for (int j = 1; j < element.points!.length; j++) {
        path.lineTo(element.points![j].dx, element.points![j].dy);
      }

      canvas.drawPath(path, paint);

      if (selectedElement != null && selectedElement!.id == element.id) {
        final selectionPaint = Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

        canvas.drawRect(element.bounds.inflate(8), selectionPaint);
      }
    }

    // Draw 3D objects with PNG support
    for (final obj in threeDObjects) {
      final rect = Rect.fromCenter(
        center: obj.position,
        width: obj.size * obj.scale,
        height: obj.size * obj.scale,
      );

      if (obj.cachedImage != null) {
        // Draw actual PNG image
        canvas.drawImageRect(
          obj.cachedImage!,
          Rect.fromLTWH(
              0,
              0,
              obj.cachedImage!.width.toDouble(),
              obj.cachedImage!.height.toDouble()
          ),
          rect,
          Paint(),
        );

        // Draw selection border if selected
        if (selected3DElement != null && selected3DElement!.id == obj.id) {
          final borderPaint = Paint()
            ..color = Colors.yellow
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;
          canvas.drawRect(rect.inflate(5), borderPaint);
        }
      } else {
        // Fallback to colored rectangle
        Color objectColor = _getColorForObject(obj.name);
        final paint = Paint()..color = objectColor.withOpacity(0.5);
        canvas.drawRect(rect, paint);

        final borderPaint = Paint()
          ..color = objectColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRect(rect, borderPaint);
      }
    }

    // Draw current stroke
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

      final start = shapePreviewPoints[0];
      final end = shapePreviewPoints[1];
      final previewPath = Path();

      switch (selectedShape) {
        case 'rectangle':
        case 'square':
          previewPath.moveTo(start.dx, start.dy);
          previewPath.lineTo(end.dx, start.dy);
          previewPath.lineTo(end.dx, end.dy);
          previewPath.lineTo(start.dx, end.dy);
          previewPath.close();
          break;
        case 'circle':
          final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
          final radius = min((end.dx - start.dx).abs(), (end.dy - start.dy).abs()) / 2;
          previewPath.addOval(Rect.fromCircle(center: center, radius: radius));
          break;
        case 'triangle':
        case 'equilateral_triangle':
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
        default:
          previewPath.moveTo(start.dx, start.dy);
          previewPath.lineTo(end.dx, start.dy);
          previewPath.lineTo(end.dx, end.dy);
          previewPath.lineTo(start.dx, end.dy);
          previewPath.close();
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
          ..color = recentShape.confidence > 0.7 ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

        canvas.drawRect(recentShape.bounds, detectionPaint);

        final textPainter = TextPainter(
          text: TextSpan(
            text: '${recentShape.shape} (${(recentShape.confidence * 100).toInt()}%)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.black87,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(recentShape.bounds.left, recentShape.bounds.top - textPainter.height - 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// FIXED: Image painter with proper ui.Image type
class _ImagePainter extends CustomPainter {
  final ui.Image image; // FIXED: Use ui.Image instead of Image

  _ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom Widgets
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = onTap == null ? 0.3 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isSelected ? Border.all(color: Colors.blue, width: 1) : null,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.blue : Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.white70,
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
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
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 4,
            spreadRadius: isSelected ? 1 : 0,
          ),
        ],
      ),
    );
  }
}