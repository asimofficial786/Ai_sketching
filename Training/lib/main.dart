import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:training/features/ai_assistant/ai_assistant.dart';

import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/guide/guide_screen.dart'; // ADD THIS IMPORT
import 'features/mode_selection/mode_selection.dart';
import 'features/air_drawing/air_drawing.dart';
import 'features/canvas/screens/home_screen.dart';

import 'providers/ai_provider.dart';
import 'providers/drawing_provider.dart';
import 'providers/air_drawing_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DrawingProvider()),
        ChangeNotifierProvider(create: (_) => AIProvider()),
        ChangeNotifierProvider(create: (_) => AirDrawingProvider())
      ],
      child: MaterialApp(
        title: 'AI Sketch Assistant',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,

        // Initial route - starts with splash
        initialRoute: '/splash',

        // Routes configuration with Guide Screen
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/guide': (context) => const GuideScreen(),      // NEW GUIDE SCREEN
          '/mode-selection': (context) => const EnhancedModeSelectionScreen(), // Updated
          '/air-drawing': (context) => const AirDrawingScreen(),
          '/home': (context) => const CompleteCanvasScreen(),

          '/ai-assistant': (context) => const AIAssistantScreen(),
        },

        // Fallback for unknown routes
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Page Not Found')),
              body: const Center(child: Text('404 - Page not found')),
            ),
          );
        },
      ),
    );
  }
}