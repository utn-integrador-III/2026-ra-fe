import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();

  static const Color _purple = Color(0xFF6C3EE8);
  static const Color _lightPurple = Color(0xFFF0EDFB);
  static const Color _gray = Color(0xFF6B7280);
  static const Color _lightGray = Color(0xFFF9F9F9);

  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  // Datos simulados hasta que el backend tenga las tablas
  final List<Map<String, dynamic>> _recents = [
    {'icon': Icons.business, 'name': 'Oficina Central', 'address': 'Av. Reforma 350', 'time': 'Hace 2h'},
    {'icon': Icons.local_cafe, 'name': 'Café Moro', 'address': 'Calle Madero 12', 'time': 'Ayer'},
    {'icon': Icons.shopping_bag, 'name': 'Centro Comercial', 'address': 'Plaza Mayor', 'time': 'Hace 3d'},
  ];

  final List<Map<String, dynamic>> _favorites = [
    {'icon': Icons.home, 'name': 'Casa', 'address': 'Calle Flores 27'},
    {'icon': Icons.work, 'name': 'Trabajo', 'address': 'Av. Reforma 350'},
    {'icon': Icons.favorite, 'name': 'Gym', 'address': 'Bvd. Artetas 5'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _authService.getProfile();
      if (mounted) setState(() { _profile = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
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
                              const Text(
                                'Mi perfil',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              IconButton(
                                onPressed: () {},
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
                                  width: 56,
                                  height: 56,
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
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _profile!['email'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
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
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
                              _statCard('${_profile!['stats']?['routes'] ?? 0}', 'Rutas'),
                              const SizedBox(width: 12),
                              _statCard('${_profile!['stats']?['favorites'] ?? 0}', 'Favoritos'),
                              const SizedBox(width: 12),
                              _statCard('${_profile!['stats']?['avg_km'] ?? 0}km', 'Avg.'),
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
                                onTap: () {},
                                child: const Text('Ver todo',
                                  style: TextStyle(color: _purple, fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _recentItem(_recents[index]),
                          childCount: _recents.length,
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
                                onTap: () {},
                                child: const Text('+ Añadir',
                                  style: TextStyle(color: _purple, fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _favoriteItem(_favorites[index]),
                          childCount: _favorites.length,
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),

      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _lightGray,
          borderRadius: BorderRadius.circular(14),
        ),
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
            child: Icon(item['icon'] as IconData, color: _purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                Text(item['address'], style: const TextStyle(fontSize: 12, color: _gray)),
              ],
            ),
          ),
          Text(item['time'], style: const TextStyle(fontSize: 11, color: _gray)),
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
              child: Icon(item['icon'] as IconData, color: _purple, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                  Text(item['address'], style: const TextStyle(fontSize: 12, color: _gray)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _gray, size: 20),
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
              _navItem(Icons.home_outlined, 'Inicio', false),
              _navItem(Icons.search_outlined, 'Buscar', false),
              _navItem(Icons.near_me_outlined, 'Navegar', false),
              _navItem(Icons.person, 'Perfil', true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    return GestureDetector(
      onTap: () {},
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