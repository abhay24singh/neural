 import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async'; 
import 'dart:convert';
import 'dart:math'; 
import 'package:crypto/crypto.dart'; 
import '../services/esp_service.dart';

// ============================================================================
// 🔐 1. CODE GENERATOR (Algorithm)
// ============================================================================
String generateNewCodeFor(String ownerNumber) {
  int rng = Random().nextInt(999999); // Random factor
  String rawData = ownerNumber + rng.toString();
  List<int> bytes = utf8.encode(rawData); 
  String newCode = sha256.convert(bytes).toString().substring(0, 6); 
  return newCode;
}

// ============================================================================
// 📍 2. HELPER FUNCTION: SAFE LOCATION SENDER
// ============================================================================
 
// ============================================================================
// 📍 2. HELPER FUNCTION: SAFE LOCATION SENDER (FIXED)
// ============================================================================
// ============================================================================
// 📍 2. HELPER FUNCTION: SAFE LOCATION SENDER (Anti-Freeze)
// ============================================================================
Future<void> _sendLocationSafely(String sender) async {
  print("📍 [STEP 3] Background location fetch...");
  Position? pos;
  
  try {
    pos = await Geolocator.getLastKnownPosition();
    if (pos == null) {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, 
        timeLimit: const Duration(seconds: 4) 
      );
    }
  } catch (e) {
    print("⚠️ [ERROR] Background location fail: $e");
  }

  // Background isolate ke liye specific instance
  final telephony = Telephony.backgroundInstance; 

  if (pos != null) {
    print("✅ [STEP 4] Location mil gayi! Bhej raha hoon...");
    // 🔥 FIX: Standard URL
    String mapLink = "https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
    
    telephony.sendSms(
      to: sender, 
      message: "NeuralGate Secure Auto-Reply:\n📍 Location:\n$mapLink"
    );
    print("🚀 [SUCCESS] Location SMS sent!");
  } else {
    print("❌ [FAILED] Phone ne koi location nahi di.");
    telephony.sendSms(
      to: sender, 
      message: "⚠️ NeuralGate Alert: Code accepted, but GPS is OFF or signal is weak on the target device."
    );
  }
}

// ============================================================================
// 🌐 3. THE GATEKEEPER: BACKGROUND SMS HANDLER
// ============================================================================
@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  // 🔥 FIX 1: THE MAGIC LINE (Zaroori for Background Tasks)
  WidgetsFlutterBinding.ensureInitialized();
  print("📥 [STEP 1] Background Handler Wake Up!");

  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isEnabled = prefs.getBool('remote_request_enabled') ?? true;
    if (!isEnabled) {
      print("🛑 Master Switch OFF. Rejecting request.");
      return;
    }

    String r = message.body?.toLowerCase().trim() ?? ""; // Received Code (r)
    String? sender = message.address;
    if (sender == null) return;

    print("📩 Sender: $sender | Message: '$r'");

    // 📥 Load Limits & Dictionaries
    int maxTpLimit = prefs.getInt('max_tp_limit') ?? 3;
    int maxReqLimit = prefs.getInt('max_req_limit') ?? 5;

    Map<String, dynamic> dic1 = {};
    String? d1Data = prefs.getString('dic1_authorized');
    if (d1Data != null) dic1 = jsonDecode(d1Data);

    Map<String, dynamic> dic2 = {};
    String? d2Data = prefs.getString('dic2_leaks');
    if (d2Data != null) dic2 = jsonDecode(d2Data);

    // 🔍 CODE MATCHING (r == h check)
    String? matchedOwner; // h1 ka number
    for (String ownerNumber in dic1.keys) {
      if (dic1[ownerNumber]['code'] == r) {
        matchedOwner = ownerNumber;
        break;
      }
    }

    if (matchedOwner == null) {
      print("❌ [STEP 2 FAIL] Request Reject: Invalid Code from $sender");
      return; 
    }

    print("✅ [STEP 2 PASS] Code Match ho gaya! Asli malik: $matchedOwner");

    // 🛡️ AUTHORIZATION & LEAK TRACKING
    if (sender == matchedOwner) {
      // SCENARIO A: Asli Malik
      print("✅ Owner Request Accept for $sender");
      await _sendLocationSafely(sender);
    } 
    else {
      // SCENARIO B: Anjaan Banda (Third Party / x)
      if (!dic2.containsKey(sender)) {
        // B1: NAYA CHOR
        int currentLeakCount = dic1[matchedOwner]['leak_count'] ?? 0;

        if (currentLeakCount >= maxTpLimit) {
          // 🚨 LIMIT CROSSED! Expiring code.
          print("🚨 Limit Crossed! Expiring code for $matchedOwner");
          dic1[matchedOwner]['code'] = "EXPIRED"; 
          await prefs.setString('dic1_authorized', jsonEncode(dic1));
          
          List<String> compromisedUsers = prefs.getStringList('compromised_users') ?? [];
          if (!compromisedUsers.contains(matchedOwner)) {
            compromisedUsers.add(matchedOwner);
            await prefs.setStringList('compromised_users', compromisedUsers);
          }
          return; 
        } else {
          // Naye chor ko allow karo
          dic1[matchedOwner]['leak_count'] = currentLeakCount + 1; 
          dic2[sender] = {
            "owner": matchedOwner,
            "count": 1 
          };
          await prefs.setString('dic1_authorized', jsonEncode(dic1));
          await prefs.setString('dic2_leaks', jsonEncode(dic2));
          
          print("⚠️ New Stranger Added to Dic2. Sending Location.");
          await _sendLocationSafely(sender);
        }
      } 
      else {
        // B2: PURANA CHOR
        int reqCount = dic2[sender]['count'] ?? 0;

        if (reqCount >= maxReqLimit) {
          print("🚫 Stranger Blocked: Request Limit Crossed for $sender");
        } else {
          dic2[sender]['count'] = reqCount + 1;
          await prefs.setString('dic2_leaks', jsonEncode(dic2));
          
          print("⚠️ Stranger limit not crossed. Sending Location.");
          await _sendLocationSafely(sender);
        }
      }
    }
  } catch (e) {
    print("❌ Background Handler Error: $e");
  }
}

// ============================================================================
// 🧠 4. MAIN NEURAL CONTROLLER CLASS
// ============================================================================
class NeuralController extends ChangeNotifier {
  final EspService _service;

  // --- DICTIONARIES & SECURITY LIMITS ---
  Map<String, dynamic> dic1Authorized = {};
  Map<String, dynamic> dic2Leaks = {}; 
  int maxTpLimit = 3;    
  int maxReqLimit = 5;   

  Map<String, dynamic> get getDic1 => dic1Authorized;
  Map<String, dynamic> get getDic2 => dic2Leaks;

  // --- ESP, GRAPH & UI VARIABLES (RESTORED) ---
  List<double> points = [];
  double threshold = 100.0;
  final double _graphMax = 250.0; 
  double get graphMax => _graphMax; 

  String activeMode = "relay";
  bool isConnected = false;
  bool isDarkMode = true; 
  
  // --- SOS & TRACKING SETTINGS (RESTORED) ---
  bool isRemoteRequestEnabled = true; 
  String locationStrategy = "off";
  double distanceThreshold = 1.0;
  bool isTrackingActive = false;

  NeuralController(this._service) {
    loadSettings(); 
    loadDictionaries();
    points = List.generate(50, (index) => 0.0);
  }

  // ==========================================
  // 🔔 POP-UP HANDLER FOR LEAKED CODES
  // ==========================================
  void checkForCompromisedUsers(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> compromisedUsers = prefs.getStringList('compromised_users') ?? [];

    for (String compromisedOwner in compromisedUsers) {
      showDialog(
        context: context,
        barrierDismissible: false, 
        builder: (context) => AlertDialog(
          title: const Text("🚨 Code Leak Detected!"),
          content: Text("Number: $compromisedOwner ka code limit cross kar chuka hai.\n\nKya aap naya code generate karke is user ko bhejna chahte hain?"),
          actions: [
            TextButton(
              onPressed: () async {
                compromisedUsers.remove(compromisedOwner);
                await prefs.setStringList('compromised_users', compromisedUsers);
                Navigator.pop(context);
              },
              child: const Text("NO", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                String newCode = generateNewCodeFor(compromisedOwner);
                
                dic1Authorized[compromisedOwner] = {"code": newCode, "leak_count": 0};
                await prefs.setString('dic1_authorized', jsonEncode(dic1Authorized));
                
                dic2Leaks.removeWhere((key, value) => value['owner'] == compromisedOwner);
                await prefs.setString('dic2_leaks', jsonEncode(dic2Leaks));
                
                Telephony.instance.sendSms(
                  to: compromisedOwner, 
                  message: "NeuralGate Alert: Your previous code was compromised. Your NEW Secret Code is: $newCode"
                );

                compromisedUsers.remove(compromisedOwner);
                await prefs.setStringList('compromised_users', compromisedUsers);
                
                notifyListeners();
                Navigator.pop(context);
              },
              child: const Text("YES, Generate & Send"),
            )
          ],
        )
      );
    }
  }

  // ==========================================
  // 🗄️ DICTIONARY & LIMITS MANAGEMENT
  // ==========================================
  Future<void> loadDictionaries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    String? d1Data = prefs.getString('dic1_authorized');
    if (d1Data != null) dic1Authorized = jsonDecode(d1Data);

    String? d2Data = prefs.getString('dic2_leaks');
    if (d2Data != null) dic2Leaks = jsonDecode(d2Data);
    
    notifyListeners();
  }
  
  void clearDic1Data() async {
    dic1Authorized.clear();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('dic1_authorized');
    notifyListeners();
    print("🧹 Dictionary 1 poori tarah clear ho gayi!");
  }

  void updateLimits(int tpLimit, int reqLimit) async {
    maxTpLimit = tpLimit;
    maxReqLimit = reqLimit;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_tp_limit', tpLimit);
    await prefs.setInt('max_req_limit', reqLimit);
    notifyListeners();
  }

  void addNewAuthorizedUser(String phoneNumber) async {
    if (!dic1Authorized.containsKey(phoneNumber)) {
      String generatedCode = generateNewCodeFor(phoneNumber);
      dic1Authorized[phoneNumber] = {
        "code": generatedCode,
        "leak_count": 0
      };
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('dic1_authorized', jsonEncode(dic1Authorized));
      notifyListeners();

      print("Sending initial code to $phoneNumber");
      Telephony.instance.sendSms(
        to: phoneNumber, 
        message: "NeuralGate SOS Alert: You are added as an Emergency Contact. Your Secret Code to request my location is: $generatedCode"
      );
    }
  }

  void resetCodeForUser(String phoneNumber) async {
    if (dic1Authorized.containsKey(phoneNumber)) {
      String newCode = generateNewCodeFor(phoneNumber);
      dic1Authorized[phoneNumber] = {
        "code": newCode,
        "leak_count": 0
      };
      
      dic2Leaks.removeWhere((key, value) => value['owner'] == phoneNumber);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('dic1_authorized', jsonEncode(dic1Authorized));
      await prefs.setString('dic2_leaks', jsonEncode(dic2Leaks));
      notifyListeners();
    }
  }

  // ==========================================
  // ⚙️ GENERAL SETTINGS & UI CONTROLS (RESTORED)
  // ==========================================
  void loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    maxTpLimit = prefs.getInt('max_tp_limit') ?? 3;
    maxReqLimit = prefs.getInt('max_req_limit') ?? 5;
    isRemoteRequestEnabled = prefs.getBool('remote_request_enabled') ?? true;
    isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    locationStrategy = prefs.getString('location_strategy') ?? "off";
    distanceThreshold = prefs.getDouble('distance_threshold') ?? 1.0;
    notifyListeners();
  }

  void toggleTheme(bool value) async {
    isDarkMode = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    notifyListeners();
  }

  void toggleRemoteRequest(bool value) async {
    isRemoteRequestEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remote_request_enabled', value);
    notifyListeners();
  }

  void setLocationStrategy(String strategy) async {
    locationStrategy = strategy;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('location_strategy', strategy);
    notifyListeners();
  }

  void setDistanceThreshold(double dist) async {
    distanceThreshold = dist;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('distance_threshold', dist);
    notifyListeners();
  }

  void setMode(String mode) {
    activeMode = mode;
    notifyListeners();
  }

  void setThreshold(double val) {
    threshold = val;
    notifyListeners();
  }

  // 🚨 FIXED MANUAL TRIGGER (With Location Support)
  // 🚨 FIXED MANUAL TRIGGER (Anti-Freeze & Anti-Spam)
  void triggerManual() async {
    print("🚨 Manual SOS Trigger Started!");
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> contacts = prefs.getStringList('emergency_contacts') ?? [];
    String msg = prefs.getString('sos_message') ?? "Emergency! Brain Signal Threshold Exceeded.";

    if (contacts.isEmpty) {
      print("❌ Error: Koi emergency contact save nahi hai!");
      return;
    }

    String finalMessage = msg;
    if (locationStrategy != "off") {
      print("📍 Location fetch kar raha hoon...");
      try {
        // Pehle fast location uthao taaki app freeze na ho
        Position? pos = await Geolocator.getLastKnownPosition();
        if (pos == null) {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium, 
            timeLimit: const Duration(seconds: 3)
          );
        }
        
        // 🔥 FIX: Standard Google Maps Link (Spam nahi lagega)
        finalMessage += "\n📍 Location: https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
        print("✅ Location mil gayi aur message mein jud gayi!");
      } catch (e) {
        print("⚠️ Location fail ho gayi: $e");
        finalMessage += "\n⚠️ (Location fetch failed. GPS might be off)";
      }
    }

    for (String number in contacts) {
      print("✉️ Sending SMS to $number...");
      Telephony.instance.sendSms(to: number, message: finalMessage);
      print("✅ SMS Successfully sent to $number");
    }
    notifyListeners();
  }

  // 🔥 FIX 2: MISSING FUNCTION RESTORED
  void stopDistanceTracking() {
    isTrackingActive = false;
    notifyListeners();
  }
}