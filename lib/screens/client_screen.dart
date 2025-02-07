import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/settings_service.dart';
import '../services/websocket_service.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  String _currentDigit = '0';
  final bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _glowAnimation = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    final websocket = Provider.of<WebSocketService>(context, listen: false);
    websocket.disconnect();
    super.dispose();
  }

  void _connectToServer(String ip, int port) async {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final websocket = Provider.of<WebSocketService>(context, listen: false);

    try {
      await websocket.connectToServer(
        ip,
        port,
        settings.digitPosition,
      );

      // Listen for time updates
      websocket.timeStream.listen((timeStr) {
        final digit = _extractDigit(timeStr, settings.digitPosition);
        setState(() {
          _currentDigit = digit;
        });
      });

      settings.serverIp = ip;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red[900],
          ),
        );
      }
    }
  }

  String _extractDigit(String timeStr, int position) {
    final timeDigits = timeStr.replaceAll(RegExp(r'[^0-9]'), '');
    if (position >= 0 && position < timeDigits.length) {
      return timeDigits[position];
    }
    return '0';
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  void _showScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scan QR Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Container(
                height: 300,
                width: 300,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      try {
                        final data = barcode.rawValue;
                        if (data != null) {
                          // Parse connection data from QR code
                          final cleanData = data.replaceAll(RegExp(r'[{}]'), '');
                          final parts = cleanData.split(',');
                          String? ip;
                          int? port;
                          
                          for (final part in parts) {
                            final keyValue = part.trim().split(':');
                            if (keyValue.length == 2) {
                              final key = keyValue[0].trim();
                              final value = keyValue[1].trim();
                              if (key == 'ip') {
                                ip = value;
                              } else if (key == 'port') {
                                port = int.tryParse(value);
                              }
                            }
                          }

                          if (ip != null && port != null) {
                            Navigator.pop(context);
                            _connectToServer(ip, port);
                          }
                        }
                      } catch (e) {
                        debugPrint('Error parsing QR code: $e');
                      }
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Point camera at QR code shown on master device',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    final websocket = Provider.of<WebSocketService>(context);
    final isConnected = websocket.status == ConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Mode'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              settings.glowColor.withOpacity(0.2),
              Colors.black,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: websocket.status != ConnectionStatus.connecting
                          ? _showScannerDialog
                          : null,
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      color: Colors.grey[400],
                      onPressed: _showSettingsDialog,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: settings.glowColor.withOpacity(0.2 * settings.brightness),
                              blurRadius: _glowAnimation.value * 20,
                              spreadRadius: _glowAnimation.value * 2,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/nixie_tube.svg',
                              width: 200,
                              height: 400,
                              colorFilter: ColorFilter.mode(
                                settings.glowColor,
                                BlendMode.srcIn,
                              ),
                            ),
                            Text(
                              _currentDigit,
                              style: TextStyle(
                                fontSize: 120,
                                fontWeight: FontWeight.bold,
                                color: settings.glowColor,
                                shadows: [
                                  Shadow(
                                    color: settings.glowColor.withOpacity(0.8 * settings.brightness),
                                    blurRadius: _glowAnimation.value * 10,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Position: ${settings.getDigitName(settings.digitPosition)}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (websocket.status == ConnectionStatus.error)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          websocket.errorMessage,
                          style: TextStyle(
                            color: Colors.red[400],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.settings, size: 24),
          const SizedBox(width: 8),
          const Text('Display Settings'),
        ],
      ),
      backgroundColor: Colors.grey[900],
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Digit Position',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select which digit this device should display:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[800]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Time Format: HH:MM:SS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(6, (index) {
                      final isSelected = settings.digitPosition == index;
                      return InkWell(
                        onTap: () => settings.digitPosition = index,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? settings.glowColor.withOpacity(0.2) : Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? settings.glowColor : Colors.grey[700]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                settings.getShortDigitName(index),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? settings.glowColor : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                settings.getDigitExample(index),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white70 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Display Options',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.brightness_6, size: 20),
                const SizedBox(width: 8),
                const Text('Brightness'),
              ],
            ),
            Slider(
              value: settings.brightness,
              onChanged: (value) => settings.brightness = value,
              activeColor: settings.glowColor,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.palette, size: 20),
                const SizedBox(width: 8),
                const Text('Glow Color'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ColorButton(
                  color: const Color(0xFFFF6B00),
                  isSelected: settings.glowColor.value == const Color(0xFFFF6B00).value,
                  onTap: () => settings.glowColor = const Color(0xFFFF6B00),
                ),
                _ColorButton(
                  color: Colors.blue,
                  isSelected: settings.glowColor.value == Colors.blue.value,
                  onTap: () => settings.glowColor = Colors.blue,
                ),
                _ColorButton(
                  color: Colors.green,
                  isSelected: settings.glowColor.value == Colors.green.value,
                  onTap: () => settings.glowColor = Colors.green,
                ),
                _ColorButton(
                  color: Colors.purple,
                  isSelected: settings.glowColor.value == Colors.purple.value,
                  onTap: () => settings.glowColor = Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.restore),
          label: const Text('Reset'),
          onPressed: () {
            settings.resetToDefaults();
            Navigator.pop(context);
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Done'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
