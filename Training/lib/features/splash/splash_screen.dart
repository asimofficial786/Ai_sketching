// lib/features/splash/splash_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _waveAnimation;
  late Animation<Color?> _colorAnimation;

  final List<Color> _paintColors = [
    const Color(0xFFFF6B6B), // Red
    const Color(0xFF4ECDC4), // Teal
    const Color(0xFF45B7D1), // Blue
    const Color(0xFF96CEB4), // Green
    const Color(0xFFFFEAA7), // Yellow
    const Color(0xFFDDA0DD), // Purple
  ];

  List<Particle> _particles = [];
  double _waveOffset = 0.0;
  bool _showContent = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _colorAnimation = ColorTween(
      begin: const Color(0xFF1A1F38),
      end: const Color(0xFF0A0E21),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();

    // Initialize particles
    _initParticles();

    // Show content after slight delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showContent = true;
        });
      }
    });

    // Animate wave
    Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (mounted) {
        setState(() {
          _waveOffset += 0.06;
        });
      }
    });

    // Navigate after 4.5 seconds
    Timer(const Duration(milliseconds: 8000), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/guide');
      }
    });
  }

  void _initParticles() {
    final random = Random();
    _particles = List.generate(40, (index) {
      return Particle(
        offset: Offset(
          random.nextDouble() * 500 - 250,
          random.nextDouble() * 500 - 250,
        ),
        size: random.nextDouble() * 6 + 2,
        color: _paintColors[random.nextInt(_paintColors.length)],
        speed: random.nextDouble() * 0.8 + 0.3,
        angle: random.nextDouble() * 2 * pi,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
          // Animated gradient background with wave effect
          Container(
          decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.8,
            colors: [
              _colorAnimation.value ?? const Color(0xFF1A1F38),
              const Color(0xFF0A0E21),
            ],
            stops: const [0.0, 0.7],
          ),
          ),
          ),

          // Wave effect overlay
          CustomPaint(
          painter: WavePainter(
          waveOffset: _waveOffset,
          progress: _controller.value,
          ),
          ),

          // Animated particles
          ..._buildParticles(),

          // Content
          if (_showContent)
          Opacity(
          opacity: _fadeAnimation.value,
          child: Center(
          child: SingleChildScrollView(
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          // Main logo with Lottie animation
          Stack(
          alignment: Alignment.center,
          children: [
          // Outer glow rings
          ..._buildGlowRings(),

          // Lottie animation container
          Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
          Color(0xFF6C63FF),
          Color(0xFF4ECDC4),
          ],
          ),
          boxShadow: [
          BoxShadow(
          color: const Color(0xFF6C63FF)
              .withOpacity(0.6),
          blurRadius: 40,
          spreadRadius: 8,
          ),
          BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 30,
          spreadRadius: 5,
          offset: const Offset(0, 15),
          ),
          ],
          ),
          child: ClipOval(
          child: Lottie.asset(
          'assets/animations/paint_brush.json',
          width: 180,
          height: 180,
          fit: BoxFit.contain,
          animate: true,
          repeat: true,
          frameRate: FrameRate.max,
          errorBuilder: (context, error, stackTrace) {
          return const Center(
          child: Icon(
          Icons.brush,
          size: 80,
          color: Colors.white,
          ),
          );
          },
          ),
          ),
          ),

          // Floating animated dots
          ..._buildFloatingDots(),
          ],
          ),

          const SizedBox(height: 40),

          // App title with gradient and shine effect
          ShaderMask(
          shaderCallback: (bounds) {
          return const LinearGradient(
          colors: [
          Color(0xFF4ECDC4),
          Color(0xFF6C63FF),
          Color(0xFFFF6B6B),
          ],
          stops: [0.0, 0.5, 1.0],
          ).createShader(bounds);
          },
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
          border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
          colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
          ],
          ),
          ),
          child: const Text(
          'AI SKETCH ASSISTANT',
          style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.5,
          ),
          ),
          ),
          ),

          const SizedBox(height: 12),

          // Tagline
          Text(
          'Intelligent Drawing & Auto-Correction',
          style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w300,
          color: Colors.white.withOpacity(0.9),
          letterSpacing: 1.0,
          fontStyle: FontStyle.italic,
          ),
          ),

          const SizedBox(height: 40),

          // AI Loading indicator
          Column(
          children: [
          Stack(
          alignment: Alignment.center,
          children: [
          // Outer ring
          SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
          value: _controller.value,
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(
          const Color(0xFF6C63FF).withOpacity(0.4),
          ),
          ),
          ),
          // Middle ring
          SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
          value: _controller.value,
          strokeWidth: 4,
          valueColor: AlwaysStoppedAnimation<Color>(
          const Color(0xFF4ECDC4).withOpacity(0.6),
          ),
          ),
          ),
          // Inner AI icon
          Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
          colors: [
          Color(0xFF6C63FF),
          Color(0xFF4ECDC4),
          ],
          ),
          boxShadow: [
          BoxShadow(
          color: const Color(0xFF6C63FF)
              .withOpacity(0.6),
          blurRadius: 15,
          spreadRadius: 3,
          ),
          ],
          ),
          child: const Icon(
          Icons.auto_awesome,
          color: Colors.white,
          size: 20,
          ),
          ),
          ],
          ),
          const SizedBox(height: 15),
          // Loading text
          SizedBox(
          width: 280,
          child: Column(
          children: [
          Text(
          _getLoadingText(_controller.value),
          style: TextStyle(
          fontSize: 13,
          color: Colors.white.withOpacity(0.8),
          letterSpacing: 0.8,
          ),
          textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
          value: _controller.value,
          backgroundColor: Colors.white.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation<Color>(
          const Color(0xFF4ECDC4),
          ),
          borderRadius: BorderRadius.circular(8),
          minHeight: 5,
          ),
          ],
          ),
          ),
          ],
          ),

          const SizedBox(height: 80), // Space for bottom team info
          ],
          ),
          ),
          ),
          ),


          // Team info at bottom - FIXED VERSION
          Positioned(
          bottom: 15,
          left: 0,
          right: 0,
          child: AnimatedSlide(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          offset: _controller.value > 0.6 ? Offset.zero : const Offset(0, 1),
          child: Opacity(
          opacity: _controller.value > 0.6 ? 1.0 : 0.0,
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
          children: [
          // Team members - VERY COMPACT
          Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [


          _buildTeamMemberChip('Sehar Shahid , Neha Saleem, Aleena kamran', 1),

          ],
          ),

          const SizedBox(height: 12),

          // Supervisor info - COMPACT
          Container(
          padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
          ),
          decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
          ),
          ),
          child: Column(
          children: [
          Text(
          'Supervised by',
          style: TextStyle(
          fontSize: 10,
          color: Colors.white.withOpacity(0.5),
          fontStyle: FontStyle.italic,
          ),
          ),
          const SizedBox(height: 2),
          Text(
          'Miss Anila Majeed',
          style: TextStyle(
          fontSize: 13,
          color: const Color(0xFF4ECDC4),
          fontWeight: FontWeight.w600,
          ),
          ),
          ],
          ),
          ),

          const SizedBox(height: 10),

          // University - COMPACT
          Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
          children: [
          Container(
          height: 1,
          width: 100,
          decoration: BoxDecoration(
          gradient: LinearGradient(
          colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.2),
          Colors.transparent,
          ],
          ),
          ),
          ),
          const SizedBox(height: 6),
          const Text(
          'LCWU • Computer Science',
          style: TextStyle(
          fontSize: 9,
          color: Colors.white54,
          letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
          ),
          ],
          ),
          ),
          ],
          ),
          ),
          ),
          ),
          ),
          ],
          );
        },
      ),
    );
  }

  List<Widget> _buildGlowRings() {
    return List.generate(3, (index) {
      final size = 220 + (index * 40);
      final opacity = 0.15 - (index * 0.05);

      return AnimatedBuilder(
        animation: _rotationAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value * (index.isOdd ? 1 : -1),
            child: Container(
              width: size.toDouble(),
              height: size.toDouble(),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF4ECDC4).withOpacity(opacity),
                  width: 1.5,
                ),
              ),
            ),
          );
        },
      );
    });
  }

  List<Widget> _buildParticles() {
    return _particles.map((particle) {
      final offsetX = particle.offset.dx +
          sin(_waveOffset + particle.angle) * particle.speed * 50;
      final offsetY = particle.offset.dy +
          cos(_waveOffset + particle.angle) * particle.speed * 50;

      return Positioned(
        left: offsetX + MediaQuery.of(context).size.width / 2,
        top: offsetY + MediaQuery.of(context).size.height / 2,
        child: Container(
          width: particle.size,
          height: particle.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: particle.color.withOpacity(0.5),
            boxShadow: [
              BoxShadow(
                color: particle.color.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildFloatingDots() {
    return List.generate(12, (index) {
      final angle = (index / 12) * 2 * pi;
      final radius = 140.0;
      final x = radius * cos(angle + _waveOffset * 2);
      final y = radius * sin(angle + _waveOffset * 2);
      final color = _paintColors[index % _paintColors.length];
      final size = 6 + sin(_waveOffset * 3 + index) * 2;

      return Positioned(
        left: 100 + x,
        top: 100 + y,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.7),
                blurRadius: 12,
                spreadRadius: 3,
              ),
            ],
          ),
        ),
      );
    });
  }

  // ULTRA COMPACT team member chip
  Widget _buildTeamMemberChip(String name, int index) {
    final color = _paintColors[index % _paintColors.length];
    final show = _controller.value > (0.6 + (index * 0.2));

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: show ? 1.0 : 0.0,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ),
    );
  }

  String _getLoadingText(double progress) {
    if (progress < 0.25) return 'Loading AI Models...';
    if (progress < 0.5) return 'Initializing Drawing Engine...';
    if (progress < 0.75) return 'Setting up Auto-Correction...';
    return 'Ready to Create Magic!';
  }
}

// Helper classes
class Particle {
  final Offset offset;
  final double size;
  final Color color;
  final double speed;
  final double angle;

  Particle({
    required this.offset,
    required this.size,
    required this.color,
    required this.speed,
    required this.angle,
  });
}

class WavePainter extends CustomPainter {
  final double waveOffset;
  final double progress;

  WavePainter({required this.waveOffset, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF6C63FF).withOpacity(0.05),
          const Color(0xFF4ECDC4).withOpacity(0.03),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);

    for (double x = 0; x < size.width; x += 10) {
      final y = size.height * 0.7 +
          sin(x * 0.01 + waveOffset) * 30 * progress +
          cos(x * 0.005 + waveOffset * 0.5) * 20 * progress;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return waveOffset != oldDelegate.waveOffset ||
        progress != oldDelegate.progress;
  }
}