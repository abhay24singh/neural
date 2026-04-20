import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/neural_controller.dart'; 

class SecurityDashboard extends StatefulWidget {
  const SecurityDashboard({Key? key}) : super(key: key);

  @override
  State<SecurityDashboard> createState() => _SecurityDashboardState();
}

class _SecurityDashboardState extends State<SecurityDashboard> {

  @override
  void initState() {
    super.initState();
    // 🔥 AUTO-REFRESH: Every time this screen opens, fetch the latest data from the hard drive!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NeuralController>(context, listen: false).loadDictionaries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Security Dashboard"),
          backgroundColor: Colors.blueGrey[900],
          foregroundColor: Colors.white,
          actions: [
            // 🔄 MANUAL REFRESH BUTTON (Press this if a text arrives while looking at the screen)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Refresh Data",
              onPressed: () {
                Provider.of<NeuralController>(context, listen: false).loadDictionaries();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Data Refreshed!"), duration: Duration(seconds: 1)),
                );
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.cyanAccent,
            tabs: [
              Tab(icon: Icon(Icons.security), text: "Authorized Owners"),
              Tab(icon: Icon(Icons.warning_amber), text: "Third Parties"),
            ],
          ),
        ),
        // Consumer automatically rebuilds the lists when data changes in the controller
        body: Consumer<NeuralController>(
          builder: (context, controller, child) {
            return TabBarView(
              children: [
                _buildOwnersTab(controller.getDic1),
                _buildThirdPartiesTab(controller.getDic2),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // 🟢 TAB 1: AUTHORIZED OWNERS (dic1)
  // ==========================================
  Widget _buildOwnersTab(Map<String, dynamic> dic1) {
    if (dic1.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.shield_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No Authorized Owners yet.", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: dic1.keys.length,
      itemBuilder: (context, index) {
        String ownerNumber = dic1.keys.elementAt(index);
        var data = dic1[ownerNumber];
        
        bool isExpired = data['code'] == "EXPIRED";

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: isExpired ? Colors.red.shade100 : Colors.green.shade100,
                child: Icon(Icons.person, color: isExpired ? Colors.red : Colors.green),
              ),
              title: Text(
                ownerNumber, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Secret Code: ${data['code']}", style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text("Code Leaked to Strangers: ${data['leak_count'] ?? 0} times"),
                  ],
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isExpired ? Colors.red : Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isExpired ? "EXPIRED" : "ACTIVE",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 🔴 TAB 2: THIRD PARTIES (dic2)
  // ==========================================
  Widget _buildThirdPartiesTab(Map<String, dynamic> dic2) {
    if (dic2.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.gpp_good_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No third-party leaks detected.", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: dic2.keys.length,
      itemBuilder: (context, index) {
        String strangerNumber = dic2.keys.elementAt(index);
        var data = dic2[strangerNumber];
        
        bool isBlocked = data['status'] == "BLOCKED";

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: isBlocked ? Colors.grey.shade300 : Colors.orange.shade100,
                child: Icon(Icons.privacy_tip, color: isBlocked ? Colors.grey : Colors.orange.shade800),
              ),
              title: Text(
                strangerNumber, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Using Code Of: ${data['used_code_of']}", style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text("Requests Made: ${data['request_count'] ?? 0}"),
                  ],
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isBlocked ? Colors.grey : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isBlocked ? "BLOCKED" : "ACTIVE",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}