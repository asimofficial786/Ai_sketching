import 'package:flutter/material.dart';

class EnhancedModeSelectionScreen extends StatefulWidget {
  const EnhancedModeSelectionScreen({super.key});

  @override
  State<EnhancedModeSelectionScreen> createState() => _EnhancedModeSelectionScreenState();
}

class _EnhancedModeSelectionScreenState extends State<EnhancedModeSelectionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _aiButtonController;
  late Animation<double> _aiButtonAnimation;
  bool _isAiButtonVisible = true;

  @override
  void initState() {
    super.initState();
    _aiButtonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _aiButtonAnimation = CurvedAnimation(
      parent: _aiButtonController,
      curve: Curves.elasticOut,
    );
    _aiButtonController.forward();
  }

  @override
  void dispose() {
    _aiButtonController.dispose();
    super.dispose();
  }

  void _toggleAiButton() {
    setState(() {
      _isAiButtonVisible = !_isAiButtonVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Attractive AI Assistant Floating Action Button
      floatingActionButton: ScaleTransition(
        scale: _aiButtonAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 80),
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(context, '/ai-assistant');
            },
            backgroundColor: Colors.amber,
            foregroundColor: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: const BorderSide(color: Colors.amberAccent, width: 2),
            ),
            icon: const Icon(Icons.auto_awesome, size: 24),
            label: const Text(
              'AI Assistant',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            tooltip: 'Get AI help with drawing',
          ),
        ),
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E21),
              Color(0xFF1A1F38),
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar with Help and AI Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Help Button
                        IconButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/guide');
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: const Icon(
                              Icons.help_outline,
                              color: Colors.white70,
                              size: 22,
                            ),
                          ),
                          tooltip: 'View Tutorial',
                        ),

                        // AI Assistant Hint
                        GestureDetector(
                          onTap: _toggleAiButton,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'AI Assistant Available',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // Title
                    const Text(
                      'Choose Your\nDrawing Mode',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Select how you want to bring your ideas to life',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Mode Selection Cards (Only 2 now)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Canvas Drawing Card
                      _ModeSelectionCard(
                        title: 'Canvas Drawing',
                        subtitle: 'Traditional Touch Drawing',
                        description: 'Draw directly on screen with precision tools, brushes, and colors.',
                        icon: Icons.brush,
                        iconBackground: const Color(0xFF4ECDC4),
                        features: const [
                          'Touch & Stylus Support',
                          'Multiple Brushes & Colors',
                          'Layer Management',
                          'Undo/Redo History',
                        ],
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/home');
                        },
                        isRecommended: true,
                      ),

                      const SizedBox(height: 25),

                      // Air Drawing Card
                      _ModeSelectionCard(
                        title: 'Air Drawing',
                        subtitle: 'Gesture-Based Drawing',
                        description: 'Draw in air using camera hand tracking. No touch required!',
                        icon: Icons.camera_alt,
                        iconBackground: const Color(0xFFFF6B6B),
                        features: const [
                          'Camera Hand Tracking',
                          'Real-time AI Processing',
                          'Gesture Controls',
                          'Contactless Drawing',
                        ],
                        onTap: () {
                          _showAirDrawingModal(context);
                        },
                        isBeta: true,
                      ),

                      const SizedBox(height: 100), // Space for FAB
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Quick Start Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/home');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Quick Start - Canvas Mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Settings Link
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/ai-settings');
                      },
                      child: Text(
                        'AI Settings & Preferences',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAirDrawingModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AirDrawingModal(),
    );
  }
}

// ==================== COPY THESE HELPER CLASSES FROM YOUR ORIGINAL CODE ====================

class _ModeSelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color iconBackground;
  final List<String> features;
  final VoidCallback onTap;
  final bool isBeta;
  final bool isRecommended;

  const _ModeSelectionCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.iconBackground,
    required this.features,
    required this.onTap,
    this.isBeta = false,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Pattern
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(
                  painter: _CardPatternPainter(color: iconBackground),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Icon
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon Container
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: iconBackground.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: iconBackground.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: iconBackground,
                          size: 36,
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Title & Badges
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (isBeta) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      'BETA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.orange,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                                if (isRecommended) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      'RECOMMENDED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.green,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Description
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Features
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: features.map((feature) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: iconBackground,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              feature,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Action Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: iconBackground.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: iconBackground.withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        color: iconBackground,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AirDrawingModal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F38),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: 15, bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF6B6B).withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFFFF6B6B),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Air Drawing Mode',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Gesture-based drawing experience',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.4),
                      ),
                    ),
                    child: const Text(
                      'BETA',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Requirements
                  _RequirementItem(
                    icon: Icons.camera_enhance,
                    text: 'Camera permission required',
                    isImportant: true,
                  ),
                  _RequirementItem(
                    icon: Icons.lightbulb,
                    text: 'Good lighting conditions',
                  ),
                  _RequirementItem(
                    icon: Icons.accessibility_new,
                    text: 'Steady hand movement',
                  ),
                  _RequirementItem(
                    icon: Icons.warning,
                    text: 'Beta - May have tracking issues',
                    isWarning: true,
                  ),

                  const SizedBox(height: 30),

                  // How to use
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to Use:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 15),
                        Text(
                          '1. Point your index finger at the camera\n'
                              '2. Move your finger slowly to draw\n'
                              '3. Keep hand steady for better tracking\n'
                              '4. Use gestures for additional controls',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white70,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.8),
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Maybe Later'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/air-drawing');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Try Air Drawing',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isImportant;
  final bool isWarning;

  const _RequirementItem({
    required this.icon,
    required this.text,
    this.isImportant = false,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(
            icon,
            color: isWarning
                ? Colors.orange
                : (isImportant ? const Color(0xFFFF6B6B) : Colors.white70),
            size: 22,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isWarning
                    ? Colors.orange
                    : (isImportant ? Colors.white : Colors.white70),
                fontWeight: isImportant ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPatternPainter extends CustomPainter {
  final Color color;

  _CardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.03)
      ..strokeWidth = 0.5;

    // Draw diagonal pattern
    for (double i = -size.height; i < size.width; i += 20) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}