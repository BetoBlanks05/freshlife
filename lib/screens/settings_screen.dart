import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

const _kTeal = Color(0xFF4DB6AC);
const _kDark = Color(0xFF263238);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Ajustes',
          style: TextStyle(
              color: _kDark, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        children: [
          // Tarjeta de perfil
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  // FIX: withOpacity → withValues(alpha:)
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _kTeal.withValues(alpha: 0.15),
                  child: const Icon(Icons.person,
                      color: _kTeal, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mi Cuenta',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? 'usuario@email.com',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _Tile(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
            subtitle: 'Alertas de stock bajo',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.palette_outlined,
            title: 'Apariencia',
            subtitle: 'Tema de la aplicación',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacidad',
            subtitle: 'Gestión de datos',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.help_outline,
            title: 'Ayuda y Soporte',
            subtitle: 'FAQ y contacto',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.info_outline,
            title: 'Acerca de FreshLife',
            subtitle: 'Versión 1.0.0',
            onTap: () {},
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            child: ElevatedButton.icon(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar Sesión'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // FIX: método separado para evitar context tras async gap
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: _kTeal, size: 24),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style:
                const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing:
            const Icon(Icons.chevron_right, color: Colors.grey),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
      ),
    );
  }
}
