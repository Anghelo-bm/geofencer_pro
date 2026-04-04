import 'package:flutter/material.dart';
import 'package:geofence_app/screens/login_screen.dart';
import 'package:geofence_app/screens/map_screen.dart';
import 'package:geofence_app/services/background_service.dart';
import 'package:provider/provider.dart';
import 'package:geofence_app/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeBackgroundService();
  
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: const GeofenceApp(),
    ),
  );
}

class GeofenceApp extends StatelessWidget {
  const GeofenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geofence Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF12121E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E2E),
          elevation: 0,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
