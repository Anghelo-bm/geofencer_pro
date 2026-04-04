import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geofence_app/services/api_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:io';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Position? _currentPosition;
  String _deviceId = "Cargando...";
  bool _isAuthorized = true; // Por ahora autorizado por defecto para la prueba
  final MapController _mapController = MapController();
  bool _hasCenteredInitially = false;

  @override
  void initState() {
    super.initState();
    _getDeviceInfo();
    _getCurrentLocation();
  }

  Future<void> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    String id = "Unknown";
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        id = androidInfo.id; // ID único de hardware
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        id = iosInfo.identifierForVendor ?? "Unknown";
      }
    } catch (e) {
      id = "Error: $e";
    }
    setState(() {
      _deviceId = id;
    });
  }

  void _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // Solicitar permiso de notificaciones (requerido para foreground service en Android 13+)
    if (Platform.isAndroid) {
      var notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }
    }

    // Solicitar permiso estricto para rastreo de fondo en ambas plataformas
    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      status = await Permission.locationWhenInUse.request();
    }
    
    if (status.isGranted) {
      var alwaysStatus = await Permission.locationAlways.status;
      if (!alwaysStatus.isGranted) {
        await Permission.locationAlways.request();
      }
    }

    // Asegurarse de que el servicio Foreground se encienda
    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      service.startService();
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2, // Actualizar cada 2 metros
      )
    ).listen((Position pos) {
      setState(() {
        _currentPosition = pos;
      });
      
      if (!_hasCenteredInitially && _currentPosition != null) {
        _centerMapOnUser();
        _hasCenteredInitially = true;
      }
      
      // Enviar al servidor Docker en tiempo real
      ApiService().sendLocation(
        pos.latitude, 
        pos.longitude, 
        pos.speed, 
        pos.accuracy, 
        _deviceId
      );
    });
  }
  
  void _centerMapOnUser() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 
        16.5 // Zoom ideal para ver calles de cerca
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return const Scaffold(
        backgroundColor: Color(0xFF12121E),
        body: Center(
          child: Text("DISPOSITIVO NO AUTORIZADO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('GEOFENCER PRO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerMapOnUser,
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.person)),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(4.711, -74.072), // Posición por defecto (Bogotá)
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      width: 80,
                      height: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.indigo.withOpacity(0.3),
                          border: Border.all(color: Colors.indigoAccent, width: 2),
                        ),
                        child: const Icon(Icons.navigation, color: Colors.white, size: 30),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Glassmorphic Overlay (Dashboard)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E).withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_currentPosition == null) ...[
                        const SizedBox(
                           height: 20,
                           width: 20,
                           child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                        ),
                        const SizedBox(width: 10),
                        const Text("CALIBRANDO GPS...", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ] else ...[
                        const Icon(Icons.satellite_alt, color: Colors.greenAccent, size: 20),
                        const SizedBox(width: 10),
                        const Text("CONEXIÓN ESTABLECIDA", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ]
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _infoItem(Icons.verified_user, "Sistema OK", Colors.green),
                      _infoItem(Icons.developer_board, "ID: ${_deviceId.substring(0, _deviceId.length > 8 ? 8 : _deviceId.length)}", Colors.blue),
                      _infoItem(Icons.speed, _currentPosition != null ? "${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h" : "0.0 km/h", Colors.orange),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  const Text("SISTEMA EXCLUSIVO Y SEGURO", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 140.0), // Elevarlo para no pisar el dashboard
        child: FloatingActionButton(
          onPressed: _centerMapOnUser,
          backgroundColor: Colors.indigo,
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
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
