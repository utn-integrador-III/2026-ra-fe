import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/routes/app_routes.dart';

class SettingsScreen extends StatefulWidget {
  final AuthService? authService;

  const SettingsScreen({super.key, this.authService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _authService = widget.authService ?? AuthService();

  static const Color _purple = Color(0xFF6C3EE8);
  static const Color _gray = Color(0xFF6B7280);

  bool _isLoading = true;
  bool _voiceGuidanceEnabled = true;
  double _walkingSpeedMps = 1.3;

  static const _speedOptions = {
    'Lento': 1.0,
    'Normal': 1.3,
    'Rápido': 1.6,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await _authService.getPreferences();
      if (mounted) {
        setState(() {
          _voiceGuidanceEnabled = prefs['voice_guidance_enabled'] ?? true;
          _walkingSpeedMps = (prefs['walking_speed_mps'] ?? 1.3).toDouble();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateVoiceGuidance(bool value) async {
    setState(() => _voiceGuidanceEnabled = value);
    try {
      await _authService.updatePreferences(voiceGuidanceEnabled: value);
    } catch (_) {
      if (mounted) setState(() => _voiceGuidanceEnabled = !value);
    }
  }

  Future<void> _updateWalkingSpeed(double value) async {
    setState(() => _walkingSpeedMps = value);
    try {
      await _authService.updatePreferences(walkingSpeedMps: value);
    } catch (_) {}
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que querés cerrar tu sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _authService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text('Preferencias'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SwitchListTile(
                  activeThumbColor: _purple,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Instrucciones por voz'),
                  subtitle: const Text('Avisos hablados durante la navegación', style: TextStyle(color: _gray, fontSize: 12)),
                  value: _voiceGuidanceEnabled,
                  onChanged: _updateVoiceGuidance,
                ),
                const SizedBox(height: 20),
                const Text('Velocidad al caminar', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: _speedOptions.entries.map((entry) {
                    final selected = _walkingSpeedMps == entry.value;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.key),
                          selected: selected,
                          selectedColor: _purple,
                          labelStyle: TextStyle(color: selected ? Colors.white : const Color(0xFF1F2937)),
                          onSelected: (_) => _updateWalkingSpeed(entry.value),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
