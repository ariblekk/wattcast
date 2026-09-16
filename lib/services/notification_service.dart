import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Layanan notifikasi lokal untuk peringatan sisa kWh menipis.
///
/// Aktif penuh di Android / iOS. Di web & desktop hanya no-op
/// (API browser tidak didukung oleh plugin).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _lowBalanceId = 7001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (kIsWeb) return;

    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwin = DarwinInitializationSettings();
    const LinuxInitializationSettings linux = LinuxInitializationSettings(
      defaultActionName: 'Buka WattCast',
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;

    // Izin notifikasi (Android 13+).
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Menampilkan notifikasi peringatan saldo rendah.
  Future<void> showLowBalanceNotification({
    required int meterId,
    required double remainingKwh,
    required double daysLeft,
    String? meterName,
  }) async {
    if (kIsWeb || !_initialized) return;

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'wattcast_low_balance',
        'Sisa Token Menipis',
        channelDescription: 'Peringatan saat estimasi sisa kWh token menipis',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final String body = meterName != null
        ? '$meterName: sisa ${remainingKwh.toStringAsFixed(1)} kWh, '
            'diperkirakan habis dalam ${daysLeft.toStringAsFixed(0)} hari. '
            'Segera isi token.'
        : 'Sisa ${remainingKwh.toStringAsFixed(1)} kWh, diperkirakan habis '
            'dalam ${daysLeft.toStringAsFixed(0)} hari. Segera isi token.';

    await _plugin.show(
      id: _lowBalanceId + meterId,
      title: 'Sisa kWh Token Menipis',
      body: body,
      notificationDetails: details,
    );
  }
}