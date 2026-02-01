import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:confetti/confetti.dart';
import 'package:screenshot/screenshot.dart';

import '../../providers/air_drawing_provider.dart';
import '../../widgets/reusable/tool_button.dart';

class AirDrawingScreen extends StatefulWidget {
  const AirDrawingScreen({super.key});

  @override
  State<AirDrawingScreen> createState() => _AirDrawingScreenState();
}

class _AirDrawingScreenState extends State<AirDrawingScreen> {
  late CameraController _cameraController;
  HandLandmarkerPlugin? _handPlugin;
  bool _isCameraReady = false;
  bool _isDetecting = false;
  late ConfettiController _confettiController;
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _initializeCameraAndPlugin();
  }

  Future<void> _initializeCameraAndPlugin() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController.initialize();

      _handPlugin = HandLandmarkerPlugin.create(
        numHands: 1,
        minHandDetectionConfidence: 0.7,
        delegate: HandLandmarkerDelegate.gpu,
      );

      await _cameraController.startImageStream(_processCameraFrame);

      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint('Initialization failed: $e');
      _showErrorSnackbar('Camera initialization failed');
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (!_isCameraReady || _isDetecting || _handPlugin == null) return;
    _isDetecting = true;

    try {
      final List<Hand> hands = _handPlugin!.detect(
        image,
        _cameraController.description.sensorOrientation,
      );

      if (mounted) {
        final provider = Provider.of<AirDrawingProvider>(context, listen: false);
        if (hands.isNotEmpty) {
          final landmarks = hands.first.landmarks
              .map((lm) => Offset(lm.x, lm.y))
              .toList();
          provider.updateHandData(landmarks);
        } else {
          provider.updateHandData([]);
        }
      }
    } catch (e) {
      debugPrint('Frame processing error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _saveDrawing() async {
    try {
      final provider = Provider.of<AirDrawingProvider>(context, listen: false);

      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Saving drawing...'),
            ],
          ),
        ),
      );

      final gallerySaved = await provider.saveDrawingToGallery();

      Navigator.pop(context);

      if (gallerySaved) {
        _confettiController.play();
        _showSuccessSnackbar('Drawing saved to gallery!');
      } else {
        _showErrorSnackbar('Failed to save drawing');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackbar('Error: ${e.toString()}');
    }
  }

  Future<void> _showSaveOptions() async {
    final result = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Save Drawing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildSaveOption(
              icon: Icons.photo_library,
              title: 'Save to Gallery',
              subtitle: 'Save as image to your device gallery',
              onTap: () async {
                Navigator.pop(context, 'gallery');
              },
            ),
            _buildSaveOption(
              icon: Icons.save,
              title: 'Save Locally',
              subtitle: 'Save to app documents folder',
              onTap: () async {
                Navigator.pop(context, 'local');
              },
            ),
            _buildSaveOption(
              icon: Icons.code,
              title: 'Export as JSON',
              subtitle: 'Save drawing data for later editing',
              onTap: () async {
                Navigator.pop(context, 'json');
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final provider = Provider.of<AirDrawingProvider>(context, listen: false);
      try {
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Saving...'),
              ],
            ),
          ),
        );

        String message = '';
        switch (result) {
          case 'gallery':
            final saved = await provider.saveDrawingToGallery();
            message = saved ? 'Saved to gallery!' : 'Failed to save';
            if (saved) _confettiController.play();
            break;
          case 'local':
            final path = await provider.saveDrawingLocally();
            message = 'Saved locally: ${path.split('/').last}';
            break;
          case 'json':
            final path = await provider.exportDrawingAsJson();
            message = 'Exported as JSON: ${path.split('/').last}';
            break;
        }

        Navigator.pop(context);
        _showSuccessSnackbar(message);
      } catch (e) {
        Navigator.pop(context);
        _showErrorSnackbar('Error: ${e.toString()}');
      }
    }
  }

  Widget _buildSaveOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
      onTap: onTap,
      tileColor: Colors.grey[800],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  void dispose() {
    _cameraController.stopImageStream();
    _cameraController.dispose();
    _handPlugin?.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Screenshot(
      controller: context.read<AirDrawingProvider>().screenshotController,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Air Drawing Canvas'),
          backgroundColor: Colors.grey[900],
          elevation: 10,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSettings,
              tooltip: 'Settings',
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _showSaveOptions,
              tooltip: 'Save Drawing',
            ),
          ],
        ),
        body: Consumer<AirDrawingProvider>(
          builder: (context, provider, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Camera Preview with overlay
                _buildCameraPreview(screenSize, provider),

                // Drawing Canvas
                _buildDrawingCanvas(screenSize, provider),

                // Hand Skeleton (toggleable)
                if (provider.showHandSkeleton)
                  _buildHandSkeleton(screenSize, provider),

                // Control Overlays
                _buildStatusOverlay(provider),
                _buildControlPanel(context, provider),

                // Confetti Effect
                ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCameraPreview(Size screenSize, AirDrawingProvider provider) {
    return Stack(
      children: [
        if (_isCameraReady)
          CameraPreview(_cameraController)
        else
          Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Initializing Camera...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        // Grid Overlay for better precision
        if (provider.handDetected && provider.isDrawing)
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(screenSize: screenSize),
            ),
          ),
      ],
    );
  }

  Widget _buildDrawingCanvas(Size screenSize, AirDrawingProvider provider) {
    return Positioned.fill(
      child: Opacity(
        opacity: provider.canvasOpacity,
        child: CustomPaint(
          painter: _AirDrawingCanvasPainter(
            points: provider.points,
            cursorPosition: provider.cursorPosition,
            handDetected: provider.handDetected,
            showCursor: provider.showCursor,
            cursorColor: provider.cursorColor,
            cursorSize: provider.cursorSize,
            screenSize: screenSize,
          ),
        ),
      ),
    );
  }

  Widget _buildHandSkeleton(Size screenSize, AirDrawingProvider provider) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _HandSkeletonPainter(
          landmarks: provider.handLandmarks,
          screenSize: screenSize,
        ),
      ),
    );
  }

  Widget _buildStatusOverlay(AirDrawingProvider provider) {
    return Positioned(
      top: 70,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Status Indicator
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: provider.handDetected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: provider.handDetected
                            ? Colors.green.withOpacity(0.8)
                            : Colors.red.withOpacity(0.8),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.handDetected ? 'HAND DETECTED' : 'NO HAND',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      provider.isDrawing ? '● DRAWING' : 'READY',
                      style: TextStyle(
                        color: provider.isDrawing ? Colors.green : Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Points Counter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue),
              ),
              child: Text(
                '${provider.points.length} points',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context, AirDrawingProvider provider) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.9),
            ],
          ),
        ),
        child: Column(
          children: [
            // Quick Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ToolButton(
                  icon: Icons.undo,
                  label: 'Undo',
                  onTap: provider.points.isNotEmpty ? provider.undo : null, // Change this
                  color: Colors.blue,
                ),
                ToolButton(
                  icon: Icons.delete,
                  label: 'Clear',
                  onTap: provider.points.isNotEmpty ? provider.clearDrawing : null, // Change this
                  color: Colors.red,
                ),
                ToolButton(
                  icon: Icons.palette,
                  label: 'Colors',
                  onTap: _showColorPicker, // Change this
                  color: provider.selectedColor,
                ),
                ToolButton(
                  icon: Icons.save,
                  label: 'Save',
                  onTap: provider.points.isNotEmpty ? _showSaveOptions : null, // Change this
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Drawing Control
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  // Drawing Toggle Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: provider.handDetected ? provider.toggleDrawing : null,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          provider.isDrawing ? Icons.stop : Icons.play_arrow,
                          key: ValueKey<bool>(provider.isDrawing),
                        ),
                      ),
                      label: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          provider.isDrawing ? 'STOP DRAWING' : 'START DRAWING',
                          key: ValueKey<bool>(provider.isDrawing),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: provider.isDrawing ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Brush Controls
                  Row(
                    children: [
                      const Icon(Icons.brush, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Brush Size',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: provider.selectedColor,
                                inactiveTrackColor: Colors.white30,
                                thumbColor: provider.selectedColor,
                                overlayColor: provider.selectedColor.withOpacity(0.3),
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 10,
                                ),
                              ),
                              child: Slider(
                                value: provider.strokeWidth,
                                min: 3,
                                max: 25,
                                divisions: 22,
                                onChanged: provider.updateStrokeWidth,
                                label: '${provider.strokeWidth.toInt()}px',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: provider.selectedColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '${provider.strokeWidth.toInt()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    final provider = Provider.of<AirDrawingProvider>(context, listen: false);
    final colors = [
      Colors.blueAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.yellowAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
      Colors.orangeAccent,
      Colors.tealAccent,
      Colors.white,
      Colors.black,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Color',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: colors.map((color) {
                return GestureDetector(
                  onTap: () {
                    provider.updateColor(color);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: provider.selectedColor == color
                            ? Colors.white
                            : Colors.transparent,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: provider.selectedColor == color
                        ? const Center(
                      child: Icon(Icons.check, color: Colors.white),
                    )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    final provider = Provider.of<AirDrawingProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Drawing Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Canvas Opacity
              _buildSettingItem(
                icon: Icons.opacity,
                title: 'Canvas Opacity',
                subtitle: 'Adjust drawing layer transparency',
                child: Slider(
                  value: provider.canvasOpacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  onChanged: provider.updateCanvasOpacity,
                  activeColor: Colors.blue,
                ),
              ),

              // Hand Skeleton Toggle
              _buildSettingItem(
                icon: Icons.architecture,
                title: 'Show Hand Skeleton',
                subtitle: 'Toggle hand landmark visualization',
                child: Switch(
                  value: provider.showHandSkeleton,
                  onChanged: (value) => provider.toggleHandSkeleton(),
                  activeColor: Colors.blue,
                ),
              ),

              // Cursor Toggle
              _buildSettingItem(
                icon: Icons.mouse,
                title: 'Show Cursor',
                subtitle: 'Toggle drawing cursor visibility',
                child: Switch(
                  value: provider.showCursor,
                  onChanged: (value) => provider.toggleCursor(),
                  activeColor: Colors.blue,
                ),
              ),

              // Cursor Color
              _buildSettingItem(
                icon: Icons.color_lens,
                title: 'Cursor Color',
                subtitle: 'Change cursor color',
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: provider.cursorColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Slider(
                        value: provider.cursorColor.red.toDouble(),
                        min: 0,
                        max: 255,
                        divisions: 255,
                        onChanged: (value) {
                          provider.updateCursorColor(
                            Color.fromRGBO(
                              value.toInt(),
                              provider.cursorColor.green,
                              provider.cursorColor.blue,
                              1,
                            ),
                          );
                        },
                        activeColor: provider.cursorColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('Close Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced Canvas Painter
class _AirDrawingCanvasPainter extends CustomPainter {
  final List<AirDrawingPoint> points;
  final Offset? cursorPosition;
  final bool handDetected;
  final bool showCursor;
  final Color cursorColor;
  final double cursorSize;
  final Size screenSize;

  _AirDrawingCanvasPainter({
    required this.points,
    required this.cursorPosition,
    required this.handDetected,
    required this.showCursor,
    required this.cursorColor,
    required this.cursorSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all connected points with smooth lines
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final paint = Paint()
        ..color = p1.color.withOpacity(0.9)
        ..strokeWidth = p1.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      final start = Offset(
        p1.point.dx * screenSize.width,
        p1.point.dy * screenSize.height,
      );
      final end = Offset(
        p2.point.dx * screenSize.width,
        p2.point.dy * screenSize.height,
      );

      canvas.drawLine(start, end, paint);

      // Add glow effect for better visibility
      if (p1.strokeWidth > 10) {
        final glowPaint = Paint()
          ..color = p1.color.withOpacity(0.3)
          ..strokeWidth = p1.strokeWidth * 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawLine(start, end, glowPaint);
      }
    }

    // Draw the live cursor
    if (handDetected && cursorPosition != null && showCursor) {
      final cursorScreenPos = Offset(
        cursorPosition!.dx * screenSize.width,
        cursorPosition!.dy * screenSize.height,
      );

      // Outer ring
      final outerPaint = Paint()
        ..color = cursorColor.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(cursorScreenPos, cursorSize + 3, outerPaint);

      // Inner circle
      final innerPaint = Paint()
        ..color = cursorColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(cursorScreenPos, cursorSize, innerPaint);

      // Crosshair for precision
      final crossPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(cursorScreenPos.dx - 10, cursorScreenPos.dy),
        Offset(cursorScreenPos.dx + 10, cursorScreenPos.dy),
        crossPaint,
      );
      canvas.drawLine(
        Offset(cursorScreenPos.dx, cursorScreenPos.dy - 10),
        Offset(cursorScreenPos.dx, cursorScreenPos.dy + 10),
        crossPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Enhanced Hand Skeleton Painter
class _HandSkeletonPainter extends CustomPainter {
  final List<Offset> landmarks;
  final Size screenSize;

  _HandSkeletonPainter({required this.landmarks, required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.length < 21) return;

    // Draw connections
    const connections = [
      [0, 1], [1, 2], [2, 3], [3, 4],
      [0, 5], [5, 6], [6, 7], [7, 8],
      [0, 9], [9, 10], [10, 11], [11, 12],
      [0, 13], [13, 14], [14, 15], [15, 16],
      [0, 17], [17, 18], [18, 19], [19, 20],
      [5, 9], [9, 13], [13, 17],
    ];

    // Draw connections with gradient
    for (final connection in connections) {
      if (connection[0] < landmarks.length && connection[1] < landmarks.length) {
        final start = landmarks[connection[0]];
        final end = landmarks[connection[1]];

        final paint = Paint()
          ..color = Colors.cyan.withOpacity(0.6)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(start.dx * screenSize.width, start.dy * screenSize.height),
          Offset(end.dx * screenSize.width, end.dy * screenSize.height),
          paint,
        );
      }
    }

    // Draw landmarks with different colors for finger types
    for (int i = 0; i < landmarks.length; i++) {
      Color color;
      double radius;

      if (i == 8) {
        color = Colors.yellow; // Index finger tip
        radius = 6;
      } else if ([4, 12, 16, 20].contains(i)) {
        color = Colors.green; // Finger tips
        radius = 5;
      } else if (i == 0) {
        color = Colors.red; // Wrist
        radius = 7;
      } else {
        color = Colors.blue; // Other landmarks
        radius = 4;
      }

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final position = Offset(
        landmarks[i].dx * screenSize.width,
        landmarks[i].dy * screenSize.height,
      );

      canvas.drawCircle(position, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Grid Painter for better drawing precision
class _GridPainter extends CustomPainter {
  final Size screenSize;

  _GridPainter({required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;

    // Draw vertical lines
    for (double x = 0; x < screenSize.width; x += 50) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, screenSize.height),
        gridPaint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y < screenSize.height; y += 50) {
      canvas.drawLine(
        Offset(0, y),
        Offset(screenSize.width, y),
        gridPaint,
      );
    }

    // Center crosshair
    final center = Offset(screenSize.width / 2, screenSize.height / 2);
    final centerPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(center.dx - 20, center.dy),
      Offset(center.dx + 20, center.dy),
      centerPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 20),
      Offset(center.dx, center.dy + 20),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}