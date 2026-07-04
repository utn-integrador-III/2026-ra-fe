import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/services/auth_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const Color _purple = Color(0xFF6C3EE8);
  static const Color _lightPurple = Color(0xFFF0EDFB);
  static const Color _gray = Color(0xFF6B7280);

  final _searchController = TextEditingController();
  final _mapController = MapController();
  final _authService = AuthService();
  final _sheetController = DraggableScrollableController();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'User-Agent': 'PathAR/1.0 (educational project)'},
  ));

  LatLng? _currentLocation;
  List<Map<String, dynamic>> _nearbyPlaces = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoadingLocation = true;
  bool _isLoadingPlaces = false;
  bool _showSearchResults = false;

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
      // Intentar con alta precisión primero
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (_) {
        // Si falla por timeout, intentar con baja precisión (más rápido)
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        );
      }

      if (mounted) {
  setState(() {
    _currentLocation = LatLng(position!.latitude, position.longitude);
    _isLoadingLocation = false;
  });
  // Esperar al siguiente frame para que el mapa se renderice
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      try {
        _mapController.move(_currentLocation!, 15);
      } catch (_) {}
    }
      });
      _loadNearbyPlaces();
    }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showSnackbar('No se pudo obtener la ubicación: $e');
      }
    }
  }

  Future<void> _loadNearbyPlaces({String? query}) async {
    if (_currentLocation == null) return;
    setState(() { _isLoadingPlaces = true; _showSearchResults = false; });

    final lat = _currentLocation!.latitude;
    final lng = _currentLocation!.longitude;
    final searchQuery = query ?? 'tienda restaurante cafe hospital banco';

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': searchQuery,
          'format': 'json',
          'limit': 15,
          'viewbox': '${lng - 0.05},${lat + 0.05},${lng + 0.05},${lat - 0.05}',
          'bounded': 1,
          'addressdetails': 1,
          'accept-language': 'es',
        },
      );

      var results = response.data as List;

      if (results.isEmpty) {
        final response2 = await _dio.get(
          'https://nominatim.openstreetmap.org/search',
          queryParameters: {
            'q': searchQuery,
            'format': 'json',
            'limit': 15,
            'addressdetails': 1,
            'accept-language': 'es',
          },
        );
        results = response2.data as List;
      }

      _processNearbyResults(results, lat, lng);
    } catch (e) {
      if (mounted) setState(() => _isLoadingPlaces = false);
    }
  }

  void _processNearbyResults(List results, double lat, double lng) {
    final places = results.map<Map<String, dynamic>>((e) {
      final placeLat = double.parse(e['lat'].toString());
      final placeLng = double.parse(e['lon'].toString());
      final distanceM = Geolocator.distanceBetween(lat, lng, placeLat, placeLng);
      return {
        'name': e['display_name'].toString().split(',').first.trim(),
        'address': e['display_name'].toString().split(',').skip(1).take(2).join(',').trim(),
        'type': e['type'] ?? e['class'] ?? 'lugar',
        'lat': placeLat,
        'lng': placeLng,
        'distance_m': distanceM.round(),
        'distance_text': distanceM < 1000 ? '${distanceM.round()} m' : '${(distanceM / 1000).toStringAsFixed(1)} km',
        'time_min': (distanceM / 80).round(),
      };
    }).toList();

    places.sort((a, b) => (a['distance_m'] as int).compareTo(b['distance_m'] as int));
    if (mounted) setState(() { _nearbyPlaces = places; _isLoadingPlaces = false; });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty || _currentLocation == null) return;
    setState(() { _isLoadingPlaces = true; _showSearchResults = true; });

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 10,
          'addressdetails': 1,
          'accept-language': 'es',
        },
      );
      _processNearbyResults(response.data as List, _currentLocation!.latitude, _currentLocation!.longitude);
      if (mounted) setState(() { _searchResults = _nearbyPlaces; _isLoadingPlaces = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingPlaces = false);
    }
  }

  Future<void> _selectDestination(Map<String, dynamic> place) async {
    try {
      final token = await _authService.getToken();
      if (token != null) {
        final dio = Dio(BaseOptions(
          baseUrl: dotenv.env['API_URL'] ?? 'http://localhost:8000',
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
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
      'origin': {'lat': _currentLocation!.latitude, 'lng': _currentLocation!.longitude},
    });
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
                          boxShadow: [BoxShadow(color: _purple.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 22),
                      ),
                    ),
                    ...(_showSearchResults ? _searchResults : _nearbyPlaces).take(10).map((place) =>
                      Marker(
                        point: LatLng(place['lat'], place['lng']),
                        width: 34, height: 34,
                        child: GestureDetector(
                          onTap: () => _selectDestination(place),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: _purple, width: 2),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
                            ),
                            child: Icon(_getCategoryIcon(place['type']), color: _purple, size: 16),
                          ),
                        ),
                      ),
                    ),
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
            initialChildSize: 0.42,  // estado medio — como está ahora
            minChildSize: 0.14,       // solo se ve la rayita y la búsqueda
            maxChildSize: 0.88,       // casi pantalla completa
            snap: true,               // ← esto ya lo tenés
            snapSizes: const [0.14, 0.42, 0.88],  // ← solo estos 3 tamaños exactos
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
                ),
                child: Column(
                  children: [
                    // ── Handle — arrastrá desde acá ──────────────
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        final screenHeight = MediaQuery.of(context).size.height;
                        final delta = -details.primaryDelta! / screenHeight;
                        final newSize = (_sheetController.size + delta).clamp(0.12, 0.90);
                        _sheetController.jumpTo(newSize);
                      },
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FD),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {});
                            if (val.length > 2) _searchPlaces(val);
                            if (val.isEmpty) setState(() { _showSearchResults = false; });
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
                                      setState(() { _showSearchResults = false; });
                                      _loadNearbyPlaces();
                                    },
                                  )
                                : const Icon(Icons.mic_outlined, color: _gray),
                            filled: true,
                            fillColor: const Color(0xFFF5F3FD),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: _purple, width: 1.5),
                            ),
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
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.1,
                              children: _categories.map((cat) => GestureDetector(
                                onTap: () => _loadNearbyPlaces(query: cat['query'] as String),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9F9F9),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 40, height: 40,
                                        decoration: BoxDecoration(color: _lightPurple, borderRadius: BorderRadius.circular(10)),
                                        child: Icon(cat['icon'] as IconData, color: _purple, size: 20),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(cat['label'] as String,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF1F2937), fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              )).toList(),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Sugerencias cercanas',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                Row(children: [
                                  Container(width: 8, height: 8,
                                    decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  const Text('CRC', style: TextStyle(fontSize: 12, color: _gray)),
                                ]),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            Text(
                              _isLoadingPlaces ? 'Buscando...' : '${_searchResults.length} resultados',
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
                                      _showSearchResults ? 'No se encontraron resultados' : 'No se encontraron lugares cercanos',
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
    return GestureDetector(
      onTap: () => _selectDestination(place),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: _lightPurple, borderRadius: BorderRadius.circular(12)),
              child: Icon(_getCategoryIcon(place['type']), color: _purple, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place['name'],
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(place['address'] ?? '',
                    style: const TextStyle(fontSize: 11, color: _gray),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${place['time_min']} min',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                Text(place['distance_text'] ?? '',
                  style: const TextStyle(fontSize: 10, color: _gray)),
              ],
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.search, 'Buscar', true, () {}),
              _navItem(Icons.near_me_outlined, 'Navegar', false, () => Navigator.pushNamed(context, '/navigation')),
              _navItem(Icons.person_outline, 'Perfil', false, () => Navigator.pushNamed(context, '/home')),
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

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}