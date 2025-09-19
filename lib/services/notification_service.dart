import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:outlet_app/constants.dart';
import 'package:outlet_app/data/models/order_model.dart';
import 'package:outlet_app/ui/widgets/order_detail_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';
//import 'package:assets_audio_player/assets_audio_player.dart';
import '../providers/dashboard_refresh_provider.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static const MethodChannel _channel = MethodChannel('com.chaimates/native');

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final ProviderContainer container;
  final player = AudioPlayer();

  NotificationService(this.container);

  static Future<void> launchOrderAlertActivity(Map<String, dynamic> orderData) async {
    try {
      print("dkC: 🚀 Trying to launch native activity...");
      await _channel.invokeMethod('launchOrderAlert', {
        'order': jsonEncode(orderData), // Ensure string is sent, not Map
      });
      print("dkC: ✅ Native activity launched");
    } catch (e, stack) {
      print("dkC: ❌ Error launching native activity: $e\n$stack");
    }
  }

  Future<void> init() async {
    await FirebaseMessaging.instance.requestPermission();
    await _registerFCMToken();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleNewOrderNotification(message);
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _sendTokenToBackend(newToken);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // App brought to foreground by tapping the notification
      _handleNewOrderNotification(message); // Your custom logic
    });

    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNewOrderNotification(initialMessage); // App launched from terminated state
    }
  }

  Future<void> _registerFCMToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _sendTokenToBackend(token);
  }

  

  Future<void> _sendTokenToBackend(String token) async {
    dynamic response;
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString("auth_token");

      if (authToken == null) return;

      response = await http.post(
        Uri.parse('$BASE_URL/api/update-fcm-token/'),
        headers: {
          'Authorization': 'Token $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcm_token': token}),
      );
    } catch (e) {
      debugPrint("Failed to send FCM token: $e");
    }
  }

  void _handleNewOrderNotification(RemoteMessage message) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final orderJsonString = message.data['order'];
      if (orderJsonString == null) return;

      final orderMap = jsonDecode(orderJsonString);
      final order = OrderModel.fromJson(orderMap);

      //await NotificationService.launchOrderAlertActivity(orderMap);
      //_playSound();
      
      // // Wake screen and play sound
       WakelockPlus.enable();
       _playSound();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => OrderDetailDialog(order: order),
      );

      _stopSound();
      WakelockPlus.disable();
    } catch (e) {
      debugPrint("❌ Failed to show order dialog: $e");
    }

    container.read(dashboardRefreshProvider.notifier).state = true;
  }

  void _playSound() async {
    // With audioplayers >=6, AssetSource expects path relative to your pubspec assets root (no leading 'assets/')
    await player.play(AssetSource('sounds/order-alert-1.mp3'));

    // _audioPlayer.open(
    //   Audio("assets/sounds/order-alert-1.mp3"),
    //   loopMode: LoopMode.single,
    //   autoStart: true,
    // );
  }

  void _stopSound() async {
    await player.stop();
  }

  static Future<void> clearTokenFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString("auth_token");

      if (authToken == null) return;

      await http.post(
        Uri.parse('http://127.0.0.1:8000/api/update-fcm-token/'),
        headers: {
          'Authorization': 'Token $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcm_token': null}),
      );
    } catch (e) {
      debugPrint("❌ Failed to clear FCM token: $e");
    }
  }
}
