import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/settings_service.dart';
import '../services/websocket_service.dart';

class MasterScreen extends StatefulWidget {
  final String localIp;

  const MasterScreen({super.key, required this.localIp});

  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> with SingleTickerProviderStateMixin {
  late DateTime _currentTime;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _timer;
  bool _showQrCode = false;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _startServer();
    _startTimer();

    // Setup pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseController.repeat(reverse: true);
  }

  void _startServer() async {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final websocket = Provider.of<WebSocketService>(context, listen: false);
    
    try {
      await websocket.startServer(settings.serverPort);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start server: $e'),
            backgroundColor: Colors.red[900],
          ),
        );
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    final websocket = Provider.of<WebSocketService>(context, listen: false);
    websocket.disconnect();
    super.dispose();
  }

  void _toggleQrCode() {
    setState(() {
      _showQrCode = !_showQrCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _currentTime.toString().split(' ')[1].substring(0, 8);
    final hours = timeStr.substring(0, 2);
    final minutes = timeStr.substring(3, 5);
    final seconds = timeStr.substring(6, 8);
    final websocket = Provider.of<WebSocketService>(context);
    final settings = Provider.of<SettingsService>(context);

    // Create connection data for QR code
    final connectionData = {
      'ip': widget.localIp,
      'port': settings.serverPort,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Mode'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showQrCode ? Icons.watch_later : Icons.qr_code,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: _toggleQrCode,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Theme.of(context).primaryColor.withOpacity(0.2),
              Colors.black,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_showQrCode) ...[
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.2),
                            blurRadius: _pulseAnimation.value * 20,
                            spreadRadius: _pulseAnimation.value * 2,
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTimeSegment(context, hours),
                            _buildSeparator(context),
                            _buildTimeSegment(context, minutes),
                            _buildSeparator(context),
                            _buildTimeSegment(context, seconds),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        data: connectionData.toString(),
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Scan to Connect',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              Text(
                'Server IP: ${widget.localIp}',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              Text(
                'Connected Clients: ${websocket.connectedClients}',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  websocket.status == ConnectionStatus.connected
                      ? websocket.connectedClients > 0
                          ? 'Broadcasting time to connected clients'
                          : 'Tap the QR code icon to show connection code'
                      : 'Server status: ${websocket.status}',
                  style: TextStyle(
                    fontSize: 16,
                    color: websocket.status == ConnectionStatus.error
                        ? Colors.red[400]
                        : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSegment(BuildContext context, String segment) {
    return Container(
      width: 80,
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).primaryColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          segment,
          style: TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
            shadows: [
              Shadow(
                color: Theme.of(context).primaryColor.withOpacity(0.8),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeparator(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 60,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
          shadows: [
            Shadow(
              color: Theme.of(context).primaryColor.withOpacity(0.8),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}
