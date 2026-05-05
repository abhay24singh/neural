import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/neural_controller.dart';

class AdvancedSettingsScreen extends StatelessWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<NeuralController>(context);

    // Dark Theme Colors
    final bgColor = const Color.fromARGB(255, 0, 0, 0); // Deep dark background
    final cardColor = const Color.fromARGB(255, 2, 16, 38); // Elevated card color
    final textColor = Colors.white;
    final subtitleColor = Colors.grey.shade400;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Security Settings", 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 1)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. LIMIT CONTROLLERS (ORANGE ACCENT) ---
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 10.0, top: 16.0),
              child: Text(
                "SECURITY THRESHOLDS",
                style: TextStyle(
                  color: Colors.orangeAccent, 
                  fontSize: 13, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 1.2
                ),
              ),
            ),
            
            Card(
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      "Max Leak Limit", 
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600)
                    ),
                    subtitle: Text(
                      "Max strangers allowed per code: ${controller.maxTpLimit}", 
                      style: TextStyle(color: subtitleColor, fontSize: 12)
                    ),
                    trailing: SizedBox(
                      width: 120,
                      child: Slider(
                        activeColor: Colors.orangeAccent,
                        inactiveColor: Colors.white12,
                        value: controller.maxTpLimit.toDouble(),
                        min: 1, max: 10, divisions: 9,
                        onChanged: (v) => controller.updateLimits(v.toInt(), controller.maxReqLimit),
                      ),
                    ),
                  ),
                  
                  const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                  
                  ListTile(
                    title: Text(
                      "Max Request Limit", 
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600)
                    ),
                    subtitle: Text(
                      "Max requests per stranger: ${controller.maxReqLimit}", 
                      style: TextStyle(color: subtitleColor, fontSize: 12)
                    ),
                    trailing: SizedBox(
                      width: 120,
                      child: Slider(
                        activeColor: Colors.orangeAccent,
                        inactiveColor: Colors.white12,
                        value: controller.maxReqLimit.toDouble(),
                        min: 1, max: 20, divisions: 19,
                        onChanged: (v) => controller.updateLimits(controller.maxTpLimit, v.toInt()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}