import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error
}

class WebSocketService extends ChangeNotifier {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _errorMessage = '';
  WebSocket? _serverSocket;
  WebSocketChannel? _clientChannel;
  final List<WebSocket> _clients = [];
  final StreamController<String> _timeController = StreamController<String>.broadcast();
  Timer? _broadcastTimer;

  ConnectionStatus get status => _status;
  String get errorMessage => _errorMessage;
  Stream<String> get timeStream => _timeController.stream;
  int get connectedClients => _clients.length;

  // Master mode methods
  Future<void> startServer(int port) async {
    try {
      _status = ConnectionStatus.connecting;
      notifyListeners();

      final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      debugPrint('WebSocket server listening on ws://localhost:$port');

      server.listen((HttpRequest request) {
        WebSocketTransformer.upgrade(request).then((WebSocket ws) {
          _handleClientConnection(ws);
        });
      });

      _status = ConnectionStatus.connected;
      _startBroadcasting();
      notifyListeners();
    } catch (e) {
      _status = ConnectionStatus.error;
      _errorMessage = 'Failed to start server: $e';
      notifyListeners();
      rethrow;
    }
  }

  void _handleClientConnection(WebSocket ws) {
    _clients.add(ws);
    notifyListeners();

    ws.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          debugPrint('Received from client: $data');
        } catch (e) {
          debugPrint('Error handling message: $e');
        }
      },
      onDone: () {
        _clients.remove(ws);
        notifyListeners();
      },
      onError: (error) {
        debugPrint('WebSocket error: $error');
        _clients.remove(ws);
        notifyListeners();
      },
    );
  }

  void _startBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_clients.isEmpty) return;

      final timeString = DateTime.now().toString();
      final message = jsonEncode({
        'type': 'time',
        'value': timeString,
      });

      for (final client in List.from(_clients)) {
        try {
          client.add(message);
        } catch (e) {
          debugPrint('Error sending to client: $e');
          _clients.remove(client);
          notifyListeners();
        }
      }
    });
  }

  // Client mode methods
  Future<void> connectToServer(String serverIp, int port, int position) async {
    try {
      _status = ConnectionStatus.connecting;
      notifyListeners();

      final wsUrl = Uri.parse('ws://$serverIp:$port');
      _clientChannel = WebSocketChannel.connect(wsUrl);

      // Send connection message with digit position
      _clientChannel?.sink.add(jsonEncode({
        'type': 'connect',
        'position': position,
      }));

      _clientChannel?.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'time') {
              _timeController.add(data['value']);
            }
          } catch (e) {
            debugPrint('Error handling message: $e');
          }
        },
        onDone: () {
          _status = ConnectionStatus.disconnected;
          notifyListeners();
        },
        onError: (error) {
          _status = ConnectionStatus.error;
          _errorMessage = 'Connection error: $error';
          notifyListeners();
        },
      );

      _status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      _status = ConnectionStatus.error;
      _errorMessage = 'Failed to connect: $e';
      notifyListeners();
      rethrow;
    }
  }

  void disconnect() {
    _clientChannel?.sink.close();
    _clientChannel = null;
    _serverSocket?.close();
    _serverSocket = null;
    _broadcastTimer?.cancel();
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _timeController.close();
    super.dispose();
  }
}
