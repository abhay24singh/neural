import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/neural_controller.dart';

class AdvancedSettingsScreen extends StatelessWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<NeuralController>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("NeuralGate: Advanced Security")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. LIMIT CONTROLLERS ---
            const Text("Security Thresholds", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            const Divider(),
            
            ListTile(
              title: const Text("Max Leak Limit (x per h)"),
              subtitle: Text("Ek code maximum kitne third-party use kar sakte hain: ${controller.maxTpLimit}"),
              trailing: SizedBox(
                width: 150,
                child: Slider(
                  value: controller.maxTpLimit.toDouble(),
                  min: 1, max: 10, divisions: 9,
                  onChanged: (v) => controller.updateLimits(v.toInt(), controller.maxReqLimit),
                ),
              ),
            ),

            ListTile(
              title: const Text("Max Request Limit (per x)"),
              subtitle: Text("Ek anjaan banda kitni baar request kar sakta hai: ${controller.maxReqLimit}"),
              trailing: SizedBox(
                width: 150,
                child: Slider(
                  value: controller.maxReqLimit.toDouble(),
                  min: 1, max: 20, divisions: 19,
                  onChanged: (v) => controller.updateLimits(controller.maxTpLimit, v.toInt()),
                ),
              ),
            )

            /* SizedBox(height: 30),

            // --- 2. LIVE DICTIONARY MONITOR (DIC 1) ---
            Text("Dictionary 1 (Authorized Keys)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            Card(
              child: ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: controller.getDic1.length,
                itemBuilder: (context, index) {
                  String key = controller.getDic1.keys.elementAt(index);
                  return ListTile(
                    title: Text("Number: $key"),
                    subtitle: Text("Leak Counter: ${controller.getDic1[key]}"),
                    trailing: Icon(Icons.verified_user, color: Colors.green),
                  );
                },
              ),
            ),

            SizedBox(height: 30),

            // --- 3. LEAK TRACKER MONITOR (DIC 2) ---
            Text("Dictionary 2 (Leak Tracking / x)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            Card(
              child: controller.getDic2.isEmpty 
                ? Padding(padding: EdgeInsets.all(16), child: Text("No leaks detected yet."))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: controller.getDic2.length,
                    itemBuilder: (context, index) {
                      String tpNumber = controller.getDic2.keys.elementAt(index);
                      var data = controller.getDic2[tpNumber];
                      return ListTile(
                        leading: CircleAvatar(child: Text("x"), backgroundColor: Colors.red.shade100),
                        title: Text("Stranger: $tpNumber"),
                        subtitle: Text("Owner: ${data['owner']} | Requests: ${data['count']}"),
                        trailing: data['count'] >= controller.maxReqLimit 
                          ? Text("BLOCKED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                          : null,
                      );
                    },
                  ),
            ),
            
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Provider.of<NeuralController>(context, listen: false).clearDic2Data();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Third Party Data Cleared! Schema Fixed.")),
                );
              },
              child: const Text("Format Third-Party Leaks (Dic2)", style: TextStyle(color: Colors.white)),
            ) */
          ],
        ),
      ),
    );
  }
}