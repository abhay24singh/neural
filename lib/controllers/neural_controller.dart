import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import '../services/esp_service.dart';
import 'dart:async'; 

// 🔥 1. BACKGROUND SMS HANDLER (App kill hone par chalega)
@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isEnabled = prefs.getBool('remote_request_enabled') ?? true;
  if (!isEnabled) return;

  String body = message.body?.toLowerCase().trim() ?? "";
  String? sender = message.address;

  if (body == "current location" && sender != null) {
    List<String> contacts = prefs.getStringList('emergency_contacts') ?? [];
    bool isAuthorized = contacts.any((contact) {
      String cleanContact = contact.replaceAll(RegExp(r'\D'), '');
      String cleanSender = sender.replaceAll(RegExp(r'\D'), '');
      return cleanSender.endsWith(cleanContact) || cleanContact.endsWith(cleanSender);
    });

    if (isAuthorized) {
      Position? pos;
      try {
        // Pehle 4 second taaza location nikalne ki koshish (Medium accuracy indoors bhi kaam karti hai)
        pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 4));
      } catch (e) {
        // Agar nahi mili, toh purani location bhej do
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos != null) {
        // 🔥 EKDUM ORIGINAL GOOGLE MAPS LINK FORMAT
        String mapLink = "https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
        Telephony.instance.sendSms(to: sender, message: "NeuralGate Auto-Reply:\nMy current location is $mapLink");
      } else {
        Telephony.instance.sendSms(to: sender, message: "NeuralGate: Unable to fetch GPS.");
      }
    }
  }
}

class NeuralController extends ChangeNotifier {
  final EspService _service;

  // ESP & Graph Variables
  List<double> points = [];
  double threshold = 100.0;
  double _graphMax = 250.0; 
  String activeMode = "relay";
  bool isConnected = false;
  bool isDarkMode = true; 
  int lastTriggerMs = 0;

  // Tracking Settings
  String locationStrategy = "static"; 
  double distanceThreshold = 0.5; 
  bool isRemoteRequestEnabled = true; 
  List<String> emergencyContacts = [];
  
  // Tracking State Variables
  bool isTrackingActive = false; 
  Timer? _trackingTimer; 
  Position? _lastSentPosition;

  NeuralController(this._service) {
    _checkPermissionsOnStart(); 
    _initSmsListener();
    loadSettings(); 
    
    _service.signalStream.listen((value) {
      isConnected = true;
      points.add(value);
      if (points.length > 150) points.removeAt(0);

      double highestInView = points.isNotEmpty ? points.reduce((a, b) => a > b ? a : b) : 100.0;
      double targetMax = (highestInView > threshold ? highestInView : threshold) * 1.2;
      _graphMax = (_graphMax * 0.9) + (targetMax * 0.1);

      if (activeMode == "sos" && value > threshold) {
        int now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastTriggerMs > 5000) {
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

  // App Start Hote Hi Permission Maango
  void _checkPermissionsOnStart() async {
    // 1. App ki UI (Screen) ko poora load hone ka time do (3 Seconds)
    await Future.delayed(const Duration(seconds: 3));

    // 2. Pehle SMS Permission maango
    await Telephony.instance.requestPhoneAndSmsPermissions;

    // 3. SMS popup band hone ke baad 2 second ka wait karo
    await Future.delayed(const Duration(seconds: 2));

    // 4. Ab Location permission check karo
    LocationPermission locPermission = await Geolocator.checkPermission();
    
    if (locPermission == LocationPermission.denied) {
      // Agar denied hai, toh popup show karne ki koshish karo
      locPermission = await Geolocator.requestPermission();
    }

    // 🔥 FAILSAFE: Agar popup nahi aaya aur directly Deny ho gaya
    // Ya agar permanently denied hai, toh seedha App Settings khol do!
    if (locPermission == LocationPermission.deniedForever || locPermission == LocationPermission.denied) {
      print("🚫 Popup Blocked by Android! Opening Settings Automatically...");
      await Geolocator.openAppSettings(); 
    }
  }

  // Foreground SMS Listener
  void _initSmsListener() {
    Telephony.instance.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        if (!isRemoteRequestEnabled) return;
        if (message.body?.toLowerCase().trim() == "current location") {
          _sendOnDemandLocation(message.address!);
        }
      },
      onBackgroundMessage: backgroundSmsHandler,
      listenInBackground: true,
    );
  }

  void _sendOnDemandLocation(String sender) async {
    bool isAuth = emergencyContacts.any((c) => sender.contains(c.replaceAll(RegExp(r'\D'), '')));
    if (isAuth) {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 4));
      } catch (e) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos != null) {
        String link = "https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
        Telephony.instance.sendSms(to: sender, message: "NeuralGate Auto-Reply:\n$link");
      }
    }
  }

  // 🔥 MAIN SOS LOGIC
  void sendSOS() async {
    print("🚀 SOS Triggered!");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    emergencyContacts = prefs.getStringList('emergency_contacts') ?? [];
    
    String? savedMessage = prefs.getString('sos_message');
    String baseMessage = (savedMessage == null || savedMessage.trim().isEmpty) 
        ? "Emergency! Brain signal threshold exceeded. [Neural Gate]" 
        : savedMessage;

    if (locationStrategy == "off") {
      _sendToAll(baseMessage);
      return;
    }

    Position? pos;
    try {
      // 4 Second Fast GPS Fetch
      pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 4));
    } catch (e) {
      // Fallback
      pos = await Geolocator.getLastKnownPosition();
    }

    if (pos != null) {
      // 🔥 YEH HAI SAHI CLICKABLE LINK 
      String link = "https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
      _sendToAll("$baseMessage\nLocation: $link");
      
      if (locationStrategy == "auto") {
        _lastSentPosition = pos;
        startDistanceTracking(); 
      }
    } else {
      _sendToAll("$baseMessage\n(Location Failed: GPS Signal Weak)");
    }
  }

  void _sendToAll(String message) {
    String defaultNumber = "+916267364421"; 
    if (emergencyContacts.isEmpty) {
      Telephony.instance.sendSms(to: defaultNumber, message: message);
    } else {
      for (String n in emergencyContacts) Telephony.instance.sendSms(to: n, message: message);
    }
  }

  // DISTANCE TRACKING 
  void startDistanceTracking() async {
    isTrackingActive = true;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_tracking_active', true);
    notifyListeners();

    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!isTrackingActive) { timer.cancel(); return; }
      try {
        Position currentPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (_lastSentPosition != null) {
          double d = Geolocator.distanceBetween(_lastSentPosition!.latitude, _lastSentPosition!.longitude, currentPos.latitude, currentPos.longitude);
          if (d >= (distanceThreshold * 1000)) {
            String link = "https://maps.google.com/?q=${currentPos.latitude},${currentPos.longitude}";
            _sendToAll("Movement Update:\n$link");
            _lastSentPosition = currentPos;
          }
        } else {
          _lastSentPosition = currentPos;
        }
      } catch (e) {}
    });
  }

  void stopDistanceTracking() async {
    isTrackingActive = false;
    _trackingTimer?.cancel();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_tracking_active', false);
    notifyListeners();
  }

  // LOAD SETTINGS
  void loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    locationStrategy = prefs.getString('location_strategy') ?? "static";
    distanceThreshold = prefs.getDouble('distance_threshold') ?? 0.5;
    isRemoteRequestEnabled = prefs.getBool('remote_request_enabled') ?? true;
    emergencyContacts = prefs.getStringList('emergency_contacts') ?? [];
    
    isTrackingActive = prefs.getBool('is_tracking_active') ?? false;
    if (isTrackingActive) {
      startDistanceTracking(); 
    }
    
    notifyListeners();
  }

  void setLocationStrategy(String val) async {
    locationStrategy = val;
    (await SharedPreferences.getInstance()).setString('location_strategy', val);
    notifyListeners();
  }

  void setDistanceThreshold(double val) async {
    distanceThreshold = val;
    (await SharedPreferences.getInstance()).setDouble('distance_threshold', val);
    notifyListeners();
  }

  void toggleRemoteRequest(bool val) async {
    isRemoteRequestEnabled = val;
    (await SharedPreferences.getInstance()).setBool('remote_request_enabled', val);
    notifyListeners();
  }

  void toggleTheme(bool v) async { isDarkMode = v; (await SharedPreferences.getInstance()).setBool('is_dark_mode', v); notifyListeners(); }
  void setThreshold(double v) { threshold = v; notifyListeners(); }
  void setMode(String m) { activeMode = m; notifyListeners(); }
  void triggerManual() { if (activeMode == "sos") sendSOS(); else _service.sendCommand("/manual"); }
  double get graphMax => _graphMax;

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }
}