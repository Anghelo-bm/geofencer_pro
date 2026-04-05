import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:geofence_app/services/api_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'geofence_foreground', // id
    'Ubicación en Segundo Plano', // título
    description: 'Este canal es para notificar que el GPS está activo', // descripción
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'geofence_foreground',
      initialNotificationTitle: 'GEOFENCER Activo',
      initialNotificationContent: 'Consultando GPS en segundo plano...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final apiService = ApiService();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  String deviceId = "Unknown-Bg";
  try {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? "Unknown-Bg";
    }
  } catch (e) {
    print("Error getting device ID in background: $e");
  }

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService(); // Asegurar foreground inmediatamente
  }

  Geolocator.getPositionStream(
    locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5, // Cada 5 metros, excelente balance en vivo/batería
      forceLocationManager: true, // Crucial para Huawei/Honor
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "Rastreo optimizado en segundo plano",
        notificationTitle: "Geofencer Profesional",
        enableWakeLock: true, // WakeLock controlado para no dormirse
        setOngoing: true,
      ),
    ),
  ).listen((Position position) async {
    // FILTRO PROFESIONAL DE SALTOS (JUMPS): 
    // Si la precisión es muy mala (> 20 metros de margen de error), lo ignoramos para evitar falsas salidas de geocerca.
    if (position.accuracy > 20.0) return;
    try {
      await apiService.sendLocation(
        position.latitude,
        position.longitude,
        position.speed,
        position.accuracy,
        deviceId, // Uso del ID real en segundo plano
      );
      print("✅ GPS Background Activado: ${position.latitude}, ${position.longitude} (Stream fluid)");
      
      service.invoke('update', {
        "lat": position.latitude, 
        "lon": position.longitude,
        "speed": position.speed
      });
    } catch (e) {
      print("❌ Error subiendo GPS de fondo (Stream): $e");
    }
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}
