import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import '../../providers/air_drawing_provider.dart';

class AirDrawingScreen extends StatefulWidget {
  const AirDrawingScreen({super.key});

  @override
  State<AirDrawingScreen> createState() => _AirDrawingScreenState();
}

class _AirDrawingScreenState extends State<AirDrawingScreen> {
  // Camera & MediaPipe Plugin
  late CameraController _cameraController;
  HandLandmarkerPlugin? _handPlugin;
  bool _isCameraReady = false;
  bool _isDetecting = false; // Guard to prevent overlapping frame processing

  @override
  void initState() {
    super.initState();
    _initializeCameraAndPlugin();
  }

  Future<void> _initializeCameraAndPlugin() async {
    try {
      // 1. Get cameras and select front-facing
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // 2. Initialize camera controller
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController.initialize();

      // 3. Initialize the MediaPipe Hand Landmarker plugin[citation:1]
      _handPlugin = HandLandmarkerPlugin.create(
        numHands: 1, // Detect one hand for drawing
        minHandDetectionConfidence: 0.7,
        delegate: HandLandmarkerDelegate.gpu, // Use GPU for best performance
      );

      // 4. Start receiving and processing camera frames
      await _cameraController.startImageStream(_processCameraFrame);

      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint('Initialization failed: $e');
    }
  }

  /// Processes each camera frame with the MediaPipe plugin.
  Future<void> _processCameraFrame(CameraImage image) async {
    if (!_isCameraReady || _isDetecting || _handPlugin == null) return;
    _isDetecting = true;

    try {
      // The `detect` method is synchronous and returns results directly[citation:5]
      final List<Hand> hands = _handPlugin!.detect(
        image,
        _cameraController.description.sensorOrientation,
      );

      if (mounted) {
        final provider = Provider.of<AirDrawingProvider>(context, listen: false);
        if (hands.isNotEmpty) {
          // Convert landmarks from the plugin to a list of Offsets.
          // The plugin returns 21 landmarks per hand[citation:1][citation:7].
          final landmarks = hands.first.landmarks
              .map((lm) => Offset(lm.x, lm.y)) // x, y are normalized (0.0 to 1.0)
              .toList();
          provider.updateHandData(landmarks);
        } else {
          // No hand detected
          provider.updateHandData([]);
        }
      }
    } catch (e) {
      debugPrint('Frame processing error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _cameraController.stopImageStream();
    _cameraController.dispose();
    _handPlugin?.dispose(); // Clean up native resources[citation:1]
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(title: const Text('Air Drawing - MediaPipe')),
      body: Consumer<AirDrawingProvider>(
        builder: (context, provider, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Camera Preview
              if (_isCameraReady)
                CameraPreview(_cameraController)
              else
                const Center(child: CircularProgressIndicator()),

              // 2. Transparent Canvas for Drawing
              Positioned.fill(
                child: CustomPaint(
                  painter: _AirDrawingCanvasPainter(
                    points: provider.points,
                    cursorPosition: provider.cursorPosition,
                    handDetected: provider.handDetected,
                    screenSize: screenSize,
                  ),
                ),
              ),

              // 3. Hand Landmark Skeleton (for visualization/debugging)
              if (provider.handDetected)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HandSkeletonPainter(
                      landmarks: provider.handLandmarks,
                      screenSize: screenSize,
                    ),
                  ),
                ),

              // 4. Control Overlays
              _buildStatusOverlay(provider),
              _buildControlPanel(context, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusOverlay(AirDrawingProvider provider) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Status Indicator
            Icon(
              Icons.circle,
              color: provider.handDetected ? Colors.green : Colors.red,
              size: 12,
            ),
            const SizedBox(width: 8),
            Text(
              provider.handDetected
                  ? 'Hand Ready ${provider.isDrawing ? '- Drawing' : ''}'
                  : 'Move hand into view',
              style: const TextStyle(color: Colors.white),
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
          color: Colors.grey[900]!.withOpacity(0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drawing Toggle Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.handDetected ? provider.toggleDrawing : null,
                icon: Icon(provider.isDrawing ? Icons.stop : Icons.play_arrow),
                label: Text(provider.isDrawing ? 'Stop Drawing' : 'Start Drawing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: provider.isDrawing ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Brush & Color Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Brush Size
                Column(
                  children: [
                    const Text('Brush', style: TextStyle(color: Colors.white)),
                    Slider(
                      value: provider.strokeWidth,
                      min: 3,
                      max: 25,
                      onChanged: provider.updateStrokeWidth,
                      activeColor: provider.selectedColor,
                    ),
                  ],
                ),
                // Color Selection
                ..._buildColorPalette(provider),
              ],
            ),
            const SizedBox(height: 8),
            // Clear Button
            TextButton.icon(
              onPressed: provider.clearDrawing,
              icon: const Icon(Icons.delete, color: Colors.white70),
              label: const Text('Clear Canvas', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildColorPalette(AirDrawingProvider provider) {
    final colors = [
      Colors.blueAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.yellowAccent,
      Colors.purpleAccent,
      Colors.white,
    ];
    return colors.map((color) {
      return GestureDetector(
        onTap: () => provider.updateColor(color),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: provider.selectedColor == color ? Colors.white : Colors.transparent,
              width: 3,
            ),
          ),
        ),
      );
    }).toList();
  }
}

/// Paints the user's drawing on the canvas.
class _AirDrawingCanvasPainter extends CustomPainter {
  final List<AirDrawingPoint> points;
  final Offset? cursorPosition;
  final bool handDetected;
  final Size screenSize;

  _AirDrawingCanvasPainter({
    required this.points,
    required this.cursorPosition,
    required this.handDetected,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all connected points
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final paint = Paint()
        ..color = p1.color
        ..strokeWidth = p1.strokeWidth
        ..strokeCap = StrokeCap.round;

      // Convert normalized points to screen coordinates
      final start = Offset(
        p1.point.dx * screenSize.width,
        p1.point.dy * screenSize.height,
      );
      final end = Offset(
        p2.point.dx * screenSize.width,
        p2.point.dy * screenSize.height,
      );

      canvas.drawLine(start, end, paint);
    }

    // Draw the live cursor (index finger tip)
    if (handDetected && cursorPosition != null) {
      final cursorPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.7)
        ..style = PaintingStyle.fill;

      final cursorScreenPos = Offset(
        cursorPosition!.dx * screenSize.width,
        cursorPosition!.dy * screenSize.height,
      );
      canvas.drawCircle(cursorScreenPos, 12, cursorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// (Optional) Paints the hand skeleton for visualization.
class _HandSkeletonPainter extends CustomPainter {
  final List<Offset> landmarks;
  final Size screenSize;
  _HandSkeletonPainter({required this.landmarks, required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.length < 21) return;

    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.6)
      ..strokeWidth = 2.0;

    // Define connections between landmarks (simplified hand skeleton)[citation:7]
    const connections = [
      [0, 1], [1, 2], [2, 3], [3, 4], // Thumb
      [0, 5], [5, 6], [6, 7], [7, 8], // Index finger
      [0, 9], [9, 10], [10, 11], [11, 12], // Middle finger
      [0, 13], [13, 14], [14, 15], [15, 16], // Ring finger
      [0, 17], [17, 18], [18, 19], [19, 20], // Pinky
      [5, 9], [9, 13], [13, 17], // Palm
    ];

    for (final connection in connections) {
      final start = landmarks[connection[0]];
      final end = landmarks[connection[1]];
      canvas.drawLine(
        Offset(start.dx * screenSize.width, start.dy * screenSize.height),
        Offset(end.dx * screenSize.width, end.dy * screenSize.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}