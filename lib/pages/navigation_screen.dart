import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/services/navigation_service.dart';
import '../core/services/location_service.dart';
import '../features/navigation/models/route_models.dart';
import '../features/navigation/widgets/ar_arrow_overlay.dart';
import '../features/navigation/widgets/ar_path_overlay.dart';

// ── Umbrales de la navegación guiada ────────────────────────────────
const double _kAdvanceRadiusM = 8.0; // a esta distancia se considera "llegó al nodo"
const double _kAnnounceRadiusM = 15.0; // avisar el giro con esta anticipación
const double _kArrivalRadiusM = 10.0; // a esta distancia del destino final, "llegaste"
const double _kRecalculateThresholdM = 35.0; // si te alejás esto del tramo, recalcular
const Duration _kRecalculateCooldown = Duration(seconds: 12);
const double _kOnPathThresholdM = 15.0; // la línea azul solo se dibuja si estás así de cerca de una acera real

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> with WidgetsBindingObserver {
  final _navService = NavigationService();
  final _tts = FlutterTts();

  bool _argsProcessed = false;
  Map<String, dynamic>? _destinationArg;
  Map<String, dynamic>? _originArg;

  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;

  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<Position>? _positionSub;

  double _deviceHeading = 0;
  double _smSinH = 0, _smCosH = 1; // suavizado circular de la brújula (evita saltos por ruido del magnetómetro)
  bool _headingInit = false;
  double? _lastRawHeading;
  double _instabilityScore = 0; // sube con saltos bruscos crudos, baja con lecturas estables
  bool get _compassUnstable => _instabilityScore >= 6;
  Position? _currentPosition;
  double? _smLat; // posición suavizada (reduce el salto/jitter del GPS crudo)
  double? _smLng;

  NavRoute? _route;
  int _currentStepIndex = 0;
  final Set<int> _announcedTurns = {};
  DateTime? _lastRecalculate;
  bool _arrived = false;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTts();
    _initCamera();
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() => _updateHeading(event.heading!));
      }
    });
  }

  /// Suavizado circular (vía seno/coseno, no promedio directo de grados)
  /// para que la flecha no tiemble con cada lectura ruidosa del
  /// magnetómetro. No "arregla" una brújula mal calibrada — para eso
  /// está el botón de calibración.
  void _updateHeading(double newHeadingDeg) {
    if (_lastRawHeading != null) {
      double jump = (newHeadingDeg - _lastRawHeading!) % 360;
      if (jump > 180) jump -= 360;
      if (jump < -180) jump += 360;
      // Un giro real de la persona también puede saltar así, pero si pasa
      // seguido (varias lecturas seguidas saltando fuerte) es más probable
      // que sea interferencia magnética que un giro genuino y sostenido.
      _instabilityScore += jump.abs() > 40 ? 1 : -0.5;
      _instabilityScore = _instabilityScore.clamp(0, 10);
    }
    _lastRawHeading = newHeadingDeg;

    final rad = newHeadingDeg * math.pi / 180;
    const alpha = 0.25;
    if (!_headingInit) {
      _smSinH = math.sin(rad);
      _smCosH = math.cos(rad);
      _headingInit = true;
    } else {
      _smSinH = _smSinH * (1 - alpha) + math.sin(rad) * alpha;
      _smCosH = _smCosH * (1 - alpha) + math.cos(rad) * alpha;
    }
    _deviceHeading = (math.atan2(_smSinH, _smCosH) * 180 / math.pi + 360) % 360;
  }

  void _showCompassCalibration() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.explore, color: Colors.white),
            SizedBox(width: 10),
            Text('Calibrar brújula', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Moví el teléfono trazando un 8 en el aire durante unos segundos. '
          'El sensor de tu celular se recalibra solo con el movimiento — '
          'esto ayuda si notás que la flecha apunta para el lado equivocado.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsProcessed) return;
    _argsProcessed = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _destinationArg = (args['destination'] as Map?)?.cast<String, dynamic>();
      _originArg = (args['origin'] as Map?)?.cast<String, dynamic>();
    }

    if (_destinationArg == null || _destinationArg!['lat'] == null) {
      setState(() {
        _loading = false;
        _error = 'No se seleccionó ningún destino. Volvé a buscar un lugar.';
      });
      return;
    }

    _startNavigation();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(backCamera, ResolutionPreset.high, enableAudio: false);
      _cameraInitFuture = _cameraController!.initialize();
      await _cameraInitFuture;
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
        await _cameraController!.setExposureMode(ExposureMode.auto);
      } catch (_) {
        // Algunos dispositivos no soportan cambiar el modo manualmente; se
        // queda con el default del sistema, que igual suele ser auto.
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Sin cámara disponible (p.ej. emulador) -> queda el fondo oscuro de respaldo
    }
  }

  Future<void> _startNavigation() async {
    setState(() { _loading = true; _error = null; });

    double? originLat = (_originArg?['lat'] as num?)?.toDouble();
    double? originLng = (_originArg?['lng'] as num?)?.toDouble();

    if (originLat == null || originLng == null) {
      try {
        final pos = await LocationService.getPrecisePosition();
        originLat = pos.latitude;
        originLng = pos.longitude;
      } catch (_) {
        setState(() { _loading = false; _error = 'No se pudo obtener tu ubicación actual.'; });
        return;
      }
    }

    final destLat = (_destinationArg!['lat'] as num).toDouble();
    final destLng = (_destinationArg!['lng'] as num).toDouble();
    final destName = _destinationArg!['name'] as String?;

    try {
      final route = await _navService.requestRoute(
        originLat: originLat,
        originLng: originLng,
        destinationLat: destLat,
        destinationLng: destLng,
        destinationName: destName,
      );
      await _navService.startRoute(route.id);

      if (!mounted) return;
      setState(() {
        _route = route;
        _currentStepIndex = 0;
        _announcedTurns.clear();
        _arrived = false;
        _loading = false;
      });

      await _tts.speak('Ruta calculada. ${route.distanceText} hasta tu destino.');
      _listenPosition();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _listenPosition() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        intervalDuration: const Duration(milliseconds: 800),
        forceLocationManager: false,
      ),
    ).listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position pos) {
    if (!mounted || _route == null || _arrived) return;

    // Suavizado exponencial: una lectura con poca precisión pesa menos,
    // así el punto usado para guiar no salta con cada rebote del GPS.
    final alpha = (1 - (pos.accuracy / 30)).clamp(0.15, 0.9);
    if (_smLat == null || _smLng == null) {
      _smLat = pos.latitude;
      _smLng = pos.longitude;
    } else {
      _smLat = _smLat! * (1 - alpha) + pos.latitude * alpha;
      _smLng = _smLng! * (1 - alpha) + pos.longitude * alpha;
    }
    final lat = _smLat!;
    final lng = _smLng!;

    setState(() => _currentPosition = pos);

    final points = _route!.points;
    final steps = _route!.steps;

    final destPoint = points.last;
    final distToDestination = Geolocator.distanceBetween(lat, lng, destPoint.lat, destPoint.lng);

    if (distToDestination <= _kArrivalRadiusM) {
      _handleArrival();
      return;
    }

    // ── Avanzar de nodo si ya estamos cerca del siguiente ──
    while (_currentStepIndex + 1 < points.length - 1) {
      final nextPoint = points[_currentStepIndex + 1];
      final d = Geolocator.distanceBetween(lat, lng, nextPoint.lat, nextPoint.lng);
      if (d <= _kAdvanceRadiusM) {
        setState(() => _currentStepIndex++);
        final activeInstruction = steps[_currentStepIndex].instruction;
        if (steps[_currentStepIndex].turn == 'left' || steps[_currentStepIndex].turn == 'right') {
          _tts.speak(activeInstruction);
        }
      } else {
        break;
      }
    }

    // ── Aviso proactivo de giro próximo ──
    final upcomingIndex = (_currentStepIndex + 1).clamp(0, steps.length - 1);
    final upcomingStep = steps[upcomingIndex];
    final targetPoint = points[upcomingIndex];
    final distToTarget = Geolocator.distanceBetween(lat, lng, targetPoint.lat, targetPoint.lng);

    if ((upcomingStep.turn == 'left' || upcomingStep.turn == 'right') &&
        distToTarget <= _kAnnounceRadiusM &&
        !_announcedTurns.contains(upcomingIndex)) {
      _announcedTurns.add(upcomingIndex);
      _tts.speak('En ${distToTarget.round()} metros, ${upcomingStep.instruction.toLowerCase()}');
    }

    // ── Recalcular si el usuario se alejó demasiado del tramo actual ──
    final distToCurrent = Geolocator.distanceBetween(lat, lng, points[_currentStepIndex].lat, points[_currentStepIndex].lng);
    final strayed = distToTarget > _kRecalculateThresholdM && distToCurrent > _kRecalculateThresholdM;
    final cooldownOk = _lastRecalculate == null ||
        DateTime.now().difference(_lastRecalculate!) > _kRecalculateCooldown;

    if (strayed && cooldownOk) {
      _lastRecalculate = DateTime.now();
      _recalculate(lat, lng);
    }

    setState(() {});
  }

  Future<void> _recalculate(double lat, double lng) async {
    if (_route == null) return;
    try {
      final updated = await _navService.recalculateRoute(
        routeId: _route!.id,
        currentLat: lat,
        currentLng: lng,
      );
      if (!mounted) return;
      setState(() {
        _route = updated;
        _currentStepIndex = 0;
        _announcedTurns.clear();
      });
      await _tts.speak('Recalculando ruta.');
    } catch (_) {
      // Si falla el recálculo, se sigue guiando con la ruta anterior
    }
  }

  Future<void> _handleArrival() async {
    setState(() => _arrived = true);
    _positionSub?.cancel();
    await _tts.speak('Llegaste a tu destino.');
    if (_route != null) {
      try {
        await _navService.finishRoute(_route!.id);
      } catch (_) {}
    }
  }

  double _remainingDistanceM() {
    if (_route == null || _smLat == null || _smLng == null) return _route?.distanceM ?? 0;
    final points = _route!.points;
    final steps = _route!.steps;
    final upcomingIndex = (_currentStepIndex + 1).clamp(0, points.length - 1);

    double remaining = Geolocator.distanceBetween(
      _smLat!, _smLng!, points[upcomingIndex].lat, points[upcomingIndex].lng,
    );
    for (int i = upcomingIndex; i < steps.length - 1; i++) {
      remaining += steps[i].distanceToNextM;
    }
    return remaining;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Distancia perpendicular (m) desde tu posición al tramo más cercano
  /// de TODA la ruta calculada. Se usa para no mostrar la línea azul
  /// cuando estás lejos de cualquier acera real (p.ej. dentro de una casa).
  double _distanceToRouteM() {
    if (_route == null || _smLat == null || _smLng == null) return double.infinity;
    final pts = _route!.points;
    if (pts.length < 2) return double.infinity;

    double best = double.infinity;
    for (int i = 0; i < pts.length - 1; i++) {
      final d = _distanceToSegmentM(_smLat!, _smLng!, pts[i].lat, pts[i].lng, pts[i + 1].lat, pts[i + 1].lng);
      if (d < best) best = d;
    }
    return best;
  }

  double _distanceToSegmentM(double plat, double plng, double alat, double alng, double blat, double blng) {
    final cosLat0 = math.cos(plat * math.pi / 180);
    double toX(double lng) => (lng - plng) * cosLat0 * 111320.0;
    double toY(double lat) => (lat - plat) * 110540.0;

    final ax = toX(alng), ay = toY(alat);
    final bx = toX(blng), by = toY(blat);
    final abx = bx - ax, aby = by - ay;
    final ab2 = abx * abx + aby * aby;
    final t = ab2 == 0 ? 0.0 : (((-ax) * abx + (-ay) * aby) / ab2).clamp(0.0, 1.0);
    final projx = ax + t * abx, projy = ay + t * aby;
    return math.sqrt(projx * projx + projy * projy);
  }

  double _relativeBearingDeg() {
    if (_route == null || _smLat == null || _smLng == null) return 0;
    final points = _route!.points;
    final targetIndex = (_currentStepIndex + 1).clamp(0, points.length - 1);
    final target = points[targetIndex];
    final targetBearing = Geolocator.bearingBetween(_smLat!, _smLng!, target.lat, target.lng);
    double diff = (targetBearing - _deviceHeading) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
  }

  Future<void> _exitNavigation() async {
    if (_route != null && !_arrived) {
      try {
        await _navService.finishRoute(_route!.id);
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _compassSub?.cancel();
    _positionSub?.cancel();
    _cameraController?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _error != null
            ? _buildError()
            : _loading
                ? _buildLoading()
                : _buildNavigationView(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('Calculando la mejor ruta...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationView() {
    final upcomingIndex = _route == null
        ? 0
        : (_currentStepIndex + 1).clamp(0, _route!.steps.length - 1);
    final upcomingStep = _route?.steps[upcomingIndex];
    final distToTarget = _route != null && _smLat != null && _smLng != null
        ? Geolocator.distanceBetween(
            _smLat!, _smLng!, _route!.points[upcomingIndex].lat, _route!.points[upcomingIndex].lng,
          )
        : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Cámara de fondo (o respaldo negro si no hay cámara) ──
        if (_cameraController != null && _cameraController!.value.isInitialized)
          FutureBuilder<void>(
            future: _cameraInitFuture,
            builder: (context, snapshot) => CameraPreview(_cameraController!),
          )
        else
          Container(color: const Color(0xFF111318)),

        // ── Línea/alfombra azul sobre el camino (solo si estás cerca de una acera real) ──
        if (_route != null && _smLat != null && _smLng != null && !_arrived &&
            _distanceToRouteM() <= _kOnPathThresholdM)
          ArPathOverlay(
            currentLat: _smLat!,
            currentLng: _smLng!,
            deviceHeadingDeg: _deviceHeading,
            pathPoints: _route!.points.sublist((_currentStepIndex + 1).clamp(0, _route!.points.length - 1)),
          ),

        // ── Flecha guía ──
        ArArrowOverlay(
          relativeBearingDeg: _relativeBearingDeg(),
          arrived: _arrived,
        ),

        // ── Barra superior: instrucción actual (FR-08) ──
        Positioned(
          top: 12, left: 12, right: 12,
          child: Row(
            children: [
              _circleButton(Icons.close, _exitNavigation),
              const SizedBox(width: 8),
              _circleButton(Icons.explore_outlined, _showCompassCalibration),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _arrived
                        ? '¡Llegaste a tu destino!'
                        : (upcomingStep?.instruction ?? 'Seguí recto'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Aviso de brújula inestable (interferencia magnética) ──
        if (_compassUnstable)
          Positioned(
            top: 68, left: 12, right: 12,
            child: GestureDetector(
              onTap: _showCompassCalibration,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade800.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Brújula inestable (¿hay algo metálico/electrónico cerca?). Tocá para calibrar.',
                        style: TextStyle(color: Colors.white, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Panel inferior: distancia (FR-11) ──
        Positioned(
          left: 12, right: 12, bottom: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_route?.destinationName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _route!.destinationName!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.directions_walk, color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Quedan ${_formatDistance(_remainingDistanceM())}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ]),
                    if (!_arrived && upcomingStep != null)
                      Text(
                        '${_formatDistance(distToTarget)} → ${_turnLabel(upcomingStep.turn)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                  ],
                ),
                if (_currentPosition != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Precisión GPS: ±${_currentPosition!.accuracy.round()} m',
                      style: TextStyle(
                        color: _currentPosition!.accuracy <= 10 ? Colors.greenAccent : Colors.amberAccent,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _turnLabel(String turn) {
    switch (turn) {
      case 'left': return 'girar a la izquierda';
      case 'right': return 'girar a la derecha';
      case 'arrive': return 'destino';
      default: return 'seguir recto';
    }
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
