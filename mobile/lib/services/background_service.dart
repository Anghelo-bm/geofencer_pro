import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
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

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Temporizador para leer GPS cada 10 segundos
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) {
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation);

      // Usar ApiService existente para enviar la ubicación real a la Web
      await apiService.sendLocation(
        position.latitude,
        position.longitude,
        position.speed,
        position.accuracy,
        'HONORANY-REAL', // Dispositivo Real para diferenciar del simulador
      );

      print("✅ Ubicación enviada en segundo plano: \${position.latitude}, \${position.longitude}");
      
      service.invoke(
        'update',
        {
          "lat": position.latitude,
          "lon": position.longitude,
        },
      );
    } catch (e) {
      print("❌ Error en GPS de fondo: \$e");
    }
  });
}
