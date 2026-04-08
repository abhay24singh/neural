import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/esp_service.dart';
import 'controllers/neural_controller.dart';
import 'widgets/neural_graph.dart';
import 'settings_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => NeuralController(EspService(host: "192.168.4.1")),
      child: const NeuralGateApp(),
    ),
  );
}

class NeuralGateApp extends StatelessWidget {
  const NeuralGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Yahan hum app ko batate hain ki controller se theme suno
    final isDark = context.watch<NeuralController>().isDarkMode;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Theme Mode set kiya isDark ke hisaab se
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007AFF), brightness: Brightness.dark),
      ),
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF0F0F5),
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007AFF), brightness: Brightness.light),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Theme read karna
    final isDark = context.watch<NeuralController>().isDarkMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Background gradient logic
            colors: isDark
                ? [const Color(0xFF0A0B10), const Color(0xFF050505)]
                : [Colors.white, const Color(0xFFE2E2E2)], // Light Mode colors
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48), // Isse text center mein rahega
                    Text("NEURALGATE",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: isDark ? Colors.white : Colors.black87)),
                    IconButton(
                      icon: Icon(Icons.settings, color: isDark ? Colors.white : Colors.black87),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SettingsPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // GRAPH CARD
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                    boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 15)],
                  ),
                  child: Consumer<NeuralController>(
                    builder: (context, ctrl, _) => NeuralGraph(
                      points: ctrl.points,
                      threshold: ctrl.threshold,
                      graphMax: ctrl.graphMax,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // CONTROL CARD
              Expanded(
                flex: 4,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121214) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                    boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 15)],
                  ),
                  child: const SingleChildScrollView(child: ControlLayout()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ControlLayout extends StatelessWidget {
  const ControlLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // Yahan bhi theme read karenge taaki text/icons update ho jayein
    final controller = context.watch<NeuralController>();
    final isDark = controller.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            underline: const SizedBox(),
            dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
            items: const [
              DropdownMenuItem(value: "relay", child: Text("Relay Module")),
              DropdownMenuItem(value: "phone", child: Text("Smartphone")),
              DropdownMenuItem(value: "sos", child: Text("SOS Mode")),
            ],
            onChanged: (v) => controller.setMode(v!),
          ),
        ),
        Divider(color: isDark ? Colors.white10 : Colors.black12, height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("LIMIT",
                style: TextStyle(
                    color: Color(0xFF007AFF), fontWeight: FontWeight.bold)),
            Selector<NeuralController, double>(
              selector: (_, c) => c.threshold,
              builder: (context, th, _) => Text("${th.toInt()}",
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
            onChanged: (v) => controller.setThreshold(v),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () => controller.triggerManual(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 65),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 10,
            shadowColor: const Color(0xFF007AFF).withOpacity(0.4),
          ),
          child: const Text("MANUAL TRIGGER",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}