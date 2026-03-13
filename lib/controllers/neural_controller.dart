import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/esp_service.dart';

class NeuralController extends ChangeNotifier {
  final EspService _service;

  List<double> points = [];
  double threshold = 100.0;
  double _graphMax = 250.0; // The adaptive vertical limit
  String activeMode = "relay";
  bool isConnected = false;
  double userThreshold = 100.0; // Store user's threshold for non-SOS modes
  double _espThreshold = 100.0; // Value sent to the ESP32
  int lastTriggerMs = 0;

  static const String sosNumber =
      "+919039421523"; // Hardcoded SOS number - replace with actual number
  static const String smsBackendUrl =
      "https://your-backend-url.com/send-sms"; // Replace with your actual backend URL

  NeuralController(this._service) {
    _service.signalStream.listen((value) {
      isConnected = true;
      points.add(value);
      if (points.length > 150) points.removeAt(0);

      // --- ADAPTIVE AUTO THRESHOLD ADJUST ---
      // Find the highest peak in the current buffer
      double highestInView =
          points.isNotEmpty ? points.reduce((a, b) => a > b ? a : b) : 100.0;

      // Target max is either the signal peak or the threshold line + 20% margin
      double targetMax =
          (highestInView > threshold ? highestInView : threshold) * 1.2;

      // Smoothly interpolate _graphMax to prevent jittery scaling
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

    // Only update the ESP threshold when not in SOS mode.
    if (activeMode != "sos") {
      _espThreshold = val;
      _service.sendCommand("/setTh?v=${_espThreshold.toInt()}");
    }

    notifyListeners();
  }

  void setMode(String mode) {
    activeMode = mode;

    if (mode == "sos") {
      // Keep the slider value stable, but tell the ESP to ignore spikes.
      _espThreshold = 10000.0;
      sendSOS(); // Send initial SOS
    } else {
      _espThreshold = userThreshold;
      _service.sendCommand("/setTarget?t=$mode");
    }

    // Update ESP threshold based on mode.
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
    const platform = MethodChannel('sos_app/sms');
    try {
      // Try direct SMS send via MethodChannel
      final result = await platform.invokeMethod('sendSMS', {
        'phone': sosNumber,
        'message': 'SOS Alert from Neural Gate',
      });
      print("SOS SMS sent directly: $result");
    } on PlatformException catch (e) {
      print("Direct SMS failed: ${e.message}, falling back to SMS app");
      // Fallback: Open SMS app
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: sosNumber,
        queryParameters: {'body': 'SOS Alert from Neural Gate'},
      );
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        print("Opened SMS app for manual send");
      } else {
        print("Could not launch SMS app");
      }
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
