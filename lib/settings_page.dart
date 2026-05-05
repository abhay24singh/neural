import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; 
import 'controllers/neural_controller.dart'; 
import 'advanced_settings_screen.dart'; 

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

  // --- UI HELPER WIDGET (UPDATED) ---
  // Ab ye function ek 'color' parameter bhi leta hai
  Widget _buildSectionHeader(String title, Color sectionColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: TextStyle(
          color: sectionColor, 
          fontSize: 13, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 1.2
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Colors based on Dark/Light mode
    Color bgColor = _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6);
    Color cardColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    Color textColor = _isDarkMode ? Colors.white : Colors.black87;
    Color subtitleColor = _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    Color dividerColor = _isDarkMode ? Colors.white10 : Colors.black12;

    // Define Vibrant Section Colors
    Color generalColor = const Color(0xFF007AFF); // Blue
    Color trackingColor = Colors.teal;           // Greenish
    Color securityColor = Colors.deepOrange;     // Orange/Red
    Color messageColor = Colors.purpleAccent;    // Purple
    Color contactsColor = const Color(0xFF10B981); // Emerald Green

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Neurat Gate settings", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor), 
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          
          // ---------------------------------------------------------
          // 1. GENERAL SETTINGS (BLUE)
          // ---------------------------------------------------------
          _buildSectionHeader('GENERAL SETTINGS', generalColor),
          Card(
            color: cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text("Dark Mode", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  subtitle: Text(_isDarkMode ? "Dark theme enabled" : "Light theme enabled", style: TextStyle(color: subtitleColor, fontSize: 12)),
                  value: _isDarkMode,
                  activeColor: generalColor,
                  onChanged: (bool value) {
                    Provider.of<NeuralController>(context, listen: false).toggleTheme(value);
                    setState(() => _isDarkMode = value);
                    _saveSettings(); 
                  },
                ),
                Divider(color: dividerColor, height: 1, indent: 16, endIndent: 16),
                
                Consumer<NeuralController>(
                  builder: (context, controller, _) {
                    return ListTile(
                      leading: Icon(Icons.touch_app, color: generalColor),
                      title: Text("Smart Phone Action", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                      subtitle: Text("Select what the trigger button controls", style: TextStyle(color: subtitleColor, fontSize: 12)),
                      trailing: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: cardColor,
                          icon: Icon(Icons.arrow_drop_down, color: textColor),
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                          value: controller.smartPhoneAction, 
                          items: const [
                            DropdownMenuItem(value: "media", child: Text("Play/Pause Media")),
                            DropdownMenuItem(value: "call_pick", child: Text("Toggle Call")),
                            DropdownMenuItem(value: "flashlight", child: Text("Flashlight")),
                            DropdownMenuItem(value: "assistant", child: Text("Voice Assistant")),
                            DropdownMenuItem(value: "volume_up", child: Text("Volume +")),
                            DropdownMenuItem(value: "volume_down", child: Text("Volume -")),
                          ],
                          onChanged: (String? newValue) {
                            if (newValue != null) controller.setSmartPhoneAction(newValue); 
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ---------------------------------------------------------
          // 2. TRACKING CONFIGURATION (TEAL)
          // ---------------------------------------------------------
          _buildSectionHeader('TRACKING CONFIGURATION', trackingColor),
          Card(
            color: cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text("Allow Remote SMS Request", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  subtitle: Text("Reply with location on 'current location' SMS", style: TextStyle(color: subtitleColor, fontSize: 12)),
                  value: Provider.of<NeuralController>(context).isRemoteRequestEnabled,
                  activeColor: trackingColor,
                  onChanged: (v) => Provider.of<NeuralController>(context, listen: false).toggleRemoteRequest(v),
                ),
                Divider(color: dividerColor, height: 1, indent: 16, endIndent: 16),
                
                ListTile(
                  title: Text("SOS Location Strategy", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: cardColor,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                      value: Provider.of<NeuralController>(context).locationStrategy,
                      items: const [
                        DropdownMenuItem(value: "off", child: Text("Only Text SMS")),
                        DropdownMenuItem(value: "static", child: Text("Current Location Once")),
                        DropdownMenuItem(value: "auto", child: Text("Auto-Update (Distance)")),
                      ],
                      onChanged: (v) => Provider.of<NeuralController>(context, listen: false).setLocationStrategy(v!),
                    ),
                  ),
                ),

                if (Provider.of<NeuralController>(context).locationStrategy == "auto") ...[
                  Divider(color: dividerColor, height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    title: Text("Update Distance Threshold", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<double>(
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                        value: Provider.of<NeuralController>(context).distanceThreshold,
                        items: [0.5, 1.0, 2.0, 5.0].map((e) => DropdownMenuItem(value: e, child: Text("$e KM"))).toList(),
                        onChanged: (v) => Provider.of<NeuralController>(context, listen: false).setDistanceThreshold(v!),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ---------------------------------------------------------
          // 3. ADVANCED SECURITY (ORANGE)
          // ---------------------------------------------------------
          const SizedBox(height: 8),
          Card(
            color: cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: securityColor.withOpacity(0.2),
                child: Icon(Icons.security, color: securityColor),
              ),
              title: Text("Advanced Security Setting", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              subtitle: Text("Manage code leaks, limits & authorized users", style: TextStyle(color: subtitleColor, fontSize: 12)),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: subtitleColor),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdvancedSettingsScreen())),
            ),
          ),

          // ---------------------------------------------------------
          // 4. CUSTOM SOS MESSAGE (PURPLE)
          // ---------------------------------------------------------
          _buildSectionHeader('CUSTOM SOS MESSAGE', messageColor),
          Card(
            color: cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _msgController,
                style: TextStyle(color: textColor),
                maxLines: null,
                cursorColor: messageColor,
                decoration: InputDecoration(
                  hintText: "Type your emergency message here...",
                  hintStyle: TextStyle(color: subtitleColor),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // ---------------------------------------------------------
          // 5. EMERGENCY CONTACTS (EMERALD GREEN)
          // ---------------------------------------------------------
          _buildSectionHeader('EMERGENCY CONTACTS', contactsColor),
          Card(
            color: cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: textColor),
                          cursorColor: contactsColor,
                          decoration: InputDecoration(
                            hintText: "Enter Phone No (e.g. +91...)",
                            hintStyle: TextStyle(color: subtitleColor),
                            filled: true,
                            fillColor: _isDarkMode ? Colors.black26 : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: contactsColor, size: 40),
                        onPressed: () {
                          if (_phoneController.text.isNotEmpty) {
                            setState(() => _contacts.add(_phoneController.text.trim()));
                            _phoneController.clear();
                          }
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  if (_contacts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text("No contacts added yet.", style: TextStyle(color: subtitleColor)),
                    ),
                    
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) => Card(
                      color: _isDarkMode ? Colors.white10 : Colors.grey.shade200,
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: Icon(Icons.person, color: contactsColor),
                        title: Text(_contacts[index], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                          onPressed: () => setState(() => _contacts.removeAt(index)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 30),

          // ---------------------------------------------------------
          // 6. SAVE BUTTON (STAYS BLUE FOR PRIMARY ACTION)
          // ---------------------------------------------------------
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: generalColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                shadowColor: generalColor.withOpacity(0.5)
              ),
              onPressed: _saveSettings,
              child: const Text("SAVE CONFIGURATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}