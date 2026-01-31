import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Timer _drawingSimulationTimer;
  final List<PaintPoint> _paintPoints = [];
  final List<Color> _paintColors = [
    const Color(0xFFFF6B6B), // Red
    const Color(0xFF4ECDC4), // Teal
    const Color(0xFF45B7D1), // Blue
    const Color(0xFF96CEB4), // Green
    const Color(0xFFFFEAA7), // Yellow
    const Color(0xFFDDA0DD), // Purple
  ];

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Setup animations
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    // Start animations
    _controller.forward();

    // Start drawing simulation
    _startDrawingSimulation();

    // Navigate after 4 seconds
    Timer(const Duration(seconds: 8), () {
      Navigator.pushReplacementNamed(context, '/guide');
    });
  }

  void _startDrawingSimulation() {
    const simulationDuration = Duration(milliseconds: 3000);
    const updateInterval = Duration(milliseconds: 30);
    final totalUpdates = simulationDuration.inMilliseconds ~/ updateInterval.inMilliseconds;

    int updateCount = 0;

    _drawingSimulationTimer = Timer.periodic(updateInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (updateCount >= totalUpdates) {
        timer.cancel();
        return;
      }

      setState(() {
        // Add new paint points in a circular/spiral pattern
        final progress = updateCount / totalUpdates;
        final angle = 2 * pi * progress * 4; // 4 full rotations
        final radius = 80.0 + 30.0 * sin(progress * pi * 2);

        final x = 150.0 + radius * cos(angle);
        final y = 150.0 + radius * sin(angle);

        _paintPoints.add(PaintPoint(
          offset: Offset(x, y),
          color: _paintColors[updateCount % _paintColors.length],
          size: 8.0 + 12.0 * sin(progress * pi),
          timestamp: DateTime.now(),
        ));

        // Keep only recent points for performance
        if (_paintPoints.length > 100) {
          _paintPoints.removeAt(0);
        }
      });

      updateCount++;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _drawingSimulationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21), // Dark background for contrast
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated background canvas texture
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [
                  const Color(0xFF1A1F38).withOpacity(0.8),
                  const Color(0xFF0A0E21),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),

          // Simulated paint strokes in background
          CustomPaint(
            painter: _CanvasTexturePainter(points: _paintPoints),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated logo container with paint theme
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Lottie animation (paint brush or hand drawing)
                        Lottie.asset(
                          'assets/animations/paint_brush.json', // You'll need to add this file
                          width: 140,
                          height: 140,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback icon if Lottie file doesn't exist
                            return const Icon(
                              Icons.brush,
                              size: 80,
                              color: Colors.white,
                            );
                          },
                        ),

                        // Canvas texture overlay
                        Positioned.fill(
                          child: ClipOval(
                            child: Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage(
                                    'images/canvas_texture.png',
                                  ),
                                  fit: BoxFit.cover,
                                  opacity: 0.2,
                                  colorFilter: ColorFilter.mode(
                                    Colors.white.withOpacity(0.1),
                                    BlendMode.overlay,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // App name with slide and fade animation
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'AI',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF4ECDC4),
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10,
                                      color: const Color(0xFF4ECDC4).withOpacity(0.5),
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                              ),
                              TextSpan(
                                text: ' SKETCH',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: [
                                    const Shadow(
                                      blurRadius: 10,
                                      color: Colors.black,
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Assistant',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 3,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Tagline with typing animation effect
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: const Color(0xFFFF6B6B),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Draw Smart • Create Perfect',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.8),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Loading indicator with paint theme
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF6C63FF).withOpacity(0.3),
                              ),
                              strokeWidth: 2,
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF6C63FF),
                                  const Color(0xFF4ECDC4),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(
                              Icons.brush,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Initializing AI Drawing Engine...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // Team info (positioned with animation)
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildTeamMember('NEHA SALEEM'),
                            Text('•', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                            _buildTeamMember('SEHAR SHAHID'),
                            Text('•', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                            _buildTeamMember('ALEENA KAMRAN'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Supervisor: Miss Anila Majeed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'LAHORE COLLEGE FOR WOMEN UNIVERSITY',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.4),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMember(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withOpacity(0.7),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// Helper class for paint points
class PaintPoint {
  final Offset offset;
  final Color color;
  final double size;
  final DateTime timestamp;

  PaintPoint({
    required this.offset,
    required this.color,
    required this.size,
    required this.timestamp,
  });
}

// Custom painter for canvas texture and paint strokes
class _CanvasTexturePainter extends CustomPainter {
  final List<PaintPoint> points;

  _CanvasTexturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw subtle canvas grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.5;

    const gridSize = 40.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw animated paint strokes
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final age = DateTime.now().difference(point.timestamp).inMilliseconds / 1000.0;
      final opacity = 1.0 - (age / 3.0).clamp(0.0, 1.0);

      if (opacity > 0) {
        final paint = Paint()
          ..color = point.color.withOpacity(opacity * 0.3)
          ..strokeWidth = point.size
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

        // Draw the point
        canvas.drawCircle(point.offset, point.size / 2, paint);

        // Draw connecting line to next point
        if (i < points.length - 1) {
          final nextPoint = points[i + 1];
          final nextOpacity = 1.0 -
              (DateTime.now().difference(nextPoint.timestamp).inMilliseconds / 1000.0).clamp(0.0, 1.0);

          if (nextOpacity > 0) {
            final linePaint = Paint()
              ..color = point.color.withOpacity((opacity + nextOpacity) * 0.15)
              ..strokeWidth = point.size * 0.7
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

            canvas.drawLine(point.offset, nextPoint.offset, linePaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Fallback version without Lottie (if you don't have the animation file)
class SimpleSplashScreen extends StatelessWidget {
  const SimpleSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple animated container without Lottie
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 70,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'AI SKETCH ASSISTANT',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Draw Smart • Create Perfect',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 50),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF6C63FF).withOpacity(0.8),
              ),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}