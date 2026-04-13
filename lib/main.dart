import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/esp_service.dart';
import 'controllers/neural_controller.dart';
import 'widgets/neural_graph.dart';
import 'settings_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      // Yahan hum ESP32 ki IP Address de rahe hain taki app us se connect ho sake
      create: (_) => NeuralController(EspService(host: "192.168.4.1")),
      child: const NeuralGateApp(),
    ),
  );
}

class NeuralGateApp extends StatelessWidget {
  const NeuralGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Yahan hum controller se pooch rahe hain: "Bhai theme konsi chalani hai? Dark ya Light?"
    final isDark = context.watch<NeuralController>().isDarkMode;

    return MaterialApp(
      debugShowCheckedModeBanner: false, // Wo kone mein 'Debug' wali patti hatane ke liye
      
      // isDark ke hisaab se theme switch hogi
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      
      // --- DARK THEME SETTINGS ---
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505), // Ekdum gehra kaala background
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007AFF), brightness: Brightness.dark), // Neela primary color
      ),
      
      // --- LIGHT THEME SETTINGS ---
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF0F0F5), // Halka greyish-white background
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007AFF), brightness: Brightness.light),
      ),
      home: const HomeScreen(), // App khulte hi ye page dikhega
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Phir se theme check kar rahe hain UI colors adjust karne ke liye
    final isDark = context.watch<NeuralController>().isDarkMode;

    return Scaffold(
      body: Container(
        // Background mein upar se niche aane wala gradient color
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0A0B10), const Color(0xFF050505)] // Dark gradient
                : [Colors.white, const Color(0xFFE2E2E2)], // Light gradient
          ),
        ),
        child: SafeArea( // SafeArea taaki text phone ke notch/camera ke piche na chhupe
          child: Column(
            children: [
              
              // --- UPRA WALI PATTI (App Name & Settings Button) ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48), // Ye space di hai taaki NEURALGATE beech mein dikhe
                    Text("NEURALGATE",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4, // Text ke beech mein space (Hacker style)
                            color: isDark ? Colors.white : Colors.black87)),
                    IconButton(
                      icon: Icon(Icons.settings, color: isDark ? Colors.white : Colors.black87),
                      onPressed: () {
                        // Settings wale page par jane ka rasta
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SettingsPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // --- GRAPH WALA DIBBA (Jisme brain ki waves chalengi) ---
              Expanded(
                flex: 3, // Screen ka 3 hissa graph ko de rahe hain
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(28), // Gol kinare
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                    boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 15)],
                  ),
                  child: Consumer<NeuralController>(
                    // Yahan asli live graph draw ho raha hai controller ke data se
                    builder: (context, ctrl, _) => NeuralGraph(
                      points: ctrl.points,
                      threshold: ctrl.threshold,
                      graphMax: ctrl.graphMax,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20), // Graph aur Control ke beech ki khaali jagah

              // --- CONTROL WALA DIBBA (Buttons aur Slider) ---
              Expanded(
                flex: 4, // Screen ka 4 hissa buttons ko de rahe hain
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121214) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                    boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 15)],
                  ),
                  child: const SingleChildScrollView(child: ControlLayout()), // Agar screen choti ho toh scroll ho jaye
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Ye class control wale dibbe ke andar ka saaman (Drop down, slider, button) banati hai
class ControlLayout extends StatelessWidget {
  const ControlLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // Controller ko bulate hain taaki uske functions use kar sakein
    final controller = context.watch<NeuralController>();
    final isDark = controller.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        // 1. SELECT DEVICE WALA DROPDOWN MENU
        Text("SELECT DEVICE",
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        Selector<NeuralController, String>(
          selector: (_, c) => c.activeMode,
          builder: (context, mode, _) => DropdownButton<String>(
            value: mode,
            isExpanded: true,
            underline: const SizedBox(), // Niche ki line hatane ke liye
            dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
            items: const [
              DropdownMenuItem(value: "relay", child: Text("Relay Module")),
              DropdownMenuItem(value: "phone", child: Text("Smartphone")),
              DropdownMenuItem(value: "sos", child: Text("SOS Mode")), // Apni emergency wali mode
            ],
            onChanged: (v) => controller.setMode(v!), // Mode badalne par controller ko batao
          ),
        ),
        
        Divider(color: isDark ? Colors.white10 : Colors.black12, height: 40),
        
        // 2. LIMIT (THRESHOLD) SET KARNE WALA SLIDER
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("LIMIT",
                style: TextStyle(
                    color: Color(0xFF007AFF), fontWeight: FontWeight.bold)),
            Selector<NeuralController, double>(
              selector: (_, c) => c.threshold,
              builder: (context, th, _) => Text("${th.toInt()}", // Slider ki value text me dikha rahe hain
                  style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87)),
            ),
          ],
        ),
        Selector<NeuralController, double>(
          selector: (_, c) => c.threshold,
          builder: (context, th, _) => Slider(
            value: th,
            min: 10,
            max: 500,
            activeColor: const Color(0xFF007AFF),
            onChanged: (v) => controller.setThreshold(v), // Slider ghiskane par limit change karo
          ),
        ),
        
        const SizedBox(height: 30),
        
        // 3. MANUAL TRIGGER BUTTON (Neela wala)
        // 3. MANUAL TRIGGER BUTTON (Neela wala)
        ElevatedButton(
          onPressed: () => controller.triggerManual(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 65),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 10,
            shadowColor: const Color(0xFF007AFF).withOpacity(0.4),
          ),
          child: const Text("MANUAL TRIGGER",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ), // 👈 MANUAL TRIGGER BUTTON YAHAN PROPERLY CLOSE HUA

        // 4. 🔥 ASLI JAADU YAHAN HAI: CONDITIONAL STOP BUTTON 🔥
        if (controller.isTrackingActive) 
          Padding(
            padding: const EdgeInsets.only(top: 20), 
            child: ElevatedButton.icon(
              onPressed: () => controller.stopLiveTracking(), 
              icon: const Icon(Icons.stop_circle, color: Colors.white, size: 28),
              label: const Text(
                "STOP LIVE TRACKING",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), 
              ), // Text widget yahan close hua
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, 
                minimumSize: const Size(double.infinity, 60), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 10,
                shadowColor: Colors.redAccent.withOpacity(0.5), 
              ),
            ), // ElevatedButton yahan close hua
          ), // Padding yahan close hua
          
      ], // 👈 Column ke 'children' yahan khatam hue
    ); // 👈 Column yahan khatam hua
  } // 👈 build context yahan khatam hua
} // 👈 ControlLayout class yahan khatam hui