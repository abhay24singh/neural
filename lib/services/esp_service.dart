import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class EspService {
  final String host;
  WebSocketChannel? _channel;
  final StreamController<double> _dataController = StreamController<double>.broadcast();
  bool _isConnecting = false;
  Timer? _reconnectTimer;

  EspService({required this.host}) {
    _connect();
  }

  Stream<double> get signalStream => _dataController.stream;

  void _connect() {
    if (_isConnecting) return;
    _isConnecting = true;

    print("Connecting to ws://$host/ws...");
    _channel = WebSocketChannel.connect(Uri.parse("ws://$host/ws"));

    _channel!.stream.listen(
      (msg) {
        _isConnecting = false;
        try {
          final data = jsonDecode(msg);
          _dataController.add((data['p'] as num).toDouble());
        } catch (e) {
          _dataController.add(0.0);
        }
      },
      onDone: () => _handleReconnect(),
      onError: (e) => _handleReconnect(),
    );
  }

  void _handleReconnect() {
    _isConnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () => _connect());
  }

  Future<void> sendCommand(String path) async {
    try {
      await http.get(Uri.parse("http://$host$path")).timeout(const Duration(milliseconds: 500));
    } catch (e) {
      print("Command failed: $e");
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _dataController.close();
  }
}