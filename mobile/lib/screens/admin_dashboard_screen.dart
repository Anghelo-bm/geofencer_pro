import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geofence_app/screens/login_screen.dart';
import 'package:geofence_app/services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final MapController _mapController = MapController();
  List<dynamic> _activeUsers = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchUsersLocation();
    // Simular recepción de datos o polleo cada 5 segundos
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchUsersLocation());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _fetchUsersLocation() async {
    // Al migrar a la nube real, esto consumirá un endpoint que devuelve TODOS los usuarios
    final apiService = ApiService();
    var locations = await apiService.getGlobalLocations();
    
    if (mounted) {
      setState(() {
        _activeUsers = locations;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('ADMIN - GEOFENCER PRO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.orange)),
        elevation: 0,
        backgroundColor: Colors.black54,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(4.711, -74.072), // Centro
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              MarkerLayer(
                markers: _activeUsers.map((user) {
                  return Marker(
                    point: LatLng(user['lat'], user['lon']),
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.location_on, color: Colors.orange, size: 40),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E).withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.orange, size: 24),
                      SizedBox(width: 10),
                      Text("PANEL GLOBAL DE ADMINISTRACIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _infoItem(Icons.people, "Usuarios Activos: ${_activeUsers.length}", Colors.blue),
                      _infoItem(Icons.warning, "Alertas Zonas: 0", Colors.redAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String text, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
