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
    required this.seed,
    required this.size,
    required this.color,
    required this.phase,
    required this.speed,
  });

  final int seed;
  final double size;
  final Color color;
  final double phase;
  final double speed;

  double _cycleProgress(double t) {
    final raw = t * speed + phase / (2 * pi);
    return raw - raw.floorToDouble();
  }

  // Fades fully in and out (0 -> 1 -> 0) once per cycle.
  double brightnessAt(double t) {
    final frac = _cycleProgress(t);
    return 1 - (2 * frac - 1).abs();
  }

  // A new random position each cycle, picked the instant the star is
  // fully faded out so the "jump" itself is invisible.
  Offset positionAt(double t) {
    final raw = t * speed + phase / (2 * pi);
    final cycle = raw.floor();
    final random = Random(seed * 97 + cycle * 131071);
    return Offset(random.nextDouble(), random.nextDouble());
  }
}

class GreetingPage extends StatefulWidget {
  const GreetingPage({super.key});

  @override
  State<GreetingPage> createState() => _GreetingPageState();
}

class _GreetingPageState extends State<GreetingPage>
    with SingleTickerProviderStateMixin {
  static const int editCount = 9;

  late final AnimationController _controller;
  static final List<_Star> _stars = List.generate(175, (index) {
    final random = Random();
    return _Star(
      seed: index,
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
                  for (final star in _stars) _buildStar(star, t, constraints),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFF7F5CFF),
                              Color(0xFFD86FFF),
                              Color(0xFF5CE1FF),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'Hello there!',
                            style: GoogleFonts.orbitron(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                              shadows: const [
                                Shadow(
                                  color: Color(0xFFB388FF),
                                  blurRadius: 30,
                                ),
                                Shadow(
                                  color: Color(0xFF5CE1FF),
                                  blurRadius: 60,
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildStar(_Star star, double t, BoxConstraints constraints) {
    final pos = star.positionAt(t);
    return Positioned(
      left: pos.dx * constraints.maxWidth,
      top: pos.dy * constraints.maxHeight,
      child: Container(
        width: star.size,
        height: star.size,
        decoration: BoxDecoration(
          color: star.color.withValues(alpha: star.brightnessAt(t)),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
