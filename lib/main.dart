import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'services/signalr_service.dart';
import 'providers/auth_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/soporte_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/service_alert_screen.dart';
import 'screens/service_status_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/vehicle_screen.dart';
import 'screens/history_screen.dart';
import 'screens/trip_detail_screen.dart';
import 'screens/earnings_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/report_incident_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/support_chat_screen.dart';

void main() {
  final signalr = SignalRService();
  runApp(
    MultiProvider(
      providers: [
        Provider<SignalRService>.value(value: signalr),
        ChangeNotifierProvider(create: (_) => AuthProvider(signalr)),
        ChangeNotifierProvider(create: (_) => RideProvider(signalr)),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider(signalr)),
        ChangeNotifierProxyProvider<AuthProvider, SoporteProvider>(
          create: (ctx) => SoporteProvider(signalr, ctx.read<AuthProvider>()),
          update: (_, auth, prev) => prev!..updateAuth(auth),
        ),
      ],
      child: const VaiaViajesApp(),
    ),
  );
}

class VaiaViajesApp extends StatelessWidget {
  const VaiaViajesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vaia Viajes Conductor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        Widget page;
        final args = settings.arguments is Map ? settings.arguments as Map : <String, dynamic>{};
        switch (settings.name) {
          case '/splash':
            page = const SplashScreen();
          case '/login':
            page = const LoginScreen();
          case '/register':
            page = const RegisterScreen();
          case '/home':
            page = const HomeScreen();
          case '/service_alert':
            page = const ServiceAlertScreen();
          case '/service_status':
            page = const ServiceStatusScreen();
          case '/profile':
            page = const ProfileScreen();
          case '/vehicle':
            page = const VehicleScreen();
          case '/history':
            page = const HistoryScreen();
          case '/trip_detail':
            page = const TripDetailScreen();
          case '/earnings':
            page = const EarningsScreen();
          case '/settings':
            page = const SettingsScreen();
          case '/chat':
            page = const ChatScreen();
          case '/notifications':
            page = const NotificationsScreen();
          case '/report_incident':
            page = const ReportIncidentScreen();
          case '/rating':
            page = const RatingScreen();
          case '/support_chat':
            page = SupportChatScreen(
              idServicio: args['idServicio'] ?? 0,
              idSolicitudExistente: args['idSolicitudExistente'],
            );
          default:
            page = const SplashScreen();
        }
        return MaterialPageRoute(builder: (_) => page, settings: settings);
      },
    );
  }
}