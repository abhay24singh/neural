import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'neuralgate_vip_channel', 
    'NeuralGate Security', 
    description: 'Keeps the SOS listener alive 24/7', 
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartService, 
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'neuralgate_vip_channel',
      initialNotificationTitle: '🛡️ NeuralGate Active',
      initialNotificationContent: 'Monitoring for remote SOS requests...',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location], 
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStartService),
  );
}

@pragma('vm:entry-point')
void onStartService(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  print("🛡️ VIP SHIELD ACTIVE! Keeping the phone awake...");
  // It does nothing else! Just keeps the memory alive.
}