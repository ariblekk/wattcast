import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:provider/provider.dart';

import 'providers/watt_provider.dart';
import 'screens/dashboard_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Konten menggambar penuh sampai belakang status bar/navigation bar
  // (gradient masthead benar-benar tembus, bukan latar sistem putih).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await NotificationService.instance.init();
  runApp(const WattCastApp());
}

class WattCastApp extends StatelessWidget {
  const WattCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WattProvider>(
      create: (_) => WattProvider()..init(),
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WattCast',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const DashboardScreen(),
    );
  }
}