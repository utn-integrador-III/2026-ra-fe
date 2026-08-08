import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Flecha guía "AR por sensores": no ancla nada en 3D, pero rota y se
/// desplaza sobre el preview de cámara según el rumbo hacia el siguiente
/// nodo de acera comparado con hacia dónde apunta el teléfono (brújula).
class ArArrowOverlay extends StatelessWidget {
  final double relativeBearingDeg; // -180..180, 0 = el destino está justo al frente
  final bool arrived;
  final double fovDeg;

  const ArArrowOverlay({
    super.key,
    required this.relativeBearingDeg,
    this.arrived = false,
    this.fovDeg = 60,
  });

  static const _blue = Color(0xFF3B82F6);
  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    if (arrived) {
      return const Center(
        child: Icon(Icons.flag_circle, size: 96, color: Colors.greenAccent,
            shadows: [Shadow(color: Colors.black54, blurRadius: 14)]),
      );
    }

    final halfFov = fovDeg / 2;
    final clamped = relativeBearingDeg.clamp(-halfFov, halfFov);
    final t = clamped / halfFov; // -1..1
    final offBounds = relativeBearingDeg.abs() > halfFov;
    final aligned = relativeBearingDeg.abs() < 12;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxOffset = (constraints.maxWidth / 2 - 60).clamp(0.0, double.infinity);
        final dx = t * maxOffset;

        return Stack(
          children: [
            Positioned(
              bottom: constraints.maxHeight * 0.26,
              left: constraints.maxWidth / 2 - 45 + dx,
              child: Transform.rotate(
                angle: relativeBearingDeg * math.pi / 180,
                child: Icon(
                  Icons.navigation,
                  size: 90,
                  color: aligned ? _blue : _amber,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 12)],
                ),
              ),
            ),
            if (offBounds)
              Positioned(
                bottom: constraints.maxHeight * 0.32,
                left: relativeBearingDeg > 0 ? null : 10,
                right: relativeBearingDeg > 0 ? 10 : null,
                child: Icon(
                  relativeBearingDeg > 0 ? Icons.chevron_right : Icons.chevron_left,
                  size: 44,
                  color: Colors.white,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 10)],
                ),
              ),
          ],
        );
      },
    );
  }
}
