import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/esp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';

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
  print("🚀 SOS with Location Triggered!");

  // 1. Location Permission Check & Request
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      print("🚫 Location permissions are denied");
      return;
    }
  }

  // 2. Current Location nikalna
  Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
  
  // 3. Google Maps Link banana
  String mapLink = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
   
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> contacts = prefs.getStringList('emergency_contacts') ?? [];
  
  // 4. Message mein Link joddna
  String? savedMessage = prefs.getString('sos_message');
  String baseMessage;

  if (savedMessage == null || savedMessage.trim().isEmpty) {
    baseMessage = "Emergency! Brain signal threshold exceeded. [Neural Gate]";
  } else {
    baseMessage = savedMessage;
  }
  String finalMessage = "$baseMessage \n\nMy Location: $mapLink";

  String defaultNumber = "+916267364421"; 
  final Telephony telephony = Telephony.instance;

  // SMS bhejne ka wahi purana logic
  if (contacts.isEmpty) {
    telephony.sendSms(to: defaultNumber, message: finalMessage);
    print("🚀 Default SMS with Location Sent!");
  } else {
    for (String number in contacts) {
      telephony.sendSms(to: number, message: finalMessage);
      print("🚀 SMS with Location sent to $number");
    }
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