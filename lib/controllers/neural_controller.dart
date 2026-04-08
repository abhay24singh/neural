 import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/esp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:telephony/telephony.dart';

class NeuralController extends ChangeNotifier {
  final EspService _service;

  List<double> points = [];
  double threshold = 100.0;
  double _graphMax = 250.0; 
  String activeMode = "relay";
  bool isConnected = false;
  double userThreshold = 100.0; 
  double _espThreshold = 100.0; 
  int lastTriggerMs = 0;
  
  // Theme ka variable
  bool isDarkMode = true; 

  static const String smsBackendUrl = "https://your-backend-url.com/send-sms"; 

  NeuralController(this._service) {
    // Theme load karne ki line
    loadTheme();
    
    _service.signalStream.listen((value) {
      isConnected = true;
      points.add(value);
      if (points.length > 150) points.removeAt(0);

      // --- ADAPTIVE AUTO THRESHOLD ADJUST ---
      double highestInView =
          points.isNotEmpty ? points.reduce((a, b) => a > b ? a : b) : 100.0;

      double targetMax =
          (highestInView > threshold ? highestInView : threshold) * 1.2;

      _graphMax = (_graphMax * 0.9) + (targetMax * 0.1);

      // Spike detection for SOS mode
      if (activeMode == "sos" && value > userThreshold) {
        int now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastTriggerMs > 3000) {
          sendSOS();
          lastTriggerMs = now;
        }
      }

      notifyListeners();
    }, onError: (_) {
      isConnected = false;
      notifyListeners();
    });
  }

  double get graphMax => _graphMax < 100 ? 100 : _graphMax;

  void setThreshold(double val) {
    threshold = val;
    userThreshold = val;

    if (activeMode != "sos") {
      _espThreshold = val;
      _service.sendCommand("/setTh?v=${_espThreshold.toInt()}");
    }

    notifyListeners();
  }

  void setMode(String mode) {
    activeMode = mode;

    if (mode == "sos") {
      _espThreshold = 10000.0;
      sendSOS(); 
    } else {
      _espThreshold = userThreshold;
      _service.sendCommand("/setTarget?t=$mode");
    }

    _service.sendCommand("/setTh?v=${_espThreshold.toInt()}");
    notifyListeners();
  }

  void triggerManual() {
    if (activeMode == "sos") {
      sendSOS();
    } else {
      _service.sendCommand("/manual");
    }
  }

  void sendSOS() async {
    print("Direct Background SOS Triggered!");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> contacts = prefs.getStringList('emergency_contacts') ?? [];
    String message = prefs.getString('sos_message') ?? "SOS Alert from Neural Gate";

    if (contacts.isEmpty) {
      print("🚨 Error: Settings mein koi number save nahi hai!");
      return; 
    }

    final Telephony telephony = Telephony.instance;
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted != null && permissionsGranted) {
      print("✅ Permission mil gayi! Background mein SMS bhej raha hoon...");
      
      for (String number in contacts) {
        // 👇 YAHAN SE HUMNE STATUS LISTENER HATA DIYA HAI 👇
        telephony.sendSms(
          to: number,
          message: message,
        );
        print("🚀 SMS sent to $number (Check recipient's phone!)");
      }
    } else {
      print("🚫 Error: User ne SMS bhejne ki permission nahi di!");
    }
  }

  // App start hote hi saved theme load karne ke liye
  void loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    notifyListeners();
  }

  // Naya theme set karne aur save karne ke liye
  void toggleTheme(bool value) async {
    isDarkMode = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    notifyListeners(); 
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}