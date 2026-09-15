import 'dart:math';
import 'dart:ui' as ui;

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

class _CometFrame {
  const _CometFrame({
    required this.head,
    required this.angle,
    required this.opacity,
    required this.trail,
  });

  final Offset head; // normalized 0..1 position of the bright head
  final double angle; // travel direction, radians
  final double opacity;
  final double trail; // trail length, normalized to screen diagonal
}

class _Comet {
  const _Comet({
    required this.seed,
    required this.phase,
    required this.period,
  });

  final int seed;
  final double phase;
  final double period; // seconds per cycle; comet only flies briefly within it

  static const double _flightFraction = 0.025;

  // Mostly dormant; returns null except during its brief flight window.
  _CometFrame? frameAt(double t) {
    final raw = (t + phase) / period;
    final cycle = raw.floor();
    final progress = raw - cycle;
    if (progress > _flightFraction) return null;

    final flightT = progress / _flightFraction;
    final random = Random(seed * 7919 + cycle * 104729);
    // Mostly horizontal, randomly left-to-right or right-to-left each
    // flight, always dipping downward at a random 15-40 degree tilt.
    final goingRight = random.nextBool();
    final startY = 0.1 + random.nextDouble() * 0.55;
    final length = 0.35 + random.nextDouble() * 0.3;
    final tilt = (15 + random.nextDouble() * 25) * pi / 180;
    final angle = goingRight ? tilt : pi - tilt;
    final startX = goingRight
        ? random.nextDouble() * 0.25
        : 1.0 - random.nextDouble() * 0.25;
    final head = Offset(
      startX + cos(angle) * length * flightT,
      startY + sin(angle) * length * flightT,
    );
    final fadeIn = (flightT / 0.2).clamp(0.0, 1.0);
    final fadeOut = (1 - (flightT - 0.6) / 0.4).clamp(0.0, 1.0);
    return _CometFrame(
      head: head,
      angle: angle,
      opacity: min(fadeIn, fadeOut),
      trail: length * 0.4,
    );
  }
}

class _CometsPainter extends CustomPainter {
  _CometsPainter(this.comets, this.t);

  final List<_Comet> comets;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final comet in comets) {
      final frame = comet.frameAt(t);
      if (frame == null || frame.opacity <= 0) continue;

      final head = Offset(
        frame.head.dx * size.width,
        frame.head.dy * size.height,
      );
      final tail = Offset(
        head.dx - cos(frame.angle) * frame.trail * size.width,
        head.dy - sin(frame.angle) * frame.trail * size.height,
      );

      final linePaint = Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(tail, head, [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: frame.opacity),
        ]);
      canvas.drawLine(tail, head, linePaint);
      canvas.drawCircle(
        head,
        2,
        Paint()..color = Colors.white.withValues(alpha: frame.opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CometsPainter oldDelegate) => true;
}

class GreetingPage extends StatefulWidget {
  const GreetingPage({super.key});

  @override
  State<GreetingPage> createState() => _GreetingPageState();
}

class _GreetingPageState extends State<GreetingPage>
    with SingleTickerProviderStateMixin {
  static const int editCount = 14;

  late final AnimationController _controller;
  Offset _parallax = Offset.zero;

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

  static final List<_Comet> _comets = List.generate(3, (index) {
    final random = Random();
    return _Comet(
      seed: index + 1000,
      phase: random.nextDouble() * 30,
      period: 14 + random.nextDouble() * 12,
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

  // Pointer position on desktop (mouse) or a finger drag on touch devices
  // both drive a subtle parallax shift of the starfield.
  void _updateParallax(Offset localPosition, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final dx = ((localPosition.dx / size.width - 0.5) * 2).clamp(-1.0, 1.0);
    final dy = ((localPosition.dy / size.height - 0.5) * 2).clamp(-1.0, 1.0);
    setState(() => _parallax = Offset(dx, dy));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 11, 29, 1),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Listener(
            onPointerHover: (e) => _updateParallax(e.localPosition, size),
            onPointerMove: (e) => _updateParallax(e.localPosition, size),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
                return Stack(
                  children: [
                    for (final star in _stars)
                      _buildStar(star, t, constraints),
                    Positioned.fill(
                      child: CustomPaint(painter: _CometsPainter(_comets, t)),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Transform.translate(
                          offset: Offset(_parallax.dx * -4, _parallax.dy * -4),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
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
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFFB388FF)
                                          .withValues(alpha: 0.75),
                                      blurRadius: 6,
                                    ),
                                    Shadow(
                                      color: const Color(0xFF5CE1FF)
                                          .withValues(alpha: 0.45),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
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
            ),
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
