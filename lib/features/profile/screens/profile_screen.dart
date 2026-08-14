import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/routes/app_routes.dart';
import '../../navigation/models/route_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _navService = NavigationService();

  static const Color _purple = Color(0xFF6C3EE8);
  static const Color _lightPurple = Color(0xFFF0EDFB);
  static const Color _gray = Color(0xFF6B7280);
  static const Color _lightGray = Color(0xFFF9F9F9);

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _recents = [];
  List<Map<String, dynamic>> _favorites = [];
  int _routesCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final token = await _authService.getToken();
      final baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      final results = await Future.wait([
        _authService.getProfile(),
        dio.get('/api/history/places').then((r) => r.data).catchError((_) => {'places': []}),
        _authService.getFavorites().catchError((_) => <Map<String, dynamic>>[]),
        _navService.getHistory().catchError((_) => <NavRoute>[]),
      ]);

      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>;
          _recents = List<Map<String, dynamic>>.from(
            (results[1] as Map)['places'] ?? [],
          );
          _favorites = List<Map<String, dynamic>>.from(results[2] as List);
          _routesCount = (results[3] as List).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _editProfile() async {
    final controller = TextEditingController(text: _profile?['name'] ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar perfil'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;
    try {
      await _authService.updateProfile(name: newName);
      if (mounted) {
        setState(() => _profile = {..._profile!, 'name': newName});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteFavorite(String id) async {
    try {
      await _authService.deleteFavorite(id);
      if (mounted) {
        setState(() => _favorites.removeWhere((f) => f['id'] == id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : SafeArea(
                  child: CustomScrollView(
                    slivers: [
                      // ── App Bar ───────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Mi perfil',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                              IconButton(
                                onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                                icon: const Icon(Icons.settings_outlined, color: _gray),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Header card ───────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C4DFF), Color(0xFF6C3EE8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 56, height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person, color: Colors.white, size: 30),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _profile!['name'] ?? 'Usuario',
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _profile!['email'] ?? '',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _profile!['badge'] ?? 'Explorer',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _editProfile,
                                  icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Stats ─────────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            children: [
                              _statCard('$_routesCount', 'Rutas'),
                              const SizedBox(width: 12),
                              _statCard('${_favorites.length}', 'Favoritos'),
                              const SizedBox(width: 12),
                              _statCard('0.0km', 'Avg.'),
                            ],
                          ),
                        ),
                      ),

                      // ── Recientes ─────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Recientes',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/search'),
                                child: const Text('Ver todo',
                                  style: TextStyle(color: _purple, fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: _recents.isEmpty
                            ? _emptyState(Icons.history, 'Aún no has visitado ningún lugar', 'Buscá un destino para empezar')
                            : Column(
                                children: _recents.take(3).map((p) => _recentItem(p)).toList(),
                              ),
                      ),

                      // ── Favoritos ─────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Favoritos',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/search'),
                                child: const Text('+ Añadir',
                                  style: TextStyle(color: _purple, fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: _favorites.isEmpty
                            ? _emptyState(Icons.favorite_border, 'Aún no tenés favoritos', 'Guardá tus lugares frecuentes aquí')
                            : Column(
                                children: _favorites.map((f) => _favoriteItem(f)).toList(),
                              ),
                      ),

                      // ── Historial de rutas ────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Historial de rutas',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, AppRoutes.navigationHistory),
                                child: const Text('Ver todo',
                                  style: TextStyle(color: _purple, fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: _routesCount == 0
                            ? _emptyState(Icons.route_outlined, 'Todavía no navegaste ninguna ruta', 'Elegí un destino y comenzá a caminar')
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                                child: Text('$_routesCount ruta${_routesCount == 1 ? '' : 's'} en tu historial',
                                  style: const TextStyle(fontSize: 12, color: _gray)),
                              ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),

      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Widgets helpers ──────────────────────────────────────────────

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _lightGray,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: _gray, size: 36),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: _gray), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: _lightGray, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: _gray)),
          ],
        ),
      ),
    );
  }

  Widget _recentItem(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: _lightPurple, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.place, color: _purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                Text(item['address'] ?? '', style: const TextStyle(fontSize: 12, color: _gray), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(item['time_ago'] ?? '', style: const TextStyle(fontSize: 11, color: _gray)),
        ],
      ),
    );
  }

  Widget _favoriteItem(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: _lightGray, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: _lightPurple, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.favorite, color: _purple, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                  Text(item['address'] ?? '', style: const TextStyle(fontSize: 12, color: _gray)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _deleteFavorite(item['id'] as String),
              icon: const Icon(Icons.delete_outline, color: _gray, size: 20),
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
            _navItem(Icons.search_outlined, 'Buscar', false, () => Navigator.pushNamed(context, '/search')),
            _navItem(Icons.near_me_outlined, 'Navegar', false, () => Navigator.pushNamed(context, '/navigation')),
            _navItem(Icons.person, 'Perfil', true, () {}),
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
}