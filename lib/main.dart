import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Greetings App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const GreetingPage(),
    );
  }
}

class _Star {
  const _Star({
    required this.left,
    required this.top,
    required this.size,
    required this.color,
    required this.phase,
    required this.speed,
  });

  final double left;
  final double top;
  final double size;
  final Color color;
  final double phase;
  final double speed;

  double brightnessAt(double t) {
    // Oscillates between 0.2 and 1.0, each star with its own phase/speed
    // so the twinkling isn't synchronized across the sky.
    return 0.6 + 0.4 * sin(2 * pi * (t * speed) + phase);
  }
}

class GreetingPage extends StatefulWidget {
  const GreetingPage({super.key});

  @override
  State<GreetingPage> createState() => _GreetingPageState();
}

class _GreetingPageState extends State<GreetingPage>
    with SingleTickerProviderStateMixin {
  static const int editCount = 7;

  late final AnimationController _controller;
  static final List<_Star> _stars = List.generate(175, (_) {
    final random = Random();
    return _Star(
      left: random.nextDouble(),
      top: random.nextDouble(),
      size: 1.5 + random.nextDouble() * 2.5,
      color: random.nextBool() ? Colors.yellow : Colors.white,
      phase: random.nextDouble() * 2 * pi,
      speed: 0.15 + random.nextDouble() * 0.35,
    );
  });

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 11, 29, 1),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
              return Stack(
                children: [
                  for (final star in _stars)
                    Positioned(
                      left: star.left * constraints.maxWidth,
                      top: star.top * constraints.maxHeight,
                      child: Container(
                        width: star.size,
                        height: star.size,
                        decoration: BoxDecoration(
                          color: star.color.withValues(
                            alpha: star.brightnessAt(t),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Center(
                    child: Text(
                      'Hello there!',
                      style: GoogleFonts.comicNeue(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 12,
                    child: Text(
                      'Test-v$editCount',
                      style: GoogleFonts.comicNeue(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
