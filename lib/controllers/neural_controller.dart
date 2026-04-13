import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import '../services/esp_service.dart';
import 'dart:async'; 
import 'package:http/http.dart' as http; 
import 'dart:convert'; 

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
  bool isDarkMode = true; 

  Timer? _liveTimer; 
  final String firebaseDbUrl = "https://tracker-gate-default-rtdb.firebaseio.com/";
  
  // 📍 Status check karne ke liye variable
  bool isTrackingActive = false; 

  String locationMode = "current"; 
  int liveDuration = 30; 

  NeuralController(this._service) {
    loadSettings(); 
    
    _service.signalStream.listen((value) {
      isConnected = true;
      points.add(value);
      if (points.length > 150) points.removeAt(0);

      double highestInView = points.isNotEmpty ? points.reduce((a, b) => a > b ? a : b) : 100.0;
      double targetMax = (highestInView > threshold ? highestInView : threshold) * 1.2;
      _graphMax = (_graphMax * 0.9) + (targetMax * 0.1);

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

  void loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    locationMode = prefs.getString('location_mode') ?? "current";
    liveDuration = prefs.getInt('live_duration') ?? 30;
    notifyListeners();
  }

  void toggleTheme(bool value) async {
    isDarkMode = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    notifyListeners(); 
  }

  void setLocationMode(String mode) async {
    locationMode = mode;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('location_mode', mode);
    notifyListeners();
  }

  void setLiveDuration(int mins) async {
    liveDuration = mins;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('live_duration', mins);
    notifyListeners();
  }

  // 🚀 SOS Function
  void sendSOS() async {
    print("🚀 SOS Triggered! Location Mode: $locationMode");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> contacts = prefs.getStringList('emergency_contacts') ?? [];
    
    String? savedMessage = prefs.getString('sos_message');
    String baseMessage = (savedMessage == null || savedMessage.trim().isEmpty) 
        ? "Emergency! Brain signal threshold exceeded. [Neural Gate]" 
        : savedMessage;

    String finalMessage = baseMessage;

    if (locationMode != "off") {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        
        if (locationMode == "current") {
          String mapLink = "https://www.google.com/maps?q=${position.latitude},${position.longitude}";
          finalMessage = "$baseMessage \n\nMy Location: $mapLink";
        } 
        else if (locationMode == "live") {
          String liveLink = "neural-traker.netlify.app"; 
          finalMessage = "$baseMessage \n\n[LIVE TRACKING] $liveDuration min: $liveLink";
          
          // 🔥 Yahan se Live Tracking engine start hoga
          startLiveTracking(); 
        }
      }
    }

    final Telephony telephony = Telephony.instance;
    String defaultNumber = "+916267364421"; 

    if (contacts.isEmpty) {
      telephony.sendSms(to: defaultNumber, message: finalMessage);
    } else {
      for (String number in contacts) {
        telephony.sendSms(to: number, message: finalMessage);
      }
    }
  }

  // 📡 Background Tracking Logic
  void startLiveTracking() {
    if (isTrackingActive) return; // Pehle se chal raha ho toh dubara mat chalao

    isTrackingActive = true;
    notifyListeners(); // UI ko batayega ki STOP button dikhao

    print("⏳ Starting $liveDuration min Live Tracking to Firebase...");

    _liveTimer?.cancel();
    int maxTicks = (liveDuration * 60) ~/ 5; 
    int currentTicks = 0;

    _liveTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      currentTicks++;

      if (currentTicks > maxTicks) {
        stopLiveTracking();
        return;
      }

      try {
        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        Map<String, dynamic> locationData = {
          "lat": pos.latitude,
          "lng": pos.longitude,
          "timestamp": DateTime.now().toIso8601String(),
          "status": "🚨 ACTIVE EMERGENCY"
        };

        String targetUrl = "${firebaseDbUrl}users/target_1/location.json";
        await http.patch(Uri.parse(targetUrl), body: json.encode(locationData));
        print("📡 Location Sent: ${pos.latitude}, ${pos.longitude}");
      } catch (e) {
        print("🚫 Firebase Error: $e");
      }
    });
  }

  void stopLiveTracking() async {
    isTrackingActive = false;
    _liveTimer?.cancel();
    notifyListeners(); // UI ko batayega ki STOP button chhupa do

    print("🛑 Live Tracking Stopped!");
    try {
      String targetUrl = "${firebaseDbUrl}users/target_1/location.json";
      await http.patch(Uri.parse(targetUrl), body: json.encode({"status": "✅ SAFE (Tracking Stopped)"}));
    } catch (e) {}
  }

  @override
  void dispose() {
    _service.dispose();
    _liveTimer?.cancel();
    super.dispose();
  }
}