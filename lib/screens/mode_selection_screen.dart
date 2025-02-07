import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'master_screen.dart';
import 'client_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  Future<String?> _getLocalIpAddress() async {
    try {
      debugPrint('Attempting to get IP address...');
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      debugPrint('Got IP address: $ip');
      return ip;
    } catch (e) {
      debugPrint('Error getting IP address: $e');
      // Default to localhost for testing
      return '127.0.0.1';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Theme.of(context).primaryColor.withOpacity(0.3),
              Colors.black,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'NIXIE NETWORK CLOCK',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Color(0xFFFF6B00),
                ),
              ),
              const SizedBox(height: 60),
              _ModeButton(
                title: 'MASTER MODE',
                subtitle: 'Control all displays',
                icon: Icons.watch_later,
                onTap: () async {
                  final ipAddress = await _getLocalIpAddress();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => MasterScreen(localIp: ipAddress ?? '127.0.0.1'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              _ModeButton(
                title: 'CLIENT MODE',
                subtitle: 'Single digit display',
                icon: Icons.display_settings,
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const ClientScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
