import 'package:flutter/material.dart';
import'dart:math';
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<GuidePage> _pages = [
    GuidePage(
      title: 'Welcome to AI Sketch Assistant',
      description: 'An intelligent drawing app that helps you create perfect sketches with AI assistance.',
      icon: Icons.auto_awesome,
      color: const Color(0xFF6C63FF),
      image: Icons.draw,
    ),
    GuidePage(
      title: 'Canvas Drawing',
      description: 'Draw directly on screen with touch. Use various brushes, colors, and tools to create your masterpiece.',
      icon: Icons.touch_app,
      color: const Color(0xFF4ECDC4),
      image: Icons.format_paint,
    ),
    GuidePage(
      title: 'Air Drawing',
      description: 'Draw in air using your phone\'s camera! Move your finger to draw without touching the screen.',
      icon: Icons.camera_alt,
      color: const Color(0xFFFF6B6B),
      image: Icons.air,
    ),
    GuidePage(
      title: 'AI Auto-Correction',
      description: 'Our AI analyzes your sketches and automatically corrects shapes, making your drawings perfect.',
      icon: Icons.auto_fix_high,
      color: const Color(0xFF45B7D1),
      image: Icons.assistant_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 2.0,
                  colors: [
                    const Color(0xFF1A1F38).withOpacity(0.8),
                    const Color(0xFF0A0E21),
                  ],
                ),
              ),
            ),

            // Skip Button
            Positioned(
              top: 20,
              right: 20,
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/mode-selection');
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.7),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Main Content
            Column(
              children: [
                // Progress Indicator
                Padding(
                  padding: const EdgeInsets.only(top: 60, bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                          (index) => Container(
                        width: _currentPage == index ? 30 : 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? _pages[index].color
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),

                // Page View
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return _GuidePageContent(page: page);
                    },
                  ),
                ),

                // Navigation Buttons
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      if (_currentPage > 0)
                        TextButton.icon(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.7),
                          ),
                        )
                      else
                        const SizedBox(width: 100),

                      // Next/Get Started Button
                      ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _pages.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            Navigator.pushReplacementNamed(context, '/mode-selection');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pages[_currentPage].color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 5,
                          shadowColor: _pages[_currentPage].color.withOpacity(0.5),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _currentPage < _pages.length - 1
                                  ? 'Next'
                                  : 'Get Started',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage < _pages.length - 1
                                  ? Icons.arrow_forward
                                  : Icons.rocket_launch,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GuidePage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final IconData image;

  GuidePage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.image,
  });
}

class _GuidePageContent extends StatelessWidget {
  final GuidePage page;

  const _GuidePageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Icon Container
          Container(
            width: 180,
            height: 180,
            margin: const EdgeInsets.only(bottom: 40),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  page.color,
                  page.color.withOpacity(0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: page.color.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background pattern
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GuidePatternPainter(color: page.color),
                  ),
                ),

                // Icon
                Icon(
                  page.image,
                  size: 80,
                  color: Colors.white,
                ),

                // Animated orbiting dots
                ...List.generate(3, (index) {
                  return Positioned(
                    left: 30 + 40 * cos(DateTime.now().millisecondsSinceEpoch * 0.001 + index * 1.2),
                    top: 30 + 40 * sin(DateTime.now().millisecondsSinceEpoch * 0.001 + index * 0.8),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.8),
                        boxShadow: [
                          BoxShadow(
                            color: page.color.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Title
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Description
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),

          // Feature Highlights
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _FeatureHighlight(
                  icon: Icons.brush,
                  label: 'Smart Tools',
                  color: page.color,
                ),
                _FeatureHighlight(
                  icon: Icons.visibility,
                  label: 'AI Vision',
                  color: page.color,
                ),
                _FeatureHighlight(
                  icon: Icons.auto_awesome,
                  label: 'Auto-Correct',
                  color: page.color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureHighlight extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureHighlight({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GuidePatternPainter extends CustomPainter {
  final Color color;

  _GuidePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    // Draw grid pattern
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}