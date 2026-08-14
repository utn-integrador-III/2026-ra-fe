import 'package:flutter/material.dart';
import '../../../core/services/navigation_service.dart';
import '../../navigation/models/route_models.dart';

class NavigationHistoryScreen extends StatefulWidget {
  const NavigationHistoryScreen({super.key});

  @override
  State<NavigationHistoryScreen> createState() => _NavigationHistoryScreenState();
}

class _NavigationHistoryScreenState extends State<NavigationHistoryScreen> {
  final _navService = NavigationService();

  static const Color _purple = Color(0xFF6C3EE8);
  static const Color _lightPurple = Color(0xFFF0EDFB);
  static const Color _gray = Color(0xFF6B7280);
  static const Color _lightGray = Color(0xFFF9F9F9);

  bool _isLoading = true;
  String? _error;
  List<NavRoute> _routes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final routes = await _navService.getHistory();
      if (mounted) setState(() { _routes = routes; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active': return 'En curso';
      case 'finished': return 'Finalizada';
      case 'cancelled': return 'Cancelada';
      default: return 'Calculada';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return const Color(0xFF3B82F6);
      case 'finished': return const Color(0xFF22C55E);
      case 'cancelled': return const Color(0xFFEF4444);
      default: return _gray;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text('Historial de rutas'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _routes.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Todavía no navegaste ninguna ruta', style: TextStyle(color: _gray)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _routes.length,
                      itemBuilder: (context, i) => _routeItem(_routes[i]),
                    ),
    );
  }

  Widget _routeItem(NavRoute route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _lightGray, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: _lightPurple, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.route, color: _purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.destinationName ?? 'Destino sin nombre',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 2),
                Text(_formatDate(route.createdAt), style: const TextStyle(fontSize: 11, color: _gray)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(route.distanceText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              const SizedBox(height: 2),
              Text(
                _statusLabel(route.status),
                style: TextStyle(fontSize: 11, color: _statusColor(route.status), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
