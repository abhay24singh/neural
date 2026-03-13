import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

void main() => runApp(const MaterialApp(home: NeuralGateApp(), debugShowCheckedModeBanner: false));

class NeuralGateApp extends StatefulWidget {
  const NeuralGateApp({super.key});
  @override
  State<NeuralGateApp> createState() => _NeuralGateAppState();
}

class _NeuralGateAppState extends State<NeuralGateApp> {
  double focusPower = 0.0, threshold = 150.0, graphMax = 200.0;

  bool isAutoMode = false;
  bool isConnected = false;

  String selectedDeviceIp = "192.168.4.1";
  String selectedTarget = "Relay";

  List<dynamic> connectedDevices = [
    {"name": "Master Node", "ip": "192.168.4.1"}
  ];

  List<FlSpot> graphPoints = [];
  List<double> signalBuffer = [];

  double xValue = 0;

  Timer? dataTimer;
  Timer? deviceTimer;

  @override
  void initState() {
    super.initState();

    dataTimer =
        Timer.periodic(const Duration(milliseconds: 150), (t) => fetchData());

    deviceTimer =
        Timer.periodic(const Duration(seconds: 5), (t) => fetchDeviceList());
  }

  Future<void> triggerSOS() async {
    final Uri smsUri = Uri(
        scheme: 'sms',
        path: '91XXXXXXXXXX',
        queryParameters: {'body': 'NeuralGate SOS!'});

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  Future<void> fetchDeviceList() async {
    try {
      final res = await http
          .get(Uri.parse('http://192.168.4.1/devices'))
          .timeout(const Duration(seconds: 2));

      if (res.statusCode == 200) {
        setState(() {
          connectedDevices = json.decode(res.body);
        });
      }
    } catch (e) {
      print("Scan Error: $e");
    }
  }

  void manualTrigger() {
    http.get(Uri.parse('http://$selectedDeviceIp/manual'));
  }

  void handleBrainTrigger() {
    if (selectedTarget == "Relay") {
      http.get(Uri.parse('http://$selectedDeviceIp/manual'));
    } else {
      print("Phone Triggered");
    }
  }

  Future<void> fetchData() async {
    try {
      final res = await http
          .get(Uri.parse('http://192.168.4.1/status'))
          .timeout(const Duration(milliseconds: 100));

      if (res.statusCode == 200) {
        double val = double.parse(res.body);

        setState(() {
          focusPower = val;
          isConnected = true;

          if (isAutoMode) {
            signalBuffer.add(focusPower);

            if (signalBuffer.length > 40) {
              signalBuffer.removeAt(0);
            }

            threshold =
                (signalBuffer.reduce((a, b) => a + b) / signalBuffer.length) *
                    1.7;

            http.get(Uri.parse(
                'http://192.168.4.1/setTh?v=${threshold.toInt()}'));
          }

          if (focusPower > threshold) {
            handleBrainTrigger();
          }

          graphMax =
              (graphMax * 0.95) + (max(focusPower, threshold) * 1.1 * 0.05);

          graphPoints.add(FlSpot(xValue++, focusPower));

          if (graphPoints.length > 50) {
            graphPoints.removeAt(0);
          }
        });
      }
    } catch (e) {
      setState(() => isConnected = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF0D0D0F),
        appBar: AppBar(
          title: const Text("NEURAL GATE PRO",
              style: TextStyle(fontSize: 14, letterSpacing: 2)),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
                icon: const Icon(Icons.sos, color: Colors.redAccent),
                onPressed: triggerSOS)
          ],
        ),
        body: Column(children: [
          Expanded(
              flex: 3,
              child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: LineChart(LineChartData(
                      minY: 0,
                      maxY: graphMax,
                      lineBarsData: [
                        LineChartBarData(
                            spots: graphPoints,
                            isCurved: true,
                            color: Colors.blueAccent,
                            barWidth: 4,
                            dotData: const FlDotData(show: false))
                      ],
                      extraLinesData: ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                            y: threshold,
                            color: Colors.redAccent.withOpacity(0.4),
                            strokeWidth: 2,
                            dashArray: [10, 5])
                      ]),
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false))))),
          Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                  color: Color(0xFF161618),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(40))),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("ACTIVE NODES",
                          style:
                              TextStyle(color: Colors.white24, fontSize: 10)),
                      DropdownButton<String>(
                        value: selectedDeviceIp,
                        dropdownColor: const Color(0xFF161618),
                        underline: const SizedBox(),
                        style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold),
                        items: connectedDevices
                            .map((d) => DropdownMenuItem<String>(
                                value: d['ip'], child: Text(d['name'])))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => selectedDeviceIp = v!),
                      )
                    ]),
                const SizedBox(height: 10),
                ElevatedButton(
                    onPressed: manualTrigger,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent),
                    child: const Text("MANUAL TRIGGER")),
                const SizedBox(height: 10),
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ["Relay", "Phone"]
                        .map((t) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: ChoiceChip(
                                  label: Text(t),
                                  selected: selectedTarget == t,
                                  onSelected: (s) =>
                                      setState(() => selectedTarget = t)),
                            ))
                        .toList()),
                SwitchListTile(
                    title: const Text("ADAPTIVE MODE",
                        style:
                            TextStyle(color: Colors.white, fontSize: 12)),
                    value: isAutoMode,
                    onChanged: (v) => setState(() => isAutoMode = v),
                    activeColor: Colors.blueAccent),
                if (!isAutoMode)
                  Slider(
                      value: threshold.clamp(10, 400),
                      min: 10,
                      max: 400,
                      activeColor: Colors.blueAccent,
                      onChanged: (v) {
                        setState(() => threshold = v);

                        http.get(Uri.parse(
                            'http://192.168.4.1/setTh?v=${v.toInt()}'));
                      }),
                Text(focusPower.toStringAsFixed(2),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 45,
                        fontWeight: FontWeight.bold))
              ]))
        ]));
  }
}