import 'package:flutter/material.dart';
import 'package:geofence_app/screens/map_screen.dart';
import 'package:geofence_app/screens/admin_dashboard_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.indigoAccent),
              const SizedBox(height: 20),
              const Text(
                'GEOFENCER PRO',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Seleccione su modo de acceso',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 60),
              
              // Botón Administrador
              _buildModernButton(
                icon: Icons.admin_panel_settings,
                title: 'Entrar como Administrador',
                subtitle: 'Ver mapa global y gestionar',
                color: Colors.indigo,
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
                },
              ),
              
              const SizedBox(height: 20),
              
              // Botón Usuario/Vehículo
              _buildModernButton(
                icon: Icons.directions_car,
                title: 'Entrar como Vehículo',
                subtitle: 'Activar rastreador GPS',
                color: Colors.teal,
                onTap: () async {
                  // Solicitar permisos básicos antes de ir a MapScreen
                  await Permission.locationWhenInUse.request();
                  if (context.mounted) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MapScreen()));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernButton({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
