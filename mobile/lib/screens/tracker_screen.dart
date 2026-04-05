import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:io';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  String _deviceId = "Cargando...";
  bool _isTracking = false;
  double _currentSpeed = 0.0;
  String _statusMessage = "Iniciando sistema seguro...";
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _getDeviceInfo();
    _enforcePermissionsAndStart();
  }

  Future<void> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    String id = "Unknown";
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        id = androidInfo.id;
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

  Future<void> _enforcePermissionsAndStart() async {
    setState(() => _statusMessage = "Verificando permisos críticos...");

    // 1. Notificaciones (Obligatorio Android 13+ para el Foreground Service)
    if (Platform.isAndroid) {
      var notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }
    }

    // 2. Batería (Ignorar Ahorro de Batería - MUY IMPORTANTE)
    if (Platform.isAndroid) {
      var batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        // Pedir directamente al OS que saque a esta app del ahorro de batería
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    // 3. GPS Básico
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _statusMessage = "Por favor, enciende el GPS del celular.");
      return;
    }

    // 4. GPS Mientras se usa
    var statusWhenInUse = await Permission.locationWhenInUse.status;
    if (!statusWhenInUse.isGranted) {
      statusWhenInUse = await Permission.locationWhenInUse.request();
    }

    // 5. GPS SIEMPRE (Crucial para rastreo bloqueado)
    if (statusWhenInUse.isGranted) {
      var statusAlways = await Permission.locationAlways.status;
      if (!statusAlways.isGranted) {
        // Mostramos un diálogo pidiendo que manualmente ponga "Permitir todo el tiempo" si Android lo oculta
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("⚠️ Permiso Requerido"),
            content: const Text("Para que tu seguridad no se interrumpa al apagar la pantalla, debes seleccionar 'Permitir todo el tiempo' en la siguiente pantalla."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text("ENTENDIDO")
              )
            ],
          )
        );
        await Permission.locationAlways.request();
      }
    }

    setState(() {
      _permissionsGranted = true;
      _statusMessage = "Encendiendo motor de rastreo...";
    });

    _startBackgroundTracker();
  }

  void _startBackgroundTracker() async {
    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      await service.startService();
    }

    setState(() {
      _isTracking = true;
      _statusMessage = "Rastreo activo. Puedes cerrar la app.";
    });

    // Escuchar el latido interno del servicio de fondo para mostrar velocidad visualmente
    service.on('update').listen((event) {
      if (event == null) return;
      double speed = (event['speed'] as num?)?.toDouble() ?? 0.0;
      if (mounted) {
        setState(() {
          _currentSpeed = speed * 3.6; // m/s a km/h
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F17), // Negro azulado para batería
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 80, color: Colors.indigoAccent),
                const SizedBox(height: 20),
                const Text("GEOFENCER PRO", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 10),
                Text("ID: $_deviceId", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                
                const SizedBox(height: 60),

                // Gran indicador Visual
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isTracking ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    border: Border.all(color: _isTracking ? Colors.greenAccent : Colors.redAccent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _isTracking ? Colors.greenAccent.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5
                      )
                    ]
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isTracking ? Icons.satellite_alt : Icons.portable_wifi_off, 
                          color: _isTracking ? Colors.greenAccent : Colors.redAccent, 
                          size: 60
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isTracking ? "ONLINE" : "OFFLINE", 
                          style: TextStyle(color: _isTracking ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 22)
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                if (_isTracking) ...[
                  Text("${_currentSpeed.toStringAsFixed(1)} km/h", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Text("Velocidad Actual", style: TextStyle(color: Colors.white54)),
                ] else ...[
                  const CircularProgressIndicator(color: Colors.indigoAccent),
                ],
                
                const SizedBox(height: 40),
                Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),

                const Spacer(),
                const Text("ESTE DISPOSITIVO ESTÁ SIENDO MONITOREADO", style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
