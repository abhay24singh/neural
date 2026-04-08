import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; // 👈 Provider ka import
import 'controllers/neural_controller.dart'; // 👈 NeuralController ka import

class SettingsPage extends StatefulWidget {
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
  _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('emergency_contacts', _contacts);
    await prefs.setString('sos_message', _msgController.text);
    await prefs.setBool('is_dark_mode', _isDarkMode);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Settings Saved Successfully!", style: TextStyle(color: Colors.white)), 
        backgroundColor: Colors.green
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Background color aur text color ab _isDarkMode ke hisaab se badlenge
    Color bgColor = _isDarkMode ? const Color(0xFF0A0E21) : Colors.white;
    Color textColor = _isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("SOS CONFIGURATION", style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor), // Back button ka color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // THEME SWITCH YAHAN HAI
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
              activeColor: Colors.blue,
              onChanged: (bool value) {
                // Yeh line NeuralController ko order degi poori app ka theme badalne ke liye
                Provider.of<NeuralController>(context, listen: false).toggleTheme(value);
                
                setState(() {
                  _isDarkMode = value;
                });
                _saveSettings(); 
              },
            ),
            const Divider(color: Colors.grey),
            const SizedBox(height: 10),

            Text("CUSTOM SOS MESSAGE", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            TextField(
              controller: _msgController,
              style: TextStyle(color: textColor),
              decoration: const InputDecoration(
                hintText: "Type your emergency message here...",
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
              ),
            ),
            const SizedBox(height: 30),
            Text("EMERGENCY CONTACTS", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: textColor),
                    decoration: const InputDecoration(
                      hintText: "Enter Phone Number (with Country Code)",
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
                  onPressed: () {
                    if (_phoneController.text.isNotEmpty) {
                      setState(() => _contacts.add(_phoneController.text));
                      _phoneController.clear();
                    }
                  },
                )
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _contacts.length,
                itemBuilder: (context, index) => ListTile(
                  leading: Icon(Icons.person, color: _isDarkMode ? Colors.white70 : Colors.black54),
                  title: Text(_contacts[index], style: TextStyle(color: textColor)),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                    onPressed: () => setState(() => _contacts.removeAt(index)),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: _saveSettings,
                child: const Text("SAVE CONFIGURATION", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}