import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; 
import 'controllers/neural_controller.dart'; 
import 'advanced_settings_screen.dart'; // 🔥 Import for Advanced Settings Screen

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  List<String> _contacts = [];
  
  bool _isDarkMode = true; 

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Local storage se data load karna
  _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _contacts = prefs.getStringList('emergency_contacts') ?? [];
      _msgController.text = prefs.getString('sos_message') ?? "Emergency! Brain Signal Threshold Exceeded.";
      _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    });
  }

  // Data save karna
  // Data save karna aur Dic1 mein add karna
  _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('emergency_contacts', _contacts);
    await prefs.setString('sos_message', _msgController.text);
    await prefs.setBool('is_dark_mode', _isDarkMode);
    
    final controller = Provider.of<NeuralController>(context, listen: false);
    controller.loadSettings();

    // 🔥 MAIN FIX: Har contact ke liye code generate karwao (agar pehle se nahi hai)
    for (String contact in _contacts) {
      controller.addNewAuthorizedUser(contact);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Settings Saved! Codes generated for new contacts.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.green
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = _isDarkMode ? const Color(0xFF0A0E21) : Colors.white;
    Color textColor = _isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("SOS CONFIGURATION", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor), 
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // ---------------------------------------------------------
            // 1. THEME SWITCH
            // ---------------------------------------------------------
            SwitchListTile(
              title: Text(
                "Dark Mode", 
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)
              ),
              subtitle: Text(
                _isDarkMode ? "Dark theme enabled" : "Light theme enabled",
                style: const TextStyle(color: Colors.grey),
              ),
              value: _isDarkMode,
              activeThumbColor: const Color(0xFF007AFF),
              onChanged: (bool value) {
                Provider.of<NeuralController>(context, listen: false).toggleTheme(value);
                setState(() {
                  _isDarkMode = value;
                });
                _saveSettings(); 
              },
            ),
            
            const Divider(color: Colors.grey),
            const SizedBox(height: 15),
            // ⚙️ SMART PHONE ACTION SELECTOR
// =================================================================
// 📱 NAYA SETTING: SMART PHONE ACTION SELECTOR
// =================================================================
Consumer<NeuralController>(
  builder: (context, controller, _) {
    return ListTile(
      leading: const Icon(Icons.touch_app, color: Colors.blueAccent),
      title: const Text(
        "Smart Phone Action", 
        style: TextStyle(fontWeight: FontWeight.bold)
      ),
      subtitle: const Text("Select what the trigger button controls"),
      trailing: DropdownButton<String>(
        value: controller.smartPhoneAction, // Ye naya variable padhega
        underline: const SizedBox(), 
        items: const [
          DropdownMenuItem(value: "media", child: Text("Play/Pause Media")),
          DropdownMenuItem(value: "call_pick", child: Text("Pick Incoming Call")),
          DropdownMenuItem(value: "flashlight", child: Text("Toggle Flashlight")),
          DropdownMenuItem(value: "assistant", child: Text("Voice Assistant")),
          DropdownMenuItem(value: "volume_up", child: Text("Increase Volume")),
        ],
        onChanged: (String? newValue) {
          if (newValue != null) {
            // Ye Dropdown change hone par memory mein save karega
            controller.setSmartPhoneAction(newValue); 
          }
        },
      ),
    );
  },
),
// =================================================================
            // ---------------------------------------------------------
            // 2. TRACKING CONFIGURATION 
            // ---------------------------------------------------------
            const Text("TRACKING CONFIGURATION", style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // 2A. Remote Request (On-Demand) Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Allow Remote SMS Request", style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
              subtitle: const Text("Reply with location on 'current location' SMS", style: TextStyle(color: Colors.grey, fontSize: 12)),
              value: Provider.of<NeuralController>(context).isRemoteRequestEnabled,
              activeThumbColor: const Color(0xFF007AFF),
              onChanged: (v) => Provider.of<NeuralController>(context, listen: false).toggleRemoteRequest(v),
            ),

            // 2B. Location Strategy Dropdown (Static, Auto-Update, etc.)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("SOS Location Strategy", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              trailing: DropdownButton<String>(
                dropdownColor: bgColor,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                value: Provider.of<NeuralController>(context).locationStrategy,
                items: const [
                  DropdownMenuItem(value: "off", child: Text("Only Text SMS")),
                  DropdownMenuItem(value: "static", child: Text("Current Location Once")),
                  DropdownMenuItem(value: "auto", child: Text("Auto-Update (Distance)")),
                ],
                onChanged: (v) => Provider.of<NeuralController>(context, listen: false).setLocationStrategy(v!),
              ),
            ),

            // 2C. Distance Selection (Sirf tab dikhega jab Auto-Update select hoga)
            if (Provider.of<NeuralController>(context).locationStrategy == "auto")
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Update Distance Threshold", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                trailing: DropdownButton<double>(
                  dropdownColor: bgColor,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  value: Provider.of<NeuralController>(context).distanceThreshold,
                  items: [0.5, 1.0, 2.0, 5.0].map((e) => DropdownMenuItem(value: e, child: Text("$e KM"))).toList(),
                  onChanged: (v) => Provider.of<NeuralController>(context, listen: false).setDistanceThreshold(v!),
                ),
              ),

            const Divider(color: Colors.grey),
            const SizedBox(height: 15),

            // ---------------------------------------------------------
            // 🔥 2D. ADVANCED SECURITY SETTINGS BUTTON (NEW)
            // ---------------------------------------------------------
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF007AFF),
                child: Icon(Icons.security, color: Colors.white),
              ),
              title: Text("Advanced Security", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              subtitle: const Text("Manage code leaks, limits & authorized users", style: TextStyle(color: Colors.grey, fontSize: 12)),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: textColor),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdvancedSettingsScreen()),
                );
              },
            ),

            const Divider(color: Colors.grey),
            const SizedBox(height: 20),

            // ---------------------------------------------------------
            // 3. CUSTOM SOS MESSAGE
            // ---------------------------------------------------------
            const Text("CUSTOM SOS MESSAGE", style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold)),
            TextField(
              controller: _msgController,
              style: TextStyle(color: textColor),
              decoration: const InputDecoration(
                hintText: "Type your emergency message here...",
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF007AFF))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF007AFF), width: 2)),
              ),
            ),
            const SizedBox(height: 30),

            // ---------------------------------------------------------
            // 4. EMERGENCY CONTACTS
            // ---------------------------------------------------------
            const Text("EMERGENCY CONTACTS", style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: textColor),
                    decoration: const InputDecoration(
                      hintText: "Enter Phone No (e.g. +91XXXXXXXXXX)",
                      hintStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF007AFF))),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF007AFF), size: 35),
                  onPressed: () {
                    if (_phoneController.text.isNotEmpty) {
                      setState(() => _contacts.add(_phoneController.text));
                      _phoneController.clear();
                    }
                  },
                )
              ],
            ),
            
            const SizedBox(height: 10),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _contacts.length,
              itemBuilder: (context, index) => Card(
                color: _isDarkMode ? Colors.white10 : Colors.grey.shade200,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: Icon(Icons.person, color: _isDarkMode ? Colors.white70 : Colors.black54),
                  title: Text(_contacts[index], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                    onPressed: () => setState(() => _contacts.removeAt(index)),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),

            // ---------------------------------------------------------
            // 5. SAVE BUTTON
            // ---------------------------------------------------------
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                  shadowColor: const Color(0xFF007AFF).withOpacity(0.5)
                ),
                onPressed: _saveSettings,
                child: const Text("SAVE CONFIGURATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
              ),
            )
          ],
        ),
      ),
    );
  }
}