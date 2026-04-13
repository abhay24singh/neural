import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; 
import 'controllers/neural_controller.dart'; 

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
    Color bgColor = _isDarkMode ? const Color(0xFF0A0E21) : Colors.white;
    Color textColor = _isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("SOS CONFIGURATION", style: TextStyle(color: textColor)),
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
              activeColor: Colors.blue,
              onChanged: (bool value) {
                Provider.of<NeuralController>(context, listen: false).toggleTheme(value);
                setState(() {
                  _isDarkMode = value;
                });
                _saveSettings(); 
              },
            ),
            const Divider(color: Colors.grey),
            const SizedBox(height: 10),

            // ---------------------------------------------------------
            // 📍 2. NEW: LOCATION MODE & DURATION
            // ---------------------------------------------------------
            Consumer<NeuralController>(
              builder: (context, controller, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("LOCATION TRACKING MODE", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    // Dropdown for Mode
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _isDarkMode ? Colors.white10 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: controller.locationMode,
                          dropdownColor: bgColor,
                          isExpanded: true,
                          icon: const Icon(Icons.location_on, color: Colors.blue),
                          style: TextStyle(color: textColor, fontSize: 16),
                          items: const [
                            DropdownMenuItem(value: "off", child: Text("📴 Off (Only Text SMS)")),
                            DropdownMenuItem(value: "current", child: Text("📍 Current Location (Static Link)")),
                            DropdownMenuItem(value: "live", child: Text("🚨 Live Tracking (Continuous)")),
                          ],
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              controller.setLocationMode(newValue);
                            }
                          },
                        ),
                      ),
                    ),
                    
                    // Conditional UI: Duration Buttons (Only shows if "Live" is selected)
                    if (controller.locationMode == "live") ...[
                      const SizedBox(height: 15),
                      Text("LIVE TRACKING DURATION", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [10, 30, 60].map((int mins) {
                          bool isSelected = controller.liveDuration == mins;
                          return ChoiceChip(
                            label: Text(mins == 60 ? "1 Hour" : "$mins Min", style: TextStyle(color: isSelected ? Colors.white : textColor)),
                            selected: isSelected,
                            selectedColor: Colors.blue,
                            backgroundColor: _isDarkMode ? Colors.white10 : Colors.grey.shade300,
                            onSelected: (bool selected) {
                              if (selected) controller.setLiveDuration(mins);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),

            // ---------------------------------------------------------
            // 3. CUSTOM SOS MESSAGE
            // ---------------------------------------------------------
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

            // ---------------------------------------------------------
            // 4. EMERGENCY CONTACTS
            // ---------------------------------------------------------
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
                   
               ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
            
            
            // ---------------------------------------------------------
            // 5. SAVE BUTTON
            // ---------------------------------------------------------
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