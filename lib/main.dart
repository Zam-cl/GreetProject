import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;

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
  const _Comet({required this.seed, required this.phase, required this.period});

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

class _FireworkParticle {
  const _FireworkParticle({
    required this.startOffset,
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
  });

  // Starting point relative to the firework's center, on the ring that
  // traces around the title text — this is what makes the burst appear to
  // surround the text instead of exploding from a single point.
  final Offset startOffset;
  final double angle; // outward travel direction, radians
  final double speed; // pixels per second
  final Color color;
  final double size;
}

class _Firework {
  _Firework({
    required this.center,
    required this.startTime,
    required Size textSize,
  }) : ringHalfWidth = textSize.width / 2 + 18,
       ringHalfHeight = textSize.height / 2 + 18,
       particles = _buildParticles(
         textSize.width / 2 + 18,
         textSize.height / 2 + 18,
       );

  final Offset center;
  final double startTime;
  final double ringHalfWidth;
  final double ringHalfHeight;
  final List<_FireworkParticle> particles;

  static const double lifespan = 1.1;
  static const double _gravity = 220; // px/s^2, pulls the sparks down

  static const List<Color> _palette = [
    Color(0xFFFFD700), // gold
    Color(0xFFFFC400), // amber
    Color(0xFFFFEA00), // vivid yellow
    Color(0xFFFFF59D), // pale yellow
    Color(0xFFFFB300), // deep amber
  ];

  static List<_FireworkParticle> _buildParticles(double halfW, double halfH) {
    final random = Random();
    return List.generate(160, (i) {
      final angle = random.nextDouble() * 2 * pi;
      return _FireworkParticle(
        startOffset: Offset(cos(angle) * halfW, sin(angle) * halfH),
        angle: angle,
        speed: 50 + random.nextDouble() * 150,
        color: _palette[random.nextInt(_palette.length)],
        size: 1.8 + random.nextDouble() * 2.0,
      );
    });
  }

  bool isDoneAt(double t) => t - startTime > lifespan;
}

class _FireworksPainter extends CustomPainter {
  _FireworksPainter(this.fireworks, this.t);

  final List<_Firework> fireworks;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final fw in fireworks) {
      final elapsed = t - fw.startTime;
      if (elapsed < 0 || elapsed > _Firework.lifespan) continue;

      // A quick bright pop framing the text at the moment of the burst.
      if (elapsed < 0.12) {
        final flashT = elapsed / 0.12;
        canvas.drawOval(
          Rect.fromCenter(
            center: fw.center,
            width: fw.ringHalfWidth * 2.2,
            height: fw.ringHalfHeight * 2.2,
          ),
          Paint()
            ..color = const Color(0xFFFFF59D)
                .withValues(alpha: (1 - flashT) * 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
        );
      }

      final progress = (elapsed / _Firework.lifespan).clamp(0.0, 1.0);
      final fade = (1 - progress) * (1 - progress);
      for (final p in fw.particles) {
        final radial = p.speed * elapsed;
        final dx = cos(p.angle) * radial;
        final dy =
            sin(p.angle) * radial +
            0.5 * _Firework._gravity * elapsed * elapsed;
        final pos = fw.center + p.startOffset + Offset(dx, dy);
        final currentSize = (p.size * (1 - progress * 0.5)).clamp(
          0.3,
          double.infinity,
        );
        canvas.drawCircle(
          pos,
          currentSize,
          Paint()..color = p.color.withValues(alpha: fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) => true;
}

class _GalaxyParticle {
  const _GalaxyParticle({
    required this.radius,
    required this.angle,
    required this.size,
    required this.color,
  });

  final double radius; // normalized 0..1 from the galaxy's center
  final double angle; // radians, position along its spiral arm
  final double size;
  final Color color;
}

List<_GalaxyParticle> _buildGalaxyParticles() {
  final particles = <_GalaxyParticle>[];
  const armCount = 3;
  const perArm = 300;
  final random = Random(42);
  for (var arm = 0; arm < armCount; arm++) {
    final armOffset = arm * (2 * pi / armCount);
    for (var i = 0; i < perArm; i++) {
      final tNorm = i / perArm;
      final baseRadius = 0.1 + tNorm * 0.9;
      final winding = tNorm * 2.7 * 2 * pi;
      final jitterAngle = (random.nextDouble() - 0.5) * 0.3 * (1 - tNorm * 0.4);
      final jitterRadius = (random.nextDouble() - 0.5) * 0.05;
      final r = (baseRadius + jitterRadius).clamp(0.05, 1.0);
      final angle = armOffset + winding + jitterAngle;
      final roll = random.nextDouble();
      final Color color;
      if (r < 0.22) {
        color = const Color(0xFFFFF6D8); // warm glow near the core
      } else if (roll < 0.12) {
        color = const Color(0xFFFF8FD0); // pink nebula knot
      } else if (roll < 0.22) {
        color = const Color(0xFFB388FF); // purple haze
      } else {
        color = const Color(0xFFBEE3FF); // blue-white young stars
      }
      final size = roll < 0.12
          ? 2.6 + random.nextDouble() * 1.6
          : 1.0 + random.nextDouble() * 1.8;
      particles.add(
        _GalaxyParticle(radius: r, angle: angle, size: size, color: color),
      );
    }
  }
  return particles;
}

class _GalaxyPainter extends CustomPainter {
  _GalaxyPainter({
    required this.particles,
    required this.particleCenters,
    required this.rotation,
    required this.maxR,
    required this.blackHoleCenter,
    required this.haloOpacity,
    this.formation = 1.0,
    this.wormholePull,
    this.wormholeCaptured,
  });

  final List<_GalaxyParticle> particles;
  // Each particle's current on-screen center — normally all equal to
  // blackHoleCenter, but they lag independently while the galaxy is being
  // dragged, which is what produces the stretchy trailing swarm look.
  final List<Offset> particleCenters;
  final double rotation;
  final double maxR;
  final Offset blackHoleCenter;
  // Fades out while dragging so the ambient glow doesn't look like it's
  // stuck to the cursor; eases back in once the galaxy is at rest.
  final double haloOpacity;
  // 0..1 growth toward `maxR` right after the galaxy reappears from an
  // explosion, so it visibly condenses back into being instead of just
  // popping into view at full size; 1.0 the rest of the time.
  final double formation;
  // Per-particle additive offset from a nearby wormhole pulling it in, and
  // the set of particle indices already fully swallowed (skipped entirely)
  // — see `_GreetingPageState._computeGalaxyWormholePull`. Null when no
  // wormhole is currently close enough to affect any particle.
  final List<Offset>? wormholePull;
  final Set<int>? wormholeCaptured;

  // Squash the disc vertically so it reads as a tilted spiral, like a real
  // galaxy seen at an angle rather than flat-on.
  static const double _tilt = 0.42;

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveR = maxR * formation;
    final starAlpha = 0.85 * formation;

    canvas.save();
    canvas.translate(blackHoleCenter.dx, blackHoleCenter.dy);
    canvas.drawCircle(
      Offset.zero,
      effectiveR * 1.05,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, effectiveR * 1.05, [
          const Color(0xFF7F5CFF).withValues(alpha: 0.18 * haloOpacity),
          const Color(0xFF7F5CFF).withValues(alpha: 0.0),
        ])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.restore();

    // Spin the stars within the disc plane first, then squash the whole
    // field vertically — keeps a fixed viewing tilt instead of the disc
    // itself tumbling as it rotates. Each star orbits around its own
    // (possibly lagging) center rather than a single shared point.
    for (var i = 0; i < particles.length; i++) {
      if (wormholeCaptured != null && wormholeCaptured!.contains(i)) continue;
      final p = particles[i];
      final angle = p.angle + rotation;
      final x = cos(angle) * p.radius * effectiveR;
      final y = sin(angle) * p.radius * effectiveR * _tilt;
      final center = particleCenters[i];
      var pos = Offset(center.dx + x, center.dy + y);
      if (wormholePull != null) pos += wormholePull![i];
      canvas.drawCircle(
        pos,
        p.size,
        Paint()..color = p.color.withValues(alpha: starAlpha),
      );
    }

    canvas.save();
    canvas.translate(blackHoleCenter.dx, blackHoleCenter.dy);

    canvas.drawCircle(
      Offset.zero,
      effectiveR * 0.16,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, effectiveR * 0.16, [
          Colors.white.withValues(alpha: 0.95),
          const Color(0xFFFFE9B3).withValues(alpha: 0.5),
          const Color(0xFFFFE9B3).withValues(alpha: 0.0),
        ])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // A black hole at the very center: a glowing accretion ring, a thin
    // bright photon ring hugging the shadow's edge, then the black shadow
    // itself on top. The ring is squashed the same as the disc so it reads
    // as viewed at the same tilt.
    final ringOuter = effectiveR * 0.17;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: ringOuter * 2,
        height: ringOuter * 2 * _tilt,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveR * 0.05
        ..shader = ui.Gradient.radial(
          Offset.zero,
          ringOuter * 1.2,
          [const Color(0xFFFFE9B3), Colors.white, const Color(0xFFFF9D5C)],
          const [0.0, 0.75, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    final holeR = effectiveR * 0.075;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: holeR * 2.3,
        height: holeR * 2.3 * _tilt,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, effectiveR * 0.01)
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: holeR * 2,
        height: holeR * 2 * _tilt,
      ),
      Paint()..color = const Color(0xFF05010A),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter oldDelegate) => true;
}

class _SupernovaSpark {
  const _SupernovaSpark({
    required this.startOffset,
    required this.velocity,
    required this.color,
    required this.size,
    required this.delay,
  });

  // Borrowed from one of the galaxy stars' own start offsets so the sparks
  // ignite scattered across the same pre-explosion shape as the stars,
  // instead of all bursting from the black hole's single point — which
  // otherwise reads as two separate explosions layered on top of each other.
  final Offset startOffset;
  final Offset velocity; // px/s
  final Color color;
  final double size;
  // A little ignition delay so the debris cloud doesn't all launch in one
  // perfectly uniform pulse.
  final double delay;
}

// Drawn instead of `_GalaxyPainter` while the galaxy is mid-supernova. Each
// star keeps flying outward from wherever it actually was on screen the
// instant the blast went off (`startOffsets`, its last drag-lag position
// relative to the black hole) — not from a single point — so the burst picks
// up exactly where the dragged galaxy left off instead of visibly collapsing
// to a dot first. An extra layer of bright, fast `sparks` plus a full-screen
// flash and an expanding shockwave ring sell the scale of the blast.
class _GalaxyExplosionPainter extends CustomPainter {
  _GalaxyExplosionPainter({
    required this.particles,
    required this.startOffsets,
    required this.velocities,
    required this.sparks,
    required this.center,
    required this.startTime,
    required this.t,
    required this.maxR,
  });

  final List<_GalaxyParticle> particles;
  final List<Offset> startOffsets; // each particle's offset from center at t0
  final List<Offset> velocities; // px/s outward velocity per particle
  final List<_SupernovaSpark> sparks;
  final Offset center;
  final double startTime;
  final double t;
  final double maxR;

  static const double duration = 2.0;
  static const double _flashDuration = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = (t - startTime).clamp(0.0, duration);
    final progress = elapsed / duration;

    // A camera-flash white-out across the whole screen plus a bright core
    // flash, right at the moment of detonation.
    final flashT = (elapsed / _flashDuration).clamp(0.0, 1.0);
    if (flashT < 1) {
      final screenFade = (1 - flashT) * (1 - flashT);
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: screenFade * 0.55),
      );
      final flashR = maxR * (0.4 + 2.4 * flashT);
      canvas.drawCircle(
        center,
        flashR,
        Paint()
          ..shader = ui.Gradient.radial(center, flashR, [
            Colors.white.withValues(alpha: (1 - flashT) * 0.95),
            const Color(0xFFFFD9A0).withValues(alpha: (1 - flashT) * 0.5),
            const Color(0xFFFFD9A0).withValues(alpha: 0.0),
          ])
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
    }

    // A shockwave ring that keeps rolling outward for the whole blast.
    final ringRadius = maxR * (0.5 + 3.6 * progress);
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, maxR * 0.06 * (1 - progress))
        ..color = const Color(0xFFFFD9A0)
            .withValues(alpha: (1 - progress) * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final fade = (1 - progress) * (1 - progress);
    for (var i = 0; i < particles.length; i++) {
      final pos = center + startOffsets[i] + velocities[i] * elapsed;
      final currentSize = (particles[i].size * (1.6 - progress)).clamp(
        0.3,
        double.infinity,
      );
      canvas.drawCircle(
        pos,
        currentSize,
        Paint()..color = particles[i].color.withValues(alpha: fade),
      );
    }

    for (final spark in sparks) {
      final local = elapsed - spark.delay;
      if (local <= 0) continue;
      final sparkProgress = (local / (duration - spark.delay)).clamp(0.0, 1.0);
      final sparkFade = (1 - sparkProgress) * (1 - sparkProgress);
      final pos = center + spark.startOffset + spark.velocity * local;
      final currentSize = (spark.size * (1.4 - sparkProgress)).clamp(
        0.2,
        double.infinity,
      );
      canvas.drawCircle(
        pos,
        currentSize,
        Paint()..color = spark.color.withValues(alpha: sparkFade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GalaxyExplosionPainter oldDelegate) => true;
}

class _WormholeMote {
  const _WormholeMote({
    required this.startAngle,
    required this.startRadius,
    required this.spinRate,
    required this.burstAngle,
    required this.burstSpeed,
    required this.color,
    required this.size,
  });

  final double startAngle; // radians, where it drifts in from
  final double startRadius; // px from center, where it starts
  final double spinRate; // extra spiral spin while falling in
  final double
  burstAngle; // radians, independent direction it flies once it bursts back out
  final double burstSpeed; // px/s
  final Color color;
  final double size;
}

// A secret one-shot easter egg: hold a finger/click on empty sky (away from
// the galaxy and the title) for a moment and a wormhole opens — a small
// accretion vortex spirals nearby light in toward the press point, then
// blinks and flings it all back out as a burst of shooting stars.
class _Wormhole {
  _Wormhole({required this.center, required this.startTime})
    : motes = _buildMotes();

  final Offset center;
  final double startTime;
  final List<_WormholeMote> motes;

  static const double suckDuration = 3.0;
  static const double flashDuration = 0.25;
  static const double burstDuration = 1.3;
  // Everything gets pulled all the way in by this fraction of `suckDuration`
  // — well before the phase actually ends — so the pull itself reads as
  // fast, with the vortex just lingering, already full, until it detonates.
  static const double captureFraction = 0.45;
  static const double totalDuration =
      suckDuration + flashDuration + burstDuration;

  // Matches the actual starfield's own colors (see `_stars` below) so the
  // motes read as real stars being pulled in, not a differently-colored
  // effect layered on top.
  static const List<Color> _palette = [
    Colors.white,
    Colors.yellow,
    Color(0xFFFFF3C4),
    Color(0xFFE8F4FF),
  ];

  static List<_WormholeMote> _buildMotes() {
    final random = Random();
    return List.generate(140, (i) {
      return _WormholeMote(
        startAngle: random.nextDouble() * 2 * pi,
        startRadius: 60 + random.nextDouble() * 220,
        spinRate: 6 + random.nextDouble() * 10,
        burstAngle: random.nextDouble() * 2 * pi,
        burstSpeed: 220 + random.nextDouble() * 380,
        color: _palette[random.nextInt(_palette.length)],
        size: 1.4 + random.nextDouble() * 2.2,
      );
    });
  }

  bool isDoneAt(double t) => t - startTime > totalDuration;
}

class _WormholePainter extends CustomPainter {
  _WormholePainter(this.wormholes, this.t);

  final List<_Wormhole> wormholes;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final w in wormholes) {
      final elapsed = t - w.startTime;
      if (elapsed < 0 || elapsed > _Wormhole.totalDuration) continue;

      if (elapsed < _Wormhole.suckDuration) {
        _paintSuckIn(canvas, w, elapsed);
      } else if (elapsed < _Wormhole.suckDuration + _Wormhole.flashDuration) {
        _paintFlash(canvas, w, elapsed - _Wormhole.suckDuration);
      } else {
        _paintBurst(
          canvas,
          w,
          elapsed - _Wormhole.suckDuration - _Wormhole.flashDuration,
        );
      }
    }
  }

  void _paintSuckIn(Canvas canvas, _Wormhole w, double elapsed) {
    final progress = (elapsed / _Wormhole.suckDuration).clamp(0.0, 1.0);

    // A small dark accretion disc grows at the center as it swallows
    // everything spiraling into it.
    final discR = 6 + 40 * progress;
    canvas.drawCircle(
      w.center,
      discR,
      Paint()
        ..shader = ui.Gradient.radial(w.center, discR, [
          const Color(0xFF05010A),
          const Color(0xFF1B0A2E).withValues(alpha: 0.6),
          const Color(0xFF1B0A2E).withValues(alpha: 0.0),
        ])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final captureT = (progress / _Wormhole.captureFraction).clamp(0.0, 1.0);
    final easeIn = Curves.easeOutCubic.transform(captureT);
    for (final m in w.motes) {
      final radius = m.startRadius * (1 - easeIn);
      // Spins faster the closer it gets to the center, like real infalling
      // matter speeding up toward the event horizon.
      final angle = m.startAngle + m.spinRate * easeIn;
      final pos =
          w.center + Offset(cos(angle) * radius, sin(angle) * radius * 0.6);
      final fade = (1 - progress * 0.3).clamp(0.0, 1.0);
      final currentSize = max(0.3, m.size * (1.1 - progress * 0.5));
      canvas.drawCircle(
        pos,
        currentSize,
        Paint()..color = m.color.withValues(alpha: fade),
      );
    }
  }

  void _paintFlash(Canvas canvas, _Wormhole w, double elapsed) {
    final flashT = (elapsed / _Wormhole.flashDuration).clamp(0.0, 1.0);
    final r = 10 + 90 * flashT;
    canvas.drawCircle(
      w.center,
      r,
      Paint()
        ..shader = ui.Gradient.radial(w.center, r, [
          Colors.white.withValues(alpha: (1 - flashT) * 0.95),
          const Color(0xFFB388FF).withValues(alpha: (1 - flashT) * 0.5),
          const Color(0xFFB388FF).withValues(alpha: 0.0),
        ])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  void _paintBurst(Canvas canvas, _Wormhole w, double elapsed) {
    final progress = (elapsed / _Wormhole.burstDuration).clamp(0.0, 1.0);
    final fade = (1 - progress) * (1 - progress);
    for (final m in w.motes) {
      final dist = m.burstSpeed * elapsed;
      final dir = Offset(cos(m.burstAngle), sin(m.burstAngle));
      final head = w.center + dir * dist;
      final tail = head - dir * (18 + 40 * progress);
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(tail, head, [
            m.color.withValues(alpha: 0),
            m.color.withValues(alpha: fade),
          ]),
      );
      canvas.drawCircle(
        head,
        m.size * 0.8,
        Paint()..color = m.color.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WormholePainter oldDelegate) => true;
}

// Render-time result of `_GreetingPageState._updateTitleWormhole`: where (in
// the title's own local coordinates) a wormhole is biting into it, and how
// big that bite currently is. `center == null` means no bite at all.
class _TitleHole {
  const _TitleHole(this.center, this.radius);
  final Offset? center;
  final double radius;
}

// Clips a growing (or shrinking) circular hole out of the title, centered
// wherever a wormhole is relative to it — this is what makes the title look
// like it's being eaten into from the wormhole's direction, in parts,
// rather than fading away as a whole.
class _EatenTextClipper extends CustomClipper<Path> {
  const _EatenTextClipper({required this.holeCenter, required this.holeRadius});

  final Offset holeCenter;
  final double holeRadius;

  @override
  Path getClip(Size size) {
    final full = Path()..addRect(Offset.zero & size);
    if (holeRadius <= 0) return full;
    final hole = Path()
      ..addOval(Rect.fromCircle(center: holeCenter, radius: holeRadius));
    return Path.combine(PathOperation.difference, full, hole);
  }

  @override
  bool shouldReclip(covariant _EatenTextClipper oldClipper) =>
      oldClipper.holeCenter != holeCenter ||
      oldClipper.holeRadius != holeRadius;
}

class GreetingPage extends StatefulWidget {
  const GreetingPage({super.key});

  @override
  State<GreetingPage> createState() => _GreetingPageState();
}

class _GreetingPageState extends State<GreetingPage>
    with SingleTickerProviderStateMixin {
  static const int editCount = 40;

  late final AnimationController _controller;
  Offset _parallax = Offset.zero;

  // Fireworks set off by tapping the title. `_stageKey` marks the Stack
  // whose coordinate space the burst (and the painter's canvas) share;
  // `_titleKey` marks the title text itself, so the burst can be sized and
  // centered around it regardless of where exactly it was tapped.
  final GlobalKey _stageKey = GlobalKey();
  final GlobalKey _titleKey = GlobalKey();
  final List<_Firework> _fireworks = [];

  // The title's current on-screen bounds, in the Stack's own coordinate
  // space — used both to center firework bursts on it and to keep the
  // galaxy from being placed on top of it.
  Rect? _currentTitleRect() {
    final stageBox = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    final titleBox = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (stageBox == null || titleBox == null) return null;
    final topLeft = stageBox.globalToLocal(titleBox.localToGlobal(Offset.zero));
    final bottomRight = stageBox.globalToLocal(
      titleBox.localToGlobal(titleBox.size.bottomRight(Offset.zero)),
    );
    return Rect.fromPoints(topLeft, bottomRight);
  }

  void _spawnFirework() {
    final rect = _currentTitleRect();
    if (rect == null) return;
    setState(
      () => _fireworks.add(
        _Firework(
          center: rect.center,
          startTime: DateTime.now().millisecondsSinceEpoch / 1000.0,
          textSize: rect.size,
        ),
      ),
    );
  }

  // Converts a point in the Stack's coordinate space into the title's own
  // local coordinates — used to place the wormhole's eaten-hole clip
  // exactly where the wormhole actually is relative to the text, through
  // whatever transforms (parallax, FittedBox scaling) sit in between.
  Offset? _stageToTitleLocal(Offset stagePos) {
    final stageBox = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    final titleBox = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (stageBox == null || titleBox == null) return null;
    return titleBox.globalToLocal(stageBox.localToGlobal(stagePos));
  }

  // If a wormhole opens close enough to the title, it eats a growing
  // circular hole into it centered wherever the wormhole actually is
  // relative to the text (see `_EatenTextClipper`) — rather than the whole
  // title fading as one piece — then the hole shrinks back down once the
  // wormhole is fully done, revealing the text again.
  _Wormhole? _titleEatenBy;
  Offset? _titleHoleStageCenter;
  double _titleHoleMaxRadius = 0;
  double? _titleReformStart;
  static const double _titleReformDuration = 1.0;

  _TitleHole _updateTitleWormhole(double t) {
    if (_titleEatenBy == null && _titleReformStart == null) {
      final rect = _currentTitleRect();
      if (rect != null) {
        for (final w in _wormholes) {
          final elapsed = t - w.startTime;
          if (elapsed < 0 || elapsed > _Wormhole.suckDuration) continue;
          final pullRadius = max(rect.width, rect.height) / 2 + 220;
          if ((w.center - rect.center).distance <= pullRadius) {
            _titleEatenBy = w;
            _titleHoleStageCenter = w.center;
            // The diagonal guarantees the hole can fully cover the text no
            // matter where within (or near) it the wormhole is centered.
            _titleHoleMaxRadius = Offset(rect.width, rect.height).distance;
            break;
          }
        }
      }
    }

    final capturedBy = _titleEatenBy;
    if (capturedBy != null) {
      if (capturedBy.isDoneAt(t)) {
        _titleEatenBy = null;
        _titleReformStart = t;
      } else {
        final stageCenter = _titleHoleStageCenter;
        final local = stageCenter == null
            ? null
            : _stageToTitleLocal(stageCenter);
        if (local == null) return const _TitleHole(null, 0);
        final elapsed = t - capturedBy.startTime;
        final rawProgress =
            (elapsed / (_Wormhole.suckDuration * _Wormhole.captureFraction))
                .clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(rawProgress);
        return _TitleHole(local, eased * _titleHoleMaxRadius);
      }
    }

    final reformStart = _titleReformStart;
    if (reformStart != null) {
      final stageCenter = _titleHoleStageCenter;
      final local = stageCenter == null
          ? null
          : _stageToTitleLocal(stageCenter);
      final since = t - reformStart;
      if (local == null || since >= _titleReformDuration) {
        _titleReformStart = null;
        _titleHoleStageCenter = null;
        return const _TitleHole(null, 0);
      }
      final progress = (since / _titleReformDuration).clamp(0.0, 1.0);
      final eased = 1 - Curves.easeIn.transform(progress);
      return _TitleHole(local, eased * _titleHoleMaxRadius);
    }

    return const _TitleHole(null, 0);
  }

  // Picks a random spot for the galaxy sized off the screen (not a quarter
  // of it, so it stays big on narrow phones too), avoiding `avoidRect`
  // (the title's bounds) when one is given. Used both for the very first
  // placement and every time the galaxy reappears after exploding.
  Rect _pickGalaxyRect(Size screenSize, {Rect? avoidRect}) {
    const edgeMargin = 12.0;
    const desiredSize = 660.0;
    final galaxySize = min(
      desiredSize,
      max(160.0, min(screenSize.width, screenSize.height) * 0.85),
    );
    final halfSize = galaxySize / 2;
    final rangeX = max(0.0, screenSize.width - galaxySize - edgeMargin * 2);
    final rangeY = max(0.0, screenSize.height - galaxySize - edgeMargin * 2);

    final random = Random();
    const avoidBuffer = 24.0;
    var tries = 0;
    Rect candidate;
    do {
      final cx = edgeMargin + halfSize + random.nextDouble() * rangeX;
      final cy = edgeMargin + halfSize + random.nextDouble() * rangeY;
      candidate = Rect.fromCenter(
        center: Offset(cx, cy),
        width: galaxySize,
        height: galaxySize,
      );
      tries++;
    } while (avoidRect != null &&
        candidate.inflate(avoidBuffer).overlaps(avoidRect) &&
        tries < 40);
    return candidate;
  }

  // Draggable galaxy: `_galaxyTarget` is the point every star eases toward
  // — the pointer while dragging, or wherever you last let go. Stars near
  // the core catch up almost instantly; outer arm stars lag behind, which
  // is what gives a drag its stretchy, swarm-follow feel and makes the
  // galaxy visibly re-gather once you stop moving it.
  Offset? _galaxyTarget;
  double? _galaxyMaxR;
  List<Offset>? _particleLag;
  bool _draggingGalaxy = false;
  double _lastGalaxyT = 0;
  double? _dragStartTime;
  bool _galaxyPlacementScheduled = false;

  // The ambient halo fades out while dragging (so it doesn't look like the
  // cursor itself is glowing) and eases back in once you let go.
  double _haloOpacity = 1.0;
  double? _dragReleasedAt;

  // Holding the drag too long makes the galaxy blow apart instead of just
  // following the pointer; it stays gone for a beat, then reappears
  // somewhere new.
  static const double _dragExplodeThreshold = 2.2;
  static const double _reappearDelay = 1.4;
  bool _exploding = false;
  double? _explodeStartTime;
  Offset? _explodeCenter;
  List<Offset>? _explodeStartOffsets;
  List<Offset>? _explodeVelocities;
  List<_SupernovaSpark>? _explodeSparks;
  bool _hidden = false;
  double? _hiddenSince;

  // If a wormhole opens close enough to part of the galaxy, only the
  // particles actually within its radius get pulled in and swallowed —
  // see `_computeGalaxyWormholePull` — rather than dragging the whole
  // galaxy in as one rigid piece. With 900 particles, a captured handful
  // vanishing (or popping back once released) is unnoticeable, so unlike
  // the whole-galaxy explosion this needs no separate reform animation.
  final Map<int, _Wormhole> _galaxyParticlesCaptured = {};

  List<Offset> _computeGalaxyWormholePull(double t) {
    final lag = _particleLag;
    final maxR = _galaxyMaxR;
    if (lag == null ||
        maxR == null ||
        _wormholes.isEmpty ||
        _hidden ||
        _exploding) {
      return const [];
    }
    final effectiveR = maxR * _galaxyFormationProgress(t);
    final rotation = t * 2 * pi / 45;
    const influenceRadius = 220.0;
    final pulls = List<Offset>.filled(_galaxyParticles.length, Offset.zero);
    for (var i = 0; i < _galaxyParticles.length; i++) {
      if (_galaxyParticlesCaptured.containsKey(i)) continue;
      final p = _galaxyParticles[i];
      final angle = p.angle + rotation;
      final natural =
          lag[i] +
          Offset(
            cos(angle) * p.radius * effectiveR,
            sin(angle) * p.radius * effectiveR * _GalaxyPainter._tilt,
          );
      for (final w in _wormholes) {
        final elapsed = t - w.startTime;
        if (elapsed < 0 || elapsed > _Wormhole.suckDuration) continue;
        final dist = (w.center - natural).distance;
        if (dist > influenceRadius) continue;
        final delay = (dist / influenceRadius) * 0.35;
        final rawProgress =
            (elapsed / (_Wormhole.suckDuration * _Wormhole.captureFraction))
                .clamp(0.0, 1.0);
        final adjusted = ((rawProgress - delay) / (1 - delay)).clamp(0.0, 1.0);
        final pull = Curves.easeOutCubic.transform(adjusted);
        pulls[i] = (w.center - natural) * pull;
        if (pull > 0.95) {
          _galaxyParticlesCaptured[i] = w;
        }
        break;
      }
    }
    return pulls;
  }

  // How long the galaxy takes to grow from nothing back to full size after
  // reappearing from an explosion; null once it's fully formed (or before
  // it's ever exploded).
  static const double _formationDuration = 2.6;
  double? _formingSince;

  // A short, sharply decaying screen-shake right as the galaxy detonates.
  // Deterministic (driven by elapsed time, not fresh randomness each frame)
  // so it reads as one smooth judder instead of flickering noise.
  static const double _shakeWindow = 0.5;
  Offset _explosionShakeOffset(double t) {
    if (!_exploding) return Offset.zero;
    final start = _explodeStartTime;
    if (start == null) return Offset.zero;
    final elapsed = t - start;
    if (elapsed > _shakeWindow) return Offset.zero;
    final decay = 1 - elapsed / _shakeWindow;
    final amplitude = 16 * decay * decay;
    return Offset(sin(elapsed * 47) * amplitude, cos(elapsed * 61) * amplitude);
  }

  void _ensureGalaxyPhysics(Size screenSize) {
    if (_galaxyTarget != null) return;
    // Provisional placement so the painters have non-null values on the
    // very first frame, before the title's real on-screen bounds are known.
    final rect = _pickGalaxyRect(screenSize);
    _galaxyTarget = rect.center;
    _galaxyMaxR = rect.width / 2;
    _particleLag = List<Offset>.filled(
      _galaxyParticles.length,
      rect.center,
      growable: false,
    );

    if (_galaxyPlacementScheduled) return;
    _galaxyPlacementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final titleRect = _currentTitleRect();
      if (titleRect == null) return;
      final refined = _pickGalaxyRect(screenSize, avoidRect: titleRect);
      setState(() {
        _galaxyTarget = refined.center;
        _galaxyMaxR = refined.width / 2;
        _particleLag = List<Offset>.filled(
          _galaxyParticles.length,
          refined.center,
          growable: false,
        );
      });
    });
  }

  void _triggerGalaxyExplosion(double t) {
    final center = _galaxyTarget;
    final lag = _particleLag;
    final maxR = _galaxyMaxR;
    if (center == null || lag == null || maxR == null) return;
    final random = Random();
    final effectiveR = maxR * _galaxyFormationProgress(t);
    final rotation = t * 2 * pi / 45;

    // Each star keeps exploding outward from wherever it actually was on
    // screen the instant the blast went off — its spiral position around
    // the (possibly drag-lagged) black hole, i.e. exactly what `_GalaxyPainter`
    // was drawing the frame before — not just the black hole's own location.
    // Using only the lag offset here (dropping the orbital spread) used to
    // make the shockwave/flash (anchored on the black hole) and the stars
    // burst from visibly different spots.
    _explodeStartOffsets = List<Offset>.generate(lag.length, (i) {
      final p = _galaxyParticles[i];
      final angle = p.angle + rotation;
      final orbitOffset = Offset(
        cos(angle) * p.radius * effectiveR,
        sin(angle) * p.radius * effectiveR * _GalaxyPainter._tilt,
      );
      return (lag[i] + orbitOffset) - center;
    });
    // The travel direction itself is always fully random and independent of
    // that starting offset: while being dragged around for the 2+ seconds
    // it takes to trigger this, the whole swarm trails behind the pointer
    // like a comet tail, so nearly every particle's offset-from-center ends
    // up pointing the same way — using that as the blast direction made the
    // "explosion" fly out in only one direction instead of everywhere.
    _explodeVelocities = List<Offset>.generate(lag.length, (i) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 260 + random.nextDouble() * 520;
      return Offset(cos(angle), sin(angle)) * speed;
    });

    const sparkPalette = [
      Colors.white,
      Color(0xFFFFE9B3),
      Color(0xFFFFB347),
      Color(0xFFFF6B4A),
    ];
    final startOffsets = _explodeStartOffsets!;
    _explodeSparks = List<_SupernovaSpark>.generate(240, (i) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 320 + random.nextDouble() * 680;
      return _SupernovaSpark(
        startOffset: startOffsets[random.nextInt(startOffsets.length)],
        velocity: Offset(cos(angle), sin(angle)) * speed,
        color: sparkPalette[random.nextInt(sparkPalette.length)],
        size: 1.2 + random.nextDouble() * 2.6,
        delay: random.nextDouble() * 0.15,
      );
    });

    _explodeCenter = center;
    _explodeStartTime = t;
    _exploding = true;
    _draggingGalaxy = false;
    _dragStartTime = null;
  }

  void _reappearGalaxy(Size screenSize, double t) {
    final rect = _pickGalaxyRect(screenSize, avoidRect: _currentTitleRect());
    _hidden = false;
    _hiddenSince = null;
    _galaxyTarget = rect.center;
    _galaxyMaxR = rect.width / 2;
    _particleLag = List<Offset>.filled(
      _galaxyParticles.length,
      rect.center,
      growable: false,
    );
    // Reuse the drag-release halo fade-in so it eases back in gently
    // instead of just popping into view at full brightness.
    _haloOpacity = 0.0;
    _dragReleasedAt = t;
    // Grow from nothing up to full size over `_formationDuration` instead
    // of appearing at full size immediately.
    _formingSince = t;
  }

  // 0..1 growth toward full size right after reappearing; 1.0 the rest of
  // the time (including on the very first, non-exploded appearance).
  double _galaxyFormationProgress(double t) {
    final since = _formingSince;
    if (since == null) return 1.0;
    final raw = ((t - since) / _formationDuration).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(raw);
  }

  void _updateGalaxyPhysics(double t, Size screenSize) {
    if (_hidden) {
      _lastGalaxyT = t;
      final since = _hiddenSince;
      if (since != null && t - since >= _reappearDelay) {
        _reappearGalaxy(screenSize, t);
      }
      return;
    }

    if (_exploding) {
      _lastGalaxyT = t;
      final start = _explodeStartTime;
      if (start != null && t - start >= _GalaxyExplosionPainter.duration) {
        _exploding = false;
        _hidden = true;
        _hiddenSince = t;
      }
      return;
    }

    final since = _formingSince;
    if (since != null && t - since >= _formationDuration) {
      _formingSince = null;
    }

    final lag = _particleLag;
    final target = _galaxyTarget;
    if (lag == null || target == null) return;
    final dt = _lastGalaxyT == 0 ? 0.0 : (t - _lastGalaxyT).clamp(0.0, 0.1);
    _lastGalaxyT = t;
    if (dt <= 0) return;
    for (var i = 0; i < lag.length; i++) {
      // Particles further out on the spiral (bigger `radius`) take longer
      // to catch up, stretching the shape while the target keeps moving.
      final tau = 0.12 + _galaxyParticles[i].radius * 0.9;
      final factor = 1 - exp(-dt / tau);
      lag[i] = Offset.lerp(lag[i], target, factor)!;
    }

    if (_draggingGalaxy) {
      final haloFactor = 1 - exp(-dt / 0.35);
      _haloOpacity += (0.0 - _haloOpacity) * haloFactor;

      final dragStart = _dragStartTime;
      if (dragStart != null && t - dragStart >= _dragExplodeThreshold) {
        _triggerGalaxyExplosion(t);
      }
    } else {
      // Wait a beat after letting go before the glow starts creeping back,
      // then bring it up slowly rather than snapping straight to full.
      const fadeInDelay = 0.7;
      final releasedAt = _dragReleasedAt;
      final sinceRelease = releasedAt == null
          ? double.infinity
          : t - releasedAt;
      if (sinceRelease >= fadeInDelay) {
        final haloFactor = 1 - exp(-dt / 1.4);
        _haloOpacity += (1.0 - _haloOpacity) * haloFactor;
      }
    }
  }

  void _onGalaxyPointerDown(PointerDownEvent event) {
    if (_hidden || _exploding) return;
    final target = _galaxyTarget;
    final maxR = _galaxyMaxR;
    if (target == null || maxR == null) return;
    if ((event.localPosition - target).distance <= maxR * 1.3) {
      _draggingGalaxy = true;
      _galaxyTarget = event.localPosition;
      _dragStartTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
    }
  }

  void _onGalaxyPointerMove(PointerEvent event) {
    if (_draggingGalaxy) {
      _galaxyTarget = event.localPosition;
    }
  }

  void _onGalaxyPointerUp(PointerEvent event) {
    if (_draggingGalaxy) {
      _dragReleasedAt = _lastGalaxyT;
    }
    _draggingGalaxy = false;
    _dragStartTime = null;
  }

  // Secret wormhole easter egg: hold still on empty sky (not on the galaxy
  // or the title) for `_wormholeHoldThreshold` seconds to open one.
  final List<_Wormhole> _wormholes = [];
  Offset? _wormholePressStart;
  double? _wormholePressStartTime;
  bool _wormholeCandidate = false;
  static const double _wormholeHoldThreshold = 0.6;
  static const double _wormholeMoveTolerance = 24;

  void _onBackgroundPointerDown(PointerDownEvent event) {
    if (_draggingGalaxy || _hidden || _exploding) return;
    final titleRect = _currentTitleRect();
    if (titleRect != null &&
        titleRect.inflate(20).contains(event.localPosition)) {
      return;
    }
    final target = _galaxyTarget;
    final maxR = _galaxyMaxR;
    if (target != null &&
        maxR != null &&
        (event.localPosition - target).distance <= maxR * 1.3) {
      return;
    }
    _wormholePressStart = event.localPosition;
    _wormholePressStartTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
    _wormholeCandidate = true;
  }

  void _onBackgroundPointerMove(PointerEvent event) {
    if (!_wormholeCandidate) return;
    final start = _wormholePressStart;
    if (start == null) return;
    if ((event.localPosition - start).distance > _wormholeMoveTolerance) {
      _wormholeCandidate = false;
      _wormholePressStart = null;
      _wormholePressStartTime = null;
    }
  }

  void _onBackgroundPointerUp(PointerEvent event) {
    _wormholeCandidate = false;
    _wormholePressStart = null;
    _wormholePressStartTime = null;
  }

  // Checked every frame from the build loop, alongside the galaxy physics —
  // opens the wormhole once a candidate press has been held long enough.
  void _updateWormholeTrigger(double t) {
    if (!_wormholeCandidate) return;
    final start = _wormholePressStartTime;
    final pos = _wormholePressStart;
    if (start == null || pos == null) return;
    if (t - start >= _wormholeHoldThreshold) {
      _wormholeCandidate = false;
      _wormholePressStart = null;
      _wormholePressStartTime = null;
      _wormholes.add(_Wormhole(center: pos, startTime: t));
    }
  }

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

  static final List<_GalaxyParticle> _galaxyParticles = _buildGalaxyParticles();

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
            onPointerMove: (e) {
              _updateParallax(e.localPosition, size);
              _onGalaxyPointerMove(e);
              _onBackgroundPointerMove(e);
            },
            onPointerDown: (e) {
              _onGalaxyPointerDown(e);
              _onBackgroundPointerDown(e);
            },
            onPointerUp: (e) {
              _onGalaxyPointerUp(e);
              _onBackgroundPointerUp(e);
            },
            onPointerCancel: (e) {
              _onGalaxyPointerUp(e);
              _onBackgroundPointerUp(e);
            },
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
                _ensureGalaxyPhysics(size);
                _updateGalaxyPhysics(t, size);
                _updateWormholeTrigger(t);
                final titleHole = _updateTitleWormhole(t);
                final galaxyPull = _computeGalaxyWormholePull(t);
                _fireworks.removeWhere((fw) => fw.isDoneAt(t));
                _wormholes.removeWhere((w) => w.isDoneAt(t));
                _galaxyParticlesCaptured.removeWhere((_, w) => w.isDoneAt(t));
                return Transform.translate(
                  offset: _explosionShakeOffset(t),
                  child: Stack(
                    key: _stageKey,
                    children: [
                      for (final star in _stars)
                        _buildStar(star, t, constraints),
                      Positioned.fill(
                        child: CustomPaint(painter: _CometsPainter(_comets, t)),
                      ),
                      if (_exploding)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GalaxyExplosionPainter(
                              particles: _galaxyParticles,
                              startOffsets: _explodeStartOffsets!,
                              velocities: _explodeVelocities!,
                              sparks: _explodeSparks!,
                              center: _explodeCenter!,
                              startTime: _explodeStartTime!,
                              t: t,
                              maxR: _galaxyMaxR!,
                            ),
                          ),
                        )
                      else if (!_hidden)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GalaxyPainter(
                              particles: _galaxyParticles,
                              particleCenters: _particleLag!,
                              rotation: t * 2 * pi / 45,
                              maxR: _galaxyMaxR!,
                              blackHoleCenter: _galaxyTarget!,
                              haloOpacity: _haloOpacity,
                              formation: _galaxyFormationProgress(t),
                              wormholePull: galaxyPull.isEmpty
                                  ? null
                                  : galaxyPull,
                              wormholeCaptured: _galaxyParticlesCaptured.isEmpty
                                  ? null
                                  : _galaxyParticlesCaptured.keys.toSet(),
                            ),
                          ),
                        ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Transform.translate(
                            offset: Offset(
                              _parallax.dx * -4,
                              _parallax.dy * -4,
                            ),
                            child: ClipPath(
                              clipper:
                                  (titleHole.center != null &&
                                      titleHole.radius > 0)
                                  ? _EatenTextClipper(
                                      holeCenter: titleHole.center!,
                                      holeRadius: titleHole.radius,
                                    )
                                  : null,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: GestureDetector(
                                  key: _titleKey,
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _spawnFirework,
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
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _FireworksPainter(_fireworks, t),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _WormholePainter(_wormholes, t),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => web.window.location.reload(),
                              icon: const Icon(Icons.refresh),
                              iconSize: 16,
                              color: Colors.white70,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              splashRadius: 16,
                              tooltip: 'Reload',
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Test-v0.$editCount',
                              style: GoogleFonts.comicNeue(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // Once a captured star has been pulled all the way onto a wormhole's
  // center, it's treated as swallowed: it stays invisible until its own
  // brightness cycle would have made it invisible anyway (the same instant
  // it would normally teleport to a fresh spot), instead of popping back
  // into view at the exact place the wormhole grabbed it from.
  final Set<int> _wormholeCaptured = {};

  // Pulls a screen position toward any wormhole currently in its suck-in
  // phase — this is what actually drags the real stars in, rather than just
  // showing a separate effect near them. Every star inside the influence
  // radius fully reaches the center by the end of the capture window
  // (`_Wormhole.captureFraction`); distance only staggers *when* a star
  // starts moving (farther ones start a beat later), never how far it
  // ultimately travels — capping the distance travelled by distance, as an
  // earlier version did, made far stars stall partway and then snap back
  // once the pull switched off instead of ever reaching the center.
  Offset? _wormholePulledPosition(_Star star, Offset basePos, double t) {
    Offset? result;
    const influenceRadius = 260.0;
    for (final w in _wormholes) {
      final elapsed = t - w.startTime;
      if (elapsed < 0 || elapsed > _Wormhole.suckDuration) continue;
      final dist = (w.center - basePos).distance;
      if (dist > influenceRadius) continue;
      final delay = (dist / influenceRadius) * 0.35;
      final rawProgress =
          (elapsed / (_Wormhole.suckDuration * _Wormhole.captureFraction))
              .clamp(0.0, 1.0);
      final adjusted = ((rawProgress - delay) / (1 - delay)).clamp(0.0, 1.0);
      final pull = Curves.easeOutCubic.transform(adjusted);
      result = Offset.lerp(basePos, w.center, pull);
      if (pull > 0.95) {
        _wormholeCaptured.add(star.seed);
      }
    }
    return result;
  }

  Widget _buildStar(_Star star, double t, BoxConstraints constraints) {
    if (_wormholeCaptured.contains(star.seed)) {
      if (star.brightnessAt(t) < 0.05) {
        _wormholeCaptured.remove(star.seed);
      } else {
        return const SizedBox.shrink();
      }
    }

    final basePos = Offset(
      star.positionAt(t).dx * constraints.maxWidth,
      star.positionAt(t).dy * constraints.maxHeight,
    );
    final pos = _wormholes.isEmpty
        ? basePos
        : (_wormholePulledPosition(star, basePos, t) ?? basePos);
    return Positioned(
      left: pos.dx,
      top: pos.dy,
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
