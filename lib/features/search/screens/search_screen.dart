import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/location_service.dart';

class SearchScreen extends StatefulWidget {
  final AuthService? authService;
  final Dio? dio;

  const SearchScreen({super.key, this.authService, this.dio});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const Color _purple = Color(0xFF6C3EE8);
  static const Color _lightPurple = Color(0xFFF0EDFB);
  static const Color _gray = Color(0xFF6B7280);

  final _searchController = TextEditingController();
  final _mapController = MapController();
  late final _authService = widget.authService ?? AuthService();
  final _sheetController = DraggableScrollableController();
  late final _dio = widget.dio ?? Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'User-Agent': 'PathAR/1.0 (educational project)'},
  ));

  LatLng? _currentLocation;
  List<Map<String, dynamic>> _nearbyPlaces = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _universityLocations = [];
  bool _isLoadingLocation = true;
  bool _isLoadingPlaces = false;
  bool _showSearchResults = false;
  double _zoom = 15;
  String? _activeCategory;

  static const List<double> _snapSizes = [0.14, 0.42, 0.88];

  final _categories = [
    {'label': 'Cafés', 'icon': Icons.coffee, 'query': 'cafe'},
    {'label': 'Comida', 'icon': Icons.restaurant, 'query': 'restaurant'},
    {'label': 'Tiendas', 'icon': Icons.shopping_bag, 'query': 'supermarket'},
    {'label': 'Turismo', 'icon': Icons.museum, 'query': 'tourism'},
    {'label': 'Transporte', 'icon': Icons.directions_bus, 'query': 'bus_station'},
    {'label': 'Salud', 'icon': Icons.local_hospital, 'query': 'hospital'},
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackbar('Se necesita permiso de ubicación');
        setState(() => _isLoadingLocation = false);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnackbar('Permiso denegado. Habilitalo en Ajustes.');
      setState(() => _isLoadingLocation = false);
      return;
    }

    try {
      Position position;
      try {
        position = await LocationService.getPrecisePosition();
      } catch (_) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        );
      }

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _mapController.move(_currentLocation!, 15);
            } catch (_) {}
          }
        });
        _loadNearbyPlaces();
        _loadUniversityLocations();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showSnackbar('No se pudo obtener la ubicación');
      }
    }
  }

  Future<void> _loadUniversityLocations() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;
      final response = await _dio.get(
        '${dotenv.env['API_URL'] ?? 'http://localhost:8000'}/api/locations/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final list = response.data as List;
      if (mounted) {
        setState(() {
          _universityLocations = list.map<Map<String, dynamic>>((e) => {
            'id': e['id'],
            'name': e['name'],
            'description': e['description'] ?? '',
            'type': e['location_type'],
            'building': e['building'] ?? '',
            'floor': e['floor'] ?? '',
            'lat': e['latitude'],
            'lng': e['longitude'],
          }).toList();
        });
      }
    } catch (_) {}
  }

  // Nominatim busca texto libre, no "cualquiera de estas categorías" — por eso
  // se consulta una categoría a la vez (con countrycodes=cr) y se combinan los
  // resultados, en vez de mandar varias palabras juntas en un solo `q=`.
  Future<List<Map<String, dynamic>>> _fetchNominatimCategory(
    String searchQuery,
    double lat,
    double lng,
  ) async {
    final baseParams = {
      'q': searchQuery,
      'format': 'json',
      'limit': 8,
      'countrycodes': 'cr',
      'addressdetails': 1,
      'accept-language': 'es',
    };

    final response = await _dio.get(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        ...baseParams,
        'viewbox': '${lng - 0.05},${lat + 0.05},${lng + 0.05},${lat - 0.05}',
        'bounded': 1,
      },
    );
    var results = response.data as List;

    if (results.isEmpty) {
      final response2 = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: baseParams,
      );
      results = response2.data as List;
    }

    return _buildPlaces(results, lat, lng);
  }

  List<Map<String, dynamic>> _buildPlaces(List results, double lat, double lng) {
    return results.map<Map<String, dynamic>>((e) {
      final placeLat = double.parse(e['lat'].toString());
      final placeLng = double.parse(e['lon'].toString());
      final distanceM = Geolocator.distanceBetween(lat, lng, placeLat, placeLng);
      return {
        'name': e['display_name'].toString().split(',').first.trim(),
        'address': e['display_name'].toString().split(',').skip(1).take(2).join(',').trim(),
        'type': e['type'] ?? e['class'] ?? 'lugar',
        'source': 'osm',
        'lat': placeLat,
        'lng': placeLng,
        'distance_m': distanceM.round(),
        'distance_text': distanceM < 1000
            ? '${distanceM.round()} m'
            : '${(distanceM / 1000).toStringAsFixed(1)} km',
        'time_min': (distanceM / 80).round(),
      };
    }).toList();
  }

  Future<void> _loadNearbyPlaces({String? query}) async {
    if (_currentLocation == null) return;
    setState(() { _isLoadingPlaces = true; _showSearchResults = false; });

    final lat = _currentLocation!.latitude;
    final lng = _currentLocation!.longitude;

    try {
      List<Map<String, dynamic>> places;
      if (query != null) {
        places = await _fetchNominatimCategory(query, lat, lng);
        debugPrint('▶ NEARBY [$query]: ${places.length} resultados');
      } else {
        // Sin categoría seleccionada: traer un poco de cada una para mostrar
        // variedad de puntos apenas se entra al mapa (restaurantes, salud, etc).
        places = [];
        for (final cat in _categories) {
          try {
            final r = await _fetchNominatimCategory(cat['query'] as String, lat, lng);
            debugPrint('▶ NEARBY [${cat['query']}]: ${r.length} resultados');
            places.addAll(r);
          } catch (e) {
            debugPrint('✗ NEARBY [${cat['query']}] ERROR: ${e.runtimeType}: $e');
          }
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
      places.sort((a, b) => (a['distance_m'] as int).compareTo(b['distance_m'] as int));
      debugPrint('▶ NEARBY TOTAL: ${places.length} resultados finales');
      if (mounted) setState(() { _nearbyPlaces = places; _isLoadingPlaces = false; });
    } catch (e) {
      debugPrint('✗ NEARBY TOP-LEVEL ERROR: ${e.runtimeType}: $e');
      if (mounted) setState(() => _isLoadingPlaces = false);
    }
  }

  void _processNearbyResults(List results, double lat, double lng) {
    final places = _buildPlaces(results, lat, lng)
      ..sort((a, b) => (a['distance_m'] as int).compareTo(b['distance_m'] as int));
    if (mounted) setState(() { _nearbyPlaces = places; _isLoadingPlaces = false; });
  }

  List<Map<String, dynamic>> _searchUniversityLocations(String query) {
    if (_currentLocation == null) return [];
    final q = query.toLowerCase();
    final lat = _currentLocation!.latitude;
    final lng = _currentLocation!.longitude;

    return _universityLocations.where((loc) {
      final name = (loc['name'] ?? '').toString().toLowerCase();
      final building = (loc['building'] ?? '').toString().toLowerCase();
      final description = (loc['description'] ?? '').toString().toLowerCase();
      return name.contains(q) || building.contains(q) || description.contains(q);
    }).map((loc) {
      final distanceM = Geolocator.distanceBetween(lat, lng, loc['lat'], loc['lng']);
      return {
        ...loc,
        'address': loc['building'] ?? '',
        'source': 'university',
        'distance_m': distanceM.round(),
        'distance_text': distanceM < 1000
            ? '${distanceM.round()} m'
            : '${(distanceM / 1000).toStringAsFixed(1)} km',
        'time_min': (distanceM / 80).round(),
      };
    }).toList();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty || _currentLocation == null) return;
    setState(() { _isLoadingPlaces = true; _showSearchResults = true; });

    final universityMatches = _searchUniversityLocations(query);

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 10,
          'countrycodes': 'cr',
          'addressdetails': 1,
          'accept-language': 'es',
        },
      );
      _processNearbyResults(
        response.data as List,
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );
      final merged = [...universityMatches, ..._nearbyPlaces];
      merged.sort((a, b) => (a['distance_m'] as int).compareTo(b['distance_m'] as int));
      if (mounted) setState(() { _searchResults = merged; _isLoadingPlaces = false; });
    } catch (e) {
      final sorted = [...universityMatches]
        ..sort((a, b) => (a['distance_m'] as int).compareTo(b['distance_m'] as int));
      if (mounted) setState(() { _searchResults = sorted; _isLoadingPlaces = false; });
    }
  }

  Future<void> _selectDestination(Map<String, dynamic> place) async {
    try {
      final token = await _authService.getToken();
      if (token != null) {
        final dio = Dio(BaseOptions(
          baseUrl: dotenv.env['API_URL'] ?? 'http://localhost:8000',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ));
        await dio.post('/api/history/places', data: {
          'name': place['name'],
          'address': place['address'] ?? place['name'],
          'latitude': place['lat'],
          'longitude': place['lng'],
          'type': place['type'],
        });
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushNamed(context, '/navigation', arguments: {
      'destination': place,
      'origin': {
        'lat': _currentLocation!.latitude,
        'lng': _currentLocation!.longitude,
      },
    });
  }

  Future<void> _addToFavorites(Map<String, dynamic> place) async {
    try {
      await _authService.addFavorite(
        name: place['name'],
        address: place['address'],
        latitude: place['lat'],
        longitude: place['lng'],
      );
      if (mounted) _showSnackbar('${place['name']} agregado a favoritos');
    } catch (e) {
      if (mounted) _showSnackbar('No se pudo agregar a favoritos');
    }
  }

  // Escala de marcadores según el zoom: puntos chicos alejado, pines completos cerca.
  double _markerSize({double min = 10, double max = 44, double minZoom = 12, double maxZoom = 18}) {
    final t = ((_zoom - minZoom) / (maxZoom - minZoom)).clamp(0.0, 1.0);
    return min + (max - min) * t;
  }

  bool get _isDotZoom => _zoom < 15;
  bool get _showMarkerLabels => _zoom >= 17;

  Widget _markerLabel(String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 3)],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
      ),
    );
  }

  Widget _zoomMarker({
    required Color color,
    required IconData icon,
    required double size,
    bool filled = true,
  }) {
    if (_isDotZoom) {
      return Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3)],
        ),
      );
    }
    if (!filled) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.45),
    );
  }

  void _snapToNearest() {
    final current = _sheetController.size;
    final closest = _snapSizes.reduce((a, b) =>
      (a - current).abs() < (b - current).abs() ? a : b,
    );
    _sheetController.animateTo(
      closest,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _purple),
              SizedBox(height: 16),
              Text('Obteniendo tu ubicación...', style: TextStyle(color: _gray)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        children: [
          // ── Mapa de fondo ─────────────────────────────────────
          if (_currentLocation != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation!,
                initialZoom: 15,
                onPositionChanged: (camera, hasGesture) {
                  if ((camera.zoom - _zoom).abs() > 0.05) {
                    setState(() => _zoom = camera.zoom);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.u_2026_ra_fe',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 44, height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _purple,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(
                            color: _purple.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 22),
                      ),
                    ),
                    // Marcadores de lugares cercanos (OSM)
                    ...(_showSearchResults ? _searchResults : _nearbyPlaces).take(15).map((place) {
                      final size = _markerSize(min: 8, max: 34);
                      final showLabel = _showMarkerLabels;
                      return Marker(
                        point: LatLng(place['lat'], place['lng']),
                        width: 100,
                        height: showLabel ? size + 20 : size,
                        alignment: Alignment.bottomCenter,
                        child: GestureDetector(
                          onTap: () => _selectDestination(place),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: size,
                                height: size,
                                child: _zoomMarker(
                                  color: _purple,
                                  icon: _getCategoryIcon(place['type']),
                                  size: size,
                                  filled: false,
                                ),
                              ),
                              if (showLabel) ...[
                                const SizedBox(height: 2),
                                _markerLabel(place['name'] ?? ''),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),

                    // Marcadores de ubicaciones universitarias (backend, incluye las agregadas manualmente)
                    ..._universityLocations.map((loc) {
                      final size = _markerSize();
                      final showLabel = _showMarkerLabels;
                      return Marker(
                        point: LatLng(loc['lat'], loc['lng']),
                        width: 100,
                        height: showLabel ? size + 20 : size,
                        alignment: Alignment.bottomCenter,
                        child: GestureDetector(
                          onTap: () => _showUniversityLocationInfo(loc),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: size,
                                height: size,
                                child: _zoomMarker(
                                  color: const Color(0xFFFF6B35),
                                  icon: Icons.school,
                                  size: size,
                                ),
                              ),
                              if (showLabel) ...[
                                const SizedBox(height: 2),
                                _markerLabel(loc['name'] ?? ''),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),

          // ── Botón mi ubicación ────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'location_btn',
              onPressed: _getLocation,
              backgroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.my_location, color: _purple),
            ),
          ),

          // ── Panel plegable ────────────────────────────────────
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.42,
            minChildSize: 0.14,
            maxChildSize: 0.88,
            snap: true,
            snapSizes: _snapSizes,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
                ),
                child: Column(
                  children: [
                    // ── Handle con snap forzado ──────────────────
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        final screenHeight = MediaQuery.of(context).size.height;
                        final delta = -details.primaryDelta! / screenHeight;
                        final newSize = (_sheetController.size + delta)
                            .clamp(_snapSizes.first, _snapSizes.last);
                        _sheetController.jumpTo(newSize);
                      },
                      onVerticalDragEnd: (_) => _snapToNearest(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                            width: 48, height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Barra de búsqueda ────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {});
                          if (val.length > 2) _searchPlaces(val);
                          if (val.isEmpty) setState(() => _showSearchResults = false);
                        },
                        onSubmitted: _searchPlaces,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF1F2937)),
                        decoration: InputDecoration(
                          hintText: 'Busca un lugar, dirección...',
                          hintStyle: const TextStyle(color: Color(0xFFBEC3CF), fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFBEC3CF)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: _gray, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() { _showSearchResults = false; _activeCategory = null; });
                                    _loadNearbyPlaces();
                                  },
                                )
                              : const Icon(Icons.mic_outlined, color: _gray),
                          filled: true,
                          fillColor: const Color(0xFFF5F3FD),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _purple, width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    // ── Contenido scrolleable ────────────────────
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          if (!_showSearchResults) ...[
                            const Text('Categorías',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.1,
                              children: _categories.map((cat) {
                                final query = cat['query'] as String;
                                final isActive = _activeCategory == query;

                                void clearCategory() {
                                  setState(() => _activeCategory = null);
                                  _loadNearbyPlaces();
                                }

                                return GestureDetector(
                                  onTap: () {
                                    if (isActive) {
                                      clearCategory();
                                    } else {
                                      setState(() => _activeCategory = query);
                                      _loadNearbyPlaces(query: query);
                                    }
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isActive ? _lightPurple : const Color(0xFFF9F9F9),
                                            borderRadius: BorderRadius.circular(14),
                                            border: isActive ? Border.all(color: _purple, width: 1.5) : null,
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 40, height: 40,
                                                decoration: BoxDecoration(
                                                  color: isActive ? _purple : _lightPurple,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  cat['icon'] as IconData,
                                                  color: isActive ? Colors.white : _purple,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                cat['label'] as String,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: const Color(0xFF1F2937),
                                                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isActive)
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: GestureDetector(
                                            onTap: clearCategory,
                                            child: Container(
                                              width: 20, height: 20,
                                              decoration: const BoxDecoration(
                                                color: _purple,
                                                shape: BoxShape.circle,
                                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
                                              ),
                                              child: const Icon(Icons.close, color: Colors.white, size: 13),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Sugerencias cercanas',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                Row(children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('CRC', style: TextStyle(fontSize: 12, color: _gray)),
                                ]),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            Text(
                              _isLoadingPlaces
                                  ? 'Buscando...'
                                  : '${_searchResults.length} resultados',
                              style: const TextStyle(fontSize: 13, color: _gray),
                            ),
                            const SizedBox(height: 12),
                          ],

                          if (_isLoadingPlaces)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: CircularProgressIndicator(color: _purple)),
                            )
                          else if ((_showSearchResults ? _searchResults : _nearbyPlaces).isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.place_outlined, color: Colors.grey[400], size: 40),
                                    const SizedBox(height: 12),
                                    Text(
                                      _showSearchResults
                                          ? 'No se encontraron resultados'
                                          : 'No se encontraron lugares cercanos',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...(_showSearchResults ? _searchResults : _nearbyPlaces)
                                .take(10)
                                .map((place) => _placeCard(place)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _placeCard(Map<String, dynamic> place) {
    final isUniversity = place['source'] == 'university';
    const orange = Color(0xFFFF6B35);

    return GestureDetector(
      onTap: () => _selectDestination(place),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: isUniversity ? orange.withOpacity(0.15) : _lightPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isUniversity ? Icons.school : _getCategoryIcon(place['type']),
                color: isUniversity ? orange : _purple,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place['name'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    place['address'] ?? '',
                    style: const TextStyle(fontSize: 11, color: _gray),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_walk, size: 13, color: Color(0xFF1F2937)),
                    const SizedBox(width: 2),
                    Text(
                      _formatWalkTime(place['time_min']),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
                Text(
                  place['distance_text'] ?? '',
                  style: const TextStyle(fontSize: 10, color: _gray),
                ),
              ],
            ),
            IconButton(
              onPressed: () => _addToFavorites(place),
              icon: const Icon(Icons.favorite_border, size: 18, color: _gray),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, -2),
        )],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.search, 'Buscar', true, () {}),
              _navItem(Icons.near_me_outlined, 'Navegar', false,
                () => Navigator.pushNamed(context, '/navigation')),
              _navItem(Icons.person_outline, 'Perfil', false,
                () => Navigator.pushNamed(context, '/home')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? _purple : _gray, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 11,
            color: active ? _purple : _gray,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  String _formatWalkTime(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }

  IconData _getCategoryIcon(String type) {
    switch (type) {
      case 'cafe': return Icons.coffee;
      case 'restaurant': case 'fast_food': return Icons.restaurant;
      case 'supermarket': case 'shop': return Icons.shopping_bag;
      case 'museum': case 'tourism': return Icons.museum;
      case 'bus_station': case 'bus_stop': return Icons.directions_bus;
      case 'hospital': case 'clinic': return Icons.local_hospital;
      case 'park': return Icons.park;
      case 'school': case 'university': return Icons.school;
      case 'bank': case 'atm': return Icons.account_balance;
      default: return Icons.place;
    }
  }

  void _showUniversityLocationInfo(Map<String, dynamic> loc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school, color: Color(0xFFFF6B35), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc['name'],
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      if (loc['building'] != null && loc['building'].toString().isNotEmpty)
                        Text(
                          '${loc['building']}${loc['floor'] != null && loc['floor'].toString().isNotEmpty ? ' · Piso ${loc['floor']}' : ''}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (loc['description'] != null && loc['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                loc['description'],
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _selectDestination(loc);
                },
                icon: const Icon(Icons.near_me, size: 18),
                label: const Text('Navegar aquí'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}